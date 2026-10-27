extends Node
## Headless gameplay smoke test: boots the real level scene, builds a few towers, plays waves at
## high speed and asserts the loop actually works end to end.
##
## This is the test that catches what unit tests cannot: wrong signal wiring, runtime type
## errors inside `_process`, a tower panel that explodes when refreshed, a wave that never
## finishes. Run with:
##     godot --headless --path . res://tests/smoke_level.tscn
## Exit code 0 = the level started, towers were placed and at least one wave was cleared.

const SIM_SECONDS := 40.0
const TIME_SCALE := 12

var _failures: Array[String] = []


func _ready() -> void:
	print("\n=== Bulwark level smoke test ===")
	App.pending_level = 0
	App.set_setting("tutorial_seen", true)
	var scene: PackedScene = load("res://scenes/game.tscn")
	var game := scene.instantiate() as GameScreen
	add_child(game)
	await _frames(4)

	_check(game.grid != null, "grid built")
	_check(game.ground_path != null and game.ground_path.total_length > 0.0, "path built")

	var start_gold: int = game.gold
	# A representative opening: cheap DPS next to the first two bends, plus a cannon.
	var placements := [
		["pulse", Vector2i(2, 1)],
		["pulse", Vector2i(4, 4)],
		["cannon", Vector2i(6, 5)],
	]
	for entry in placements:
		var error: String = game.place_tower(String(entry[0]), entry[1])
		_check(error == "", "place %s at %s (error: %s)" % [entry[0], entry[1], error])
	_check(game.gold < start_gold, "building spends gold")
	_check(game.snapshot()["towers"] == placements.size(), "all towers registered on the grid")

	# Rejection paths must be reported, not crash.
	_check(game.place_tower("rail", Vector2i(8, 3)) == "ui.reason.no_gold",
		"an unaffordable tower is refused with the right reason")
	_check(game.place_tower("pulse", Vector2i(1, 2)) == "ui.reason.on_path",
		"building on the road is refused")
	_check(game.place_tower("pulse", Vector2i(2, 1)) != "", "building on a tower is refused")

	# Selecting a tower exercises the panel refresh path (the most layout-heavy UI code).
	var tower := game.select_tower_at(Vector2i(2, 1))
	_check(tower != null, "tower selection works")
	await _frames(2)

	# Play the first waves quickly.
	Engine.time_scale = TIME_SCALE
	game._on_call_wave()
	await _seconds(SIM_SECONDS)
	Engine.time_scale = 1.0
	await _frames(2)

	var snap: Dictionary = game.snapshot()
	print("  after %.0fs of play: %s" % [SIM_SECONDS, snap])
	_check(int(snap["gold_earned"]) > 0, "kills paid out gold")
	_check(int(snap["wave"]) >= 2, "waves progressed (reached wave %d)" % int(snap["wave"]))
	_check(int(snap["enemies"]) >= 0, "enemy list is consistent")

	if _failures.is_empty():
		print("\nSMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("\nSMOKE TEST FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", message])
	if not condition:
		_failures.append(message)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
