class_name ValueSlider
extends Control
## A flat, touch-first slider.
##
## Godot's HSlider needs icon textures for its grabber to look like anything; this draws the
## track and knob from primitives instead, so it matches the rest of the UI and gives a 44 px
## tall hit area (the recommended minimum for a finger).

signal value_changed(value: float)

const TRACK_HEIGHT := 6.0
const KNOB_RADIUS := 11.0
const TOUCH_HEIGHT := 44.0

@export var value: float = 0.5:
	set = set_value
@export var track_color: Color = Palette.SURFACE_HI
@export var fill_color: Color = Palette.ACCENT

var _dragging := false


func _ready() -> void:
	custom_minimum_size.y = TOUCH_HEIGHT
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_value(next: float) -> void:
	var clamped := clampf(next, 0.0, 1.0)
	if is_equal_approx(clamped, value):
		return
	value = clamped
	queue_redraw()
	value_changed.emit(value)


func _draw() -> void:
	var center_y := size.y * 0.5
	var left := KNOB_RADIUS
	var right := size.x - KNOB_RADIUS
	if right <= left:
		return
	var track := Rect2(left, center_y - TRACK_HEIGHT * 0.5, right - left, TRACK_HEIGHT)
	draw_rect(track, track_color)
	var knob_x := lerpf(left, right, value)
	draw_rect(Rect2(left, center_y - TRACK_HEIGHT * 0.5, knob_x - left, TRACK_HEIGHT), fill_color)
	draw_circle(Vector2(knob_x, center_y), KNOB_RADIUS, Palette.TEXT)
	if has_focus():
		draw_arc(Vector2(knob_x, center_y), KNOB_RADIUS + 5.0, 0, TAU, 24, Palette.ACCENT, 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				grab_focus()
				_apply_at(mb.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_apply_at((event as InputEventMouseMotion).position.x)
		accept_event()


func _apply_at(x: float) -> void:
	var left := KNOB_RADIUS
	var right := size.x - KNOB_RADIUS
	if right <= left:
		return
	set_value((x - left) / (right - left))


## Keyboard / gamepad support: left/right nudges the value in 10% steps.
func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event.is_action_pressed("ui_left"):
		set_value(value - 0.1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		set_value(value + 0.1)
		accept_event()
