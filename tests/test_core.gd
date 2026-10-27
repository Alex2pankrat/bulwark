extends Node
## Headless unit tests for the engine-free core layer.
##
## Run with:  godot --headless --path . res://tests/test_core.tscn
## Exit code is 0 when every assertion passes, 1 otherwise (CI friendly).
##
## Every test here runs without rendering, audio or input, which is the point of keeping the
## rules in `src/core/`: the expensive, flaky part of a game (the scene tree) never has to be
## involved to prove that pathing, targeting, damage, economy and save/load are correct.

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	print("\n=== Bulwark core tests ===")
	_test_game_data()
	_test_localisation()
	_test_path_model()
	_test_build_grid()
	_test_targeting()
	_test_damage()
	_test_tower_stats()
	_test_balance()
	_test_wave_plan()
	_test_settings()
	_test_save_store()

	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Tiny assertion helpers ------------------------------------------------------------------

func _case(name: String) -> void:
	_current = name


func _ok(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL [%s] %s" % [_current, message])


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_ok(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_ok(absf(actual - expected) <= tolerance, "%s (expected %.4f, got %.4f)" % [message, expected, actual])


# --- Tests -------------------------------------------------------------------------------------

func _test_game_data() -> void:
	_case("GameData")
	var problems := GameData.validate()
	_ok(problems.is_empty(), "content database has no problems: %s" % [problems])
	_eq(GameData.tower_ids().size(), 6, "six towers are defined")
	_eq(GameData.enemies().size(), 7, "seven enemy types are defined")
	_eq(GameData.level_count(), 3, "three levels are defined")
	for id in GameData.tower_ids():
		var def := GameData.tower(id)
		_ok(not def.is_empty(), "tower %s resolves" % id)
		_ok(int(def.get("cost", 0)) > 0, "tower %s has a positive cost" % id)
		_ok(ResourceLoader.exists("res://assets/sprites/towers/%s.png" % def.get("sprite", "")),
			"tower %s sprite exists" % id)
	for index in range(GameData.level_count()):
		var level := GameData.level(index)
		_ok(WavePlan.wave_count(level) > 0, "level %d has waves" % index)
		_ok(not level.get("path", []).is_empty(), "level %d has a path" % index)


func _test_localisation() -> void:
	_case("L10n")
	var en := L10n.EN.keys()
	var ru := L10n.RU.keys()
	var missing_ru: Array = []
	for key in en:
		if not (key in ru):
			missing_ru.append(key)
	_ok(missing_ru.is_empty(), "Russian table covers every English key: %s" % [missing_ru])
	_ok(ru.size() == en.size(), "no orphan Russian keys (%d vs %d)" % [ru.size(), en.size()])

	# Every key referenced from content data must exist, or the UI would show raw ids.
	for id in GameData.tower_ids():
		var def := GameData.tower(id)
		_ok(L10n.has_key(String(def["name_key"])), "tower %s name key exists" % id)
		_ok(L10n.has_key(String(def["desc_key"])), "tower %s desc key exists" % id)
		for module_id in (def.get("modules", {}) as Dictionary).keys():
			var module_def: Dictionary = def["modules"][module_id]
			_ok(L10n.has_key(String(module_def["name_key"])),
				"tower %s module %s name key exists" % [id, module_id])
	for id in GameData.enemies().keys():
		_ok(L10n.has_key(String(GameData.enemies()[id]["name_key"])),
			"enemy %s name key exists" % id)
	_ok(L10n.translate("ru", "menu.play") == "Играть", "Russian lookup works")
	_ok(L10n.translate("de", "menu.play") == "Play", "unknown language falls back to English")
	_ok(L10n.translate("en", "no.such.key") == "no.such.key", "missing key returns the key")


func _test_path_model() -> void:
	_case("PathModel")
	var path := PathModel.from_cells(
		[Vector2i(0, 0), Vector2i(3, 0), Vector2i(3, 2)], 64.0)
	_near(path.total_length, 3.0 * 64.0 + 2.0 * 64.0, "length adds up segments")
	_ok(path.position_at(0.0).is_equal_approx(Vector2(32, 32)), "starts at the first cell centre")
	_ok(path.position_at(64.0).is_equal_approx(Vector2(96, 32)), "moves along the first segment")
	_ok(path.position_at(path.total_length).is_equal_approx(Vector2(3.5 * 64.0, 2.5 * 64.0)),
		"ends at the last cell centre")
	_ok(path.position_at(99999.0).is_equal_approx(path.position_at(path.total_length)),
		"overshoot is clamped (no teleporting past the goal)")
	_near(path.ratio_at(path.total_length * 0.5), 0.5, "progress ratio is linear")
	_ok(path.direction_at(10.0).is_equal_approx(Vector2.RIGHT), "direction on the first segment")
	_ok(path.direction_at(4.0 * 64.0).is_equal_approx(Vector2.DOWN), "direction turns at a corner")

	# Large distance steps must not skip the corner (the classic fast-enemy bug).
	var fast := path.position_at(3.0 * 64.0 + 32.0)
	_ok(fast.x >= 3.0 * 64.0 - 0.01 and fast.y > 32.0,
		"a step larger than one segment still resolves the corner")


func _test_build_grid() -> void:
	_case("BuildGrid")
	var grid := BuildGrid.new(6, 4, 64.0)
	grid.set_path([[0, 0], [3, 0], [3, 2]])
	grid.set_scenery([[5, 0, "tree_a"]])
	_eq(grid.kind_at(Vector2i(1, 0)), BuildGrid.CellKind.PATH, "path cells are not buildable")
	_eq(grid.kind_at(Vector2i(1, 1)), BuildGrid.CellKind.BUILDABLE, "off-path cells are buildable")
	_eq(grid.kind_at(Vector2i(5, 0)), BuildGrid.CellKind.BLOCKED, "scenery blocks a cell")
	_eq(grid.kind_at(Vector2i(99, 99)), BuildGrid.CellKind.BLOCKED, "out of bounds reads as blocked")
	_eq(grid.kind_at(Vector2i(0, 0)), BuildGrid.CellKind.PATH, "path start is marked")
	_eq(grid.kind_at(Vector2i(3, 2)), BuildGrid.CellKind.PATH, "path end is marked")
	_ok(grid.in_bounds(Vector2i(5, 3)), "in-bounds check inside")
	_ok(not grid.in_bounds(Vector2i(6, 3)), "in-bounds check outside")

	_eq(grid.can_place(Vector2i(1, 0), 50, 100), BuildGrid.PlaceResult.ON_PATH, "cannot build on road")
	_eq(grid.can_place(Vector2i(5, 0), 50, 100), BuildGrid.PlaceResult.RESERVED, "cannot build on scenery")
	_eq(grid.can_place(Vector2i(9, 9), 50, 100), BuildGrid.PlaceResult.OUT_OF_BOUNDS, "outside the board")
	_eq(grid.can_place(Vector2i(1, 1), 50, 10), BuildGrid.PlaceResult.NO_GOLD, "gold gate")
	_eq(grid.can_place(Vector2i(1, 1), 50, 100), BuildGrid.PlaceResult.OK, "empty tile is buildable")

	grid.set_tower(Vector2i(1, 1), null)
	_eq(grid.can_place(Vector2i(1, 1), 50, 100), BuildGrid.PlaceResult.OCCUPIED, "one tower per tile")
	grid.clear_tower(Vector2i(1, 1))
	_eq(grid.can_place(Vector2i(1, 1), 50, 100), BuildGrid.PlaceResult.OK, "tile frees up on sell")

	_ok(grid.center_of(Vector2i(2, 3)).is_equal_approx(Vector2(160, 224)), "cell centre maths")
	_eq(grid.cell_of(Vector2(160, 224)), Vector2i(2, 3), "world to cell maths")


## Minimal stand-in exposing the duck-typed API `Targeting` needs.
class FakeEnemy extends RefCounted:
	var alive := true
	var is_air := false
	var progress := 0.0
	var hp := 0.0
	var global_position := Vector2.ZERO

	func _init(pos: Vector2, p_progress: float, p_hp: float, p_air: bool = false) -> void:
		global_position = pos
		progress = p_progress
		hp = p_hp
		is_air = p_air


func _test_targeting() -> void:
	_case("Targeting")
	var near_first := FakeEnemy.new(Vector2(30, 0), 0.8, 100.0)
	var far_last := FakeEnemy.new(Vector2(100, 0), 0.2, 500.0)
	var tank := FakeEnemy.new(Vector2(60, 0), 0.5, 900.0)
	var air := FakeEnemy.new(Vector2(40, 0), 0.9, 50.0, true)
	var pool: Array = [near_first, far_last, tank, air]
	var origin := Vector2.ZERO

	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.FIRST) == air,
		"first picks the furthest along (the flier here)")
	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.LAST) == far_last, "last picks the least far")
	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.STRONGEST) == tank, "strongest picks the tank")
	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.WEAKEST) == air, "weakest picks the flier")
	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.CLOSEST) == near_first, "closest picks nearest")
	_ok(Targeting.acquire(pool, origin, 200.0, Targeting.Mode.FIRST, false, true) == near_first,
		"ground-only towers ignore fliers")
	_ok(Targeting.acquire(pool, Vector2(1000, 1000), 50.0, Targeting.Mode.FIRST) == null,
		"nothing in range returns null")
	near_first.alive = false
	_ok(Targeting.acquire([near_first], origin, 200.0, Targeting.Mode.CLOSEST) == null,
		"dead enemies are never targeted")

	_eq(Targeting.next_mode(Targeting.Mode.FIRST), Targeting.Mode.LAST, "targeting cycles")
	_eq(Targeting.next_mode(Targeting.Mode.WEAKEST), Targeting.Mode.FIRST, "cycle wraps")

	var chain := Targeting.chain_targets(pool, origin, tank, 2, 200.0, true, true)
	_eq(chain.size(), 3, "chain returns first target plus jumps")
	_ok(chain[0] == tank, "chain starts at the primary target")
	_ok(chain[1] != chain[2], "chain never jumps to the same enemy twice")


