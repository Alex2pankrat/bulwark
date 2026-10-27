class_name Damage
extends RefCounted
## Damage resolution shared by projectiles, beams, splash and abilities.
##
## Model: flat armour is subtracted after a percentage resistance, then a floor stops armour
## from ever fully negating a hit. Flat armour punishes fast/low-damage towers, percentage
## resistance punishes one-note builds — together they keep the tower roster relevant.

## Raw damage -> damage actually applied.
## `armor` is flat reduction, `pierce` ignores that much armour, `resist` is the target's
## percentage resistance for this damage type (0.25 = takes 25% less).
static func resolve(raw: float, armor: float, pierce: float, resist: float, mark_bonus: float = 0.0) -> float:
	if raw <= 0.0:
		return 0.0
	var effective_armor := maxf(0.0, armor - pierce)
	var after_armor := raw - effective_armor
	var floor_value := raw * Balance.MIN_DAMAGE_FRACTION
	var post := maxf(floor_value, after_armor)
	var post_resist := post * (1.0 - clampf(resist, 0.0, 0.9))
	return maxf(1.0, post_resist * (1.0 + maxf(0.0, mark_bonus)))


## Falls off linearly from the centre of a splash to `Balance.SPLASH_EDGE_FRACTION` at the rim.
static func splash_falloff(distance: float, radius: float) -> float:
	if radius <= 0.0:
		return 1.0
	var t := clampf(distance / radius, 0.0, 1.0)
	return lerpf(1.0, Balance.SPLASH_EDGE_FRACTION, t)


## Chain lightning damage for jump `index` (0 = primary target).
static func chain_damage(base: float, index: int) -> float:
	return base * pow(Balance.CHAIN_FALLOFF, index)


## Slow stacking: the strongest slow wins, and refresh extends rather than multiplies.
## `current` is a dictionary {factor, time}; returns the new dictionary.
static func merge_slow(current: Dictionary, factor: float, duration: float) -> Dictionary:
	var out := current.duplicate()
	if factor <= 0.0 or duration <= 0.0:
		return out
	if factor >= float(out.get("factor", 0.0)):
		out["factor"] = factor
		out["time"] = maxf(float(out.get("time", 0.0)), duration)
	else:
		out["time"] = maxf(float(out.get("time", 0.0)), duration * 0.5)
	return out


static func merge_dot(current: Dictionary, dps: float, duration: float) -> Dictionary:
	var out := current.duplicate()
	if dps <= 0.0 or duration <= 0.0:
		return out
	out["dps"] = maxf(float(out.get("dps", 0.0)), dps)
	out["time"] = maxf(float(out.get("time", 0.0)), duration)
	return out
