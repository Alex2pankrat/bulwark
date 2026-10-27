class_name Icons
extends RefCounted
## Minimal vector iconography, drawn from primitives.
##
## The whole HUD identity is stroke-and-fill geometry rather than bitmap icons: it stays crisp
## at any resolution (1080p phone to 4K monitor), inherits the palette, and keeps the project's
## art direction consistent instead of mixing in a third-party icon set. Glyphs are described
## in a 0..1 unit square, so one implementation serves 14 px labels and 64 px buttons.

## Draws `glyph` centred inside `rect`.
static func draw_glyph(canvas: CanvasItem, glyph: String, rect: Rect2, color: Color,
		weight: float = -1.0) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	if unit <= 1.0:
		return
	var stroke := weight if weight > 0.0 else maxf(1.5, unit * 0.11)
	var origin := rect.position + (rect.size - Vector2(unit, unit)) * 0.5
	var p := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x, y) * unit
	match glyph:
		"heart": _heart(canvas, p, unit, color)
		"coin": _coin(canvas, p, unit, color, stroke)
		"wave": _chevrons(canvas, p, unit, color, stroke)
		"pause":
			canvas.draw_rect(Rect2(p.call(0.3, 0.2), Vector2(0.16, 0.6) * unit), color)
			canvas.draw_rect(Rect2(p.call(0.54, 0.2), Vector2(0.16, 0.6) * unit), color)
		"play":
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.32, 0.18), p.call(0.82, 0.5), p.call(0.32, 0.82)]), color)
		"speed":
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.15, 0.2), p.call(0.55, 0.5), p.call(0.15, 0.8)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.5, 0.2), p.call(0.9, 0.5), p.call(0.5, 0.8)]), color)
		"bolt":
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.58, 0.08), p.call(0.22, 0.56), p.call(0.45, 0.56),
				p.call(0.38, 0.92), p.call(0.78, 0.4), p.call(0.53, 0.4)]), color)
		"bomb":
			canvas.draw_circle(p.call(0.45, 0.62), 0.3 * unit, color)
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.62, 0.4), p.call(0.72, 0.26), p.call(0.86, 0.2)]),
				color, stroke, true)
		"star": _star(canvas, p, color)
		"lock":
			canvas.draw_arc(p.call(0.5, 0.45), 0.2 * unit, PI, TAU, 16, color, stroke, true)
			canvas.draw_rect(Rect2(p.call(0.24, 0.45), Vector2(0.52, 0.42) * unit), color)
		"back", "arrow_left":
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.62, 0.18), p.call(0.32, 0.5), p.call(0.62, 0.82)]),
				color, stroke, true)
			canvas.draw_line(p.call(0.34, 0.5), p.call(0.86, 0.5), color, stroke, true)
		"arrow_right":
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.38, 0.18), p.call(0.68, 0.5), p.call(0.38, 0.82)]),
				color, stroke, true)
			canvas.draw_line(p.call(0.14, 0.5), p.call(0.66, 0.5), color, stroke, true)
		"close":
			canvas.draw_line(p.call(0.24, 0.24), p.call(0.76, 0.76), color, stroke, true)
			canvas.draw_line(p.call(0.76, 0.24), p.call(0.24, 0.76), color, stroke, true)
		"check":
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.18, 0.54), p.call(0.42, 0.76), p.call(0.82, 0.26)]),
				color, stroke, true)
		"upgrade":
			canvas.draw_line(p.call(0.5, 0.82), p.call(0.5, 0.2), color, stroke, true)
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.26, 0.44), p.call(0.5, 0.2), p.call(0.74, 0.44)]),
				color, stroke, true)
		"sell":
			canvas.draw_arc(p.call(0.5, 0.5), 0.34 * unit, 0, TAU, 20, color, stroke, true)
			canvas.draw_polyline(PackedVector2Array([
				p.call(0.35, 0.42), p.call(0.5, 0.58), p.call(0.65, 0.42)]),
				color, stroke, true)
		"target":
			canvas.draw_arc(p.call(0.5, 0.5), 0.3 * unit, 0, TAU, 20, color, stroke, true)
			canvas.draw_circle(p.call(0.5, 0.5), 0.08 * unit, color)
			for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				var a: Vector2 = Vector2(0.5, 0.5) + dir * 0.42
				var b: Vector2 = Vector2(0.5, 0.5) + dir * 0.3
				canvas.draw_line(p.call(a.x, a.y), p.call(b.x, b.y), color, stroke, true)
		"sound":
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.16, 0.38), p.call(0.36, 0.38), p.call(0.58, 0.16),
				p.call(0.58, 0.84), p.call(0.36, 0.62), p.call(0.16, 0.62)]), color)
			canvas.draw_arc(p.call(0.56, 0.5), 0.22 * unit, -PI / 3.0, PI / 3.0, 12, color, stroke, true)
			canvas.draw_arc(p.call(0.56, 0.5), 0.34 * unit, -PI / 3.0, PI / 3.0, 14, color, stroke, true)
		"music":
			canvas.draw_line(p.call(0.38, 0.7), p.call(0.38, 0.2), color, stroke, true)
			canvas.draw_line(p.call(0.38, 0.2), p.call(0.74, 0.14), color, stroke, true)
			canvas.draw_line(p.call(0.74, 0.14), p.call(0.74, 0.64), color, stroke, true)
			canvas.draw_circle(p.call(0.3, 0.72), 0.11 * unit, color)
			canvas.draw_circle(p.call(0.66, 0.66), 0.11 * unit, color)
		"globe":
			canvas.draw_arc(p.call(0.5, 0.5), 0.36 * unit, 0, TAU, 24, color, stroke, true)
			canvas.draw_line(p.call(0.14, 0.5), p.call(0.86, 0.5), color, stroke * 0.8, true)
			canvas.draw_arc(p.call(0.5, 0.5), 0.16 * unit, 0, TAU, 16, color, stroke * 0.8, true)
		"reset":
			canvas.draw_arc(p.call(0.5, 0.52), 0.32 * unit, -PI * 0.85, PI * 0.75, 20, color, stroke, true)
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.62, 0.1), p.call(0.86, 0.3), p.call(0.56, 0.34)]), color)
		"grid":
			for row in range(2):
				for col in range(2):
					canvas.draw_rect(Rect2(
						p.call(0.2 + col * 0.34, 0.2 + row * 0.34),
						Vector2(0.26, 0.26) * unit), color)
		"snow":
			for angle in [0.0, PI / 3.0, -PI / 3.0]:
				var dir := Vector2(cos(angle), sin(angle))
				canvas.draw_line(p.call(0.5, 0.5) - dir * 0.4 * unit,
					p.call(0.5, 0.5) + dir * 0.4 * unit, color, stroke, true)
		"chain":
			for point in [Vector2(0.18, 0.7), Vector2(0.5, 0.3), Vector2(0.82, 0.7)]:
				canvas.draw_circle(p.call(point.x, point.y), 0.11 * unit, color)
			canvas.draw_line(p.call(0.24, 0.63), p.call(0.45, 0.37), color, stroke * 0.7, true)
			canvas.draw_line(p.call(0.55, 0.37), p.call(0.76, 0.63), color, stroke * 0.7, true)
		"skull":
			canvas.draw_circle(p.call(0.5, 0.44), 0.32 * unit, color)
			canvas.draw_rect(Rect2(p.call(0.34, 0.62), Vector2(0.32, 0.26) * unit), color)
			canvas.draw_circle(p.call(0.38, 0.44), 0.08 * unit, Color(0, 0, 0, 0.55))
			canvas.draw_circle(p.call(0.62, 0.44), 0.08 * unit, Color(0, 0, 0, 0.55))
		"info":
			canvas.draw_arc(p.call(0.5, 0.5), 0.36 * unit, 0, TAU, 24, color, stroke, true)
			canvas.draw_circle(p.call(0.5, 0.3), 0.07 * unit, color)
			canvas.draw_line(p.call(0.5, 0.45), p.call(0.5, 0.72), color, stroke, true)
		"shield":
			canvas.draw_colored_polygon(PackedVector2Array([
				p.call(0.5, 0.1), p.call(0.84, 0.28), p.call(0.76, 0.7),
				p.call(0.5, 0.92), p.call(0.24, 0.7), p.call(0.16, 0.28)]), color)
		"plus":
			canvas.draw_line(p.call(0.5, 0.2), p.call(0.5, 0.8), color, stroke, true)
			canvas.draw_line(p.call(0.2, 0.5), p.call(0.8, 0.5), color, stroke, true)
		"minus":
			canvas.draw_line(p.call(0.2, 0.5), p.call(0.8, 0.5), color, stroke, true)
		"gear":
			canvas.draw_arc(p.call(0.5, 0.5), 0.22 * unit, 0, TAU, 18, color, stroke, true)
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				var dir := Vector2(cos(angle), sin(angle))
				canvas.draw_line(p.call(0.5, 0.5) + dir * 0.28 * unit,
					p.call(0.5, 0.5) + dir * 0.42 * unit, color, stroke, true)
		_:
			canvas.draw_arc(p.call(0.5, 0.5), 0.34 * unit, 0, TAU, 20, color, stroke, true)