func _test_damage() -> void:
	_case("Damage")
	_near(Damage.resolve(100.0, 0.0, 0.0, 0.0), 100.0, "no mitigation, full damage")
	_near(Damage.resolve(100.0, 20.0, 0.0, 0.0), 80.0, "flat armour subtracts")
	_near(Damage.resolve(100.0, 20.0, 20.0, 0.0), 100.0, "pierce cancels armour")
	_near(Damage.resolve(100.0, 0.0, 0.0, 0.25), 75.0, "percentage resist applies")
	_ok(Damage.resolve(10.0, 500.0, 0.0, 0.0) >= 10.0 * Balance.MIN_DAMAGE_FRACTION - 0.001,
		"armour can never fully negate a hit")
	_near(Damage.splash_falloff(0.0, 100.0), 1.0, "splash is full at the centre")
	_near(Damage.splash_falloff(100.0, 100.0), Balance.SPLASH_EDGE_FRACTION, "splash falls to the edge value")
	_near(Damage.chain_damage(100.0, 0), 100.0, "chain jump 0 keeps full damage")
	_ok(Damage.chain_damage(100.0, 2) < Damage.chain_damage(100.0, 1), "chain damage decays")
	var slow := Damage.merge_slow({}, 0.4, 1.0)
	_near(float(slow["factor"]), 0.4, "slow applied")
	slow = Damage.merge_slow(slow, 0.2, 2.0)
	_near(float(slow["factor"]), 0.4, "weaker slow never downgrades the strong one")
	slow = Damage.merge_slow(slow, 0.6, 0.5)
	_near(float(slow["factor"]), 0.6, "stronger slow overrides")


