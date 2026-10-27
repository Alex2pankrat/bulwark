extends Screen
## Title screen. Calm music, one primary action, everything else one tap away.


func _build() -> void:
	Audio.play_music("calm")
	add_child(MenuBackdrop.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(center)

	var column := UIKit.vbox(14)
	column.custom_minimum_size.x = 320
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := UIKit.label(Loc.t("app.title"), "DisplayLabel")
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var tagline := UIKit.label(Loc.t("app.tagline"), "SmallLabel")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	column.add_child(UIKit.spacer(false, true))

	var play := UIKit.button(_play_label(), "PrimaryButton", _on_play)
	play.custom_minimum_size.y = 54
	play.add_theme_font_size_override("font_size", 19)
	column.add_child(play)

	column.add_child(UIKit.button(Loc.t("menu.levels"), "", func() -> void:
		Audio.play_sfx("ui_click", -6.0)
		App.goto_scene(App.LEVEL_SELECT_SCENE)))
	column.add_child(UIKit.button(Loc.t("menu.settings"), "GhostButton", func() -> void:
		App.open_settings(App.MENU_SCENE)))
	column.add_child(UIKit.button(Loc.t("menu.credits"), "GhostButton", func() -> void:
		App.open_credits()))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		column.add_child(UIKit.button(Loc.t("menu.quit"), "GhostButton", func() -> void:
			App.quit()))

	var star_row := UIKit.hbox(6)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_child(Glyph.of("star", 16, Palette.GOLD))
	star_row.add_child(UIKit.label(str(App.total_stars()), "GoldLabel"))
	column.add_child(star_row)

	var version := UIKit.label("v%s · CC0 art · MIT code" % str(ProjectSettings.get_setting(
		"application/config/version", "1.0.0")), "TinyLabel")
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position += Vector2(-18, -14)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(version)

	UIKit.focus_first(column)


func _play_label() -> String:
	# "Continue" when a run is already unlocked, "Play" on a fresh profile.
	for i in range(GameData.level_count()):
		if App.level_progress(String(GameData.level(i).get("id", ""))).get("best_wave", 0):
			# Returning players resume at their furthest unlocked mission.
			for j in range(GameData.level_count() - 1, -1, -1):
				if App.is_level_unlocked(j) and not bool(
						App.level_progress(String(GameData.level(j).get("id", ""))).get("cleared", false)):
					App.pending_level = j
					return Loc.t("menu.continue")
	return Loc.t("menu.play")


func _on_play() -> void:
	if App.pending_level <= 0:
		Audio.play_sfx("ui_click", -6.0)
	App.start_level(App.pending_level)


func on_back() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		App.quit()
