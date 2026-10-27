extends Node
## Audio service: bus routing, pooled one-shots, crossfaded music. Autoload name: `Audio`.
##
## Follows the audio-design playbook: sliders are 0..1 gains mapped to dB on *buses* (never on
## individual clips), one-shots come from a fixed pool so no node is ever allocated per shot,
## and identical sounds fired in the same instant are throttled so a dozen towers firing at
## once does not turn into a wall of noise.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 14
## Minimum gap between two instances of the same sound (seconds) — anti "machine gun".
const SAME_SOUND_GAP := 0.035

const SFX_FILES := {
	"ui_click": "ui_click.ogg",
	"ui_back": "ui_back.ogg",
	"ui_hover": "ui_hover.ogg",
	"select": "select.ogg",
	"error": "error.ogg",
	"build": "tower_place.ogg",
	"sell": "tower_sell.ogg",
	"upgrade": "tower_upgrade.ogg",
	"shoot_pulse": "shoot_pulse.ogg",
	"shoot_cannon": "shoot_cannon.ogg",
	"shoot_frost": "shoot_frost.ogg",
	"shoot_arc": "shoot_arc.ogg",
	"shoot_rail": "shoot_rail.ogg",
	"hit": "enemy_hit.ogg",
	"death": "enemy_death.ogg",
	"leak": "leak.ogg",
	"boss": "boss_spawn.ogg",
	"wave": "wave_start.ogg",
	"gold": "gold.ogg",
	"victory": "victory.ogg",
	"defeat": "defeat.ogg",
}

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_index := 0
var _current_track := ""
var _music_tween: Tween
var _gains := {"master": 0.9, "music": 0.55, "sfx": 0.8}
var _ducked := false
var _ready_done := false


# --- Setup --------------------------------------------------------------------------------------

func _ensure() -> void:
	if _ready_done:
		return
	_ready_done = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
	for i in range(2):
		var music := AudioStreamPlayer.new()
		music.bus = &"Music"
		music.volume_db = -80.0
		add_child(music)
		_music_players.append(music)
	apply_volumes(_gains["master"], _gains["music"], _gains["sfx"])


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


# --- Volumes -------------------------------------------------------------------------------------

func apply_volumes(master: float, music: float, sfx: float) -> void:
	_ensure()
	_gains = {"master": master, "music": music, "sfx": sfx}
	_set_bus_gain("Master", master)
	_set_bus_gain("Music", music * (0.35 if _ducked else 1.0))
	_set_bus_gain("SFX", sfx)


func _set_bus_gain(bus_name: String, gain: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, gain <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(gain, 0.0001, 1.0)))


## Lowers the music when the app loses focus (mobile: another app opened).
func duck(value: bool) -> void:
	_ensure()
	if _ducked == value:
		return
	_ducked = value
	_set_bus_gain("Music", float(_gains["music"]) * (0.35 if value else 1.0))


# --- One-shots ------------------------------------------------------------------------------------

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	_ensure()
	var stream := _stream_for(sfx_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sfx_name, -1.0)) < SAME_SOUND_GAP:
		return
	_last_played[sfx_name] = now
	var player := _free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Slight random pitch so repeated shots do not sound machine-stamped.
func play_varied(sfx_name: String, volume_db: float = 0.0, spread: float = 0.07) -> void:
	play_sfx(sfx_name, volume_db, 1.0 + randf_range(-spread, spread))


func _free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	# Everything is busy: steal the first one rather than dropping the sound entirely.
	return _pool[0] if not _pool.is_empty() else null


func _stream_for(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	if not SFX_FILES.has(sfx_name):
		push_warning("Unknown sfx: %s" % sfx_name)
		return null
	var path: String = SFX_DIR + String(SFX_FILES[sfx_name])
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Missing sfx file: %s" % path)
		return null
	_cache[sfx_name] = stream
	return stream


# --- Music ------------------------------------------------------------------------------------------

## Crossfades to `track` ("calm", "battle"). Re-requesting the current track is a no-op, so
## screens can call this every time they become visible.
func play_music(track: String, fade_time: float = 0.8) -> void:
	_ensure()
	if track == _current_track:
		return
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("Missing music: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_current_track = track
	var outgoing := _music_players[_music_index]
	_music_index = 1 - _music_index
	var incoming := _music_players[_music_index]
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_kill_music_tween()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", -6.0, fade_time)
	_music_tween.tween_property(outgoing, "volume_db", -60.0, fade_time)
	_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_time: float = 0.6) -> void:
	_ensure()
	_current_track = ""
	_kill_music_tween()
	_music_tween = create_tween()
	for player in _music_players:
		if player.playing:
			_music_tween.parallel().tween_property(player, "volume_db", -60.0, fade_time)
	_music_tween.chain().tween_callback(_stop_all_music)


func _stop_all_music() -> void:
	for player in _music_players:
		player.stop()


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
