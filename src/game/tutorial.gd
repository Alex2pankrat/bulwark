class_name Tutorial
extends RefCounted
## Guided first-run onboarding.
##
## Watches a small context dictionary every frame and walks a new player through the core loop:
## place a tower, call the wave, inspect a tower, use an ability. It runs only once (the
## `tutorial_seen` setting gates it at the call site); `skip()` or reaching the end ends it and
## marks the tutorial as seen.
##
## The controller is intentionally dumb about the world: the game screen feeds it facts and it
## just decides which tip to show and when to advance, so it is trivial to reason about and test.

signal step_changed(step_index: int, total: int, tip_key: String)
signal completed()

## Tip localisation keys, in the order they are shown.
const TIPS: Array[String] = [
	"tip.welcome",
	"tip.place_step",
	"tip.call_step",
	"tip.upgrade_step",
	"tip.ability_step",
]

## Welcome is shown for this long before advancing, so it is readable.
const WELCOME_SECONDS := 2.2

var _step := 0
var _active := false
var _step_elapsed := 0.0


func start() -> void:
	_active = true
	_step = 0
	_step_elapsed = 0.0
	_emit()


func stop() -> void:
	_active = false
	_step = 0


func skip() -> void:
	if not _active:
		return
	_active = false
	completed.emit()


func is_active() -> bool:
	return _active


func current_tip_key() -> String:
	return TIPS[_step] if _step < TIPS.size() else ""


## Called every frame with the run context. Advances the active step when its condition holds.
## Context keys: `elapsed`, `towers_built`, `wave_called`, `tower_selected`, `ability_used`,
## `wave_cleared`.
func update(context: Dictionary) -> void:
	if not _active:
		return
	_step_elapsed += float(context.get("delta", 0.0))
	if _step >= TIPS.size():
		_finish()
		return
	if _step_done(_step, context):
		_step += 1
		if _step >= TIPS.size():
			_finish()
		else:
			_step_elapsed = 0.0
			_emit()


func _finish() -> void:
	_active = false
	completed.emit()


func _emit() -> void:
	step_changed.emit(_step, TIPS.size(), current_tip_key())


func _step_done(step: int, context: Dictionary) -> bool:
	match step:
		0:
			return _step_elapsed >= WELCOME_SECONDS
		1:
			return int(context.get("towers_built", 0)) >= 1
		2:
			return bool(context.get("wave_called", false))
		3:
			return bool(context.get("tower_selected", false))
		4:
			# The ability tip is the last one; finish once it is used or a wave has cleared
			# (some players never touch abilities, and the tutorial should not hang on it).
			return bool(context.get("ability_used", false)) or int(context.get("wave_cleared", 0)) >= 1
		_:
			return true
