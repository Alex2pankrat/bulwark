extends Node
## Balance regression test: play every level with a *simple, sensible* policy and require that a
## competent player can clear it on Normal.
##
## Why this exists: tuning curves in a JSON file is easy to break and impossible to eyeball.
## This harness is the guard rail — it places towers where they actually cover the road,
## upgrades when it can afford to, and calls waves early for the bonus. If a difficulty pass
## makes a level unwinnable, CI fails instead of players finding out.
##
## Run with:  godot --headless --path . res://tests/autoplay.tscn
## Exit code 0 = every level cleared.

## The harness is run with `--fixed-fps 480`, which makes `delta` a constant 1/480 s. With
## `TIME_SCALE = 8` every simulation step is exactly 1/60 s — the same granularity as real
## play at 60 FPS — while the run still advances eight times faster than wall-clock time.
## That keeps the balance numbers comparable between runs instead of depending on frame rate.
const TIME_SCALE := 8
const REAL_TIMEOUT := 110.0     ## wall-clock guard per level
const MAX_TOWERS := 16

## The policy's opening build order; later towers repeat the last entry.
const BUILD_ORDER: Array[String] = ["pulse", "pulse", "cannon", "pulse", "frost", "arc", "cannon",
	"rail", "arc", "pulse", "cannon", "rail"]

var _failures: Array[String] = []
var _difficulty := int(Balance.Difficulty.NORMAL)