static func _heart(canvas: CanvasItem, p: Callable, unit: float, color: Color) -> void:
	canvas.draw_circle(p.call(0.31, 0.34), 0.21 * unit, color)
	canvas.draw_circle(p.call(0.69, 0.34), 0.21 * unit, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		p.call(0.1, 0.4), p.call(0.9, 0.4), p.call(0.5, 0.9)]), color)


static func _coin(canvas: CanvasItem, p: Callable, unit: float, color: Color, stroke: float) -> void:
	canvas.draw_circle(p.call(0.5, 0.5), 0.42 * unit, color)
	canvas.draw_arc(p.call(0.5, 0.5), 0.26 * unit, 0, TAU, 18,
		Color(0, 0, 0, 0.28), maxf(1.0, stroke * 0.7), true)


static func _chevrons(canvas: CanvasItem, p: Callable, unit: float, color: Color, stroke: float) -> void:
	canvas.draw_polyline(PackedVector2Array([
		p.call(0.16, 0.62), p.call(0.5, 0.26), p.call(0.84, 0.62)]), color, stroke, true)
	canvas.draw_polyline(PackedVector2Array([
		p.call(0.16, 0.86), p.call(0.5, 0.5), p.call(0.84, 0.86)]), color, stroke, true)


static func _star(canvas: CanvasItem, p: Callable, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI / 2.0 + TAU * float(i) / 10.0
		var radius := 0.46 if i % 2 == 0 else 0.19
		points.append(p.call(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius))
	canvas.draw_colored_polygon(points, color)
