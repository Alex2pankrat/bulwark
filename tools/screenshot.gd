extends Node
## Development tool: renders scenes to PNG so the visual design can be reviewed without a
## human at a desktop. Used to produce `docs/screenshots/*` and in visual review passes.
##
## Usage (needs a display; on CI use `xvfb-run`):
##     godot --path . res://tools/screenshot.tscn -- --out=/tmp/shots --level=0
##
## It drives the real scenes — no mock data — so what lands in the PNG is what a player sees.

const SHOT_SIZE := Vector2i(1280, 720)

var _out_dir := "user://screenshots"
var _level := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--level="):
			_level = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	App.set_setting("tutorial_seen", true)
	Engine.time_scale = 1.0

	await _shot_menu()
	await _shot_level_select()
	await _shot_settings()
	await _shot_credits()
	await _shot_game()
	await _shot_mobile()
	print("screenshots written to %s" % _out_dir)
	get_tree().quit(0)


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	var err := image.save_png(path)
	print("  %s -> %s" % [name, error_string(err) if err != OK else path])


func _open(scene_path: String) -> Node:
	for child in get_children():
		child.queue_free()
	await _frames(2)
	var scene: PackedScene = load(scene_path)
	var instance := scene.instantiate()
	add_child(instance)
	await _frames(6)
	return instance


func _shot_menu() -> void:
	await _open("res://scenes/main_menu.tscn")
	await _frames(10)
	await _capture("01_main_menu")


func _shot_level_select() -> void:
	await _open("res://scenes/level_select.tscn")
	await _frames(6)
	await _capture("02_level_select")


func _shot_settings() -> void:
	await _open("res://scenes/settings_screen.tscn")
	await _frames(6)
	await _capture("03_settings")


func _shot_credits() -> void:
	await _open("res://scenes/credits_screen.tscn")
	await _frames(6)
	await _capture("04_credits")


## Renders the game scene at a 19.5:9 phone viewport (landscape — the orientation the game
## ships with) to check that the HUD survives a very wide aspect ratio.
func _shot_mobile() -> void:
	# Godot ignores window_set_size for the *content* viewport under `keep` aspect, so this
	# shot is taken by running the tool with a wide --resolution (see docs/ARCHITECTURE.md).
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x / viewport_size.y < 1.9:
		DisplayServer.window_set_size(Vector2i(1170, 540))
		await _frames(6)
		viewport_size = get_viewport().get_visible_rect().size
	print("   phone shot viewport: %s" % viewport_size)
	App.pending_level = _level
	var game := await _open("res://scenes/game.tscn") as GameScreen
	game.place_tower("pulse", Vector2i(2, 1))
	game.place_tower("cannon", Vector2i(4, 4))
	game._on_call_wave()
	await get_tree().create_timer(3.0).timeout
	game.select_tower_at(Vector2i(2, 1))
	await _frames(3)
	await _capture("08_phone_wide")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(2)


func _shot_game() -> void:
	App.pending_level = _level
	var game := await _open("res://scenes/game.tscn") as GameScreen
	# Build a representative defence so the board is not empty in the screenshot.
	var build := [
		["pulse", Vector2i(2, 1)], ["pulse", Vector2i(4, 4)], ["cannon", Vector2i(6, 5)],
		["frost", Vector2i(8, 3)], ["arc", Vector2i(5, 3)],
	]
	for entry in build:
		game.place_tower(String(entry[0]), entry[1])
	await _frames(4)
	await _capture("05_game_prepare")

	# Mid-wave action shot with the tower inspector open.
	game._on_call_wave()
	Engine.time_scale = 1.0
	await get_tree().create_timer(4.0).timeout
	game.select_tower_at(Vector2i(4, 4))
	await _frames(3)
	await _capture("06_game_wave")

	# Pause dialog.
	game._open_pause()
	await _frames(8)
	await _capture("07_pause")
	App.set_paused(false)
