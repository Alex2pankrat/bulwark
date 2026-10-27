class_name Palette
extends RefCounted
## Central colour palette.
##
## The design language is "flat, minimal, high contrast": a single dark neutral family for
## surfaces, one warm accent for gold/currency, one cool accent for interaction and one
## danger colour. Terrain colours are taken from the Kenney "Tower Defense (top-down)" pack
## so that board and sprites share one palette.
##
## Colour is never the only carrier of meaning (accessibility): every state that uses colour
## here is also encoded by shape, icon or text.

# --- Surfaces -------------------------------------------------------------------------------
const BG := Color("14181b")          ## App background, behind everything.
const BOARD_BG := Color("101315")    ## Behind the grid (the "outside" of the board).
const SURFACE := Color("1e2429")     ## Panels.
const SURFACE_ALT := Color("262d33") ## Raised rows, inputs, buttons at rest.
const SURFACE_HI := Color("333c44")  ## Hover / pressed surfaces.
const LINE := Color("39434c")        ## Hairlines and separators.

# --- Text -----------------------------------------------------------------------------------
const TEXT := Color("eef2f5")
const TEXT_MUTED := Color("93a1ab")
const TEXT_DIM := Color("6b7883")

# --- Accents --------------------------------------------------------------------------------
const ACCENT := Color("2ec4b6")      ## Interaction: highlights, selected, focus.
const ACCENT_DARK := Color("1d8b81")
const GOLD := Color("f2b134")        ## Currency.
const DANGER := Color("e94f37")      ## Damage, invalid placement, leaks.
const FROST := Color("6fc3e8")       ## Slow / frost element.
const ARC := Color("b18cff")         ## Chain lightning element.
const HEAL := Color("57d68d")        ## Support / healing.
const WARN := Color("ffd166")

# --- Terrain (Kenney TD pack values) -------------------------------------------------------
const CELL_BUILDABLE := Color("ecdcb8")  ## Cream ground: build here.
const CELL_BUILDABLE_LINE := Color("ddca9d")
const CELL_PATH := Color("89a4a6")       ## Slate road.
const CELL_PATH_LINE := Color("7b969a")
const CELL_BLOCKED := Color("2ecc71")    ## Grass: occupied by scenery.
const PATH_CENTER := Color("7b969a")

# --- Utility --------------------------------------------------------------------------------

static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## Darken or lighten a colour by `amount` (-1..1) without touching alpha.
static func shade(c: Color, amount: float) -> Color:
	if amount >= 0.0:
		return c.lightened(amount)
	return c.darkened(-amount)

## Element accent used by towers, projectiles and status effects.
static func element_color(element: String) -> Color:
	match element:
		"explosive": return GOLD
		"frost": return FROST
		"arc": return ARC
		"energy": return ACCENT
		"heal": return HEAL
		_: return TEXT_MUTED
