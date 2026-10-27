class_name PathModel
extends RefCounted
## A poly-line path that enemies walk by accumulated distance.
##
## Following the playbook, movement is expressed as "distance travelled" rather than "move
## toward the next waypoint": the leftover distance after reaching a waypoint is carried into
## the next segment, so fast units never lose time at corners and never overshoot. The same
## number doubles as targeting priority (`progress`), so "first" means "closest to the exit".

var points: PackedVector2Array = PackedVector2Array()
var total_length: float = 0.0

var _cumulative: PackedFloat32Array = PackedFloat32Array()


static func from_cells(cells: Array, cell_size: float) -> PathModel:
	var pts := PackedVector2Array()
	for cell in cells:
		var c: Vector2i = cell if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
		# Cell coordinates address a cell; the path runs through its centre.
		pts.append(Vector2(c.x + 0.5, c.y + 0.5) * cell_size)
	return from_points(pts)


static func from_points(pts: PackedVector2Array) -> PathModel:
	var model := PathModel.new()
	model.points = pts
	model._rebuild()
	return model


func _rebuild() -> void:
	_cumulative = PackedFloat32Array()
	_cumulative.append(0.0)
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		_cumulative.append(total)
	total_length = total


## Position along the path at `distance` pixels from the start, clamped to the ends.
func position_at(distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1 or distance <= 0.0:
		return points[0]
	if distance >= total_length:
		return points[points.size() - 1]
	var seg := _segment_index(distance)
	var seg_start := _cumulative[seg]
	var seg_len := _cumulative[seg + 1] - seg_start
	if seg_len <= 0.0001:
		return points[seg]
	var t := (distance - seg_start) / seg_len
	return points[seg].lerp(points[seg + 1], t)


## Normalised travel direction at `distance`; used for sprite facing.
func direction_at(distance: float) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	var seg := _segment_index(clampf(distance, 0.0, total_length))
	return (points[seg + 1] - points[seg]).normalized()


## 0..1 progress along the whole path (targeting priority).
func ratio_at(distance: float) -> float:
	if total_length <= 0.0:
		return 0.0
	return clampf(distance / total_length, 0.0, 1.0)


func _segment_index(distance: float) -> int:
	var lo := 0
	var hi := _cumulative.size() - 2
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi + 1) / 2
		if _cumulative[mid] <= distance:
			lo = mid
		else:
			hi = mid - 1
	return maxi(0, lo)
