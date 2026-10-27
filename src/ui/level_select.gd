extends Screen
## Mission select: cards with stars, best wave and lock state.
##
## Cards wrap into rows by the available width: three per row on a desktop window, one
## row on a phone — so six missions stay readable without a horizontal scroll.

const CARD_WIDTH := 280.0


func _build() -> void:
	Audio.play_music("calm")

	var column := UIKit.vbox(16)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(column)

	column.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var row := FlowContainer.new()
	row.flow_direction = FlowContainer.FLOW_DIRECTION_LEFT_TO_RIGHT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(row)

	for index in range(GameData.level_count()):
		row.add_child(_build_card(index))


func _build_header() -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.icon_button("back", Palette.TEXT, func() -> void:
		Audio.play_sfx("ui_back", -6.0)
		App.goto_scene(App.MENU_SCENE), 44))
	row.add_child(UIKit.label(Loc.t("menu.levels"), "TitleLabel"))
	row.add_child(UIKit.spacer(true))
	var stars := UIKit.hbox(6)
	stars.add_child(Glyph.of("star", 18, Palette.GOLD))
	stars.add_child(UIKit.label(str(App.total_stars()), "GoldLabel"))
	row.add_child(stars)
	return row


func _build_card(index: int) -> Control:
	var level := GameData.level(index)
	var level_id := String(level.get("id", ""))
	var progress := App.level_progress(level_id)
	var unlocked := App.is_level_unlocked(index)
	var cleared := bool(progress.get("cleared", false))
	var stars := int(progress.get("stars", 0))

	var card := UIKit.panel("CardPanel")
	card.custom_minimum_size = Vector2(CARD_WIDTH, 210)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body := UIKit.card_body(card, 10)

	var title_row := UIKit.hbox(8)
	title_row.add_child(UIKit.label(Loc.t(String(level.get("name_key", ""))), "HeadingLabel"))
	title_row.add_child(UIKit.spacer(true))
	title_row.add_child(UIKit.label("%d" % (index + 1), "NumberLabel"))
	body.add_child(title_row)

	body.add_child(UIKit.wrapped(Loc.t(String(level.get("desc_key", ""))), "SmallLabel",
		CARD_WIDTH - 40))

	var star_row := UIKit.hbox(4)
	for i in range(3):
		star_row.add_child(Glyph.of("star", 18, Palette.GOLD if i < stars else Palette.TEXT_DIM))
	body.add_child(star_row)

	body.add_child(UIKit.label(
		Loc.tf("level.progress", [int(progress.get("best_wave", 0))]), "TinyLabel"))
	body.add_child(UIKit.spacer(false, true))

	if not unlocked:
		var locked := UIKit.button(Loc.t("common.locked"), "", Callable())
		locked.disabled = true
		body.add_child(locked)
	else:
		var label := Loc.t("result.retry") if cleared else Loc.t("menu.play")
		body.add_child(UIKit.button(label, "PrimaryButton" if not cleared else "", func() -> void:
			App.start_level(index)))
	return card
