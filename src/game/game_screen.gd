class_name GameScreen
extends Control
## The level scene: owns the world, wires the systems together, and resolves combat.
##
## Division of responsibility (kept strict so the file stays readable):
##   * `Board` draws terrain and placement feedback.
##   * `Enemy` / `Tower` / `Projectile` are behaviours with no knowledge of the rules.
##   * `WaveDirector` owns pacing, `Abilities` owns cooldowns, `HUD` owns presentation.
##   * This node is the only place that knows the *rules*: gold, lives, damage resolution,
##     auras, leaks and the win/lose conditions.

const BOARD_MARGIN_TOP := 78.0
const BOARD_MARGIN_BOTTOM := 172.0
const BOARD_MARGIN_SIDE := 16.0
## Inset left on a phone-sized viewport: the HUD floats over the board instead of reserving
## margins, so the board can use the whole screen.
const COMPACT_INSET := 8.0
const SPEEDS: Array[int] = [1, 2, 3]

var level_index: int = 0
var level: Dictionary = {}
var grid: BuildGrid
var ground_path: PathModel
var air_path: PathModel

var gold: int = 0
var lives: int = 0
var lives_max: int = 0
var gold_earned: int = 0

var _board_root: Node2D
var _board: Board
var _entities: Node2D
var _projectile_layer: Node2D
var _fx: Fx
var _hud: HUD
var _director: WaveDirector
var _abilities := Abilities.new()

var _towers: Array[Tower] = []
var _enemies: Array[Enemy] = []

var _build_mode: String = ""
var _selected: Tower = null
var _pending_ability: String = ""
var _speed_index: int = 0
var _overclock_left: float = 0.0
var _overlay: Overlay = null
var _finished := false
var _ui_accum := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _base_board_position := Vector2.ZERO
var _medic_accum := 0.0
var _best_hint := false


# --- Lifecycle -----------------------------------------------------------------------------------

func _ready() -> void:
	theme = ThemeFactory.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The root must not eat input: board taps are handled in `_unhandled_input`, so anything
	# with MOUSE_FILTER_STOP at this level would swallow every tap on the playfield. Only the
	# HUD buttons (and modal overlays) are allowed to capture the pointer.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_index = App.pending_level
	level = GameData.level(level_index)
	if level.is_empty():
		push_error("Level %d is missing" % level_index)
		App.goto_scene(App.MENU_SCENE)
		return

	_build_world()
	_build_hud()
	_connect_director()
	_apply_starting_state()
	_director.start(level)
	Audio.play_music("battle")
	_show_first_hint()
	resized.connect(_layout)
	_layout()


func _build_world() -> void:
	var grid_cfg: Dictionary = level.get("grid", {})
	grid = BuildGrid.new(int(grid_cfg.get("cols", 14)), int(grid_cfg.get("rows", 10)),
		float(grid_cfg.get("cell", 64)))
	grid.set_path(level.get("path", []))
	grid.set_scenery(level.get("scenery", []))

	ground_path = PathModel.from_cells(level.get("path", []), grid.cell_size)
	air_path = _build_air_path(level.get("path", []))

	_board_root = Node2D.new()
	add_child(_board_root)

	_board = Board.new()
	_board.setup(grid, level, ground_path)
	_board.set_grid_visible(bool(App.get_setting("grid_overlay")))
	_board_root.add_child(_board)

	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	_board_root.add_child(_entities)

	_projectile_layer = Node2D.new()
	_projectile_layer.z_index = 10
	_board_root.add_child(_projectile_layer)

	_fx = Fx.new()
	_board_root.add_child(_fx)


## Fliers follow the same corridor but skip every other bend, so they arrive sooner while still
## crossing the towers the player built along the route. a fully straight line would bypass the
## board and turn "flying" from a targeting choice into an unavoidable leak.
func _build_air_path(path_points: Array) -> PathModel:
	if path_points.size() < 3:
		return ground_path
	var points := PackedVector2Array()
	for i in range(path_points.size()):
		var is_end := i == 0 or i == path_points.size() - 1
		if is_end or i % 2 == 1:
			points.append(grid.center_of(
				Vector2i(int(path_points[i][0]), int(path_points[i][1]))))
	return PathModel.from_points(points)


func _build_hud() -> void:
	_hud = HUD.new()
	add_child(_hud)
	_hud.setup_towers(GameData.tower_ids(), gold)
	_hud.setup_abilities(_abilities)
	_hud.set_wave_total(WavePlan.wave_count(level))
	_hud.build_selected.connect(_on_build_selected)
	_hud.call_wave_pressed.connect(_on_call_wave)
	_hud.speed_pressed.connect(_cycle_speed)
	_hud.pause_pressed.connect(_open_pause)
	_hud.ability_pressed.connect(_on_ability_pressed)
	_hud.upgrade_pressed.connect(_on_upgrade)
	_hud.sell_pressed.connect(_on_sell)
	_hud.targeting_pressed.connect(_on_targeting)
	_hud.module_pressed.connect(_on_module)
	_hud.cancel_pressed.connect(_cancel_build)
	_hud.panel_closed.connect(_deselect_tower)
	_director = WaveDirector.new()
	_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_director)
	App.settings_changed.connect(_on_setting_changed)


