class_name MenuBackdrop
extends Control
## Faint animated backdrop: a drifting dot grid plus slow orbit rings.
##
## Deliberately near-invisible (alpha ~0.05–0.12) so menus stay calm and text stays readable; it
## only exists so the screen is not a flat rectangle. `reduce_motion` freezes it.

const DOT_SPACING := 44.0
const DOT_RADIUS := 1.6
const DRIFT := 12.0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if bool(App.get_setting("reduce_motion")):
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var offset := Vector2(sin(_time * 0.12) * DRIFT, cos(_time * 0.1) * DRIFT)
	var color := Palette.with_alpha(Palette.ACCENT, 0.09)
	var y := fposmod(offset.y, DOT_SPACING)
	while y < size.y:
		var x := fposmod(offset.x, DOT_SPACING)
		while x < size.x:
			draw_circle(Vector2(x, y), DOT_RADIUS, color)
			x += DOT_SPACING
		y += DOT_SPACING

	# Three slow orbiting rings in the corners: motion without noise.
	var centers := [
		Vector2(size.x * 0.14, size.y * 0.82),
		Vector2(size.x * 0.88, size.y * 0.18),
		Vector2(size.x * 0.72, size.y * 0.9),
	]
	for i in range(centers.size()):
		var center: Vector2 = centers[i]
		var radius := 90.0 + float(i) * 46.0 + sin(_time * 0.35 + float(i)) * 8.0
		draw_arc(center, radius, 0, TAU, 48,
			Palette.with_alpha(Palette.ACCENT if i % 2 == 0 else Palette.GOLD, 0.06), 1.5, true)
