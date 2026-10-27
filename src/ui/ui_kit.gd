class_name UIKit
extends RefCounted
## Small declarative helpers for building the interface in code.
##
## Screens stay readable ("vbox of header + buttons") and every control automatically follows
## the shared theme, minimum touch size and focus rules. Anything that needs more than a couple
## of lines gets its own widget class instead (Glyph, ValueSlider, ToggleSwitch, TowerButton…).

## Minimum finger target on a phone, scaled by the UI stretch factor.
const TOUCH := Vector2(48, 48)


static func vbox(separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func label(text: String, variation: String = "") -> Label:
	var node := Label.new()
	node.text = text
	if variation != "":
		node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func wrapped(text: String, variation: String = "", min_width: float = 0.0) -> Label:
	var node := label(text, variation)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_width > 0.0:
		node.custom_minimum_size.x = min_width
	return node


static func icon(glyph: String, px: float = 20.0, color: Color = Palette.TEXT) -> Glyph:
	return Glyph.of(glyph, px, color)


static func spacer(expand_horizontal: bool = false, expand_vertical: bool = false) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand_horizontal:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, variation: String = "", on_pressed: Callable = Callable()) -> Button:
	var node := Button.new()
	node.text = text
	if variation != "":
		node.theme_type_variation = variation
	node.custom_minimum_size.y = TOUCH.y
	node.focus_mode = Control.FOCUS_ALL
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	_sfx(node)
	return node


static func icon_button(glyph: String, color: Color = Palette.TEXT, on_pressed: Callable = Callable(),
		size: float = 48.0) -> Button:
	var node := Button.new()
	node.theme_type_variation = "IconButton"
	node.custom_minimum_size = Vector2(size, size)
	node.focus_mode = Control.FOCUS_ALL
	var glyph_node := Glyph.of(glyph, size * 0.5, color)
	glyph_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(glyph_node)
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	_sfx(node)
	return node


static func panel(variation: String = "") -> PanelContainer:
	var node := PanelContainer.new()
	if variation != "":
		node.theme_type_variation = variation
	return node


## Creates the vertical body inside an existing panel and returns it.
static func card_body(container: PanelContainer, separation: int = 12) -> VBoxContainer:
	var box := vbox(separation)
	container.add_child(box)
	return box


static func separator() -> HSeparator:
	return HSeparator.new()


## Horizontal row of mutually exclusive chips (styling only — call `wire_chips` to react).
static func chip_row(options: Array[Dictionary], selected: int) -> HBoxContainer:
	var row := hbox(6)
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var chip := button(String(option.get("label", "")),
			"ChipSelected" if i == selected else "ChipButton")
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 38
		row.add_child(chip)
	return row


## Connects every chip in `row` to `on_select(index)` and keeps the visual selection in sync.
static func wire_chips(row: HBoxContainer, on_select: Callable) -> void:
	for i in range(row.get_child_count()):
		var chip := row.get_child(i) as Button
		if chip == null:
			continue
		chip.pressed.connect(func() -> void:
			on_select.call(i)
			style_chips(row, i))


## Re-applies chip styling after the selection changed.
static func style_chips(row: HBoxContainer, selected: int) -> void:
	var index := 0
	for child in row.get_children():
		if child is Button:
			(child as Button).theme_type_variation = "ChipSelected" if index == selected else "ChipButton"
			index += 1


## Label + icon pair used across the HUD and info panels.
static func stat(icon_name: String, text: String, value_variation: String = "Label",
		icon_color: Color = Palette.TEXT_MUTED) -> HBoxContainer:
	var row := hbox(6)
	row.add_child(icon(icon_name, 16, icon_color))
	row.add_child(label(text, value_variation))
	return row


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", left)
	box.add_theme_constant_override("margin_top", top)
	box.add_theme_constant_override("margin_right", right)
	box.add_theme_constant_override("margin_bottom", bottom)
	box.add_child(child)
	return box


static func full_rect(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Gives keyboard/gamepad users something to focus as soon as a screen opens.
static func focus_first(root: Node) -> bool:
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.visible:
				control.grab_focus()
				return true
			if focus_first(control):
				return true
	return false


## Click/hover feedback for every button without repeating the wiring everywhere.
static func _sfx(button_node: Button) -> void:
	button_node.mouse_entered.connect(func() -> void:
		if button_node.focus_mode != Control.FOCUS_NONE:
			Audio.play_sfx("ui_hover", -16.0))
	button_node.pressed.connect(func() -> void: Audio.play_sfx("ui_click", -6.0))
