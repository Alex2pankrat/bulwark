class_name Enemy
extends Node2D
## A single enemy walking the lane.
##
## Movement is pure "distance along the path" (see `PathModel`), so speed changes from slows,
## frame hitches and speed boosts all behave identically. Rendering is deliberately cheap: one
## sprite plus a `_draw()` health bar that only redraws when health/status actually changes.

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)

const SPRITE_DIR := "res://assets/sprites/enemies/"
const SPRITE_ANGLE_OFFSET := PI * 0.5

var def: Dictionary = {}
var enemy_id: String = ""
var max_hp: float = 1.0
var hp: float = 1.0
var base_speed: float = 0.0        ## pixels per second at 1× speed
var armor: float = 0.0
var gold: int = 0
var lives_cost: int = 1
var is_air: bool = false
var radius_px: float = 18.0
var resist: Dictionary = {}

var path: PathModel
var distance: float = 0.0
var progress: float = 0.0
var alive: bool = true

var slow: Dictionary = {}          ## {factor, time}
var dot: Dictionary = {}           ## {dps, time}
var mark_bonus: float = 0.0
var mark_time: float = 0.0
## Heal aura strength this unit projects on nearby allies (fraction of their max HP/second).
## Applied by the world each tick, never to itself.
var heal_rate: float = 0.0
var split: Dictionary = {}
var immune_slow: bool = false

var _sprite: Sprite2D
var _lane_offset: Vector2 = Vector2.ZERO
var _flash: float = 0.0
var _death_tween: Tween


func setup(p_def: Dictionary, p_hp: float, p_speed: float, p_armor: float,
		p_path: PathModel, lane_offset: float = 0.0) -> void:
	def = p_def
	enemy_id = String(p_def.get("_id", ""))
	max_hp = maxf(1.0, p_hp)
	hp = max_hp
	base_speed = p_speed
	armor = p_armor
	gold = int(p_def.get("gold", 5))
	lives_cost = int(p_def.get("lives", 1))
	is_air = bool(p_def.get("is_air", false))
	resist = p_def.get("resist", {})
	immune_slow = bool(p_def.get("immune_slow", false))
	split = p_def.get("split", {})
	heal_rate = float(p_def.get("heal", {}).get("rate", 0.0))
	path = p_path

	var scale_factor := float(p_def.get("scale", 0.6))
	radius_px = float(p_def.get("radius", 0.3)) * 64.0
	# Ground units get a small perpendicular offset so a group does not overlap into one blob.
	if not is_air:
		_lane_offset = Vector2(0.0, lane_offset * 64.0 * 0.55)

	_sprite = Sprite2D.new()
	var path_sprite := SPRITE_DIR + String(p_def.get("sprite", "grunt")) + ".png"
	if ResourceLoader.exists(path_sprite):
		_sprite.texture = load(path_sprite)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	_update_transform()


func speed_multiplier() -> float:
	var slow_factor := 1.0
	if not slow.is_empty() and float(slow.get("factor", 0.0)) > 0.0:
		slow_factor = 1.0 - clampf(float(slow["factor"]), 0.0, 0.85)
	return slow_factor


func current_speed() -> float:
	return base_speed * speed_multiplier()


func _process(delta: float) -> void:
	if not alive:
		return
	_tick_status(delta)
	if not alive:
		return
	distance += current_speed() * delta
	if distance >= path.total_length:
		alive = false
		leaked.emit(self)
		return
	progress = path.ratio_at(distance)
	_update_transform()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		_sprite.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.2, 2.2), _flash)


func _tick_status(delta: float) -> void:
	if not slow.is_empty():
		slow["time"] = float(slow["time"]) - delta
		if float(slow["time"]) <= 0.0:
			slow = {}
			_redraw_status()
	if not dot.is_empty():
		dot["time"] = float(dot["time"]) - delta
		var dps := float(dot.get("dps", 0.0))
		if dps > 0.0:
			hp -= dps * delta
			queue_redraw()
			if hp <= 0.0:
				_die()
				return
		if float(dot["time"]) <= 0.0:
			dot = {}
			_redraw_status()
	if mark_time > 0.0:
		mark_time = maxf(0.0, mark_time - delta)
		if mark_time <= 0.0:
			mark_bonus = 0.0
			queue_redraw()


func _update_transform() -> void:
	var base := path.position_at(distance)
	var dir := path.direction_at(distance)
	if is_air:
		position = base
		# Slight vertical lift so fliers read as airborne even in a flat art style.
		position += Vector2(0, -6)
	else:
		position = base + _lane_offset
	# Every sprite is drawn facing "up", so a quarter turn aligns it with the direction of
	# travel. Ground units used to keep rotation 0 and always faced the top of the screen; they
	# now turn at every bend like the fliers already did.
	rotation = dir.angle() + SPRITE_ANGLE_OFFSET


# --- Combat -------------------------------------------------------------------------------------

## Applies already-resolved damage. Returns true when this hit killed the enemy.
## Armour and resistances have already been applied by `Damage.resolve` in the game screen.
func take_damage(amount: float) -> bool:
	if not alive or amount <= 0.0:
		return false
	hp -= amount
	_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		_die()
		return true
	return false


func apply_slow(factor: float, duration: float) -> void:
	if immune_slow or factor <= 0.0:
		return
	slow = Damage.merge_slow(slow, factor, duration)
	_redraw_status()


func apply_dot(dps: float, duration: float) -> void:
	dot = Damage.merge_dot(dot, dps, duration)
	_redraw_status()


func apply_mark(bonus: float, duration: float) -> void:
	mark_bonus = maxf(mark_bonus, bonus)
	mark_time = maxf(mark_time, duration)
	queue_redraw()


## Heals another enemy (used by the mender support unit).
func heal(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func _die() -> void:
	if not alive:
		return
	alive = false
	died.emit(self)
	# Short dissolve, then free. Any tower targeting us simply skips non-alive enemies.
	_death_tween = create_tween()
	_death_tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.14)
	_death_tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.14)
	_death_tween.tween_callback(queue_free)


func _redraw_status() -> void:
	if _sprite == null:
		return
	var tint := Color.WHITE
	if not dot.is_empty():
		tint = tint.lerp(Color(1.35, 0.85, 0.7), 0.5)
	if not slow.is_empty():
		tint = tint.lerp(Color(0.7, 0.95, 1.35), 0.55)
	_sprite.modulate = tint
	queue_redraw()


# --- Health bar ----------------------------------------------------------------------------------

func _draw() -> void:
	if not alive or hp >= max_hp:
		return
	var width := maxf(26.0, radius_px * 2.2)
	var height := 4.0
	var top := -radius_px - 12.0
	var bar := Rect2(Vector2(-width * 0.5, top), Vector2(width, height))
	draw_rect(bar, Color(0, 0, 0, 0.55))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var fill := Palette.DANGER if ratio < 0.35 else Palette.WARN if ratio < 0.7 else Palette.ACCENT
	draw_rect(Rect2(bar.position, Vector2(width * ratio, height)), fill)
	if mark_time > 0.0:
		draw_arc(Vector2.ZERO, radius_px + 4.0, 0, TAU, 18,
			Palette.with_alpha(Palette.ARC, 0.8), 2.0, true)
