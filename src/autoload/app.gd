extends Node
## Global application service: settings, campaign progress, screen navigation, pause.
##
## Everything that outlives a single scene lives here. Screens never talk to each other
## directly — they route through `App`, which keeps the scene graph shallow and testable (a
## screen can be opened on its own without a menu in front of it).
##
## Autoload name: `App`.

signal settings_changed(key: String, value: Variant)
signal progress_changed()
signal paused_changed(is_paused: bool)
signal save_transfer_done(action: String, message: String)

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const SETTINGS_SCENE := "res://scenes/settings_screen.tscn"
const CREDITS_SCENE := "res://scenes/credits_screen.tscn"
const ACHIEVEMENTS_SCENE := "res://scenes/achievements_screen.tscn"

var settings := SettingsModel.new()
var progress: Dictionary = SaveStore.empty_progress()

## Level the "Play" button should start (set by the mission select screen).
var pending_level: int = 0

## Screen stack, used for overlays (pause, settings) that must return to what was underneath.
var _stack: Array[String] = []
var _store := SaveStore.new()
var _achievements: Achievements = Achievements.new()
var _perf_overlay: PerfOverlay
var _save_timer: Timer
var _is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.8
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	_perf_overlay = PerfOverlay.new()
	add_child(_perf_overlay)
	_apply_all_settings()


func _notification(what: int) -> void:
	# Mobile: never lose progress when the player backgrounds the app.
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			_flush_save()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			Audio.duck(true)
		NOTIFICATION_PREDELETE:
			ThemeFactory.clear_cache()


# --- Persistence -----------------------------------------------------------------------------

func _load() -> void:
	var data := _store.load_data()
	settings = SettingsModel.new(data.get("settings", {}))
	if not settings.get_value("tutorial_seen"):
		settings.set_value("language", SettingsModel.system_language())
	progress = data.get("progress", SaveStore.empty_progress())
	_achievements = Achievements.new(progress.get("achievements", []) as Array)
	# Re-evaluate against the loaded profile: newly-met criteria unlock on load too.
	_evaluate_achievements(_build_achievement_snapshot({}))
	if _store.last_error != "":
		push_warning("SaveStore: %s" % _store.last_error)


## Queues a save. Rapid changes (dragging a slider) collapse into one write.
func request_save() -> void:
	if _save_timer == null:
		return
	_save_timer.start()


func _flush_save() -> void:
	_store.save_data(settings.to_dict(), progress)
	if _store.last_error != "":
		push_warning("SaveStore: %s" % _store.last_error)


# --- Settings ---------------------------------------------------------------------------------

func get_setting(key: String) -> Variant:
	return settings.get_value(key)


func set_setting(key: String, value: Variant) -> void:
	settings.set_value(key, value)
	_apply_one(key)
	settings_changed.emit(key, settings.get_value(key))
	request_save()


func reset_settings() -> void:
	settings.reset()
	_apply_all_settings()
	request_save()


func _apply_all_settings() -> void:
	Loc.set_language(String(settings.get_value("language")))
	Audio.apply_volumes(
		float(settings.get_value("master_volume")),
		float(settings.get_value("music_volume")),
		float(settings.get_value("sfx_volume")))
	for key in settings.data.keys():
		settings_changed.emit(String(key), settings.get_value(String(key)))
	if _perf_overlay != null:
		_perf_overlay.set_enabled(bool(settings.get_value("perf_overlay")))


func _apply_one(key: String) -> void:
	match key:
		"language":
			Loc.set_language(String(settings.get_value("language")))
		"master_volume", "music_volume", "sfx_volume":
			Audio.apply_volumes(
				float(settings.get_value("master_volume")),
				float(settings.get_value("music_volume")),
				float(settings.get_value("sfx_volume")))
		"perf_overlay":
			if _perf_overlay != null:
				_perf_overlay.set_enabled(bool(settings.get_value("perf_overlay")))


func difficulty() -> int:
	return int(settings.get_value("difficulty"))


# --- Campaign progress -------------------------------------------------------------------------

