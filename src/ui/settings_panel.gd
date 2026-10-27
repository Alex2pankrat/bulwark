class_name SettingsPanel
extends VBoxContainer
## The settings body, shown by the settings screen (reachable from the main menu and from the
## in-game pause menu).
##
## One implementation means a setting can never drift between the two entry points, and it
## makes the accessibility options reachable in the middle of a level — which is exactly when
## a player needs them.
##
## Every control writes straight through `App.set_setting()`, which applies, emits and saves.
##
## The layout is responsive: when the panel is wide enough (a desktop window, or a short
## phone-landscape viewport) the sections split into two columns so the panel uses the width
## instead of stacking into one tall strip; on a narrow/tall viewport they stack. The panel
## decides for itself from its own size, so the same code is correct on every screen.

signal closed()
## Emitted when the panel re-lays itself out (column count change), so a host screen can
## re-fit its scroll content to the new height.
signal layout_changed()

## Minimum panel width before the sections split into two columns.
const TWO_COLUMN_MIN_WIDTH := 760.0

var _shake_slider: ValueSlider
var _shake_value: Label
var _body: Control
var _columns := 1


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build()


func _build() -> void:
	if _body == null:
		_body = UIKit.vbox(16)
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_body)
	else:
		for child in _body.get_children():
			child.queue_free()
	_layout_sections()


## Rebuilds only when the column count actually changes, so dragging a window edge does not
## throw away a slider the player is dragging.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		var desired := 2 if size.x >= TWO_COLUMN_MIN_WIDTH else 1
		if desired != _columns:
			_columns = desired
			_build()
			layout_changed.emit()
	super._notification(what)


func _layout_sections() -> void:
	var sections: Array = [
		_audio_section(),
		_gameplay_section(),
		_accessibility_section(),
		_licence_section(),
	]
	if _columns >= 2 and sections.size() >= 2:
		var half: int = int((sections.size() + 1) / 2.0)
		var left := UIKit.vbox(20)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var right := UIKit.vbox(20)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(sections.size()):
			(left if i < half else right).add_child(sections[i])
		var row := UIKit.hbox(24)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		row.add_child(right)
		_body.add_child(row)
	else:
		var stack := UIKit.vbox(20)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for section in sections:
			stack.add_child(section)
		_body.add_child(stack)


# --- Sections ------------------------------------------------------------------------------------

func _audio_section() -> VBoxContainer:
	var box := _section_box()
	box.add_child(UIKit.label(Loc.t("settings.audio"), "HeadingLabel"))
	_slider_row(box, "sound", "settings.master", "master_volume")
	_slider_row(box, "music", "settings.music", "music_volume")
	_slider_row(box, "bolt", "settings.sfx", "sfx_volume")
	return box


func _gameplay_section() -> VBoxContainer:
	var box := _section_box()
	box.add_child(UIKit.label(Loc.t("settings.gameplay"), "HeadingLabel"))
	_choice_row(box, "settings.difficulty", _difficulty_options(), App.difficulty(),
		func(index: int) -> void: App.set_setting("difficulty", index))
	_choice_row(box, "settings.language", _language_options(),
		SettingsModel.LANGUAGES.find(String(App.get_setting("language"))),
		func(index: int) -> void: App.set_setting("language", SettingsModel.LANGUAGES[index]))
	return box


func _accessibility_section() -> VBoxContainer:
	var box := _section_box()
	box.add_child(UIKit.label(Loc.t("settings.accessibility"), "HeadingLabel"))
	_toggle_row(box, "grid", "settings.grid_overlay", "grid_overlay")
	_toggle_row(box, "target", "settings.damage_numbers", "damage_numbers")
	_toggle_row(box, "reset", "settings.reduce_motion", "reduce_motion")
	_toggle_row(box, "shield", "settings.colorblind", "colorblind_mode")
	_shake_row(box)
	return box


func _licence_section() -> VBoxContainer:
	var box := _section_box()
	box.add_child(UIKit.label(Loc.t("credits.license"), "HeadingLabel"))
	_button_row(box, "settings.reset_progress", "DangerButton", _confirm_reset)
	return box


func _section_box() -> VBoxContainer:
	var box := UIKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


# --- Rows ------------------------------------------------------------------------------------------

func _slider_row(parent: Control, icon_name: String, label_key: String, setting_key: String) -> void:
	var row := UIKit.hbox(10)
	row.add_child(Glyph.of(icon_name, 18, Palette.TEXT_MUTED))
	var label := UIKit.label(Loc.t(label_key), "SmallLabel")
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := ValueSlider.new()
	slider.value = float(App.get_setting(setting_key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		App.set_setting(setting_key, value))
	row.add_child(slider)
	parent.add_child(row)


func _toggle_row(parent: Control, icon_name: String, label_key: String, setting_key: String) -> void:
	var row := UIKit.hbox(10)
	row.add_child(Glyph.of(icon_name, 18, Palette.TEXT_MUTED))
	var label := UIKit.label(Loc.t(label_key), "SmallLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := ToggleSwitch.new()
	toggle.is_on = bool(App.get_setting(setting_key))
	toggle.toggled.connect(func(value: bool) -> void: App.set_setting(setting_key, value))
	row.add_child(toggle)
	parent.add_child(row)


func _shake_row(parent: Control) -> void:
	var row := UIKit.hbox(10)
	row.add_child(Glyph.of("star", 18, Palette.TEXT_MUTED))
	var label := UIKit.label(Loc.t("settings.screen_shake"), "SmallLabel")
	label.custom_minimum_size.x = 150
	row.add_child(label)
	_shake_slider = ValueSlider.new()
	_shake_slider.value = float(App.get_setting("screen_shake"))
	_shake_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shake_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shake_slider.value_changed.connect(func(value: float) -> void:
		App.set_setting("screen_shake", value))
	row.add_child(_shake_slider)
	_shake_value = UIKit.label("%d%%" % roundi(_shake_slider.value * 100.0), "TinyLabel")
	_shake_value.custom_minimum_size.x = 40
	row.add_child(_shake_value)
	parent.add_child(row)


func _choice_row(parent: Control, label_key: String, options: Array[String], selected: int,
		on_select: Callable) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(UIKit.label(Loc.t(label_key), "SmallLabel"))
	var entries: Array[Dictionary] = []
	for option in options:
		entries.append({"label": option})
	var row := UIKit.chip_row(entries, selected)
	UIKit.wire_chips(row, on_select)
	column.add_child(row)
	parent.add_child(column)


func _button_row(parent: Control, label_key: String, variation: String, on_press: Callable) -> void:
	var button := UIKit.button(Loc.t(label_key), variation, on_press)
	button.custom_minimum_size = Vector2(0, 46)
	parent.add_child(button)


func _difficulty_options() -> Array[String]:
	return [Loc.t("difficulty.easy"), Loc.t("difficulty.normal"), Loc.t("difficulty.hard")]


func _language_options() -> Array[String]:
	return ["English", "Русский"]


func _confirm_reset() -> void:
	var overlay := Overlay.open(get_tree().current_scene, Loc.t("settings.reset_progress"),
		Loc.t("settings.reset_confirm"))
	overlay.add_button(Loc.t("common.cancel"), "GhostButton", func() -> void: overlay.close())
	overlay.add_button(Loc.t("common.reset"), "DangerButton", func() -> void:
		App.reset_progress()
		overlay.close())
	overlay.focus_default()