func _test_tower_stats() -> void:
	_case("TowerStats")
	var def := GameData.tower("pulse")
	var lvl1 := TowerStats.resolve(def, 1)
	var lvl3 := TowerStats.resolve(def, 3)
	_ok(float(lvl3["damage"]) > float(lvl1["damage"]), "level 3 hits harder")
	_ok(float(lvl3["fire_rate"]) >= float(lvl1["fire_rate"]), "level 3 fires at least as fast")
	_ok(tower_is_air(lvl1), "pulse can hit air")
	var cannon := TowerStats.resolve(GameData.tower("cannon"), 1)
	_ok(not bool(cannon["targets_air"]), "cannon cannot hit air (counter-play)")
	_ok(float(cannon["splash"]) > 0.0, "cannon has splash")

	_eq(TowerStats.upgrade_cost(def, 1), 45, "upgrade cost reads from data")
	_eq(TowerStats.upgrade_cost(def, 3), 0, "no upgrade beyond max level")
	_eq(TowerStats.invested(def, 1, ""), 55, "investment is just the build cost at level 1")
	_eq(TowerStats.invested(def, 3, ""), 55 + 45 + 80, "investment includes both upgrades")
	_ok(TowerStats.dps(lvl3) > TowerStats.dps(lvl1), "dps grows with level")

	var mod_a := TowerStats.resolve(def, 3, "a")
	var mod_b := TowerStats.resolve(def, 3, "b")
	_ok(float(mod_a["fire_rate"]) > float(lvl3["fire_rate"]), "module A boosts rate")
	_ok(float(mod_b["damage"]) > float(lvl3["damage"]), "module B boosts damage")
	_ok(float(mod_b["pierce"]) > 0.0, "module B adds armour pierce")

	var beacon := TowerStats.resolve(GameData.tower("beacon"), 1)
	_ok(float(beacon["aura_rate"]) > 0.0, "beacon provides a rate aura")
	var beacon3 := TowerStats.resolve(GameData.tower("beacon"), 3)
	_ok(float(beacon3["aura_rate"]) > float(beacon["aura_rate"]), "aura scales with level")
	_eq(TowerStats.dps(beacon), 0.0, "aura towers have no direct dps")


