class_name Targeting
extends RefCounted
## Target selection for towers and splash/chain queries.
##
## Exposing priority as a per-tower setting changes optimal play far more than raw stats do:
## "first" stops leaks, "last" feeds another tower, "strongest" burns tanks, "weakest" secures
## bounty. Towers hold their priority in `mode`; the UI cycles it.

enum Mode { FIRST, LAST, CLOSEST, STRONGEST, WEAKEST }

const MODE_ORDER: Array[Mode] = [Mode.FIRST, Mode.LAST, Mode.CLOSEST, Mode.STRONGEST, Mode.WEAKEST]


static func mode_key(mode: int) -> String:
	match mode:
		Mode.FIRST: return "target.first"
		Mode.LAST: return "target.last"
		Mode.CLOSEST: return "target.closest"
		Mode.STRONGEST: return "target.strongest"
		Mode.WEAKEST: return "target.weakest"
		_: return "target.first"


static func next_mode(mode: int) -> int:
	var idx := MODE_ORDER.find(mode)
	return MODE_ORDER[(idx + 1) % MODE_ORDER.size()]


## Picks a target from `candidates` (any objects exposing progress, global_position, hp and
## is_air) inside `radius` of `origin`.
##
## `can_air` / `can_ground` filter by domain, which is what makes ground-only towers a real
## trade-off instead of a straight downgrade.
static func acquire(
	candidates: Array,
	origin: Vector2,
	radius: float,
	mode: int,
	can_air: bool = true,
	can_ground: bool = true
) -> Object:
	var best: Object = null
	var best_score := -INF
	var radius_sq := radius * radius
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var target := candidate as Object
		if not target.get("alive"):
			continue
		var air := bool(target.get("is_air"))
		if air and not can_air:
			continue
		if not air and not can_ground:
			continue
		var pos: Vector2 = target.get("global_position")
		if origin.distance_squared_to(pos) > radius_sq:
			continue
		var score := _score(target, origin, mode)
		if score > best_score:
			best_score = score
			best = target
	return best


static func _score(target: Object, origin: Vector2, mode: int) -> float:
	match mode:
		Mode.FIRST:
			return float(target.get("progress"))
		Mode.LAST:
			return -float(target.get("progress"))
		Mode.CLOSEST:
			return -origin.distance_squared_to(target.get("global_position"))
		Mode.STRONGEST:
			return float(target.get("hp"))
		Mode.WEAKEST:
			return -float(target.get("hp"))
		_:
			return 0.0


## All live targets inside a radius (used by splash damage, auras and "weakest N" modules).
static func in_radius(
	candidates: Array,
	origin: Vector2,
	radius: float,
	can_air: bool = true,
	can_ground: bool = true
) -> Array:
	var out: Array = []
	var radius_sq := radius * radius
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var target := candidate as Object
		if not target.get("alive"):
			continue
		var air := bool(target.get("is_air"))
		if air and not can_air:
			continue
		if not air and not can_ground:
			continue
		if origin.distance_squared_to(target.get("global_position")) <= radius_sq:
			out.append(target)
	return out


## For chain lightning: repeatedly picks the nearest not-yet-hit live target, so the bolt
## "walks" through a crowd instead of always hitting the same neighbour.
static func chain_targets(
	candidates: Array,
	origin: Vector2,
	first: Object,
	jumps: int,
	radius: float,
	can_air: bool = true,
	can_ground: bool = true
) -> Array:
	var path: Array = []
	if first == null or not is_instance_valid(first):
		return path
	path.append(first)
	var pool := in_radius(candidates, origin, radius, can_air, can_ground)
	pool.erase(first)
	var current: Vector2 = first.get("global_position")
	for _i in range(jumps):
		var nearest: Object = null
		var nearest_dist := INF
		for candidate in pool:
			var dist: float = current.distance_squared_to(candidate.get("global_position"))
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = candidate
		if nearest == null:
			break
		path.append(nearest)
		pool.erase(nearest)
		current = nearest.get("global_position")
	return path
