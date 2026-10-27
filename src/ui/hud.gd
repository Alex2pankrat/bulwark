class_name HUD
extends Control
## In-level interface: status chips, wave control, build bar, ability bar, tower inspector.
##
## Layout is deliberately overlay-based (top strip + bottom strip, empty middle) rather than a
## side panel: it survives portrait, landscape and ultrawide without a second layout code path,
## keeps the whole board visible, and puts build buttons under the thumbs on a phone.
##
## The HUD never reads game state directly — the game screen pushes values in, the HUD emits
## intents out.

signal build_selected(tower_id: String)
signal call_wave_pressed()
signal speed_pressed()
signal pause_pressed()
signal ability_pressed(ability_id: String)
signal upgrade_pressed()
signal sell_pressed()
signal targeting_pressed()
signal module_pressed(module_id: String)
signal panel_closed()

const CHIP_HEIGHT := 40.0

var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _status_label: Label
var _status_hint: Label
var _call_button: Button
var _speed_button: Button
var _speed_glyph: Glyph
var _build_row: HBoxContainer
var _ability_row: HBoxContainer
var _preview_row: HBoxContainer
var _tower_panel: TowerPanel
var _toast: PanelContainer
var _toast_label: Label
var _status_panel: PanelContainer
var _toast_tween: Tween
var _build_buttons: Dictionary = {}
var _ability_buttons: Dictionary = {}
var _bottom_slot: HBoxContainer
var _selected_tower_id := ""
var _wave_total: int = 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# --- Construction ---------------------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	column.add_child(_margin(_build_top_bar(), 14, 12, 14, 0))
	column.add_child(UIKit.spacer(false, true))
	column.add_child(_margin(_build_bottom_bar(), 14, 0, 14, 12))

	_build_toast()


func _build_top_bar() -> Control:
	var row := UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lives_label = _chip(row, "heart", Palette.DANGER)
	_gold_label = _chip(row, "coin", Palette.GOLD)
	_wave_label = _chip(row, "wave", Palette.ACCENT)
	row.add_child(UIKit.spacer(true))
	_speed_button = UIKit.button("1×", "ChipButton", func() -> void: speed_pressed.emit())
	_speed_button.custom_minimum_size = Vector2(58, CHIP_HEIGHT)
	row.add_child(_speed_button)
	row.add_child(UIKit.icon_button("pause", Palette.TEXT, func() -> void: pause_pressed.emit(), CHIP_HEIGHT))
	return row


func _build_bottom_bar() -> Control:
	var column := UIKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Wave status: one centred card above the build bar, hidden while a wave is running so the
	# board gets the whole screen exactly when the player is looking at it.
	_status_panel = UIKit.panel("HudPanel")
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var status_box := UIKit.hbox(14)
	_status_panel.add_child(status_box)
	var text_box := UIKit.vbox(2)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label = UIKit.label("", "HeadingLabel")
	_status_hint = UIKit.label("", "TinyLabel")
	text_box.add_child(_status_label)
	text_box.add_child(_status_hint)
	status_box.add_child(text_box)
	_preview_row = UIKit.hbox(10)
	_preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(_preview_row)
	_call_button = UIKit.button(Loc.t("game.call_now"), "PrimaryButton",
		func() -> void: call_wave_pressed.emit())
	_call_button.custom_minimum_size = Vector2(196, 42)
	status_box.add_child(_call_button)
	var status_wrapper := UIKit.hbox(0)
	status_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	status_wrapper.add_child(_status_panel)
	column.add_child(status_wrapper)

	_bottom_slot = UIKit.hbox(12)
	_bottom_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_row = UIKit.hbox(8)
	_build_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_slot.add_child(_build_row)

	_tower_panel = TowerPanel.new()
	_tower_panel.visible = false
	_tower_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_panel.upgrade_pressed.connect(func() -> void: upgrade_pressed.emit())
	_tower_panel.sell_pressed.connect(func() -> void: sell_pressed.emit())
	_tower_panel.targeting_pressed.connect(func() -> void: targeting_pressed.emit())
	_tower_panel.module_pressed.connect(func(id: String) -> void: module_pressed.emit(id))
	_tower_panel.closed.connect(func() -> void: panel_closed.emit())
	_bottom_slot.add_child(_tower_panel)

	_bottom_slot.add_child(UIKit.spacer(true))
	_ability_row = UIKit.hbox(8)
	_ability_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_slot.add_child(_ability_row)
	column.add_child(_bottom_slot)
	return column


func _build_toast() -> void:
	_toast = UIKit.panel("HudPanel")
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast.modulate = Color(1, 1, 1, 0)
	_toast_label = UIKit.label("", "SmallLabel")
	_toast_label.add_theme_color_override("font_color", Palette.TEXT)
	_toast.add_child(_toast_label)
	add_child(_toast)


func _margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := UIKit.margin(child, left, top, right, bottom)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## Status pill: icon + value, `MOUSE_FILTER_IGNORE` so taps fall through to the board.
func _chip(row: HBoxContainer, glyph: String, color: Color) -> Label:
	var panel := UIKit.panel("HudPanel")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UIKit.hbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(Glyph.of(glyph, 17, color))
	var value := UIKit.label("0", "NumberLabel")
	value.add_theme_font_size_override("font_size", 18)
	box.add_child(value)
	row.add_child(panel)
	return value


