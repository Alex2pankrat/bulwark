extends Screen
## Achievements gallery: a progress header plus one card per achievement.
##
## Unlocked cards are highlighted with their icon and description; locked ones stay muted with a
## lock glyph. The count comes straight from the `Achievements` engine, so the screen never
## duplicates unlock state — it only renders it.

func _build() -> void:
	Audio.play_music("calm")
	var compact := UIKit.is_compact()

	var column := UIKit.vbox(16)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(column)

	column.add_child(_build_header(compact))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	var engine := App.achievements()
	for id in engine.DEFINITIONS.keys():
		grid.add_child(_build_card(engine.describe(id), compact))


func _build_header(compact: bool) -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.icon_button("back", Palette.TEXT, func() -> void:
		Audio.play_sfx("ui_back", -6.0)
		App.goto_scene(App.MENU_SCENE), 44 if not compact else 52))
	row.add_child(UIKit.label(Loc.t("ach.title"), "TitleLabel"))
	row.add_child(UIKit.spacer(true))
	var count := UIKit.hbox(6)
	count.add_child(UIKit.label(
		Loc.tf("ach.progress", [App.achievements().unlocked_count(), App.achievements().total_count()]),
		"GoldLabel"))
	row.add_child(count)
	return row


func _build_card(info: Dictionary, compact: bool) -> Control:
	var unlocked: bool = bool(info.get("unlocked", false))
	var card := UIKit.panel("CardPanel")
	card.custom_minimum_size = Vector2(300.0 if not compact else 340.0, 120.0 if not compact else 134.0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		card.add_theme_color_override("modulate", Palette.TEXT_DIM * 0.7)
	var body := UIKit.card_body(card, 10)

	var icon_row := UIKit.hbox(10)
	var icon_color := Palette.GOLD if unlocked else Palette.TEXT_DIM
	icon_row.add_child(Glyph.of(String(info.get("icon", "star")), 24 if not compact else 28,
		icon_color))
	var title := UIKit.label(String(info.get("title", "")), "HeadingLabel")
	if compact:
		title.add_theme_font_size_override("font_size", 20)
	icon_row.add_child(title)
	icon_row.add_child(UIKit.spacer(true))
	var badge_glyph := "check" if unlocked else "lock"
	var badge_color := Palette.ACCENT if unlocked else Palette.TEXT_DIM
	icon_row.add_child(Glyph.of(badge_glyph, 18 if not compact else 20, badge_color))
	body.add_child(icon_row)

	var desc := UIKit.wrapped(String(info.get("desc", "")), "SmallLabel",
		card.custom_minimum_size.x - 40)
	if compact:
		desc.add_theme_font_size_override("font_size", 16)
	body.add_child(desc)
	return card