func level_progress(level_id: String) -> Dictionary:
	var levels: Dictionary = progress.get("levels", {})
	return levels.get(level_id, {"stars": 0, "best_wave": 0, "cleared": false})


func is_level_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var previous := GameData.level(index - 1)
	if previous.is_empty():
		return true
	return bool(level_progress(String(previous.get("id", ""))).get("cleared", false))


func total_stars() -> int:
	var sum := 0
	for key in (progress.get("levels", {}) as Dictionary).keys():
		sum += int(level_progress(String(key)).get("stars", 0))
	return sum


## Records a finished run. Stars and best wave only ever improve. `run_stats` carries per-run
## facts (towers built, bosses killed, lives lost, ability uses) used for achievement checks.
func record_result(level_index: int, stars: int, wave_reached: int, cleared: bool,
	run_stats: Dictionary = {}) -> Dictionary:
	var level := GameData.level(level_index)
	var level_id := String(level.get("id", ""))
	var levels: Dictionary = progress.get("levels", {})
	var entry: Dictionary = levels.get(level_id, {"stars": 0, "best_wave": 0, "cleared": false})
	var previous_stars := int(entry.get("stars", 0))
	entry["stars"] = maxi(previous_stars, stars)
	entry["best_wave"] = maxi(int(entry.get("best_wave", 0)), wave_reached)
	entry["cleared"] = bool(entry.get("cleared", false)) or cleared
	if cleared and int(run_stats.get("lives_lost", 0)) == 0:
		entry["flawless"] = true
	levels[level_id] = entry
	progress["levels"] = levels
	if String(level.get("mode", "")) == "endless":
		progress["endless_best_wave"] = maxi(int(progress.get("endless_best_wave", 0)), wave_reached)
	progress_changed.emit()
	request_save()
	_evaluate_achievements(_build_achievement_snapshot(run_stats))
	return {"entry": entry, "new_best_stars": int(entry["stars"]) > previous_stars}


## Accessor for the achievement engine (read-only usage for screens).
func achievements() -> Achievements:
	return _achievements


## Builds the fact snapshot the achievement checks read. Persisted facts come from progress;
## `run_stats` adds the per-run numbers a single session accumulates.
func _build_achievement_snapshot(run_stats: Dictionary) -> Dictionary:
	var levels: Dictionary = progress.get("levels", {})
	var levels_cleared := 0
	var stars_earned := 0
	var max_stars := 0
	var flawless_levels: Array = []
	for key in levels.keys():
		var e: Variant = levels[key]
		if bool(e.get("cleared", false)):
			levels_cleared += 1
		if bool(e.get("flawless", false)):
			flawless_levels.append(key)
		var s := int(e.get("stars", 0))
		stars_earned += s
		max_stars = maxi(max_stars, s)
	return {
		"levels_cleared": levels_cleared,
		"max_stars": max_stars,
		"stars_earned": stars_earned,
		"total_stars": GameData.total_stars(),
		"total_levels": GameData.campaign_level_count(),
		"best_wave_endless": int(progress.get("endless_best_wave", 0)),
		"flawless_levels": flawless_levels,
		"towers_in_run": int(run_stats.get("towers_built", 0)),
		"bosses_killed": run_stats.get("bosses_killed", []),
		"total_ability_uses": int(run_stats.get("ability_uses", 0)),
	}


## Evaluates the snapshot, persists newly-unlocked ids, and returns the ids unlocked now.
func _evaluate_achievements(snapshot: Dictionary) -> Array[String]:
	var newly := _achievements.evaluate(snapshot)
	if not newly.is_empty():
		progress["achievements"] = _achievements.to_store()
		progress_changed.emit()
		request_save()
	return newly


func reset_progress() -> void:
	progress = SaveStore.empty_progress()
	progress_changed.emit()
	request_save()


# --- Save transfer (export / import) -------------------------------------------------------------

## Exports the current save to a file the player picks (desktop) or a fixed path (mobile/web).
func export_save() -> void:
	_open_save_dialog("export")


