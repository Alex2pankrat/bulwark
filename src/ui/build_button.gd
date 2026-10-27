class_name BuildButton
extends Button
## One tower in the build bar: sprite, price, and an "unaffordable" state.
##
## Shows the real sprite (not an abstract icon) so players learn the tower silhouettes from the
## build bar — important when the same shapes appear on the board.

var tower_id: String = ""
var cost: int = 0

var _sprite: TextureRect
var _cost_label: Label
var _coin: Glyph
var _border: StyleBoxFlat


func setup(id: String, def: Dictionary) -> void:
	tower_id = id
	cost = int(def.get("cost", 0))
	custom_minimum_size = Vector2(74, 82)
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = "IconButton"
	tooltip_text = "%s\n%s\n%s %d" % [
		Loc.t(String(def.get("name_key", ""))),
		Loc.t(String(def.get("desc_key", ""))),
		Loc.t("hud.gold"), cost,
	]

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(0, 46)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite_path := "res://assets/sprites/towers/%s.png" % String(def.get("sprite", ""))
	if ResourceLoader.exists(sprite_path):
		_sprite.texture = load(sprite_path)
	column.add_child(_sprite)

	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 3)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin = Glyph.of("coin", 12, Palette.GOLD)
	price_row.add_child(_coin)
	_cost_label = UIKit.label(str(cost), "SmallLabel")
	price_row.add_child(_cost_label)
	column.add_child(price_row)


## Dims the tile when the player cannot afford it; never hides it (players plan ahead).
func set_affordable(affordable: bool) -> void:
	modulate = Color(1, 1, 1, 1) if affordable else Color(1, 1, 1, 0.42)
	_cost_label.add_theme_color_override("font_color",
		Palette.TEXT_MUTED if affordable else Palette.DANGER)
	_coin.color = Palette.GOLD if affordable else Palette.DANGER


func set_selected(selected: bool) -> void:
	# A thicker accent border is the selection cue; colour alone is not enough (accessibility).
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.with_alpha(Palette.ACCENT, 0.18) if selected else Palette.SURFACE_ALT
	box.set_corner_radius_all(12)
	if selected:
		box.set_border_width_all(2)
		box.border_color = Palette.ACCENT
	box.content_margin_left = 6
	box.content_margin_right = 6
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	add_theme_stylebox_override("pressed", box)