func _connect_director() -> void:
	_director.spawn_requested.connect(_spawn_enemy)
	_director.prep_started.connect(_on_prep_started)
	_director.prep_remaining.connect(_on_prep_remaining)
	_director.wave_started.connect(_on_wave_started)
	_director.wave_cleared.connect(_on_wave_cleared)
	_director.all_waves_cleared.connect(_on_victory)


func _apply_starting_state() -> void:
	var difficulty := App.difficulty()
	var cfg := Balance.difficulty_config(difficulty)
	lives_max = int(cfg["lives"]) if int(cfg["lives"]) > 0 else int(level.get("lives", 20))
	lives = lives_max
	gold = int(float(level.get("start_gold", 250)) * (0.85 if difficulty == Balance.Difficulty.EASY else 1.0))
	gold_earned = 0
	_hud.set_lives(lives, lives_max)
	_hud.set_gold(gold)


# --- Layout ---------------------------------------------------------------------------------------

## Phones (and small windows) get the board at the full screen with the HUD floating on top of
## it; desktop keeps the inset layout with the HUD living in the reserved margins.
func _compact_viewport() -> bool:
	if OS.has_feature("mobile"):
		return true
	return size.x < 900.0 or size.y < 560.0


func _layout() -> void:
	if _board_root == null:
		return
	var compact := _compact_viewport()
	var margin_side := COMPACT_INSET if compact else BOARD_MARGIN_SIDE
	var margin_top := COMPACT_INSET if compact else BOARD_MARGIN_TOP
	var margin_bottom := COMPACT_INSET if compact else BOARD_MARGIN_BOTTOM
	var available := Rect2(
		Vector2(margin_side, margin_top),
		size - Vector2(margin_side * 2.0, margin_top + margin_bottom))
	if available.size.x <= 0.0 or available.size.y <= 0.0:
		return
	var board_size := grid.board_size()
	var scale_factor := minf(available.size.x / board_size.x, available.size.y / board_size.y)
	_board_root.scale = Vector2(scale_factor, scale_factor)
	_base_board_position = available.position + (available.size - board_size * scale_factor) * 0.5
	_board_root.position = _base_board_position


# --- Frame loop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return
	_ui_accum += delta
	if _ui_accum >= 0.1:
		var step := _ui_accum
		_ui_accum = 0.0
		_abilities.tick(step)      # real elapsed time: cooldowns must not depend on the UI rate
		_hud.update_abilities(_abilities)
	if _overclock_left > 0.0:
		_overclock_left = maxf(0.0, _overclock_left - delta)
		if _overclock_left == 0.0:
			_recompute_buffs()
	_tick_medics(delta)
	_tick_shake(delta)
	if not _pending_ability == "":
		_update_ability_preview()


## Menders heal nearby allies: a small, readable support behaviour that punishes pure AoE.
func _tick_medics(delta: float) -> void:
	_medic_accum += delta
	if _medic_accum < 0.25:
		return
	_medic_accum = 0.0
	for medic in _enemies:
		if not is_instance_valid(medic) or not medic.alive or medic.heal_rate <= 0.0:
			continue
		var radius := float(medic.def.get("heal", {}).get("radius", 1.8)) * grid.cell_size
		for other in Targeting.in_radius(_enemies, medic.global_position, radius, true, true):
			var enemy := other as Enemy
			if enemy != medic and enemy.hp < enemy.max_hp:
				enemy.heal(enemy.max_hp * medic.heal_rate * 0.25)
				_fx.ring(enemy.position, 12.0, Palette.HEAL, 0.3)


func _tick_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	_shake_time += delta * 34.0
	var amount := _trauma * _trauma * float(App.get_setting("screen_shake"))
	if amount <= 0.001:
		_board_root.position = _base_board_position
		return
	_board_root.position = _base_board_position + Vector2(
		sin(_shake_time * 1.7) * 9.0 * amount,
		sin(_shake_time * 2.3) * 6.0 * amount)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


# --- Input -------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _overlay != null:
		return
	var tap_position := Vector2.INF
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tap_position = mb.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			tap_position = touch.position
	elif event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return

	if tap_position == Vector2.INF:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_open_pause()
		elif event.is_action_pressed("call_wave"):
			_on_call_wave()
		elif event.is_action_pressed("cycle_speed"):
			_cycle_speed()
		elif event.is_action_pressed("ability_1"):
			_on_ability_pressed("airstrike")
		elif event.is_action_pressed("ability_2"):
			_on_ability_pressed("overclock")
		return

	_handle_board_tap(tap_position)


