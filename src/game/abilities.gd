class_name Abilities
extends RefCounted
## Cooldown-driven active abilities.
##
## Active abilities are what make a wave feel like a fight rather than a spreadsheet: they give
## the player something to *do* during a wave, and they scale with timing skill instead of
## with gold. State only — the world decides what an ability actually does.

signal used(id: String)
signal became_ready(id: String)

## `targeted` abilities ask the player to tap the board before firing.
const DEFS: Array[Dictionary] = [
	{
		"id": "airstrike",
		"name_key": "ability.airstrike.name",
		"desc_key": "ability.airstrike.desc",
		"icon": "bomb",
		"color": "explosive",
		"cooldown": 34.0,
		"targeted": true,
		"radius_cells": 2.3,
		"damage": 240.0,
		"damage_type": "explosive",
	},
	{
		"id": "overclock",
		"name_key": "ability.overclock.name",
		"desc_key": "ability.overclock.desc",
		"icon": "bolt",
		"color": "arc",
		"cooldown": 38.0,
		"targeted": false,
		"duration": 6.0,
		"rate_mult": 1.7,
	},
]

var _remaining: Dictionary = {}   ## id -> seconds until ready
var _was_ready: Dictionary = {}


func _init() -> void:
	for def in DEFS:
		_remaining[def["id"]] = 0.0
		_was_ready[def["id"]] = true


func def_for(id: String) -> Dictionary:
	for def in DEFS:
		if String(def["id"]) == id:
			return def
	return {}


func is_ready(id: String) -> bool:
	return float(_remaining.get(id, 0.0)) <= 0.0


func cooldown_left(id: String) -> float:
	return maxf(0.0, float(_remaining.get(id, 0.0)))


## 0 = fully charged, 1 = just used (drives the radial mask in the HUD).
func cooldown_fraction(id: String) -> float:
	var def := def_for(id)
	if def.is_empty():
		return 0.0
	return clampf(cooldown_left(id) / maxf(0.1, float(def["cooldown"])), 0.0, 1.0)


## Steps the timers. Returns the list of abilities that became ready this tick.
func tick(delta: float) -> Array[String]:
	var ready_now: Array[String] = []
	for def in DEFS:
		var id := String(def["id"])
		var left := float(_remaining.get(id, 0.0))
		if left > 0.0:
			left = maxf(0.0, left - delta)
			_remaining[id] = left
		var ready := left <= 0.0
		if ready and not bool(_was_ready.get(id, true)):
			_was_ready[id] = true
			ready_now.append(id)
			became_ready.emit(id)
		elif not ready:
			_was_ready[id] = false
	return ready_now


## Consumes an ability. Returns false when it is still charging.
func use(id: String) -> bool:
	if not is_ready(id) or def_for(id).is_empty():
		return false
	_remaining[id] = float(def_for(id)["cooldown"])
	_was_ready[id] = false
	used.emit(id)
	return true


func reset() -> void:
	for def in DEFS:
		_remaining[def["id"]] = 0.0
		_was_ready[def["id"]] = true
