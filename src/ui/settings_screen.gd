extends Screen
## Full-screen settings, wrapping the shared `SettingsPanel`.


func _build() -> void:
	var column := UIKit.vbox(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(column)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.icon_button("back", Palette.TEXT, func() -> void:
		Audio.play_sfx("ui_back", -6.0)
		on_back(), 44))
	header.add_child(UIKit.label(Loc.t("settings.title"), "TitleLabel"))
	header.add_child(UIKit.spacer(true))
	header.add_child(UIKit.label(Loc.t("settings.saved"), "TinyLabel"))
	column.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	# A readable column: settings should not stretch to 3000 px on an ultrawide monitor.
	var panel := SettingsPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 420
	var centered := CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centered.add_child(panel)
	scroll.add_child(UIKit.margin(centered, 2, 2, 18, 2))

	# Rebuild on language change so every label is retranslated immediately.
	Loc.language_changed.connect(func(_language: String) -> void: _rebuild())


func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	_build()


func on_back() -> void:
	App.pop_scene()
