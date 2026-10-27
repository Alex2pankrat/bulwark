class_name Glyph
extends Control
## A single vector icon. Purely decorative: it never takes input, so it can be dropped inside
## buttons, rows and labels without stealing the click.

@export var glyph: String = "star":
	set(value):
		glyph = value
		queue_redraw()
@export var color: Color = Palette.TEXT:
	set(value):
		color = value
		queue_redraw()
@export var weight: float = -1.0:
	set(value):
		weight = value
		queue_redraw()


## Convenience constructor so call sites read as `Glyph.of("coin", 20, Palette.GOLD)`.
static func of(p_glyph: String, px: float = 20.0, p_color: Color = Palette.TEXT) -> Glyph:
	var node := Glyph.new()
	node.glyph = p_glyph
	node.color = p_color
	node.custom_minimum_size = Vector2(px, px)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(20, 20)


func _draw() -> void:
	Icons.draw_glyph(self, glyph, Rect2(Vector2.ZERO, size), color, weight)
