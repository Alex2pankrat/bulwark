extends Node
## Headless UI-screen regression test.
##
## Run with:  godot --headless --path . res://tests/test_screens.tscn
## Exit code 0 when every screen builds, 1 otherwise (CI friendly).
##
## This guards the bug class that the core unit tests cannot see: a screen whose `_build()` is
## skipped (a parse error, a missing API, a bad layout call) renders EMPTY at runtime while the
## engine-free core layer still passes. Instantiating the real scenes here turns "the window is
## blank" into a hard CI failure instead of a player-reported regression.

const MIN_DESCENDANTS := 10

const SCREENS: Array[Dictionary] = [
	{"name": "MainMenu", "scene": "res://scenes/main_menu.tscn", "min": 10},
	{"name": "SettingsScreen", "scene": "res://scenes/settings_screen.tscn", "min": 30},
	{"name": "LevelSelectScreen", "scene": "res://scenes/level_select.tscn", "min": 30},
	{"name": "AchievementsScreen", "scene": "res://scenes/achievements_screen.tscn", "min": 40},
	{"name": "CreditsScreen", "scene": "res://scenes/credits_screen.tscn", "min": 10},
]

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("\n=== Bulwark UI screen tests ===")
	for entry in SCREENS:
		await _test_screen(String(entry["name"]), String(entry["scene"]), int(entry["min"]))
	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _test_screen(name: String, scene_path: String, min_descendants: int) -> void:
	var scene: PackedScene = load(scene_path)
	_check(scene != null, "%s: scene loads" % name)
	if scene == null:
		return

	var screen = scene.instantiate() as Node
	_check(screen != null, "%s: instantiates" % name)
	if screen == null:
		return

	add_child(screen)
	# Let _ready / _build (and any open animation setup) run before counting.
	await _frames(6)

	var count := _count_descendants(screen)
	_check(count >= min_descendants,
		"%s: builds content (%d descendants, need >= %d)" % [name, count, min_descendants])

	remove_child(screen)
	screen.queue_free()


func _count_descendants(node: Node) -> int:
	var total := node.get_child_count()
	for i in range(node.get_child_count()):
		total += _count_descendants(node.get_child(i))
	return total


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [ok] %s" % message)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % message)
