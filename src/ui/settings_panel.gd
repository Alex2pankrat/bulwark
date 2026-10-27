class_name SettingsPanel
extends VBoxContainer
## The settings body, shared by the settings screen and the in-game pause menu.
##
## One implementation means a setting can never drift between the two entry points, and it
## makes the accessibility options reachable in the middle of a level — which is exactly when
## a player needs them.
##
## Every control writes straight through `App.set_setting()`, which applies, emits and saves.

signal closed()

var _shake_slider: ValueSlider
var _shake_value: Label


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_build()


func _build() -> void:
	_section(Loc.t("settings.audio"))
	_slider_row("sound", "settings.master", "master_volume")
	_slider_row("music", "settings.music", "music_volume")
	_slider_row("bolt", "settings.sfx", "sfx_volume")

	_section(Loc.t("settings.gameplay"))
	_choice_row("settings.difficulty", _difficulty_options(), App.difficulty(),
		func(index: int) -> void: App.set_setting("difficulty", index))
	_choice_row("settings.language", _language_options(),
		SettingsModel.LANGUAGES.find(String(App.get_setting("language"))),
		func(index: int) -> void: App.set_setting("language", SettingsModel.LANGUAGES[index]))

	_section(Loc.t("settings.accessibility"))
	_toggle_row("grid", "settings.grid_overlay", "grid_overlay")
	_toggle_row("target", "settings.damage_numbers", "damage_numbers")
	_toggle_row("reset", "settings.reduce_motion", "reduce_motion")
	_toggle_row("shield", "settings.colorblind", "colorblind_mode")
	_shake_row()

	_section(Loc.t("credits.license"))
	_button_row("settings.reset_progress", "DangerButton", _confirm_reset)


# --- Rows ------------------------------------------------------------------------------------------

func _section(title: String) -> void:
	add_child(UIKit.label(title, "HeadingLabel"))


func _slider_row(icon_name: String, label_key: String, setting_key: String) -> void:
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
	add_child(row)


func _toggle_row(icon_name: String, label_key: String, setting_key: String) -> void:
	var row := UIKit.hbox(10)
	row.add_child(Glyph.of(icon_name, 18, Palette.TEXT_MUTED))
	var label := UIKit.label(Loc.t(label_key), "SmallLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := ToggleSwitch.new()
	toggle.is_on = bool(App.get_setting(setting_key))
	toggle.toggled.connect(func(value: bool) -> void: App.set_setting(setting_key, value))
	row.add_child(toggle)
	add_child(row)


func _shake_row() -> void:
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
		App.set_setting("screen_shake", value)
		_shake_value.text = "%d%%" % roundi(value * 100.0))
	row.add_child(_shake_slider)
	_shake_value = UIKit.label("%d%%" % roundi(_shake_slider.value * 100.0), "TinyLabel")
	_shake_value.custom_minimum_size.x = 40
	row.add_child(_shake_value)
	add_child(row)


func _choice_row(label_key: String, options: Array[String], selected: int, on_select: Callable) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(UIKit.label(Loc.t(label_key), "SmallLabel"))
	var entries: Array[Dictionary] = []
	for option in options:
		entries.append({"label": option})
	var row := UIKit.chip_row(entries, selected)
	UIKit.wire_chips(row, on_select)
	column.add_child(row)
	add_child(column)


func _button_row(label_key: String, variation: String, on_press: Callable) -> void:
	var button := UIKit.button(Loc.t(label_key), variation, on_press)
	button.custom_minimum_size = Vector2(0, 46)
	add_child(button)


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
