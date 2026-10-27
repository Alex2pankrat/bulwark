class_name BuildGrid
extends RefCounted
## The placement model: which cells the path occupies, which are scenery, which are buildable.
##
## Kept separate from any node so placement rules can be unit-tested and so the renderer only
## has to draw what the model reports.

enum CellKind { BUILDABLE, PATH, BLOCKED }

## Why a placement failed — surfaced to the player, hence an enum rather than a bool.
enum PlaceResult { OK, OUT_OF_BOUNDS, ON_PATH, OCCUPIED, RESERVED, NO_GOLD }

var cols: int = 0
var rows: int = 0
var cell_size: float = 64.0

var _path_cells: Dictionary = {}     ## Vector2i -> true
var _scenery: Dictionary = {}        ## Vector2i -> String (prop sprite id)
var _towers: Dictionary = {}         ## Vector2i -> Object (tower node, may be null for tests)


func _init(p_cols: int = 14, p_rows: int = 10, p_cell_size: float = 64.0) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size


## Marks every cell a cell-space poly-line passes through. Level paths are rectilinear, but
## diagonal steps are handled too so hand-edited levels cannot silently lose tiles.
func set_path(cells: Array) -> void:
	_path_cells.clear()
	for i in range(cells.size() - 1):
		var a := _to_cell(cells[i])
		var b := _to_cell(cells[i + 1])
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var cur := a
		_path_cells[cur] = true
		var guard := 0
		while cur != b and guard < 512:
			if cur.x != b.x:
				cur.x += step.x
			elif cur.y != b.y:
				cur.y += step.y
			_path_cells[cur] = true
			guard += 1


## Scenery entries are `[x, y, prop]` triples from the level file.
func set_scenery(entries: Array) -> void:
	_scenery.clear()
	for entry in entries:
		if entry is Array and entry.size() >= 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			var prop := String(entry[2]) if entry.size() > 2 else "bush"
			_scenery[cell] = prop


func kind_at(cell: Vector2i) -> CellKind:
	if not in_bounds(cell):
		return CellKind.BLOCKED
	if _path_cells.has(cell):
		return CellKind.PATH
	if _scenery.has(cell):
		return CellKind.BLOCKED
	return CellKind.BUILDABLE


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func scenery_at(cell: Vector2i) -> String:
	return String(_scenery.get(cell, ""))


func has_tower(cell: Vector2i) -> bool:
	return _towers.has(cell)


func tower_at(cell: Vector2i) -> Object:
	return _towers.get(cell, null)


func set_tower(cell: Vector2i, tower: Object) -> void:
	_towers[cell] = tower


func clear_tower(cell: Vector2i) -> void:
	_towers.erase(cell)


func tower_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _towers.keys():
		out.append(cell)
	return out


func path_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _path_cells.keys():
		out.append(cell)
	return out


func scenery_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _scenery.keys():
		out.append(cell)
	return out


# --- Coordinate helpers ----------------------------------------------------------------------

func cell_of(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / cell_size), floori(world.y / cell_size))


## Top-left corner of a cell in world space.
func world_of(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size


## Centre of a cell in world space (where towers stand).
func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func board_size() -> Vector2:
	return Vector2(cols, rows) * cell_size


# --- Placement rules -------------------------------------------------------------------------

## Checks a candidate cell without spending anything.
func can_place(cell: Vector2i, cost: int, gold: int) -> PlaceResult:
	if not in_bounds(cell):
		return PlaceResult.OUT_OF_BOUNDS
	match kind_at(cell):
		CellKind.PATH:
			return PlaceResult.ON_PATH
		CellKind.BLOCKED:
			return PlaceResult.RESERVED
	if has_tower(cell):
		return PlaceResult.OCCUPIED
	if gold < cost:
		return PlaceResult.NO_GOLD
	return PlaceResult.OK


static func explain(result: PlaceResult) -> String:
	match result:
		PlaceResult.OUT_OF_BOUNDS: return "ui.reason.out_of_bounds"
		PlaceResult.ON_PATH: return "ui.reason.on_path"
		PlaceResult.OCCUPIED: return "ui.reason.occupied"
		PlaceResult.RESERVED: return "ui.reason.reserved"
		PlaceResult.NO_GOLD: return "ui.reason.no_gold"
		_: return ""


func _to_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