func _handle_board_tap(screen_position: Vector2) -> void:
	var local := _board_root.to_local(screen_position)
	var cell := grid.cell_of(local)
	if not grid.in_bounds(cell):
		# Tapping off the board while a tower is armed cancels the placement (the "cancel zone");
		# an armed ability still casts where the player pointed.
		if _build_mode != "":
			_cancel_build()
			return
		if _pending_ability == "":
			_deselect_tower()
			return

	if _pending_ability != "":
		_cast_ability(Vector2(local))
		return

	# Tapping an existing tower always inspects it, even mid-build: cancelling the build mode
	# there is friendlier than refusing the tap with "tile already has a tower".
	var existing := grid.tower_at(cell) as Tower
	if existing != null:
		_build_mode = ""
		_board.clear_hover()
		_board.set_preview_tower("")
		_hud.set_selected_tower("")
		_select_tower(existing)
		return

	if _build_mode != "":
		_try_place(cell)
		_board.clear_hover()
		return

	_deselect_tower()
	_board.clear_hover()


func _update_hover(screen_position: Vector2) -> void:
	if _build_mode == "" and _pending_ability == "":
		_board.clear_hover()
		return
	var local := _board_root.to_local(screen_position)
	var cell := grid.cell_of(local)
	if _build_mode != "":
		var def := GameData.tower(_build_mode)
		var result := grid.can_place(cell, int(def.get("cost", 0)), gold)
		var range_px := float(TowerStats.resolve(def, 1).get("range", 0.0)) * grid.cell_size
		_board.set_hover(cell, result == BuildGrid.PlaceResult.OK, range_px, grid.center_of(cell))
	else:
		_board.set_hover(cell, true, 0.0, grid.center_of(cell))


func _update_ability_preview() -> void:
	var def := _abilities.def_for(_pending_ability)
	if def.is_empty():
		return
	var screen_position := get_local_mouse_position()
	var local := _board_root.to_local(screen_position)
	var radius := float(def.get("radius_cells", 2.0)) * grid.cell_size
	_board.set_ability_preview(local, radius, Palette.element_color(String(def.get("color", "energy"))))


# --- Building -----------------------------------------------------------------------------------------

func _on_build_selected(tower_id: String) -> void:
	if _build_mode == tower_id:
		_build_mode = ""
		_board.set_preview_tower("")
		_hud.set_selected_tower("")
		_board.clear_hover()
		_hud.set_build_mode_active(false)
		return
	_build_mode = tower_id
	_pending_ability = ""
	_deselect_tower()
	_board.set_preview_tower(tower_id)
	_hud.set_selected_tower(tower_id)
	_hud.set_build_mode_active(true)
	var def := GameData.tower(tower_id)
	if gold < int(def.get("cost", 0)):
		_hud.toast(Loc.t("ui.reason.no_gold"), Palette.DANGER)
	else:
		_hud.toast(Loc.t("build.place_hint"), Palette.TEXT_MUTED)


func _try_place(cell: Vector2i) -> void:
	var result := place_tower(_build_mode, cell)
	if not result.is_empty():
		Audio.play_sfx("error", -8.0)
		_hud.toast(Loc.t(result), Palette.DANGER)


## Places a tower. Returns "" on success, or the localisation key explaining the refusal.
## Public (not `_`-prefixed) because the UI, replays and the headless smoke test all use it.
func place_tower(tower_id: String, cell: Vector2i) -> String:
	var def := GameData.tower(tower_id)
	if def.is_empty():
		return "ui.reason.out_of_bounds"
	var cost := int(def.get("cost", 0))
	var result := grid.can_place(cell, cost, gold)
	if result != BuildGrid.PlaceResult.OK:
		return BuildGrid.explain(result)
	gold -= cost
	var tower := Tower.new()
	tower.position = grid.center_of(cell)
	_entities.add_child(tower)
	tower.setup(tower_id, def, cell, self)
	tower.name = "Tower_%d_%d" % [cell.x, cell.y]
	_towers.append(tower)
	grid.set_tower(cell, tower)
	_recompute_buffs()
	_fx.ring(tower.position, 26.0, Palette.ACCENT, 0.35)
	_fx.dust(tower.position, Palette.CELL_BUILDABLE)
	Audio.play_sfx("build", -4.0, randf_range(0.95, 1.05))
	_hud.set_gold(gold)
	# Placing several towers in a row is the common case, so the mode stays armed — but the build
	# bar comes back now that the player is no longer reaching for a tile under it.
	_hud.set_selected_tower(_build_mode)
	_hud.set_build_mode_active(false)
	return ""


