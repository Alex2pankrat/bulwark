extends Screen
## Credits and asset licensing. Everything shipped with the game is listed with its licence.

const ENTRIES := [
	{"label": "credits.code", "value": "Bulwark contributors — MIT"},
	{"label": "credits.art", "value": "Kenney.nl — Tower Defense (Top-Down), Particle Pack — CC0"},
	{"label": "credits.audio", "value": "Kenney.nl — Interface, Impact, UI, Digital & Music Jingles — CC0"},
	{"label": "credits.music", "value": "Procedurally generated for Bulwark (tools/make_music.py) — CC0"},
	{"label": "credits.font", "value": "Inter by The Inter Project Authors — SIL OFL 1.1"},
	{"label": "credits.engine", "value": "Godot Engine 4.7 — MIT"},
]


func _build() -> void:
	Audio.play_music("calm")

	var column := UIKit.vbox(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(column)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.icon_button("back", Palette.TEXT, func() -> void:
		Audio.play_sfx("ui_back", -6.0)
		App.pop_scene(), 44))
	header.add_child(UIKit.label(Loc.t("credits.title"), "TitleLabel"))
	column.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var body := UIKit.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	for entry in ENTRIES:
		var card := UIKit.panel("InsetPanel")
		var inner := UIKit.card_body(card, 2)
		inner.add_child(UIKit.label(Loc.t(String(entry["label"])), "TinyLabel"))
		inner.add_child(UIKit.wrapped(String(entry["value"]), "SmallLabel", 720))
		body.add_child(card)

	body.add_child(UIKit.label(Loc.t("credits.made_with"), "TinyLabel"))


func on_back() -> void:
	App.pop_scene()
