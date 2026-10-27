class_name Tower
extends Node2D
## A placed tower: stats, targeting, cooldown and its own visuals.
##
## The tower owns *when* it shoots and *what* it shoots at; the world (`GameScreen`) owns what a
## shot does — projectiles, beams, splash, damage numbers. That split keeps this file about
## tower behaviour only, and lets the same tower code be used by any world implementation.

signal stats_changed(tower: Tower)

const SPRITE_DIR := "res://assets/sprites/towers/"
const SPRITE_SCALE := 0.80

var tower_id: String = ""
var def: Dictionary = {}
var level: int = 1
var module: String = ""
var stats: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var targeting_mode: int = Targeting.Mode.FIRST

## Multipliers coming from support auras and abilities (recomputed by the world).
var rate_mult: float = 1.0
var damage_mult: float = 1.0

var world: Node = null
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _sprite: Sprite2D
var _cooldown: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _idle_tween: Tween


func setup(p_id: String, p_def: Dictionary, p_cell: Vector2i, p_world: Node) -> void:
	tower_id = p_id
	def = p_def
	cell = p_cell
	world = p_world

	_sprite = Sprite2D.new()
	var sprite_path := SPRITE_DIR + String(def.get("sprite", "")) + ".png"
	if ResourceLoader.exists(sprite_path):
		_sprite.texture = load(sprite_path)
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

	refresh_stats()
	# A small "pop" so placement reads as an action rather than a state change.
	if not bool(App.get_setting("reduce_motion")):
		scale = Vector2(0.7, 0.7)
		_idle_tween = create_tween()
		_idle_tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Stats and upgrades -----------------------------------------------------------------------

func refresh_stats() -> void:
	stats = TowerStats.resolve(def, level, module)
	queue_redraw()
	stats_changed.emit(self)


func upgrade_cost() -> int:
	return TowerStats.upgrade_cost(def, level)


func can_upgrade() -> bool:
	return level < TowerStats.MAX_LEVEL


func upgrade() -> void:
	if not can_upgrade():
		return
	level += 1
	refresh_stats()


func available_modules() -> Dictionary:
	return TowerStats.modules(def) if level >= TowerStats.MAX_LEVEL and module == "" else {}


func install_module(module_id: String) -> void:
	if not available_modules().has(module_id):
		return
	module = module_id
	refresh_stats()


func invested() -> int:
	return TowerStats.invested(def, level, module)


func sell_value() -> int:
	return int(floor(invested() * Balance.SELL_REFUND))


func range_px() -> float:
	return float(stats.get("range", 0.0)) * 64.0


func aura_range_px() -> float:
	return float(stats.get("aura_range", 0.0)) * 64.0


func is_aura() -> bool:
	return String(stats.get("kind", "")) == "aura"


func cycle_targeting() -> void:
	targeting_mode = Targeting.next_mode(targeting_mode)
	queue_redraw()


func set_buffs(p_rate_mult: float, p_damage_mult: float) -> void:
	rate_mult = p_rate_mult
	damage_mult = p_damage_mult


# --- Firing -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_aura():
		return
	var rate := float(stats.get("fire_rate", 0.0)) * rate_mult
	if rate <= 0.0:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := Targeting.acquire(world.get_enemies(), global_position, range_px(),
		targeting_mode, bool(stats.get("targets_air", true)), bool(stats.get("targets_ground", true)))
	if target == null:
		return
	_cooldown = 1.0 / rate
	_fire_at(target)


func _fire_at(target: Object) -> void:
	var target_pos: Vector2 = target.get("global_position")
	_aim = (target_pos - global_position).normalized()
	if bool(stats.get("rotates", false)) and _sprite != null:
		_sprite.rotation = _aim.angle() + PI * 0.5
	world.on_tower_fired(self, target, stats)


# --- Visuals ------------------------------------------------------------------------------------

func muzzle_position() -> Vector2:
	return global_position + _aim * 22.0


func _draw() -> void:
	# Level pips under the tower: filled = current level, so upgrades are readable at a glance.
	var pip_y := 26.0
	var count := TowerStats.MAX_LEVEL
	var spacing := 9.0
	var start_x := -spacing * float(count - 1) * 0.5
	for i in range(count):
		var center := Vector2(start_x + spacing * i, pip_y)
		if i < level:
			draw_circle(center, 3.0, Palette.GOLD)
		else:
			draw_circle(center, 2.4, Palette.with_alpha(Palette.BG, 0.55))
	if module != "":
		draw_circle(Vector2(0, pip_y + 9.0), 2.6, Palette.ACCENT)
	if selected:
		draw_arc(Vector2.ZERO, range_px(), 0, TAU, 72, Palette.with_alpha(Palette.ACCENT, 0.85), 2.0, true)
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 24, Palette.ACCENT, 2.0, true)
	elif is_aura():
		draw_arc(Vector2.ZERO, aura_range_px(), 0, TAU, 48,
			Palette.with_alpha(Palette.HEAL, 0.28), 1.5, true)