## Selects the tower on `cell` (no-op when the cell is empty). Returns the tower, if any.
func select_tower_at(cell: Vector2i) -> Tower:
	var tower := grid.tower_at(cell) as Tower
	if tower != null:
		_select_tower(tower)
	return tower


## Snapshot of the run, used by tests and by the results screen.
func snapshot() -> Dictionary:
	return {
		"gold": gold,
		"lives": lives,
		"lives_max": lives_max,
		"wave": _director.wave_index,
		"waves_total": WavePlan.wave_count(level),
		"enemies": _enemies.size(),
		"towers": _towers.size(),
		"finished": _finished,
		"gold_earned": gold_earned,
	}


func _select_tower(tower: Tower) -> void:
	if _selected != null:
		_selected.selected = false
	_selected = tower
	tower.selected = true
	_build_mode = ""
	_pending_ability = ""
	_board.set_preview_tower("")
	_hud.set_build_mode_active(false)
	_hud.show_tower_panel(tower, gold)


## Drops an armed build without placing: the cancel button, a repeated build tap or an
## out-of-board tap all end here, and the build bar returns.
func _cancel_build() -> void:
	if _build_mode == "":
		return
	_build_mode = ""
	_board.set_preview_tower("")
	_board.clear_hover()
	_hud.set_selected_tower("")
	_hud.set_build_mode_active(false)


func _deselect_tower() -> void:
	if _selected != null:
		_selected.selected = false
		_selected = null
	_hud.hide_tower_panel()
	if _build_mode == "":
		_hud.set_selected_tower("")
		_hud.set_build_mode_active(false)


## Upgrades a tower. Returns "" on success or the localisation key explaining the refusal.
func upgrade_tower(tower: Tower) -> String:
	if tower == null or not is_instance_valid(tower) or not tower.can_upgrade():
		return "tower.max_level"
	var cost := tower.upgrade_cost()
	if gold < cost:
		return "ui.reason.no_gold"
	gold -= cost
	tower.upgrade()
	_recompute_buffs()
	_fx.ring(tower.position, 30.0, Palette.GOLD, 0.4)
	Audio.play_sfx("upgrade", -4.0)
	_hud.set_gold(gold)
	_hud.update_tower_panel(tower, gold)
	return ""


## Installs a max-level module. Returns "" on success or a refusal reason key.
func install_module(tower: Tower, module_id: String) -> String:
	if tower == null or not is_instance_valid(tower):
		return "ui.reason.occupied"
	var cost := TowerStats.module_cost(tower.def, module_id)
	if not tower.available_modules().has(module_id):
		return "tower.max_level"
	if gold < cost:
		return "ui.reason.no_gold"
	gold -= cost
	tower.install_module(module_id)
	_recompute_buffs()
	Audio.play_sfx("upgrade", -3.0)
	_fx.ring(tower.position, 34.0, Palette.ACCENT, 0.45)
	_hud.set_gold(gold)
	_hud.update_tower_panel(tower, gold)
	return ""


## Sells a tower back for a partial refund. Returns the refunded amount.
func sell_tower(tower: Tower) -> int:
	if tower == null or not is_instance_valid(tower):
		return 0
	var refund := tower.sell_value()
	gold += refund
	grid.clear_tower(tower.cell)
	_towers.erase(tower)
	_fx.dust(tower.position, Palette.TEXT_MUTED)
	Audio.play_sfx("sell", -4.0)
	if _selected == tower:
		_selected = null
		_hud.hide_tower_panel()
	tower.queue_free()
	_recompute_buffs()
	_hud.set_gold(gold)
	return refund


## Every tower currently on the board (read-only view for UI and automation).
func towers_in_play() -> Array[Tower]:
	return _towers


func is_finished() -> bool:
	return _finished


## True once the world and the wave director are alive (guards callers against a failed boot).
func is_initialised() -> bool:
	return _director != null and grid != null


func _on_upgrade() -> void:
	if _selected == null:
		return
	var reason := upgrade_tower(_selected)
	if reason != "":
		Audio.play_sfx("error", -8.0)
		_hud.toast(Loc.t(reason), Palette.DANGER)


func _on_module(module_id: String) -> void:
	if _selected == null:
		return
	var reason := install_module(_selected, module_id)
	if reason != "":
		Audio.play_sfx("error", -8.0)
		_hud.toast(Loc.t(reason), Palette.DANGER)


func _on_sell() -> void:
	if _selected == null:
		return
	sell_tower(_selected)
	_deselect_tower()


func _on_targeting() -> void:
	if _selected == null:
		return
	_selected.cycle_targeting()
	_hud.update_tower_panel(_selected, gold)