## Imports a save file into the current profile, replacing settings and progress.
func import_save() -> void:
	_open_save_dialog("import")


func _open_save_dialog(action: String) -> void:
	# Godot 4.7's file dialog is callback-based: (title, directory, filename, show_hidden,
	# mode, filters, callback). On headless/mobile it returns ERR_UNAVAILABLE and never calls
	# the callback, so the return code selects the file-based fallback path.
	var mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if action == "export" \
		else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
	var err := DisplayServer.file_dialog_show(
		Loc.t("settings.save_data"), "", "", false, mode, ["*.json"],
		func(paths: PackedStringArray, p_err: int) -> void:
			_on_save_dialog_result(action, paths, p_err))
	if err != OK:
		save_transfer_done.emit(action, _save_transfer_fallback(action))


## Handles the file-dialog callback: a non-empty path list means the player chose a file.
func _on_save_dialog_result(action: String, paths: PackedStringArray, err: int) -> void:
	if err != OK or paths.is_empty():
		return  # the player cancelled, or the dialog failed
	_finish_save_transfer(action, String(paths[0]))


## Non-desktop fallback: write/read a fixed path reachable through the OS file manager.
func _save_transfer_fallback(action: String) -> String:
	var target := "user://bulwark_save_%s.json" % action
	if action == "export":
		var err := _store.export_to(target, settings.to_dict(), progress)
		return err if not err.is_empty() else Loc.t("settings.save_exported")
	var data := _store.import_from(target)
	if data.is_empty():
		return Loc.t("settings.save_failed")
	_apply_imported(data)
	return Loc.t("settings.save_imported")


## Replaces the in-memory profile with an imported save and persists it.
func _apply_imported(data: Dictionary) -> void:
	settings = SettingsModel.new(data.get("settings", {}))
	_apply_all_settings()
	progress = data.get("progress", SaveStore.empty_progress())
	if not progress.has("levels"):
		progress["levels"] = {}
	progress_changed.emit()
	request_save()


func _finish_save_transfer(action: String, selected_path: String) -> void:
	if action == "export":
		var err := _store.export_to(selected_path, settings.to_dict(), progress)
		save_transfer_done.emit("export", err if not err.is_empty() else Loc.t("settings.save_exported"))
	else:
		var data := _store.import_from(selected_path)
		if data.is_empty():
			save_transfer_done.emit("import", Loc.t("settings.save_failed"))
		else:
			_apply_imported(data)
			save_transfer_done.emit("import", Loc.t("settings.save_imported"))


# --- Navigation --------------------------------------------------------------------------------

## Replaces the current screen (menu -> level select -> game).
func goto_scene(path: String) -> void:
	_stack.clear()
	set_paused(false)
	get_tree().change_scene_to_file(path)


## Opens a screen on top of the current one; `pop()` returns to it.
func push_scene(path: String) -> void:
	_stack.append(path)
	get_tree().change_scene_to_file(path)


func pop_scene() -> void:
	if _stack.size() >= 2:
		_stack.pop_back()
		get_tree().change_scene_to_file(_stack.pop_back() if not _stack.is_empty() else MENU_SCENE)
	else:
		goto_scene(MENU_SCENE)


func start_level(index: int) -> void:
	pending_level = clampi(index, 0, maxi(0, GameData.level_count() - 1))
	_stack = [MENU_SCENE, LEVEL_SELECT_SCENE, GAME_SCENE]
	goto_scene(GAME_SCENE)


func open_settings(from_path: String = "") -> void:
	_stack.append(from_path if from_path != "" else MENU_SCENE)
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func open_credits() -> void:
	push_scene(CREDITS_SCENE)


# --- Pause -------------------------------------------------------------------------------------

func set_paused(value: bool) -> void:
	_is_paused = value
	get_tree().paused = value
	paused_changed.emit(value)


func is_paused() -> bool:
	return _is_paused


func quit() -> void:
	_flush_save()
	ThemeFactory.clear_cache()
	get_tree().quit()
