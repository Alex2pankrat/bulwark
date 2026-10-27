class_name Overlay
extends Control
## Modal dialog used for pause and end-of-level results.
##
## Runs with `PROCESS_MODE_ALWAYS` so it keeps working while the game tree is paused, which is
## what lets the pause menu exist without a second scene.

signal dismissed()

var _card: PanelContainer
var _body: VBoxContainer
var _buttons: HBoxContainer
var _title: Label
var _subtitle: Label
var _stars: HBoxContainer


static func open(parent: Node, title: String, subtitle: String = "") -> Overlay:
	var overlay := Overlay.new()
	overlay.build(title, subtitle)
	parent.add_child(overlay)
	return overlay


func build(title: String, subtitle: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeFactory.get_theme()

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = UIKit.panel("OverlayPanel")
	_card.custom_minimum_size = Vector2(420, 0)
	center.add_child(_card)
	var column := UIKit.card_body(_card, 14)
	column.custom_minimum_size.x = 380

	_title = UIKit.label(title, "TitleLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = UIKit.wrapped(subtitle, "SmallLabel", 360)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	_stars = UIKit.hbox(6)
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_stars)

	_body = UIKit.vbox(6)
	column.add_child(_body)

	_buttons = UIKit.hbox(10)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_buttons)

	# Animate in unless the player asked for less motion.
	if not bool(App.get_setting("reduce_motion")):
		_card.scale = Vector2(0.94, 0.94)
		_card.pivot_offset = Vector2(190, 0)
		var tween := create_tween()
		tween.tween_property(_card, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.14)


func set_subtitle(text: String) -> void:
	_subtitle.text = text


func add_button(text: String, variation: String, callback: Callable) -> Button:
	var button := UIKit.button(text, variation, func() -> void:
		Audio.play_sfx("ui_click", -4.0)
		callback.call())
	button.custom_minimum_size = Vector2(140, 46)
	_buttons.add_child(button)
	return button


func add_row(icon_name: String, label_text: String, value_text: String,
		color: Color = Palette.TEXT) -> void:
	var row := UIKit.hbox(8)
	row.add_child(Glyph.of(icon_name, 16, color))
	row.add_child(UIKit.label(label_text, "SmallLabel"))
	row.add_child(UIKit.spacer(true))
	row.add_child(UIKit.label(value_text, "HeadingLabel"))
	_body.add_child(row)


## Three outline slots; `count` of them filled based on the run result.
func show_stars(count: int, maximum: int = 3) -> void:
	for child in _stars.get_children():
		child.queue_free()
	for i in range(maximum):
		var filled := i < count
		_stars.add_child(Glyph.of("star", 30, Palette.GOLD if filled else Palette.TEXT_DIM))


func focus_default() -> void:
	UIKit.focus_first(_buttons)


func close() -> void:
	dismissed.emit()
	queue_free()
