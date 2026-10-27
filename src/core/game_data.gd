class_name GameData
extends RefCounted
## Loads and validates the JSON content database (towers, enemies, levels).
##
## Everything the game knows about content is data: adding a tower or an enemy never requires
## touching gameplay code, only a JSON entry plus a sprite. The database is loaded once and
## cached statically; `validate()` is exercised by the test suite so a typo in the data fails
## loudly in CI instead of quietly in a level.

const TOWERS_PATH := "res://data/towers.json"
const ENEMIES_PATH := "res://data/enemies.json"
const LEVELS_DIR := "res://data/levels"

const REQUIRED_TOWER_KEYS: Array[String] = [
	"cost", "kind", "damage_type", "range", "damage", "fire_rate", "levels",
]
const REQUIRED_ENEMY_KEYS: Array[String] = ["hp", "speed", "gold", "lives", "radius", "sprite"]
const REQUIRED_LEVEL_KEYS: Array[String] = [
	"id", "grid", "path", "start_gold", "prep_time", "hp_mult", "waves",
]

static var _towers: Dictionary = {}
static var _enemies: Dictionary = {}
static var _levels: Array[Dictionary] = []
static var _errors: Array[String] = []


# --- Loading ---------------------------------------------------------------------------------

static func _ensure_loaded() -> void:
	if not _towers.is_empty():
		return
	_errors.clear()
	_towers = _load_object(TOWERS_PATH)
	_enemies = _load_object(ENEMIES_PATH)
	_levels = _load_levels()
	validate()


static func _load_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("missing file: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_errors.append("invalid JSON object: %s" % path)
		return {}
	return parsed as Dictionary


static func _load_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		_errors.append("missing levels directory: %s" % LEVELS_DIR)
		return levels
	dir.list_dir_begin()
	var names: Array[String] = []
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()  # level_01, level_02, ... deterministic order
	for name in names:
		var level := _load_object("%s/%s" % [LEVELS_DIR, name])
		if not level.is_empty():
			level["_file"] = name
			levels.append(level)
	return levels


# --- Public API ------------------------------------------------------------------------------

static func towers() -> Dictionary:
	_ensure_loaded()
	return _towers


static func tower_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for id in _towers.keys():
		ids.append(String(id))
	ids.sort()
	return ids


static func tower(id: String) -> Dictionary:
	_ensure_loaded()
	return _towers.get(id, {})


static func enemies() -> Dictionary:
	_ensure_loaded()
	return _enemies


static func enemy(id: String) -> Dictionary:
	_ensure_loaded()
	return _enemies.get(id, {})


static func levels() -> Array[Dictionary]:
	_ensure_loaded()
	return _levels


static func level_count() -> int:
	return levels().size()


static func level(index: int) -> Dictionary:
	var all := levels()
	if index < 0 or index >= all.size():
		return {}
	return all[index]


static func error_messages() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


# --- Validation ------------------------------------------------------------------------------

## Returns a list of human readable problems; empty means the database is sound.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for id in _towers.keys():
		var def: Dictionary = _towers[id]
		for key in REQUIRED_TOWER_KEYS:
			if not def.has(key):
				problems.append("tower '%s' is missing '%s'" % [id, key])
		if not def.has("sprite") or not ResourceLoader.exists(_sprite_path(def)):
			problems.append("tower '%s' has an unresolvable sprite" % id)
		var levels: Dictionary = def.get("levels", {})
		for curve in ["damage", "rate", "range"]:
			var arr: Array = levels.get(curve, [])
			if arr.size() < 3:
				problems.append("tower '%s' needs 3 values for levels.%s" % [id, curve])
		if def.get("kind", "") not in ["projectile", "beam", "aura"]:
			problems.append("tower '%s' has unknown kind '%s'" % [id, def.get("kind")])
	for id in _enemies.keys():
		var def: Dictionary = _enemies[id]
		for key in REQUIRED_ENEMY_KEYS:
			if not def.has(key):
				problems.append("enemy '%s' is missing '%s'" % [id, key])
		if not ResourceLoader.exists(_sprite_path({"sprite": def.get("sprite", "")}, "enemies")):
			problems.append("enemy '%s' has an unresolvable sprite" % id)
	for level in _levels:
		for key in REQUIRED_LEVEL_KEYS:
			if not level.has(key):
				problems.append("level '%s' is missing '%s'" % [level.get("id", "?"), key])
		if (level.get("path", []) as Array).size() < 2:
			problems.append("level '%s' path needs at least 2 waypoints" % level.get("id", "?"))
		if (level.get("waves", []) as Array).is_empty():
			problems.append("level '%s' has no waves" % level.get("id", "?"))
	return problems


static func _sprite_path(def: Dictionary, folder: String = "towers") -> String:
	return "res://assets/sprites/%s/%s.png" % [folder, def.get("sprite", "")]
