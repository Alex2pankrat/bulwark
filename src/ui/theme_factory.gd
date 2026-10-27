class_name ThemeFactory
extends RefCounted
## Builds the single Theme used by every screen.
##
## One theme, defined in code, means the whole UI rescales and recolours from one place and
## reviewers can diff styling changes instead of inspecting `.tres` resources. Type variations
## (`PrimaryButton`, `CardPanel`, `TitleLabel`, …) keep call sites declarative:
## `UIKit.button("Play", "PrimaryButton")`.

const FONT_PATH := "res://assets/fonts/Inter.ttf"

const SIZES := {
	"display": 40,
	"title": 26,
	"heading": 19,
	"body": 16,
	"small": 14,
	"tiny": 12,
}

static var _theme: Theme
static var _fonts: Dictionary = {}


## Drops cached Theme/Font resources. Called on shutdown (and by tests) so the process exits
## with an empty resource pool instead of reporting objects still alive at exit.
static func clear_cache() -> void:
	_theme = null
	_fonts.clear()


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


# --- Fonts -----------------------------------------------------------------------------------

## Inter is a variable font; `FontVariation` picks the weight without shipping five files.
static func font(weight: int = 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base: FontFile = load(FONT_PATH)
	if base == null:
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": float(weight)}
	variation.variation_embolden = 0.0
	_fonts[weight] = variation
	return variation


# --- Building -------------------------------------------------------------------------------------

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(400)
	theme.default_font_size = SIZES["body"]

	_style_labels(theme)
	_style_buttons(theme)
	_style_panels(theme)
	_style_misc(theme)
	return theme


static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_font("font", "Label", font(400))
	theme.set_font_size("font_size", "Label", SIZES["body"])

	_label_variation(theme, "DisplayLabel", 700, SIZES["display"], Palette.TEXT)
	_label_variation(theme, "TitleLabel", 700, SIZES["title"], Palette.TEXT)
	_label_variation(theme, "HeadingLabel", 600, SIZES["heading"], Palette.TEXT)
	_label_variation(theme, "SmallLabel", 500, SIZES["small"], Palette.TEXT_MUTED)
	_label_variation(theme, "TinyLabel", 500, SIZES["tiny"], Palette.TEXT_DIM)
	_label_variation(theme, "GoldLabel", 700, SIZES["body"], Palette.GOLD)
	_label_variation(theme, "DangerLabel", 700, SIZES["body"], Palette.DANGER)
	_label_variation(theme, "AccentLabel", 600, SIZES["body"], Palette.ACCENT)
	_label_variation(theme, "NumberLabel", 700, SIZES["title"], Palette.TEXT)


static func _label_variation(theme: Theme, name: String, weight: int, size: int, color: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font(weight))
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


static func _style_buttons(theme: Theme) -> void:
	theme.set_font("font", "Button", font(600))
	theme.set_font_size("font_size", "Button", SIZES["body"])
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT)
	theme.set_color("font_pressed_color", "Button", Palette.TEXT)
	theme.set_color("font_focus_color", "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)
	_apply_button_boxes(theme, "Button", Palette.SURFACE_ALT, Palette.TEXT, Palette.SURFACE_HI)

	# Primary: the single most important action on a screen.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_color("font_color", "PrimaryButton", Palette.BG)
	theme.set_color("font_hover_color", "PrimaryButton", Palette.BG)
	theme.set_color("font_pressed_color", "PrimaryButton", Palette.BG)
	theme.set_color("font_focus_color", "PrimaryButton", Palette.BG)
	theme.set_color("font_disabled_color", "PrimaryButton", Palette.with_alpha(Palette.BG, 0.45))
	_apply_button_boxes(theme, "PrimaryButton", Palette.ACCENT, Palette.BG, Palette.ACCENT.lightened(0.15))

	# Danger: destructive confirmations (sell, reset).
	theme.set_type_variation("DangerButton", "Button")
	theme.set_color("font_color", "DangerButton", Palette.TEXT)
	theme.set_color("font_hover_color", "DangerButton", Palette.TEXT)
	theme.set_color("font_pressed_color", "DangerButton", Palette.TEXT)
	theme.set_color("font_focus_color", "DangerButton", Palette.TEXT)
	_apply_button_boxes(theme, "DangerButton", Palette.DANGER.darkened(0.25), Palette.TEXT, Palette.DANGER)

	# Ghost: low-emphasis actions (back, cancel).
	theme.set_type_variation("GhostButton", "Button")
	theme.set_color("font_color", "GhostButton", Palette.TEXT_MUTED)
	theme.set_color("font_hover_color", "GhostButton", Palette.TEXT)
	theme.set_color("font_pressed_color", "GhostButton", Palette.TEXT)
	theme.set_color("font_focus_color", "GhostButton", Palette.TEXT)
	_apply_button_boxes(theme, "GhostButton", Color(0, 0, 0, 0), Palette.LINE, Palette.SURFACE_ALT)

	# Chip: compact segmented options (difficulty, language, targeting).
	theme.set_type_variation("ChipButton", "Button")
	theme.set_font("font", "ChipButton", font(600))
	theme.set_font_size("font_size", "ChipButton", SIZES["small"])
	theme.set_color("font_color", "ChipButton", Palette.TEXT_MUTED)
	theme.set_color("font_hover_color", "ChipButton", Palette.TEXT)
	theme.set_color("font_pressed_color", "ChipButton", Palette.TEXT)
	theme.set_color("font_focus_color", "ChipButton", Palette.TEXT)
	_apply_button_boxes(theme, "ChipButton", Palette.SURFACE_ALT, Palette.TEXT, Palette.SURFACE_HI, 8)

	# Selected chip (mutually exclusive choices).
	theme.set_type_variation("ChipSelected", "Button")
	theme.set_font("font", "ChipSelected", font(700))
	theme.set_font_size("font_size", "ChipSelected", SIZES["small"])
	theme.set_color("font_color", "ChipSelected", Palette.BG)
	theme.set_color("font_hover_color", "ChipSelected", Palette.BG)
	theme.set_color("font_pressed_color", "ChipSelected", Palette.BG)
	theme.set_color("font_focus_color", "ChipSelected", Palette.BG)
	_apply_button_boxes(theme, "ChipSelected", Palette.ACCENT, Palette.BG, Palette.ACCENT, 8)

	# Icon button: square, square corners, no text.
	theme.set_type_variation("IconButton", "Button")
	_apply_button_boxes(theme, "IconButton", Palette.SURFACE_ALT, Palette.LINE, Palette.SURFACE_HI, 12)
	theme.set_constant("h_separation", "IconButton", 0)


static func _apply_button_boxes(theme: Theme, type: String, bg: Color, border: Color,
		hover_bg: Color, radius: int = 12) -> void:
	theme.set_stylebox("normal", type, _box(bg, radius, 0 if border.a == 0.0 else 0, Color.TRANSPARENT))
	theme.set_stylebox("hover", type, _box(hover_bg, radius))
	theme.set_stylebox("pressed", type, _box(bg.darkened(0.18) if bg.a > 0.0 else Palette.SURFACE_HI, radius))
	theme.set_stylebox("disabled", type, _box(Palette.with_alpha(Palette.SURFACE_ALT, 0.5), radius))
	theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), radius, 2, Palette.ACCENT))
	theme.set_constant("outline_size", type, 0)


