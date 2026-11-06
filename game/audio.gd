class_name GameAudio
extends Node
## Local, original PCM audio. All volume arguments are linear 0..1.
## Cosmetic voice choice never consumes the simulation's random streams.

const CUES: Dictionary = {
	"move": "res://assets/sfx_move.wav",
	"step": "res://assets/sfx_step.wav",
	"hit": "res://assets/sfx_hit.wav",
	"death": "res://assets/sfx_death.wav",
	"loot": "res://assets/sfx_loot.wav",
	"ui": "res://assets/sfx_ui.wav",
	"cast": "res://assets/sfx_cast.wav",
	"blocked": "res://assets/sfx_blocked.wav",
	"heal": "res://assets/sfx_heal.wav",
}
const AMBIENCE: Dictionary = {
	"city": "res://assets/ambient_city.wav",
	"dungeon": "res://assets/ambient_dungeon.wav",
}
const VOICE_COUNT: int = 12

var master_volume: float = 0.7
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var muted: bool = false:
	set(value):
		muted = value
		if is_node_ready():
			set_volumes(master_volume, music_volume, sfx_volume)
var _voices: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_voice: int = 0
var _active_music: int = 0
var _mode: String = ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "Effect%d" % index
		voice.max_polyphony = 1
		add_child(voice)
		_voices.append(voice)
	for index: int in range(2):
		var track := AudioStreamPlayer.new()
		track.name = "Ambience%d" % index
		track.set_meta("gain", 0.0)
		add_child(track)
		_music.append(track)
	set_volumes(master_volume, music_volume, sfx_volume)


func play(cue: String) -> void:
	if not CUES.has(cue) or _voices.is_empty() or muted:
		return
	var stream: AudioStream = _get_stream(str(CUES[cue]))
	if stream == null:
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stop()
	voice.stream = stream
	voice.play()


func ambient(mode: String) -> void:
	if _music.is_empty() or mode == _mode:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var previous: AudioStreamPlayer = _music[_active_music]
	_active_music = 1 - _active_music
	var current: AudioStreamPlayer = _music[_active_music]
	current.stop()
	_mode = mode
	_set_music_gain(0.0, current)
	if AMBIENCE.has(mode):
		var base: AudioStream = _get_stream(str(AMBIENCE[mode]))
		if base is AudioStreamWAV:
			var loop: AudioStreamWAV = base.duplicate() as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(round(loop.get_length() * float(loop.mix_rate)))
			current.stream = loop
		else:
			current.stream = base
		if current.stream != null:
			current.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_method(_set_music_gain.bind(previous), float(previous.get_meta("gain", 0.0)), 0.0, 0.7)
	_fade.tween_method(_set_music_gain.bind(current), 0.0, 1.0 if AMBIENCE.has(mode) else 0.0, 0.7)
	_fade.chain().tween_callback(previous.stop)


func set_volumes(master: float, music: float, sfx: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	for voice: AudioStreamPlayer in _voices:
		voice.volume_db = _decibels(master_volume * sfx_volume)
	for track: AudioStreamPlayer in _music:
		_set_music_gain(float(track.get_meta("gain", 0.0)), track)


func set_muted(value: bool) -> void:
	muted = value


func _set_music_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.set_meta("gain", gain)
	player.volume_db = _decibels(master_volume * music_volume * gain)


func _decibels(gain: float) -> float:
	return -80.0 if muted or gain <= 0.0 else linear_to_db(gain)


func _get_stream(path: String) -> AudioStream:
	if not _streams.has(path):
		if not ResourceLoader.exists(path):
			push_warning("Missing local audio asset: " + path)
			return null
		_streams[path] = load(path) as AudioStream
	return _streams[path] as AudioStream

func _exit_tree() -> void:
	# Release duplicated ambience and its playback before the audio server exits.
	if _fade != null and _fade.is_valid(): _fade.kill()
	for player: AudioStreamPlayer in _voices + _music:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_voices.clear()
	_music.clear()
	_streams.clear()
