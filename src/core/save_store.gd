class_name SaveStore
extends RefCounted
## Crash-safe, versioned JSON persistence for settings and campaign progress.
##
## Follows the save-systems playbook: plain data only (never node paths or engine objects), a
## `version` field on every file, an atomic temp-write + rename so a crash can never leave a
## half-written save, and a defensive load that migrates old versions and falls back to the
## backup when the primary file is corrupt.

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://bulwark_save.json"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func backup_path() -> String:
	return path + ".bak"


## Explains the most recent load/save problem ("" when everything went fine).
var last_error: String = ""


## Loads the save file, returning a `{version, settings, progress}` dictionary.
## Never throws: on any problem the defaults are returned and `last_error` explains why.
func load_data() -> Dictionary:
	var raw := _read_json(path)
	if raw.is_empty():
		raw = _read_json(backup_path())
		if not raw.is_empty():
			last_error = "recovered from backup"
	if raw.is_empty():
		return empty_state()
	return migrate(raw)


func save_data(settings: Dictionary, progress: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"settings": settings,
		"progress": progress,
		"meta": {"saved_at": Time.get_unix_time_from_system(), "game": "bulwark"},
	}
	# Keep the previous good file as a backup before replacing it.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup_path()))
	return _write_json_atomic(path, payload)


static func empty_state() -> Dictionary:
	return {"version": SAVE_VERSION, "settings": {}, "progress": empty_progress()}


static func empty_progress() -> Dictionary:
	return {"levels": {}, "total_stars": 0}


## Brings an older save up to the current schema. Each step is additive so future versions
## can be migrated by appending one block.
func migrate(raw: Dictionary) -> Dictionary:
	var version := int(raw.get("version", 0))
	var out := empty_state()
	out["settings"] = raw.get("settings", {}) if raw.get("settings") is Dictionary else {}
	var progress: Variant = raw.get("progress", {})
	out["progress"] = progress if progress is Dictionary else empty_progress()
	if not out["progress"].has("levels"):
		out["progress"]["levels"] = {}
	if version < 1:
		# v0 files (pre-release builds) had no star map; nothing to move, just stamp it.
		out["version"] = 1
		version = 1
	out["version"] = SAVE_VERSION
	return out


func _read_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var text := FileAccess.get_file_as_string(file_path)
	if text.strip_edges().is_empty():
		last_error = "empty save file"
		return {}
	# `JSON.new().parse()` returns an error code instead of printing to the console, so a
	# corrupt save is a handled case rather than alarming noise in the player's log.
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		last_error = "corrupt save file: %s" % json.get_error_message()
		return {}
	return json.data as Dictionary


## Writes to `<path>.tmp`, flushes, then renames over the target. Rename is atomic on the
## platforms we ship to, so the save is either the old file or the new one.
func _write_json_atomic(file_path: String, payload: Dictionary) -> bool:
	var tmp := file_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		last_error = "cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		return false
	file.store_string(JSON.stringify(payload, "\t", false))
	file.flush()
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(file_path))
	if err != OK:
		last_error = "rename failed: %s" % error_string(err)
		return false
	last_error = ""
	return true


## Deletes all persisted data (used by the "reset progress" button).
func wipe() -> void:
	for target in [path, backup_path(), path + ".tmp"]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