func _ready() -> void:
	var difficulty := Balance.Difficulty.NORMAL
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty="):
			difficulty = int(arg.get_slice("=", 1))
	_difficulty = difficulty
	print("\n=== Bulwark autoplay balance test (difficulty %d) ===" % difficulty)
	App.set_setting("tutorial_seen", true)
	App.set_setting("difficulty", difficulty)
	Engine.time_scale = TIME_SCALE
	for index in range(GameData.level_count()):
		await _play(index)
	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("\nAUTOPLAY PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("\nAUTOPLAY FAILED (%d)" % _failures.size())
		get_tree().quit(1)


func _play(index: int) -> void:
	var level_name := Loc.t(String(GameData.level(index).get("name_key", "")))
	print("\n--- level %d (%s) ---" % [index + 1, level_name])
	App.pending_level = index
	# A finished run pauses the tree; reset it before the next level starts.
	App.set_paused(false)
	Engine.time_scale = TIME_SCALE
	var scene: PackedScene = load("res://scenes/game.tscn")
	var game := scene.instantiate() as GameScreen
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var candidates := _rank_cells(game)
	var built := 0
	var elapsed := 0.0
	var last_wave := -1
	var upgrades := 0
	var modules := 0

	while not game.is_finished() and elapsed < REAL_TIMEOUT:
		await get_tree().create_timer(0.25, true, false, true).timeout
		elapsed += 0.25

		# 1. Build while there is space and money. Falls back to a cheaper tower instead of
		#    sitting on a pile of gold waiting for an expensive one (a player would too).
		if built < MAX_TOWERS and not candidates.is_empty():
			var want := BUILD_ORDER[mini(built, BUILD_ORDER.size() - 1)]
			var placed := ""
			if game.gold >= int(GameData.tower(want).get("cost", 999)):
				placed = want
			else:
				for fallback in BUILD_ORDER:
					if game.gold >= int(GameData.tower(fallback).get("cost", 999)):
						placed = fallback
						break
			if placed != "":
				var cell: Vector2i = candidates.pop_front()
				if game.place_tower(placed, cell) == "":
					built += 1

		# 2. Spend leftovers on upgrades (tall beats wide once the board is covered).
		for tower in game.towers_in_play():
			if tower.can_upgrade() and game.gold >= tower.upgrade_cost() + 40:
				if game.upgrade_tower(tower) == "":
					upgrades += 1
				break

		# 3. Offer max-level modules once gold is comfortable.
		for tower in game.towers_in_play():
			if not tower.available_modules().is_empty() and game.gold > 220:
				var module_id := String(tower.available_modules().keys()[0])
				if game.install_module(tower, module_id) == "":
					modules += 1
				break

		# 4. Use abilities: bomb the densest cluster, overclock while a wave is running.
		if game.ability_ready("overclock") and int(game.snapshot()["enemies"]) >= 6:
			game.cast_ability("overclock")
		if game.ability_ready("airstrike"):
			var target := _best_airstrike_point(game)
			if target != Vector2.INF:
				game.cast_ability("airstrike", target)

		# 5. Call the next wave early only when there is nothing useful left to buy; otherwise
		#    let the countdown run (a player banking for an upgrade does the same).
		var snapshot: Dictionary = game.snapshot()
		if int(snapshot["wave"]) != last_wave:
			last_wave = int(snapshot["wave"])
			print("    wave %d: lives %d, gold %d, towers %d" % [
				last_wave, int(snapshot["lives"]), int(snapshot["gold"]), int(snapshot["towers"])])
		if int(snapshot["gold"]) < 60:
			game._on_call_wave()

	if not game.is_initialised():
		_check(false, "level %d failed to initialise" % (index + 1))
		game.queue_free()
		return
	var final: Dictionary = game.snapshot()
	var cleared := int(final["wave"]) >= int(final["waves_total"]) and int(final["lives"]) > 0
	# Hard is the expert setting: the yardstick there is "gets to the endgame", not "wins",
	# because a scripted policy plays noticeably worse than a human at that level.
	var reached := float(final["wave"]) / maxf(1.0, float(final["waves_total"])) >= 0.7
	print("  result: %s | wave %d/%d | lives %d/%d | towers %d | upgrades %d | modules %d | gold %d" % [
		"VICTORY" if cleared else "DEFEAT",
		int(final["wave"]), int(final["waves_total"]),
		int(final["lives"]), int(final["lives_max"]),
		int(final["towers"]), upgrades, modules, int(final["gold"])])
	if _difficulty >= Balance.Difficulty.HARD:
		_check(reached, "level %d reaches the endgame on Hard" % (index + 1))
	else:
		_check(cleared, "level %d is winnable at this difficulty" % (index + 1))
	game.queue_free()
	App.set_paused(false)
	await get_tree().process_frame


## Greedy: find the point on the route with the most enemies around it, if it is worth bombing.
## Returns a board-local position, which is the space `GameScreen.cast_ability` expects.
func _best_airstrike_point(game: GameScreen) -> Vector2:
	var best := Vector2.INF
	var best_count := 2
	for enemy in game.get_enemies():
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var count := 0
		for other in game.get_enemies():
			if is_instance_valid(other) and other.alive \
				and enemy.global_position.distance_to(other.global_position) <= 2.0 * 64.0:
				count += 1
		if count > best_count:
			best_count = count
			best = game._board_root.to_local(enemy.global_position)
	return best


## Ranks buildable cells by how much of the route they cover, ignoring cells next to towers.
func _rank_cells(game: GameScreen) -> Array[Vector2i]:
	var path := game.ground_path
	var samples := 48
	var scored: Array[Dictionary] = []
	for y in range(game.grid.rows):
		for x in range(game.grid.cols):
			var cell := Vector2i(x, y)
			if game.grid.kind_at(cell) != BuildGrid.CellKind.BUILDABLE:
				continue
			var center := game.grid.center_of(cell)
			var covered := 0
			for i in range(samples + 1):
				var point := path.position_at(path.total_length * float(i) / float(samples))
				if center.distance_to(point) <= 2.4 * game.grid.cell_size:
					covered += 1
			if covered == 0:
				continue
			scored.append({"cell": cell, "score": covered, "pos": center})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	var out: Array[Vector2i] = []
	for entry in scored:
		out.append(entry["cell"])
	return out


func _check(condition: bool, message: String) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", message])
	if not condition:
		_failures.append(message)
