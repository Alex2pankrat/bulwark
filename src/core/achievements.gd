class_name Achievements
extends RefCounted
## Defined, unlockable achievements and the engine that tracks progress toward them.
##
## Each achievement has an id, a localisation key (`ach.<id>.name` / `.desc`), an icon glyph and
## a check method. The game feeds a `snapshot` — a flat dictionary of facts (levels cleared,
## waves survived, towers built, abilities used, …) — and any achievement whose check passes is
## unlocked and persisted.
##
## Tracking is passive: a level end or save load calls `evaluate(snapshot)`, which unlocks
## anything newly satisfied. Because everything is driven off the same snapshot, adding an
## achievement is data plus one predicate — no per-event wiring.

signal unlocked(achievement: String)

## Achievement definitions. The predicate for each id is the method `_check_<id>`, dispatched by
## name at eval time — so the table is a plain const of display data (no Callables at parse time).
const DEFINITIONS := {
	"first_clear": {
		"title": "ach.first_clear.name",
		"desc": "ach.first_clear.desc",
		"icon": "star",
	},
	"three_star": {
		"title": "ach.three_star.name",
		"desc": "ach.three_star.desc",
		"icon": "star",
	},
	"no_leak": {
		"title": "ach.no_leak.name",
		"desc": "ach.no_leak.desc",
		"icon": "check",
	},
	"tower_master": {
		"title": "ach.tower_master.name",
		"desc": "ach.tower_master.desc",
		"icon": "grid",
	},
	"endless_10": {
		"title": "ach.endless_10.name",
		"desc": "ach.endless_10.desc",
		"icon": "wave",
	},
	"boss_slayer": {
		"title": "ach.boss_slayer.name",
		"desc": "ach.boss_slayer.desc",
		"icon": "skull",
	},
	"collection": {
		"title": "ach.collection.name",
		"desc": "ach.collection.desc",
		"icon": "coin",
	},
	"all_cleared": {
		"title": "ach.all_cleared.name",
		"desc": "ach.all_cleared.desc",
		"icon": "globe",
	},
}

var _unlocked: Dictionary = {}  # id -> true


## Builds the unlock set from a stored list of unlocked ids.
func _init(stored_ids: Array = []) -> void:
	for id in stored_ids:
		if DEFINITIONS.has(id):
			_unlocked[id] = true


## Returns true if the achievement is already unlocked.
func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


## Lists all achievement ids that are currently unlocked.
func unlocked_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _unlocked.keys():
		out.append(String(id))
	return out


## Number of unlocked achievements.
func unlocked_count() -> int:
	return _unlocked.size()


## Total number of defined achievements.
func total_count() -> int:
	return DEFINITIONS.size()


## Snapshots a definition for display (title, description, icon, unlocked state).
func describe(achievement_id: String) -> Dictionary:
	var def: Dictionary = DEFINITIONS.get(achievement_id, {})
	return {
		"id": achievement_id,
		"title": Loc.t(String(def.get("title", ""))),
		"desc": Loc.t(String(def.get("desc", ""))),
		"icon": String(def.get("icon", "star")),
		"unlocked": is_unlocked(achievement_id),
	}


## Evaluates the snapshot: unlocks every achievement whose check passes. Returns the list of
## achievement ids newly unlocked by this call (empty if none).
func evaluate(snapshot: Dictionary) -> Array[String]:
	var newly: Array[String] = []
	for id in DEFINITIONS.keys():
		if _unlocked.get(id):
			continue
		var def: Dictionary = DEFINITIONS[id]
		var check := Callable(self, "_check_%s" % String(id))
		if check.is_valid() and check.call(snapshot):
			_unlocked[id] = true
			newly.append(id)
			unlocked.emit(id)
	return newly


## Serialises the set of unlocked ids for persistence.
func to_store() -> Array[String]:
	var out: Array[String] = []
	for id in _unlocked.keys():
		out.append(String(id))
	return out


## Loads unlocked ids from a persisted array, replacing the current set.
func load_stored(stored_ids: Array) -> void:
	_unlocked = {}
	for id in stored_ids:
		if DEFINITIONS.has(id):
			_unlocked[id] = true


# --- Predicates (one per achievement id) -------------------------------------------------------

func _check_first_clear(s: Dictionary) -> bool:
	return int(s.get("levels_cleared", 0)) >= 1


func _check_three_star(s: Dictionary) -> bool:
	return int(s.get("max_stars", 0)) >= 3


func _check_no_leak(s: Dictionary) -> bool:
	var levels: Array = s.get("flawless_levels", [])
	return levels.size() > 0


func _check_tower_master(s: Dictionary) -> bool:
	return int(s.get("towers_in_run", 0)) >= 15


func _check_endless_10(s: Dictionary) -> bool:
	return int(s.get("best_wave_endless", 0)) >= 10


func _check_boss_slayer(s: Dictionary) -> bool:
	var bosses: Array = s.get("bosses_killed", [])
	return bosses.size() > 0


func _check_collection(s: Dictionary) -> bool:
	var total := int(s.get("total_stars", 0))
	return int(s.get("stars_earned", 0)) >= total and total > 0


func _check_all_cleared(s: Dictionary) -> bool:
	var total := int(s.get("total_levels", 0))
	return int(s.get("levels_cleared", 0)) >= total and total > 0
