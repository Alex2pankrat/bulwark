class_name TutorialBanner
extends Control
## Dismissible card that shows the current onboarding tip above the board.
##
## The game screen drives it from the `Tutorial` controller's `step_changed` signal; the banner
## itself is presentation only. It sits at the top of the playfield, away from the build bar,
## and never blocks board taps.

signal skip_pressed()

var _tip_label: Label
var _step_label: Label
var _compact := false


func _ready() -> void:
	theme = ThemeFactory.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact = UIKit.is_compact()
	_build()


func _build() -> void:
	var card := UIKit.panel("OverlayPanel")
	card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 12.0
	card.offset_top = 70.0 if not _compact else 64.0
	card.offset_right = -12.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var body := UIKit.card_body(card, 10)
	_step_label = UIKit.label("", "TinyLabel")
	_step_label.add_theme_color_override("font_color", Palette.ACCENT)
	body.add_child(_step_label)
	_tip_label = UIKit.wrapped("", "SmallLabel", 360 if not _compact else 460)
	if _compact:
		_tip_label.add_theme_font_size_override("font_size", 16)
	body.add_child(_tip_label)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skip := UIKit.button(Loc.t("tutorial.skip"), "GhostButton",
		func() -> void: skip_pressed.emit())
	skip.custom_minimum_size = Vector2(88 if not _compact else 104, 34 if not _compact else 42)
	if _compact:
		skip.add_theme_font_size_override("font_size", 14)
	row.add_child(skip)
	body.add_child(row)


func set_step(step_index: int, total: int, tip_key: String) -> void:
	_step_label.text = Loc.tf("tutorial.step", [step_index + 1, total])
	_tip_label.text = Loc.t(tip_key)


# show() / hide() are the inherited CanvasItem methods (visible = true / false). The game
# screen calls them directly; defining custom wrappers would shadow the native methods and
# Godot rejects that, so they are intentionally not re-declared here.
