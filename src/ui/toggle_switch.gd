class_name ToggleSwitch
extends Control
## A minimal switch (pill + sliding knob). Also usable with keyboard/gamepad focus.

signal toggled(is_on: bool)

const WIDTH := 52.0
const HEIGHT := 30.0

@export var is_on: bool = false:
	set = set_on

var _anim: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_anim = 1.0 if is_on else 0.0


func set_on(next: bool) -> void:
	if is_on == next:
		return
	is_on = next
	var target := 1.0 if is_on else 0.0
	if not is_inside_tree():
		_anim = target
		queue_redraw()
		return
	var tween := create_tween()
	tween.tween_method(_set_anim, _anim, target, 0.14).set_ease(Tween.EASE_OUT)
	toggled.emit(is_on)


func _set_anim(v: float) -> void:
	_anim = v
	queue_redraw()


func _draw() -> void:
	var radius := size.y * 0.5
	var bg := Palette.ACCENT.lerp(Palette.SURFACE_HI, 1.0 - _anim)
	_draw_pill(Rect2(Vector2.ZERO, size), radius, bg)
	var knob_x := lerpf(radius, size.x - radius, _anim)
	draw_circle(Vector2(knob_x, size.y * 0.5), radius - 5.0, Palette.TEXT)
	if has_focus():
		_draw_pill(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), radius + 3.0,
			Palette.with_alpha(Palette.ACCENT, 0.0), Palette.ACCENT)


func _draw_pill(rect: Rect2, radius: float, fill: Color, border: Color = Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	if border.a > 0.0:
		box.set_border_width_all(2)
		box.border_color = border
	draw_style_box(box, rect)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			set_on(not is_on)
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event.is_action_pressed("ui_accept"):
		set_on(not is_on)
		accept_event()
