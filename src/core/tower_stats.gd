class_name TowerStats
extends RefCounted
## Resolves a tower definition + upgrade level + chosen module into concrete numbers.
##
## Towers are described once in `data/towers.json`. Three upgrade levels are expressed as
## multiplier curves, and at max level the player picks one of two mutually exclusive modules.
## `resolve()` is a pure function (no nodes, no state), which is what makes the balance suite
## able to assert on it directly.

const MAX_LEVEL := 3

## Modifier keys understood by `_apply_modifiers`: explicit source -> target stat mapping.
## Explicit (rather than string-trimmed) so adding a stat can never silently collide.
const MULT_KEYS := {
	"damage_mult": "damage",
	"rate_mult": "fire_rate",
	"range_mult": "range",
	"splash_mult": "splash",
	"chain_mult": "chain",
	"slow_mult": "slow_factor",
	"aura_rate_mult": "aura_rate",
	"aura_range_mult": "aura_range",
	"aura_damage_mult": "aura_damage",
	"projectile_speed_mult": "projectile_speed",
}
const ADD_KEYS := {"chain_add": "chain", "pierce_add": "pierce", "splash_add": "splash"}
## Keys copied verbatim (booleans, enums, flat bonuses).
const OVERRIDE_KEYS: Array[String] = [
	"targets_air", "targets_ground", "damage_type", "element", "mark_bonus",
]


## Full stat block for a tower instance.
## Returns a dictionary; unknown keys are left at their default so gameplay code can read
## freely without null checks.
static func resolve(def: Dictionary, level: int = 1, module: String = "") -> Dictionary:
	var lv := clampi(level, 1, MAX_LEVEL)
	var curves: Dictionary = def.get("levels", {})
	var stats := {
		"id": def.get("id", ""),
		"sprite": def.get("sprite", ""),
		"name_key": def.get("name_key", ""),
		"desc_key": def.get("desc_key", ""),
		"kind": def.get("kind", "projectile"),
		"damage_type": def.get("damage_type", "kinetic"),
		"element": def.get("element", def.get("damage_type", "kinetic")),
		"rotates": bool(def.get("rotates", false)),
		"level": lv,
		"module": module,
		"damage": float(def.get("damage", 0.0)) * _curve(curves, "damage", lv),
		"fire_rate": float(def.get("fire_rate", 0.0)) * _curve(curves, "rate", lv),
		"range": float(def.get("range", 0.0)) * _curve(curves, "range", lv),
		"splash": float(def.get("splash", 0.0)),
		"chain": float(def.get("chain", 0)),
		"pierce": float(def.get("pierce", 0.0)),
		"projectile_speed": float(def.get("projectile_speed", 12.0)),
		"slow_factor": float(def.get("slow", {}).get("factor", 0.0)),
		"slow_duration": float(def.get("slow", {}).get("duration", 0.0)),
		"dot_dps": float(def.get("dot", {}).get("dps", 0.0)),
		"dot_duration": float(def.get("dot", {}).get("duration", 0.0)),
		"aura_rate": float(def.get("aura", {}).get("rate_mult", 0.0))
				* _curve(curves, "aura", lv),
		"aura_range": float(def.get("aura", {}).get("range", 0.0)) * _curve(curves, "range", lv),
		"aura_damage": float(def.get("aura", {}).get("damage_mult", 0.0)),
		"targets_air": bool(def.get("targets_air", true)),
		"targets_ground": bool(def.get("targets_ground", true)),
		"mark_bonus": float(def.get("mark_bonus", 0.0)),
		"icon_color": def.get("icon_color", ""),
	}
	if module != "" and def.has("modules"):
		var mod: Dictionary = def["modules"].get(module, {})
		stats = _apply_modifiers(stats, mod.get("mods", {}))
	return stats


static func _curve(curves: Dictionary, key: String, level: int) -> float:
	var arr: Array = curves.get(key, [])
	if arr.is_empty():
		return 1.0
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])


static func _apply_modifiers(stats: Dictionary, mods: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	for key in mods.keys():
		if MULT_KEYS.has(key):
			var stat: String = MULT_KEYS[key]
			out[stat] = float(out.get(stat, 0.0)) * float(mods[key])
		elif ADD_KEYS.has(key):
			var stat: String = ADD_KEYS[key]
			out[stat] = float(out.get(stat, 0.0)) + float(mods[key])
		elif OVERRIDE_KEYS.has(key):
			out[key] = mods[key]
	return out


## Gold cost to upgrade from `level` to `level + 1`; 0 when already maxed.
static func upgrade_cost(def: Dictionary, level: int) -> int:
	var arr: Array = def.get("levels", {}).get("upgrade_cost", [])
	if level >= MAX_LEVEL or level < 1 or level > arr.size():
		return 0
	return int(arr[level - 1])


static func max_level() -> int:
	return MAX_LEVEL


## Available module options for a tower (empty unless the tower defines them).
static func modules(def: Dictionary) -> Dictionary:
	return def.get("modules", {})


static func module_cost(def: Dictionary, module_id: String) -> int:
	return int(def.get("modules", {}).get(module_id, {}).get("cost", 0))


## Everything the player has sunk into this tower, used for the sell refund.
static func invested(def: Dictionary, level: int, module: String) -> int:
	var total := int(def.get("cost", 0))
	for lv in range(1, level):
		total += upgrade_cost(def, lv)
	if module != "":
		total += module_cost(def, module)
	return total


## Damage per second, useful for UI and for balance tests. Auras report 0.
static func dps(stats: Dictionary) -> float:
	if String(stats.get("kind", "")) == "aura":
		return 0.0
	var dmg := float(stats.get("damage", 0.0))
	if float(stats.get("chain", 0.0)) >= 1.0:
		# Chain adds secondary hits at a known falloff.
		var extra := 0.0
		var mult := 1.0
		for i in range(int(stats["chain"])):
			mult *= Balance.CHAIN_FALLOFF
			extra += mult
		dmg *= 1.0 + extra
	return dmg * float(stats.get("fire_rate", 0.0))
