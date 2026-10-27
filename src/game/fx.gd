class_name Fx
extends Node2D
## One node for every transient visual: muzzle flashes, impacts, explosions, lightning, dust
## and floating damage numbers.
##
## Everything is data in three arrays and drawn in a single `_draw()` pass. No per-effect nodes
## means no allocation spikes while a wave is being shredded, which is exactly the situation
## where a hitch is most noticeable (see the performance-optimization playbook).

const MAX_FLOATS := Balance.MAX_DAMAGE_POPUPS
const GRAVITY := 260.0

var _shapes: Array[Dictionary] = []     ## {kind, pos, radius, color, life, max_life, points}
var _particles: Array[Dictionary] = []  ## {pos, vel, life, max_life, size, color, gravity}
var _floats: Array[Dictionary] = []     ## {pos, vel, text, color, life, max_life}
var _font: Font


func _ready() -> void:
	z_index = 20
	_font = ThemeFactory.font(700)


func _process(delta: float) -> void:
	var dirty := false
	for i in range(_shapes.size() - 1, -1, -1):
		_shapes[i]["life"] = float(_shapes[i]["life"]) - delta
		if float(_shapes[i]["life"]) <= 0.0:
			_shapes.remove_at(i)
		dirty = true
	for i in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[i]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(i)
			continue
		var vel: Vector2 = particle["vel"]
		vel.y += GRAVITY * float(particle.get("gravity", 0.0)) * delta
		particle["vel"] = vel * (1.0 - 2.2 * delta)
		particle["pos"] = Vector2(particle["pos"]) + vel * delta
		dirty = true
	for i in range(_floats.size() - 1, -1, -1):
		var item: Dictionary = _floats[i]
		item["life"] = float(item["life"]) - delta
		if float(item["life"]) <= 0.0:
			_floats.remove_at(i)
			continue
		item["pos"] = Vector2(item["pos"]) + Vector2(item["vel"]) * delta
		item["vel"] = Vector2(item["vel"]) * (1.0 - 1.6 * delta) + Vector2(0, -260.0 * delta)
		dirty = true
	if dirty:
		queue_redraw()


# --- Spawning ------------------------------------------------------------------------------------

func muzzle(pos: Vector2, direction: Vector2, color: Color) -> void:
	_shapes.append({
		"kind": "muzzle", "pos": pos, "radius": 9.0, "color": color,
		"dir": direction, "life": 0.09, "max_life": 0.09,
	})
	for i in range(3):
		var spread := direction.rotated(randf_range(-0.5, 0.5))
		_particles.append({
			"pos": pos, "vel": spread * randf_range(120.0, 260.0),
			"life": 0.18, "max_life": 0.18, "size": randf_range(1.5, 2.6),
			"color": color, "gravity": 0.1,
		})


func impact(pos: Vector2, color: Color, strength: float = 1.0) -> void:
	_shapes.append({"kind": "flash", "pos": pos, "radius": 12.0 * strength, "color": color,
		"life": 0.14, "max_life": 0.14})
	for i in range(int(4 * strength)):
		var angle := randf() * TAU
		_particles.append({
			"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * randf_range(60.0, 190.0),
			"life": 0.25, "max_life": 0.25, "size": randf_range(1.2, 2.4),
			"color": color, "gravity": 0.4,
		})


func explosion(pos: Vector2, radius: float, color: Color) -> void:
	_shapes.append({"kind": "blast", "pos": pos, "radius": radius, "color": color,
		"life": 0.34, "max_life": 0.34})
	_shapes.append({"kind": "ring", "pos": pos, "radius": radius, "color": color,
		"life": 0.4, "max_life": 0.4})
	for i in range(14):
		var angle := randf() * TAU
		_particles.append({
			"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * randf_range(120.0, 420.0),
			"life": randf_range(0.25, 0.5), "max_life": 0.5,
			"size": randf_range(1.5, 3.4), "color": color, "gravity": 0.5,
		})


func ring(pos: Vector2, radius: float, color: Color, duration: float = 0.4) -> void:
	_shapes.append({"kind": "ring", "pos": pos, "radius": radius, "color": color,
		"life": duration, "max_life": duration})


func dust(pos: Vector2, color: Color) -> void:
	for i in range(8):
		var angle := randf() * TAU
		_particles.append({
			"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * randf_range(40.0, 130.0),
			"life": 0.3, "max_life": 0.3, "size": randf_range(1.6, 3.0),
			"color": color, "gravity": 0.2,
		})


## Chain lightning / rail tracer: a poly-line that fades out.
func beam(points: PackedVector2Array, color: Color, width: float = 3.0,
		duration: float = 0.16) -> void:
	if points.size() < 2:
		return
	_shapes.append({"kind": "beam", "pos": Vector2.ZERO, "radius": width, "color": color,
		"points": points, "life": duration, "max_life": duration})


func number(pos: Vector2, text: String, color: Color) -> void:
	if _floats.size() >= MAX_FLOATS:
		_floats.pop_front()
	_floats.append({
		"pos": pos + Vector2(randf_range(-6.0, 6.0), -6.0),
		"vel": Vector2(randf_range(-24.0, 24.0), -70.0),
		"text": text, "color": color, "life": 0.7, "max_life": 0.7,
	})


func clear_all() -> void:
	_shapes.clear()
	_particles.clear()
	_floats.clear()
	queue_redraw()


# --- Drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	for shape in _shapes:
		var t := 1.0 - float(shape["life"]) / maxf(0.001, float(shape["max_life"]))
		var color: Color = shape["color"]
		match String(shape["kind"]):
			"muzzle":
				var dir: Vector2 = shape["dir"]
				var pos: Vector2 = shape["pos"]
				draw_line(pos, pos + dir * 14.0 * (1.0 - t),
					Palette.with_alpha(color, 1.0 - t), 4.0 * (1.0 - t) + 1.0, true)
				draw_circle(pos, float(shape["radius"]) * (1.0 - t * 0.6),
					Palette.with_alpha(color, 0.9 * (1.0 - t)))
			"flash":
				draw_circle(shape["pos"], float(shape["radius"]) * (0.4 + t),
					Palette.with_alpha(color, 0.75 * (1.0 - t)))
			"blast":
				draw_circle(shape["pos"], float(shape["radius"]) * (0.25 + 0.75 * t),
					Palette.with_alpha(color, 0.32 * (1.0 - t)))
			"ring":
				draw_arc(shape["pos"], float(shape["radius"]) * (0.2 + 0.8 * t), 0, TAU, 48,
					Palette.with_alpha(color, 0.85 * (1.0 - t)), 3.0, true)
			"beam":
				var alpha := 1.0 - t
				draw_polyline(shape["points"], Palette.with_alpha(color, alpha),
					float(shape["radius"]), true)
				draw_polyline(shape["points"], Palette.with_alpha(Color.WHITE, alpha * 0.7),
					maxf(1.0, float(shape["radius"]) * 0.35), true)
	for particle in _particles:
		var fade := float(particle["life"]) / maxf(0.001, float(particle["max_life"]))
		draw_circle(particle["pos"], float(particle["size"]) * fade,
			Palette.with_alpha(particle["color"], fade))
	for item in _floats:
		var fade := clampf(float(item["life"]) / maxf(0.001, float(item["max_life"])), 0.0, 1.0)
		var text: String = item["text"]
		var font_size := 15
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos: Vector2 = Vector2(item["pos"]) - Vector2(width * 0.5, 0)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3,
			Palette.with_alpha(Palette.BG, 0.8 * fade))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Palette.with_alpha(item["color"], fade))
