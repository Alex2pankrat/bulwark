extends Screen
## Full-screen settings, wrapping the shared `SettingsPanel`.
##
## The panel is centred and grows up to a readable maximum width, so it is never a thin
## 420 px column stretched down a desktop window, and never squeezed on a phone. The panel
## itself switches between one and two columns from its own size.

## Maximum panel width before it stops growing (centred on wider screens).
const PANEL_MAX_WIDTH := 1000.0

var _panel: SettingsPanel
var _viewport: Control
var _lang_connected := false
var _resized_connected := false


func _build() -> void:
	var column := UIKit.vbox(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_content(column)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.icon_button("back", Palette.TEXT, func() -> void:
		Audio.play_sfx("ui_back", -6.0)
		on_back(), 44))
	header.add_child(UIKit.label(Loc.t("settings.title"), "TitleLabel"))
	header.add_child(UIKit.spacer(true))
	header.add_child(UIKit.label(Loc.t("settings.saved"), "TinyLabel"))
	column.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	# Plain Control (not a Container) so we place the panel with explicit offsets below — that
	# keeps it centred regardless of container size-flag behaviour. Its height drives the scrollbar.
	_viewport = Control.new()
	_viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_child(_viewport)

	_panel = SettingsPanel.new()
	# Anchors collapsed to (0,0) so offsets fully define position and size.
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_viewport.add_child(_panel)
	# The panel is a fresh node on every (re)build, so connecting here cannot stack; it keeps the
	# scroll content height in sync when the panel switches between one and two columns.
	_panel.layout_changed.connect(_layout_panel)

	# Both connections must be made exactly once: `_rebuild` re-enters `_build`, and reconnecting
	# there would stack callbacks on the same signal.
	if not _resized_connected:
		resized.connect(_layout_panel)
		_resized_connected = true
	if not _lang_connected:
		Loc.language_changed.connect(func(_language: String) -> void: _rebuild())
		_lang_connected = true

	_layout_panel()
	# After a rebuild (language change) the viewport may not have been laid out yet, so the
	# deferred call positions the panel once the tree settles.
	_layout_panel.call_deferred()


## Centres the panel horizontally and caps its width. Vertical size is the panel's content
## height, so the scrollbar appears when the panel is taller than the screen.
func _layout_panel() -> void:
	if _panel == null or _viewport == null:
		return
	if _viewport.size.x <= 0.0:
		return
	var width := mini(PANEL_MAX_WIDTH, maxf(420.0, _viewport.size.x - 32.0))
	var height := maxf(_panel.min_size.y, 200.0)
	var x := maxf(8.0, (_viewport.size.x - width) * 0.5)
	_panel.offset_left = x
	_panel.offset_top = 4.0
	_panel.offset_right = x + width
	_panel.offset_bottom = 4.0 + height
	_viewport.custom_minimum_size.y = height + 8.0


func _rebuild() -> void:
	for child in content.get_children():
		child.queue_free()
	_lang_connected = false
	_build()


func on_back() -> void:
	App.pop_scene()
