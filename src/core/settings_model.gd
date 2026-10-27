class_name SettingsModel
extends RefCounted
## Player settings as plain data.
##
## Kept engine-free and serialisable so it can be written to disk, reset to defaults, and
## unit-tested. Accessibility options live here next to the obvious ones on purpose: they are
## part of the settings contract, not an afterthought bolted onto the pause menu.

const DEFAULTS := {
	"master_volume": 0.9,
	"music_volume": 0.55,
	"sfx_volume": 0.8,
	"difficulty": 1,                 # Balance.Difficulty.NORMAL
	"language": "en",
	"damage_numbers": true,
	"screen_shake": 0.7,             # 0 = off (accessibility), 1 = full
	"reduce_motion": false,
	"grid_overlay": true,
	"colorblind_mode": false,
	"tutorial_seen": false,
}

const LANGUAGES: Array[String] = ["en", "ru"]

var data: Dictionary = {}


func _init(initial: Dictionary = {}) -> void:
	data = DEFAULTS.duplicate(true)
	merge(initial)


## Applies a partial dictionary on top of the current values, sanitising every key.
func merge(patch: Dictionary) -> void:
	for key in patch.keys():
		if DEFAULTS.has(key):
			data[key] = _sanitise(String(key), patch[key])


func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if DEFAULTS.has(key):
		data[key] = _sanitise(key, value)


func reset() -> void:
	data = DEFAULTS.duplicate(true)


func _sanitise(key: String, value: Variant) -> Variant:
	match key:
		"master_volume", "music_volume", "sfx_volume", "screen_shake":
			return clampf(float(value), 0.0, 1.0)
		"difficulty":
			return clampi(int(value), 0, Balance.DIFFICULTY_ORDER.size() - 1)
		"language":
			var lang := String(value)
			return lang if LANGUAGES.has(lang) else DEFAULTS["language"]
		"damage_numbers", "reduce_motion", "grid_overlay", "colorblind_mode", "tutorial_seen":
			return bool(value)
		_:
			return value


func to_dict() -> Dictionary:
	return data.duplicate(true)


## Language tag used by the localiser, optionally following the OS locale on first run.
static func system_language() -> String:
	var locale := OS.get_locale_language()
	return "ru" if locale == "ru" else "en"