# --- Populating --------------------------------------------------------------------------------------

## Builds one button per tower from the content database.
func setup_towers(tower_ids: Array[String], gold: int) -> void:
	for child in _build_row.get_children():
		child.queue_free()
	_build_buttons.clear()
	for tower_id in tower_ids:
		var def := GameData.tower(tower_id)
		if def.is_empty():
			continue
		var button := BuildButton.new()
		button.setup(tower_id, def)
		button.pressed.connect(func() -> void: build_selected.emit(tower_id))
		_build_row.add_child(button)
		_build_buttons[tower_id] = button
	refresh_affordability(gold)


func setup_abilities(abilities: Abilities) -> void:
	for child in _ability_row.get_children():
		child.queue_free()
	_ability_buttons.clear()
	for def in Abilities.DEFS:
		var button := AbilityButton.new()
		button.setup(def)
		var id := String(def["id"])
		button.pressed.connect(func() -> void: ability_pressed.emit(id))
		_ability_row.add_child(button)
		_ability_buttons[id] = button
	update_abilities(abilities)


func set_wave_total(total: int) -> void:
	_wave_total = maxi(1, total)


func set_lives(current: int, maximum: int) -> void:
	_lives_label.text = "%d" % current
	_lives_label.add_theme_color_override("font_color",
		Palette.DANGER if current <= maxi(3, int(maximum * 0.2)) else Palette.TEXT)


func set_gold(value: int) -> void:
	_gold_label.text = str(value)
	refresh_affordability(value)


func set_wave(index: int) -> void:
	_wave_label.text = "%d/%d" % [mini(index, _wave_total), _wave_total]


func set_speed(multiplier: int) -> void:
	_speed_button.text = "%d×" % multiplier


func set_prep(seconds_left: float, wave_number: int) -> void:
	_status_panel.visible = true
	_status_label.text = "%s %d" % [Loc.t("game.calling_in"), int(ceil(maxf(0.0, seconds_left)))]
	_status_hint.text = "+%d %s · %s" % [
		Balance.early_call_bonus(seconds_left), Loc.t("hud.gold"), Loc.t("game.wave_bonus")]
	_status_hint.add_theme_color_override("font_color", Palette.GOLD)
	_call_button.visible = true
	_call_button.text = "%s %d" % [Loc.t("game.call_now"), wave_number]
	set_wave(wave_number - 1)


func set_wave_running(wave_number: int) -> void:
	_status_panel.visible = false
	_call_button.visible = false
	set_wave(wave_number)


func set_preview(entries: Array[Dictionary]) -> void:
	for child in _preview_row.get_children():
		child.queue_free()
	var boss := false
	for entry in entries:
		var enemy_id := String(entry.get("enemy", ""))
		var def := GameData.enemy(enemy_id)
		if def.is_empty():
			continue
		if enemy_id == "boss":
			boss = true
		var item := UIKit.hbox(3)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rect := TextureRect.new()
		rect.texture = load("res://assets/sprites/enemies/%s.png" % String(def.get("sprite", "")))
		rect.custom_minimum_size = Vector2(20, 20)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(def.get("is_air", false)):
			rect.modulate = Palette.FROST
		item.add_child(rect)
		var count := UIKit.label("×%d" % int(entry.get("count", 0)), "TinyLabel")
		item.add_child(count)
		_preview_row.add_child(item)
	if boss:
		_status_hint.text = Loc.t("game.boss_incoming")
		_status_hint.add_theme_color_override("font_color", Palette.DANGER)
	else:
		_status_hint.add_theme_color_override("font_color", Palette.TEXT_DIM)


func refresh_affordability(gold: int) -> void:
	for tower_id in _build_buttons.keys():
		var button: BuildButton = _build_buttons[tower_id]
		button.set_affordable(gold >= button.cost)


func set_selected_tower(tower_id: String) -> void:
	_selected_tower_id = tower_id
	for id in _build_buttons.keys():
		(_build_buttons[id] as BuildButton).set_selected(String(id) == tower_id)


func show_tower_panel(tower: Tower, gold: int) -> void:
	_build_row.visible = false
	_tower_panel.visible = true
	_tower_panel.refresh(tower, gold)
	set_selected_tower("")


func hide_tower_panel() -> void:
	_tower_panel.visible = false
	_build_row.visible = true


func update_tower_panel(tower: Tower, gold: int) -> void:
	if _tower_panel.visible:
		_tower_panel.refresh(tower, gold)


func update_abilities(abilities: Abilities) -> void:
	for id in _ability_buttons.keys():
		var button: AbilityButton = _ability_buttons[id]
		button.update_cooldown(abilities.cooldown_fraction(String(id)),
			abilities.cooldown_left(String(id)))


func is_tower_panel_open() -> bool:
	return _tower_panel.visible


func tower_panel_visible() -> bool:
	return _tower_panel.visible


# --- Feedback ------------------------------------------------------------------------------------------

func toast(message: String, color: Color = Palette.TEXT) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate", Color.WHITE, 0.12)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate", Color(1, 1, 1, 0), 0.25)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func set_hint(text: String) -> void:
	if text == "":
		_status_hint.text = ""
		return
	_status_hint.text = text
	_status_hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
