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

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const SETTINGS_SCENE := "res://scenes/settings_screen.tscn"
const CREDITS_SCENE := "res://scenes/credits_screen.tscn"

var settings := SettingsModel.new()
var progress: Dictionary = SaveStore.empty_progress()

## Level the "Play" button should start (set by the mission select screen).
var pending_level: int = 0

## Screen stack, used for overlays (pause, settings) that must return to what was underneath.
var _stack: Array[String] = []
var _store := SaveStore.new()
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


func _apply_one(key: String) -> void:
	match key:
		"language":
			Loc.set_language(String(settings.get_value("language")))
		"master_volume", "music_volume", "sfx_volume":
			Audio.apply_volumes(
				float(settings.get_value("master_volume")),
				float(settings.get_value("music_volume")),
				float(settings.get_value("sfx_volume")))


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


## Records a finished run. Stars and best wave only ever improve.
func record_result(level_index: int, stars: int, wave_reached: int, cleared: bool) -> Dictionary:
	var level := GameData.level(level_index)
	var level_id := String(level.get("id", ""))
	var levels: Dictionary = progress.get("levels", {})
	var entry: Dictionary = levels.get(level_id, {"stars": 0, "best_wave": 0, "cleared": false})
	var previous_stars := int(entry.get("stars", 0))
	entry["stars"] = maxi(previous_stars, stars)
	entry["best_wave"] = maxi(int(entry.get("best_wave", 0)), wave_reached)
	entry["cleared"] = bool(entry.get("cleared", false)) or cleared
	levels[level_id] = entry
	progress["levels"] = levels
	progress_changed.emit()
	request_save()
	return {"entry": entry, "new_best_stars": int(entry["stars"]) > previous_stars}


func reset_progress() -> void:
	progress = SaveStore.empty_progress()
	progress_changed.emit()
	request_save()


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
