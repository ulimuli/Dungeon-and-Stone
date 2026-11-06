extends SceneTree
const Audio = preload("res://game/audio.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var audio: GameAudio = Audio.new()
	audio.muted = true
	root.add_child(audio)
	audio.set_volumes(0.0,0.0,0.0)
	audio.muted = false # Load/play actual assets silently, not a mocked backend.
	audio.ambient("city")
	var city_loop: WeakRef = weakref(audio._music[audio._active_music].stream)
	check(city_loop.get_ref() is AudioStreamWAV,"City ambience creates an actual local looping WAV")
	await create_timer(0.05).timeout
	audio.ambient("dungeon") # Close while a crossfade is still in progress.
	var dungeon_loop: WeakRef = weakref(audio._music[audio._active_music].stream)
	check(dungeon_loop.get_ref() is AudioStreamWAV and dungeon_loop.get_ref() != city_loop.get_ref(),"Crossfade uses independently owned loop resources")
	for cue: String in Audio.CUES: audio.play(cue)
	check(audio._streams.size() == Audio.CUES.size()+Audio.AMBIENCE.size(),"All shipped combat/UI/loot/environment sounds load through real playback")
	var instance: WeakRef = weakref(audio)
	audio.queue_free()
	await create_timer(0.25).timeout
	check(instance.get_ref() == null,"Audio owner frees while its crossfade and voices were active")
	check(city_loop.get_ref() == null,"Exit releases the previous duplicated ambience loop")
	check(dungeon_loop.get_ref() == null,"Exit releases current ambience and its playback resource")
	print("AUDIO LIFECYCLE: %d checks, %d failures. Actual local playback/crossfade shutdown; silence via zero volume, no settings or save writes." % [checks,failures])
	quit(1 if failures else 0)
