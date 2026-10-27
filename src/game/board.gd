class_name Board
extends Node2D
## Draws the playfield: terrain, road, scenery, build grid and placement feedback.
##
## One node draws the whole static layer, so the board costs a single canvas item no matter how
## big the map is. Dynamic things (towers, enemies, projectiles, effects) are separate nodes on
## top, which keeps redraw triggers narrow: hovering a tile never redraws an enemy.

const PROP_DIR := "res://assets/sprites/props/"
const FRAME := 10.0

var grid: BuildGrid
var level: Dictionary = {}
var ground_path: PathModel

var _props: Dictionary = {}          ## prop name -> Texture2D
var _hover_cell := Vector2i(-1, -1)
var _hover_valid := false
var _hover_range := -1.0
var _hover_origin := Vector2.ZERO
var _ability_preview: Dictionary = {}
var _preview_tower := ""             ## tower id being placed (ghost icon)
var _ghost_texture: Texture2D
var show_grid := true


func setup(p_grid: BuildGrid, p_level: Dictionary, p_path: PathModel) -> void:
	grid = p_grid
	level = p_level
	ground_path = p_path
	_preload_props()
	queue_redraw()


func _preload_props() -> void:
	for cell in grid.scenery_cells():
		var prop := grid.scenery_at(cell)
		if prop == "" or _props.has(prop):
			continue
		var path := PROP_DIR + prop + ".png"
		if ResourceLoader.exists(path):
			_props[prop] = load(path)


# --- Feed-back state ------------------------------------------------------------------------------

func set_hover(cell: Vector2i, valid: bool, range_px: float, origin: Vector2) -> void:
	if cell == _hover_cell and valid == _hover_valid and is_equal_approx(range_px, _hover_range):
		return
	_hover_cell = cell
	_hover_valid = valid
	_hover_range = range_px
	_hover_origin = origin
	queue_redraw()


func clear_hover() -> void:
	if _hover_cell == Vector2i(-1, -1) and _ability_preview.is_empty():
		return
	_hover_cell = Vector2i(-1, -1)
	_ability_preview = {}
	queue_redraw()


func set_preview_tower(tower_id: String) -> void:
	_preview_tower = tower_id
	var def := GameData.tower(tower_id)
	if def.is_empty():
		_ghost_texture = null
	else:
		var path := "res://assets/sprites/towers/%s.png" % String(def.get("sprite", ""))
		_ghost_texture = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()


func set_ability_preview(center: Vector2, radius_px: float, color: Color) -> void:
	_ability_preview = {"center": center, "radius": radius_px, "color": color}
	queue_redraw()


func clear_ability_preview() -> void:
	_ability_preview = {}
	queue_redraw()


func set_grid_visible(value: bool) -> void:
	show_grid = value
	queue_redraw()


# --- Drawing -----------------------------------------------------------------------------------------

func _draw() -> void:
	_draw_frame()
	_draw_cells()
	_draw_road()
	_draw_scenery()
	_draw_endpoints()
	_draw_hover()
	_draw_ability_preview()


func _draw_frame() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.BOARD_BG
	box.set_corner_radius_all(18)
	box.shadow_color = Palette.with_alpha(Color.BLACK, 0.35)
	box.shadow_size = 18
	draw_style_box(box, Rect2(Vector2(-FRAME, -FRAME), grid.board_size() + Vector2(FRAME, FRAME) * 2.0))


func _draw_cells() -> void:
	var cs := grid.cell_size
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(x, y) * cs, Vector2(cs, cs))
			match grid.kind_at(cell):
				BuildGrid.CellKind.BUILDABLE:
					draw_rect(rect, Palette.CELL_BUILDABLE)
					if show_grid:
						draw_rect(rect.grow(-0.5), Palette.CELL_BUILDABLE_LINE, false, 1.0)
				BuildGrid.CellKind.BLOCKED:
					draw_rect(rect, Palette.CELL_BLOCKED)
				BuildGrid.CellKind.PATH:
					draw_rect(rect, Palette.CELL_PATH)


func _draw_road() -> void:
	if ground_path == null or ground_path.points.size() < 2:
		return
	draw_polyline(ground_path.points, Palette.CELL_PATH_LINE, 26.0, true)
	# Dashed centre line: reads as a road, not a river.
	var dash_step := 18.0
	var total := ground_path.total_length
	var d := 8.0
	while d < total - 8.0:
		var a := ground_path.position_at(d)
		var b := ground_path.position_at(minf(d + dash_step * 0.55, total))
		draw_line(a, b, Palette.with_alpha(Palette.CELL_BUILDABLE, 0.35), 2.0, true)
		d += dash_step


func _draw_scenery() -> void:
	var cs := grid.cell_size
	for cell in grid.scenery_cells():
		var prop := grid.scenery_at(cell)
		var center := grid.center_of(cell)
		var texture: Texture2D = _props.get(prop, null)
		if texture != null:
			var tex_size := texture.get_size() * (cs * 0.86 / 64.0)
			draw_texture_rect(texture, Rect2(center - tex_size * 0.5, tex_size), false)
		else:
			draw_circle(center, cs * 0.22, Palette.with_alpha(Palette.BG, 0.25))


func _draw_endpoints() -> void:
	if ground_path == null or ground_path.points.size() < 2:
		return
	var start := ground_path.points[0]
	var start_dir := ground_path.direction_at(0.0)
	draw_circle(start, 13.0, Palette.with_alpha(Palette.DANGER, 0.9))
	draw_line(start - start_dir * 22.0, start, Palette.with_alpha(Palette.DANGER, 0.5), 5.0, true)

	var finish := ground_path.points[ground_path.points.size() - 1]
	draw_circle(finish, 18.0, Palette.with_alpha(Palette.ACCENT, 0.18))
	draw_arc(finish, 18.0, 0, TAU, 32, Palette.ACCENT, 3.0, true)
	draw_arc(finish, 9.0, 0, TAU, 24, Palette.with_alpha(Palette.ACCENT, 0.7), 2.0, true)


func _draw_hover() -> void:
	if _hover_cell.x < 0:
		return
	var cs := grid.cell_size
	var center := grid.center_of(_hover_cell)
	var color := Palette.ACCENT if _hover_valid else Palette.DANGER
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.with_alpha(color, 0.16)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Palette.with_alpha(color, 0.95)
	draw_style_box(box, Rect2(grid.world_of(_hover_cell) + Vector2(2, 2), Vector2(cs - 4, cs - 4)))
	if _hover_valid and _hover_range > 0.0:
		draw_circle(_hover_origin, _hover_range, Palette.with_alpha(color, 0.06))
		draw_arc(_hover_origin, _hover_range, 0, TAU, 64, Palette.with_alpha(color, 0.45), 1.5, true)
		if _ghost_texture != null:
			var ghost_size := Vector2(cs * 0.82, cs * 0.82)
			draw_texture_rect(_ghost_texture, Rect2(center - ghost_size * 0.5, ghost_size), false,
				Palette.with_alpha(Color.WHITE, 0.75))


func _draw_ability_preview() -> void:
	if _ability_preview.is_empty():
		return
	var center: Vector2 = _ability_preview["center"]
	var radius: float = _ability_preview["radius"]
	var color: Color = _ability_preview["color"]
	draw_circle(center, radius, Palette.with_alpha(color, 0.14))
	draw_arc(center, radius, 0, TAU, 64, Palette.with_alpha(color, 0.9), 2.0, true)
	draw_arc(center, radius * 0.5, 0, TAU, 48, Palette.with_alpha(color, 0.4), 1.5, true)