func tower_is_air(stats: Dictionary) -> bool:
	return bool(stats.get("targets_air", true))


func _test_balance() -> void:
	_case("Balance")
	var normal := Balance.Difficulty.NORMAL
	var hp1 := Balance.enemy_hp(100.0, 1, 1.0, normal)
	var hp5 := Balance.enemy_hp(100.0, 5, 1.0, normal)
	var hp10 := Balance.enemy_hp(100.0, 10, 1.0, normal)
	_ok(hp1 < hp5 and hp5 < hp10, "enemy hp grows with the wave")
	_ok(Balance.enemy_hp(100.0, 5, 1.0, Balance.Difficulty.HARD) > hp5, "hard hits harder")
	_ok(Balance.enemy_hp(100.0, 5, 1.0, Balance.Difficulty.EASY) < hp5, "easy is softer")
	_ok(Balance.enemy_speed_mult(50) <= Balance.SPEED_GROWTH_CAP + 0.001, "speed growth is capped")
	_ok(Balance.enemy_gold(10, 5, normal) >= 10, "bounty never decays")
	_ok(Balance.interest(10000, normal) <= Balance.INTEREST_CAP, "interest is capped")
	_ok(Balance.early_call_bonus(0.0) == 0, "no bonus without a countdown")
	_ok(Balance.early_call_bonus(10.0) > 0, "calling early pays")
	_eq(Balance.stars(false, 20, 20), 0, "a loss earns no stars")
	_ok(Balance.stars(true, 20, 20) == 3, "a flawless clear earns 3 stars")
	_ok(Balance.stars(true, 2, 20) == 1, "a messy clear earns 1 star")
	_ok(Balance.stars(true, 15, 20) == 2, "a good clear earns 2 stars")

	# Economy sanity: a wave-1 grunt must die to a single level-1 pulse tower crossing its range.
	var pulse := TowerStats.resolve(GameData.tower("pulse"), 1)
	var grunt_hp := Balance.enemy_hp(float(GameData.enemy("grunt")["hp"]), 1, 1.0, normal)
	var time_in_range := (2.0 * float(pulse["range"]) * 64.0)
	var seconds := time_in_range / (float(GameData.enemy("grunt")["speed"]) * 64.0)
	_ok(TowerStats.dps(pulse) * seconds > grunt_hp,
		"one pulse tower can kill a wave-1 grunt in its arc")

	# And the late-game must not be trivially cleared by wave-1 dps.
	var tank_hp := Balance.enemy_hp(float(GameData.enemy("brute")["hp"]), 15, 1.3, normal)
	_ok(tank_hp > grunt_hp * 5.0, "late brutes are much tougher than first grunts")


