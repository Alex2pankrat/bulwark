class_name AbilityButton
extends Button
## Round ability button with a radial cooldown mask and a seconds-remaining readout.
##
## The mask is an *overlay* child rather than a custom `_draw` on the Button itself, so the
## themed button background, focus ring and pressed states all keep working untouched.

var ability_id: String = ""

var _mask: CooldownMask
var _label: Label
var _glyph: Glyph
var _color: Color = Palette.ACCENT
var _cooldown := 0.0


func setup(def: Dictionary) -> void:
	ability_id = String(def.get("id", ""))
	_cooldown = maxf(0.1, float(def.get("cooldown", 30.0)))
	custom_minimum_size = Vector2(64, 64)
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = "IconButton"
	_color = Palette.element_color(String(def.get("color", "energy")))
	tooltip_text = "%s\n%s" % [
		Loc.t(String(def.get("name_key", ""))),
		Loc.t(String(def.get("desc_key", ""))),
	]

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_glyph = Glyph.of(String(def.get("icon", "bolt")), 26, _color)
	center.add_child(_glyph)

	_mask = CooldownMask.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_label = UIKit.label("", "TinyLabel")
	row.add_child(_label)


## `fraction` 1 = just used, 0 = ready.
func update_cooldown(fraction: float, seconds_left: float) -> void:
	_mask.fraction = clampf(fraction, 0.0, 1.0)
	_mask.queue_redraw()
	_label.text = "" if fraction <= 0.0 else str(int(ceil(seconds_left)))
	_glyph.color = _color if fraction <= 0.0 else Palette.with_alpha(_color, 0.45)


## Darkens the button as a pie from 12 o'clock, clockwise, by the remaining charge.
class CooldownMask:
	extends Control
	var fraction: float = 0.0

	func _draw() -> void:
		if fraction <= 0.0:
			return
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.52
		var steps := 32
		var points := PackedVector2Array([center])
		var sweep := TAU * fraction
		for i in range(steps + 1):
			var angle := -PI * 0.5 + sweep * float(i) / float(steps)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color(0.05, 0.06, 0.07, 0.7))
