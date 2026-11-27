class_name PerfOverlay
extends CanvasLayer
## Debug overlay showing live frame timing (FPS, frame time, draw calls, objects).
##
## Hidden by default and toggled from Settings (`settings.perf_overlay`). It is a CanvasLayer so
## it renders above the game regardless of which screen is active, and it never takes input.

const MAX_SAMPLES := 60

var _fps_label: Label
var _detail_label: Label
var _enabled := false
var _frame_times: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_build()
	layer = 30
	visible = false


func _build() -> void:
	var root := Control.new()
	# CanvasLayer is a CanvasItem, not a Control, so it carries no theme: set it on the child.
	root.theme = ThemeFactory.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 8.0
	root.offset_top = 8.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var card := UIKit.panel("OverlayPanel")
	card.custom_minimum_size = Vector2(240.0, 64.0)
	root.add_child(card)

	var body := UIKit.card_body(card, 6)
	_fps_label = UIKit.label("--", "NumberLabel")
	_fps_label.add_theme_color_override("font_color", Palette.ACCENT)
	body.add_child(_fps_label)
	_detail_label = UIKit.wrapped("", "TinyLabel", 240)
	_detail_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	body.add_child(_detail_label)


## Toggles the overlay. When enabled it is shown and starts collecting frame samples.
func set_enabled(value: bool) -> void:
	_enabled = value
	visible = value
	if value:
		_frame_times.clear()
	else:
		_frame_times.clear()
	update_text()


func is_enabled() -> bool:
	return _enabled


func _process(delta: float) -> void:
	if not _enabled:
		return
	_frame_times.append(delta)
	if _frame_times.size() > MAX_SAMPLES:
		_frame_times.erase(0)
	update_text()


func update_text() -> void:
	if _frame_times.size() == 0:
		_fps_label.text = "--"
		_detail_label.text = ""
		return
	var avg_dt := 0.0
	for t in _frame_times:
		avg_dt += t
	avg_dt /= float(_frame_times.size())
	var fps := 1.0 / avg_dt if avg_dt > 0.0 else 0.0
	_fps_label.text = "%d fps" % int(fps)
	_detail_label.text = _detail_text()


func _detail_text() -> String:
	var draws := int(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	return "%d ms · %d draws · %d obj" % [
		roundi(_frame_times[_frame_times.size() - 1] * 1000.0), draws, objects,
	]