## Support auras: every tower inside a beacon's radius gets its rate (and maybe damage) buffed.
func _recompute_buffs() -> void:
	var overclock := 1.7 if _overclock_left > 0.0 else 1.0
	for tower in _towers:
		if not is_instance_valid(tower):
			continue
		var rate := 1.0
		var damage := 1.0
		for beacon in _towers:
			if beacon == tower or not is_instance_valid(beacon) or not beacon.is_aura():
				continue
			if beacon.global_position.distance_to(tower.global_position) <= beacon.aura_range_px():
				rate += float(beacon.stats.get("aura_rate", 0.0))
				damage += float(beacon.stats.get("aura_damage", 0.0))
		tower.set_buffs(rate * overclock, damage)
	if _selected != null:
		_hud.update_tower_panel(_selected, gold)


# --- Abilities ------------------------------------------------------------------------------------------

func _on_ability_pressed(ability_id: String) -> void:
	var def := _abilities.def_for(ability_id)
	if def.is_empty():
		return
	if not _abilities.is_ready(ability_id):
		Audio.play_sfx("error", -10.0)
		_hud.toast("%s · %ds" % [Loc.t("ability.cooldown"),
			int(ceil(_abilities.cooldown_left(ability_id)))], Palette.TEXT_MUTED)
		return
	if bool(def.get("targeted", false)):
		_pending_ability = ability_id
		_build_mode = ""
		_board.set_preview_tower("")
		_deselect_tower()
		_hud.toast(Loc.t(String(def.get("desc_key", ""))), Palette.ACCENT)
		return
	_fire_ability(ability_id, Vector2.ZERO)


## Fires an ability immediately. Targeted abilities need a board position; untargeted ones ignore
## it. Public so the HUD, replays and automation share a single entry point.
func cast_ability(ability_id: String, at: Vector2 = Vector2.INF) -> bool:
	if not _abilities.is_ready(ability_id) or _finished:
		return false
	var def := _abilities.def_for(ability_id)
	if def.is_empty():
		return false
	if bool(def.get("targeted", false)) and at == Vector2.INF:
		return false
	_pending_ability = ""
	_board.clear_ability_preview()
	_fire_ability(ability_id, at)
	return true


func ability_ready(ability_id: String) -> bool:
	return _abilities.is_ready(ability_id)


func _cast_ability(local_position: Vector2) -> void:
	var ability_id := _pending_ability
	_pending_ability = ""
	_board.clear_ability_preview()
	_board.clear_hover()
	_fire_ability(ability_id, local_position)


func _fire_ability(ability_id: String, local_position: Vector2) -> void:
	var def := _abilities.def_for(ability_id)
	if not _abilities.use(ability_id):
		return
	_hud.update_abilities(_abilities)
	match ability_id:
		"airstrike":
			var radius := float(def.get("radius_cells", 2.2)) * grid.cell_size
			var damage := float(def.get("damage", 200.0))
			_fx.explosion(local_position, radius, Palette.GOLD)
			Audio.play_sfx("shoot_cannon", -2.0, 0.75)
			add_trauma(0.5)
			# `local_position` is board-local (FX space); targeting reads global positions, so the
			# same tap is converted once for the radius query.
			var origin := _board_root.to_global(local_position)
			for target in Targeting.in_radius(_enemies, origin, radius, true, true):
				var enemy := target as Enemy
				var falloff := Damage.splash_falloff(enemy.global_position.distance_to(origin), radius)
				_apply_damage(enemy, damage * falloff, {
					"damage_type": "explosive", "pierce": 4.0, "element": "explosive",
				})
		"overclock":
			_overclock_left = float(def.get("duration", 6.0))
			_recompute_buffs()
			Audio.play_sfx("upgrade", -2.0, 0.8)
			_hud.toast(Loc.t("ability.overclock.name"), Palette.ARC)
			for tower in _towers:
				_fx.ring(tower.position, 22.0, Palette.ARC, 0.5)


# --- Enemies ----------------------------------------------------------------------------------------------

func _spawn_enemy(enemy_id: String) -> void:
	if _enemies.size() >= Balance.MAX_ENEMIES:
		return
	var source := GameData.enemy(enemy_id)
	if source.is_empty():
		return
	var def := source.duplicate(true)
	def["_id"] = enemy_id
	var wave := _director.wave_index + 1
	var difficulty := App.difficulty()
	var hp := Balance.enemy_hp(float(def.get("hp", 50.0)), wave, float(level.get("hp_mult", 1.0)), difficulty)
	var speed := float(def.get("speed", 1.0)) * Balance.enemy_speed_mult(wave) * grid.cell_size
	var armor := float(def.get("armor", 0.0)) + Balance.enemy_armor_bonus(wave)
	var path := air_path if bool(def.get("is_air", false)) else ground_path

	var enemy := Enemy.new()
	_entities.add_child(enemy)
	enemy.setup(def, hp, speed, armor, path, randf_range(-1.0, 1.0))
	enemy.gold = Balance.enemy_gold(int(def.get("gold", 5)), wave, difficulty)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemies.append(enemy)
	_director.on_enemy_spawned()
	if enemy_id == "boss":
		Audio.play_sfx("boss", -2.0)
		_hud.toast(Loc.t("enemy.boss.name"), Palette.DANGER)
		add_trauma(0.35)