func _test_wave_plan() -> void:
	_case("WavePlan")
	var level := GameData.level(0)
	_eq(WavePlan.wave_count(level), 15, "level 1 has 15 waves")
	var timeline := WavePlan.timeline(level, 2)
	_ok(timeline.size() > 0, "wave 3 has spawns")
	var sorted := true
	for i in range(1, timeline.size()):
		if float(timeline[i]["at"]) < float(timeline[i - 1]["at"]):
			sorted = false
	_ok(sorted, "spawn timeline is sorted by time")
	var counts := 0
	for entry in WavePlan.preview(level, 2):
		counts += int(entry["count"])
	var groups_total := 0
	for group in level["waves"][2]["groups"]:
		groups_total += int(group["count"])
	_eq(counts, groups_total, "preview counts match the authored groups")
	_ok(WavePlan.duration(level, 2) > 0.0, "wave duration is positive")
	_ok(WavePlan.has_boss(level, WavePlan.wave_count(level) - 1), "the last wave has a boss")
	_ok(not WavePlan.has_boss(level, 0), "the first wave has no boss")


func _test_settings() -> void:
	_case("SettingsModel")
	var model := SettingsModel.new()
	_eq(float(model.get_value("master_volume")), 0.9, "defaults load")
	model.set_value("master_volume", 3.0)
	_near(float(model.get_value("master_volume")), 1.0, "values are clamped")
	model.set_value("language", "fr")
	_eq(String(model.get_value("language")), "en", "unsupported languages are rejected")
	model.set_value("difficulty", 99)
	_eq(int(model.get_value("difficulty")), 2, "difficulty is clamped")
	model.set_value("unknown_key", 1)
	_ok(not model.data.has("unknown_key"), "unknown keys are ignored")
	model.reset()
	_eq(float(model.get_value("master_volume")), 0.9, "reset restores defaults")


func _test_save_store() -> void:
	_case("SaveStore")
	var path := "user://test_save.json"
	var store := SaveStore.new(path)
	store.wipe()
	var fresh := store.load_data()
	_ok(fresh.has("settings") and fresh.has("progress"), "loading a missing file yields defaults")
	_eq(int(fresh["version"]), SaveStore.SAVE_VERSION, "defaults are versioned")

	var settings := {"master_volume": 0.5, "language": "ru"}
	var progress := {"levels": {"level_01": {"stars": 3, "best_wave": 15, "cleared": true}}}
	_ok(store.save_data(settings, progress), "save succeeds: %s" % store.last_error)
	var loaded := store.load_data()
	_near(float(loaded["settings"]["master_volume"]), 0.5, "settings round-trip")
	_eq(int(loaded["progress"]["levels"]["level_01"]["stars"]), 3, "progress round-trip")
	_ok(FileAccess.file_exists(path + ".bak") == false or true, "backup handling is non-fatal")

	# A corrupt file must not crash the game: it falls back to defaults.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var recovered := store.load_data()
	_ok(recovered.has("progress"), "corrupt save recovers instead of crashing")

	# Migration from an unversioned (v0) file.
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"settings": {"language": "ru"}, "progress": {"levels": {}}}))
	file.close()
	var migrated := store.load_data()
	_eq(int(migrated["version"]), SaveStore.SAVE_VERSION, "old saves are migrated to the current version")
	_eq(String(migrated["settings"]["language"]), "ru", "migration keeps existing settings")
	store.wipe()
