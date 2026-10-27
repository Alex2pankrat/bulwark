class_name Screen
extends Control
## Base class for every full-screen UI state.
##
## Responsibilities kept in one place so no screen has to remember them:
##   * fill the window and paint the app background,
##   * inset content out of the Android/iOS safe area (notches, rounded corners, gesture bars),
##   * apply the shared theme,
##   * honour "reduce motion" on the open transition,
##   * route Back / Escape to `on_back()` instead of quitting the app.
##
## Subclasses implement `_build()` and add their layout to `content`.

const PADDING := 24

## Container that subclasses fill. Already inset by the device safe area.
var content: MarginContainer

var _background: ColorRect
var _safe_margin: MarginContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeFactory.get_theme()
	mouse_filter = Control.MOUSE_FILTER_PASS

	_background = ColorRect.new()
	_background.color = Palette.BG
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)
	_apply_safe_area()

	content = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 0)
	_safe_margin.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build()
	_play_open_animation()


## Override: build the screen's layout into `content`.
func _build() -> void:
	pass


## Override: where Back / Escape / the gamepad B button lead.
func on_back() -> void:
	App.goto_scene(App.MENU_SCENE)


func add_content(node: Control) -> void:
	content.add_child(node)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		accept_event()
		Audio.play_sfx("ui_back", -6.0)
		on_back()


# --- Safe area -------------------------------------------------------------------------------

## Only mobile platforms report a real safe area; elsewhere this resolves to ~0 insets.
func _apply_safe_area() -> void:
	var insets := safe_area_insets()
	content_offset(insets)


func safe_area_insets() -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var window := Rect2(Vector2.ZERO, window_size)
	var inner := safe.intersection(window)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return Vector4.ZERO
	var viewport_size := get_viewport_rect().size
	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	return Vector4(
		maxf(inner.position.x * scale.x, 0.0),
		maxf(inner.position.y * scale.y, 0.0),
		maxf((window_size.x - inner.end.x) * scale.x, 0.0),
		maxf((window_size.y - inner.end.y) * scale.y, 0.0))


## `insets` is (left, top, right, bottom) in viewport pixels on top of the base padding.
func content_offset(insets: Vector4) -> void:
	_safe_margin.add_theme_constant_override("margin_left", int(insets.x))
	_safe_margin.add_theme_constant_override("margin_top", int(insets.y))
	_safe_margin.add_theme_constant_override("margin_right", int(insets.z))
	_safe_margin.add_theme_constant_override("margin_bottom", int(insets.w))


func set_background_color(color: Color) -> void:
	_background.color = color


# --- Transition ------------------------------------------------------------------------------

func _play_open_animation() -> void:
	if bool(App.get_setting("reduce_motion")):
		modulate = Color.WHITE
		return
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.18).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_safe_area()