static func _style_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _box(Palette.SURFACE, 16, 0, Color.TRANSPARENT, 14))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _box(Palette.SURFACE, 18, 0, Color.TRANSPARENT, 16))
	# HUD surfaces float over gameplay, so they get a soft shadow to separate board from chrome.
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", _box(Palette.with_alpha(Palette.SURFACE, 0.94), 12, 0,
		Color.TRANSPARENT, 9, 10))
	theme.set_type_variation("OverlayPanel", "PanelContainer")
	theme.set_stylebox("panel", "OverlayPanel", _box(Palette.SURFACE, 20, 0, Color.TRANSPARENT, 22, 26))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(Palette.SURFACE_ALT, 12, 0, Color.TRANSPARENT, 11))


static func _style_misc(theme: Theme) -> void:
	theme.set_stylebox("separator", "HSeparator", _box(Palette.LINE, 0, 0, Color.TRANSPARENT, 0))
	theme.set_constant("separation", "HSeparator", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "GridContainer", 8)
	theme.set_stylebox("panel", "TooltipPanel", _box(Palette.SURFACE_HI, 10, 0, Color.TRANSPARENT, 10))
	theme.set_font("font", "TooltipLabel", font(500))
	theme.set_font_size("font_size", "TooltipLabel", SIZES["small"])
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)


static func _box(bg: Color, radius: int, border_width: int = 0, border_color: Color = Color.TRANSPARENT,
		padding: int = 12, shadow: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border_width)
	box.border_color = border_color
	if shadow > 0:
		box.shadow_size = shadow
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding * 0.7
	box.content_margin_bottom = padding * 0.7
	box.anti_aliasing = true
	return box
