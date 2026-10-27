class_name Projectile
extends Node2D
## A homing shell.
##
## Homes on the target while it lives and keeps flying to the last known position if the target
## dies first, so a shot always resolves (no silent disappearance, and splash still lands where
## the player expects). The world applies the damage on `hit`.

var speed: float = 900.0
var payload: Dictionary = {}
var target: Object = null
var target_position: Vector2 = Vector2.ZERO
var color: Color = Palette.ACCENT
var radius: float = 3.5
## The world that resolves the hit (`GameScreen`), set at spawn.
var world: Node = null
var _trail: Array[Vector2] = []


func setup(from: Vector2, at: Object, p_payload: Dictionary, p_speed: float, p_world: Node) -> void:
	global_position = from
	target = at
	world = p_world
	payload = p_payload
	speed = maxf(60.0, p_speed)
	color = Palette.element_color(String(p_payload.get("element", "energy")))
	radius = float(p_payload.get("visual_radius", 3.5))
	target_position = at.get("global_position") if at != null and is_instance_valid(at) else from


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target) and bool(target.get("alive")):
		target_position = target.get("global_position")
	var to_target := target_position - position
	var step := speed * delta
	if to_target.length() <= maxf(step, radius + 4.0):
		global_position = target_position
		_resolve()
		return
	_trail.push_front(position)
	if _trail.size() > 4:
		_trail.pop_back()
	position += to_target.normalized() * step
	queue_redraw()


func _resolve() -> void:
	if world != null and world.has_method("on_projectile_hit"):
		world.on_projectile_hit(self)
	queue_free()


func _draw() -> void:
	for i in range(_trail.size()):
		var alpha := 0.35 * (1.0 - float(i) / float(_trail.size() + 1))
		var local := _trail[i] - position
		draw_circle(local, radius * (1.0 - 0.15 * float(i)), Palette.with_alpha(color, alpha))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.85))
