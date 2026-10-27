class_name WaveDirector
extends Node
## Drives the prepare → spawn → clear loop.
##
## The director is deliberately dumb about the world: it owns *timing* and *what to spawn*, and
## emits signals. That keeps wave pacing testable in isolation (feed it a level dictionary and
## step it with a fake delta) and keeps `GameScreen` focused on entities.

signal prep_started(wave_index: int, seconds: float)
signal prep_remaining(wave_index: int, seconds_left: float)
signal wave_started(wave_index: int)
signal spawn_requested(enemy_id: String)
signal wave_cleared(wave_index: int)
signal all_waves_cleared()

enum State { IDLE, PREP, SPAWNING, WAITING_CLEAR, FINISHED }

var state: State = State.IDLE
var wave_index: int = 0              ## 0-based index of the wave being prepared/spawned
var live_enemies: int = 0
var level: Dictionary = {}

var _timeline: Array[Dictionary] = []
var _cursor: int = 0
var _clock: float = 0.0
var _prep_total: float = 0.0
var _prep_left: float = 0.0
var _last_emitted_left: float = -1.0
var _completing: bool = false


func start(p_level: Dictionary) -> void:
	level = p_level
	wave_index = 0
	live_enemies = 0
	state = State.IDLE
	_begin_prep()


func wave_total() -> int:
	return WavePlan.wave_count(level)


func is_prep() -> bool:
	return state == State.PREP


func prep_seconds_left() -> float:
	return maxf(0.0, _prep_left)


func prep_fraction() -> float:
	if _prep_total <= 0.0:
		return 0.0
	return clampf(_prep_left / _prep_total, 0.0, 1.0)


func _begin_prep() -> void:
	if wave_index >= wave_total():
		state = State.FINISHED
		all_waves_cleared.emit()
		return
	state = State.PREP
	var prep_time := float(level.get("prep_time", 16.0))
	_prep_total = prep_time
	_prep_left = prep_time
	_last_emitted_left = -1.0
	prep_started.emit(wave_index, _prep_left)


## Starts the next wave immediately. Returns the seconds that were skipped (for the HUD bonus).
func call_wave_now() -> float:
	if state != State.PREP:
		return 0.0
	var skipped := _prep_left
	_prep_left = 0.0
	_launch_wave()
	return skipped


func _launch_wave() -> void:
	_timeline = WavePlan.timeline(level, wave_index)
	_cursor = 0
	_clock = 0.0
	state = State.SPAWNING
	wave_started.emit(wave_index)


## `delta` already carries `Engine.time_scale`, which is how the 1×/2×/3× control is applied to
## enemies, towers and pacing alike.
func _process(delta: float) -> void:
	var scaled := delta
	match state:
		State.PREP:
			_prep_left -= scaled
			# Emit at most ~10×/s so the HUD label does not relayout every frame.
			if absf(_prep_left - _last_emitted_left) >= 0.1:
				_last_emitted_left = _prep_left
				prep_remaining.emit(wave_index, _prep_left)
			if _prep_left <= 0.0:
				_launch_wave()
		State.SPAWNING:
			_clock += scaled
			while _cursor < _timeline.size() and float(_timeline[_cursor]["at"]) <= _clock:
				spawn_requested.emit(String(_timeline[_cursor]["enemy"]))
				_cursor += 1
			if _cursor >= _timeline.size():
				state = State.WAITING_CLEAR
		State.WAITING_CLEAR:
			if live_enemies <= 0 and not _completing:
				_complete_wave()


func on_enemy_spawned() -> void:
	live_enemies += 1


func on_enemy_removed() -> void:
	live_enemies = maxi(0, live_enemies - 1)
	if state == State.WAITING_CLEAR and live_enemies == 0 and not _completing:
		_complete_wave()


func _complete_wave() -> void:
	if state == State.FINISHED or _completing:
		return
	_completing = true
	var cleared := wave_index
	wave_index += 1
	wave_cleared.emit(cleared)
	if wave_index >= wave_total():
		state = State.FINISHED
		all_waves_cleared.emit()
		_completing = false
		return
	# Brief breather before the next countdown so the clear reads as a beat in the pacing.
	await get_tree().create_timer(0.9).timeout
	_completing = false
	if state != State.FINISHED:
		_begin_prep()