## Live enemies, already pruned on death/leak. Towers and effects read this every frame.
func get_enemies() -> Array[Enemy]:
	return _enemies


func _remove_enemy(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_director.on_enemy_removed()


func _on_enemy_died(enemy: Enemy) -> void:
	_remove_enemy(enemy)
	gold += enemy.gold
	gold_earned += enemy.gold
	_hud.set_gold(gold)
	Audio.play_sfx("death", -12.0, randf_range(0.9, 1.1))
	_fx.impact(enemy.position, Palette.element_color("kinetic"), 1.2)
	_spawn_split(enemy)


## Bosses break into smaller units: killing the big one is progress, not victory.
func _spawn_split(enemy: Enemy) -> void:
	var split: Dictionary = enemy.split
	if split.is_empty():
		return
	var child_id := String(split.get("enemy", "swarm"))
	var count := int(split.get("count", 3))
	for i in range(count):
		var source := GameData.enemy(child_id)
		if source.is_empty():
			continue
		var def := source.duplicate(true)
		def["_id"] = child_id
		var wave := _director.wave_index + 1
		var child := Enemy.new()
		_entities.add_child(child)
		child.setup(def,
			Balance.enemy_hp(float(def.get("hp", 20.0)), wave, float(level.get("hp_mult", 1.0)), App.difficulty()),
			float(def.get("speed", 1.0)) * Balance.enemy_speed_mult(wave) * grid.cell_size,
			float(def.get("armor", 0.0)) + Balance.enemy_armor_bonus(wave),
			enemy.path, randf_range(-1.0, 1.0))
		child.distance = maxf(0.0, enemy.distance - 24.0 + float(i) * 12.0)
		child.gold = Balance.enemy_gold(int(def.get("gold", 3)), wave, App.difficulty())
		child.died.connect(_on_enemy_died)
		child.leaked.connect(_on_enemy_leaked)
		_enemies.append(child)
		_director.on_enemy_spawned()
		_fx.explosion(enemy.position, 18.0, Palette.DANGER)


func _on_enemy_leaked(enemy: Enemy) -> void:
	_remove_enemy(enemy)
	lives -= enemy.lives_cost
	Audio.play_sfx("leak", -2.0)
	add_trauma(0.45)
	_fx.ring(enemy.path.points[enemy.path.points.size() - 1], 40.0, Palette.DANGER, 0.5)
	_hud.set_lives(lives, lives_max)
	if lives <= 0:
		_on_defeat()


# --- Damage resolution ---------------------------------------------------------------------------------------

func on_tower_fired(tower: Tower, target: Object, stats: Dictionary) -> void:
	var payload := {
		"damage": float(stats.get("damage", 0.0)) * tower.damage_mult,
		"damage_type": String(stats.get("damage_type", "kinetic")),
		"element": String(stats.get("element", "energy")),
		"pierce": float(stats.get("pierce", 0.0)),
		"splash": float(stats.get("splash", 0.0)) * grid.cell_size,
		"slow_factor": float(stats.get("slow_factor", 0.0)),
		"slow_duration": float(stats.get("slow_duration", 0.0)),
		"mark_bonus": float(stats.get("mark_bonus", 0.0)),
		"dot_dps": float(stats.get("dot_dps", 0.0)),
		"dot_duration": float(stats.get("dot_duration", 0.0)),
	}
	Audio.play_varied("shoot_" + tower.tower_id if Audio.SFX_FILES.has("shoot_" + tower.tower_id)
		else "shoot_pulse", -14.0, 0.06)
	# `_fx` draws in board-local space, so the muzzle (already local) is passed straight through.
	_fx.muzzle(tower.muzzle_position(),
		(Vector2(target.get("position")) - tower.position).normalized(),
		Palette.element_color(payload["element"]))

	if String(stats.get("kind", "projectile")) == "projectile":
		var projectile := Projectile.new()
		_projectile_layer.add_child(projectile)
		# Projectiles are deliberately fast: flight time should read as impact, not as travel.
		projectile.setup(tower.muzzle_position(), target, payload,
			float(stats.get("projectile_speed", 12.0)) * grid.cell_size * 1.6, self)
	else:
		_fire_beam(tower, target, stats, payload)


## Instant-hit weapons: rail (single, long) and arc (chain through a crowd).
func _fire_beam(tower: Tower, target: Object, stats: Dictionary, payload: Dictionary) -> void:
	var color := Palette.element_color(String(payload["element"]))
	var chain := float(stats.get("chain", 0.0))
	var targets: Array = [target]
	if chain >= 1.0:
		targets = Targeting.chain_targets(_enemies, tower.global_position, target, int(chain),
			tower.range_px(), bool(stats.get("targets_air", true)), bool(stats.get("targets_ground", true)))
	var points := PackedVector2Array([tower.muzzle_position()])
	for i in range(targets.size()):
		var enemy := targets[i] as Enemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		points.append(enemy.position)
		_apply_damage(enemy, Damage.chain_damage(float(payload["damage"]), i), payload)
	_fx.beam(points, color, 3.5 if chain < 1.0 else 2.5, 0.14)


func on_projectile_hit(projectile: Projectile) -> void:
	var payload := projectile.payload
	# FX draws in board-local space; targeting queries read global positions. Keep both.
	var hit_local := projectile.position
	var hit_global := projectile.global_position
	var splash := float(payload.get("splash", 0.0))
	var color := Palette.element_color(String(payload.get("element", "energy")))
	if splash > 0.0:
		_fx.explosion(hit_local, splash, color)
		Audio.play_sfx("hit", -14.0)
		for target in Targeting.in_radius(_enemies, hit_global, splash, true, true):
			var enemy := target as Enemy
			var falloff := Damage.splash_falloff(enemy.global_position.distance_to(hit_global), splash)
			_apply_damage(enemy, float(payload["damage"]) * falloff, payload)
	else:
		# The target may have died (and been freed) while the shell was in flight: casting a
		# freed object throws, so validity is checked *before* the cast.
		var enemy: Enemy = null
		if is_instance_valid(projectile.target):
			enemy = projectile.target as Enemy
		if enemy != null and enemy.alive:
			_apply_damage(enemy, float(payload["damage"]), payload)
			_fx.impact(hit_local, color, 1.0)
		else:
			_fx.impact(hit_local, color, 0.6)


func _apply_damage(enemy: Enemy, raw: float, payload: Dictionary) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
		return
	var resist := float(enemy.resist.get(String(payload.get("damage_type", "kinetic")), 0.0))
	var resolved := Damage.resolve(raw, enemy.armor, float(payload.get("pierce", 0.0)), resist,
		enemy.mark_bonus)
	var killed := enemy.take_damage(resolved)
	if float(payload.get("slow_factor", 0.0)) > 0.0:
		enemy.apply_slow(float(payload["slow_factor"]), float(payload.get("slow_duration", 1.0)))
	if float(payload.get("mark_bonus", 0.0)) > 0.0:
		enemy.apply_mark(float(payload["mark_bonus"]), 3.0)
	if float(payload.get("dot_dps", 0.0)) > 0.0:
		enemy.apply_dot(float(payload["dot_dps"]), float(payload.get("dot_duration", 2.0)))
	if bool(App.get_setting("damage_numbers")):
		_fx.number(enemy.position + Vector2(0, -14),
			str(roundi(resolved)), Palette.element_color(String(payload.get("element", "energy"))))
	if killed:
		add_trauma(0.06)


# --- Wave flow -------------------------------------------------------------------------------------------------

func _on_prep_started(wave_index: int, seconds: float) -> void:
	_hud.set_prep(seconds, wave_index + 1)
	_hud.set_preview(WavePlan.preview(level, wave_index))
	if WavePlan.has_boss(level, wave_index):
		_hud.toast(Loc.t("game.boss_incoming"), Palette.DANGER)


func _on_prep_remaining(wave_index: int, seconds_left: float) -> void:
	_hud.set_prep(seconds_left, wave_index + 1)


func _on_call_wave() -> void:
	if not _director.is_prep():
		return
	var skipped := _director.call_wave_now()
	var bonus := Balance.early_call_bonus(skipped)
	if bonus > 0:
		gold += bonus
		gold_earned += bonus
		_hud.set_gold(gold)
		_hud.toast("+%d %s" % [bonus, Loc.t("game.wave_bonus")], Palette.GOLD)
		Audio.play_sfx("gold", -8.0)


func _on_wave_started(wave_index: int) -> void:
	_hud.set_wave_running(wave_index + 1)
	Audio.play_sfx("wave", -8.0)
	_fx.clear_all()


func _on_wave_cleared(wave_index: int) -> void:
	var bonus := WavePlan.clear_bonus(level, wave_index)
	var interest := Balance.interest(gold, App.difficulty())
	gold += bonus + interest
	gold_earned += bonus + interest
	_hud.set_gold(gold)
	Audio.play_sfx("gold", -10.0, 1.1)
	if interest > 0:
		_hud.toast("+%d · %s +%d" % [bonus, Loc.t("game.interest"), interest], Palette.GOLD)
	else:
		_hud.toast("+%d %s" % [bonus, Loc.t("hud.gold")], Palette.GOLD)


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	var speed := SPEEDS[_speed_index]
	Engine.time_scale = float(speed)
	_hud.set_speed(speed)
	Audio.play_sfx("select", -12.0)


# --- End states -------------------------------------------------------------------------------------------------

func _on_victory() -> void:
	if _finished:
		return
	var stars := Balance.stars(true, lives, lives_max)
	var result := App.record_result(level_index, stars, WavePlan.wave_count(level), true)
	_best_hint = bool(result.get("new_best_stars", false))
	Audio.play_sfx("victory", -4.0)
	Audio.stop_music(1.0)
	_show_result(true, stars, result)


func _on_defeat() -> void:
	if _finished:
		return
	App.record_result(level_index, 0, maxi(1, _director.wave_index + 1), false)
	Audio.play_sfx("defeat", -4.0)
	Audio.stop_music(1.0)
	_show_result(false, 0, {})



func _show_result(won: bool, stars: int, result: Dictionary) -> void:
	_finished = true
	_speed_index = 0
	Engine.time_scale = 1.0
	App.set_paused(true)
	_build_mode = ""
	_pending_ability = ""
	_selected = null
	var overlay := Overlay.open(self,
		Loc.t("game.victory") if won else Loc.t("game.defeat"),
		Loc.t(String(level.get("name_key", ""))))
	overlay.show_stars(stars)
	overlay.add_row("wave", Loc.t("game.wave_reached"),
		"%d / %d" % [_director.wave_index if won else maxi(1, _director.wave_index + 1),
			WavePlan.wave_count(level)], Palette.ACCENT)
	overlay.add_row("heart", Loc.t("game.lives_left"), "%d / %d" % [maxi(0, lives), lives_max],
		Palette.DANGER)
	overlay.add_row("coin", Loc.t("game.gold_earned"), str(gold_earned), Palette.GOLD)
	if _best_hint:
		overlay.add_row("star", Loc.t("result.stars_earned"), Loc.t("result.unlocked"), Palette.GOLD)
	if won and level_index + 1 < GameData.level_count():
		overlay.add_button(Loc.t("result.next"), "PrimaryButton", func() -> void:
			App.start_level(level_index + 1))
	overlay.add_button(Loc.t("result.retry"), "PrimaryButton" if not won else "", func() -> void:
		_restart())
	overlay.add_button(Loc.t("result.menu"), "GhostButton", func() -> void:
		App.goto_scene(App.LEVEL_SELECT_SCENE))
	overlay.focus_default()
	_overlay = overlay


func _restart() -> void:
	Engine.time_scale = 1.0
	App.set_paused(false)
	App.start_level(level_index)


# --- Pause -------------------------------------------------------------------------------------------------------

func _open_pause() -> void:
	if _finished or _overlay != null:
		return
	App.set_paused(true)
	# Pausing mid-placement would leave the build bar hidden on resume; drop the mode so the
	# player comes back to a clean HUD.
	_cancel_build()
	_pending_ability = ""
	_board.clear_ability_preview()
	var overlay := Overlay.open(self, Loc.t("pause.title"),
		Loc.t(String(level.get("name_key", ""))))
	overlay.add_row("wave", Loc.t("hud.wave"),
		"%d / %d" % [_director.wave_index + 1, WavePlan.wave_count(level)], Palette.ACCENT)
	# Each button closes the dialog first, so the overlay is always freed exactly once.
	var choose := func(action: Callable) -> void:
		overlay.close()
		action.call()
	overlay.add_button(Loc.t("common.resume"), "PrimaryButton",
		func() -> void: choose.call(_resume))
	overlay.add_button(Loc.t("common.restart"), "",
		func() -> void: choose.call(_restart))
	overlay.add_button(Loc.t("menu.settings"), "GhostButton", func() -> void:
		choose.call(func() -> void:
			Engine.time_scale = 1.0
			App.set_paused(false)
			App.open_settings(App.GAME_SCENE)))
	overlay.add_button(Loc.t("menu.levels"), "GhostButton", func() -> void:
		choose.call(func() -> void:
			Engine.time_scale = 1.0
			App.set_paused(false)
			App.goto_scene(App.LEVEL_SELECT_SCENE)))
	overlay.focus_default()
	_overlay = overlay
	overlay.dismissed.connect(_resume)


func _resume() -> void:
	_overlay = null
	App.set_paused(false)
	Engine.time_scale = float(SPEEDS[_speed_index])


# --- Misc -----------------------------------------------------------------------------------------------------------

func _show_first_hint() -> void:
	if bool(App.get_setting("tutorial_seen")):
		return
	_hud.toast(Loc.t("tip.place"), Palette.TEXT_MUTED)
	App.set_setting("tutorial_seen", true)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "grid_overlay":
		_board.set_grid_visible(bool(value))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Engine.time_scale = 1.0
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		# The board is scaled into the available area; without this a resized window keeps the
		# old framing. Everything under `_board_root` uses local coordinates, so re-scaling it
		# does not disturb towers, enemies, projectiles or effects.
		_layout()
	super._notification(what)
