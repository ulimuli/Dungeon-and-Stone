extends SceneTree
## Rendered assisted senses fixture; no save/settings writes and no human playtest.
const MAIN = preload("res://main.tscn")
var checks: int = 0
var failures: int = 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game: Control = MAIN.instantiate(); root.add_child(game)
	game.settings.fullscreen = false; game.settings.muted = true; game.settings.reduced_motion = true; game.apply_settings()
	game.sim.new_campaign("Senses fixture","human","adventurer",74119)
	check(game.sim.enter_region(1),"Actual expedition entry")
	game.sim.state.units = []; game.sim.state.party = []; game.sim.state.map.traps = []
	for y: int in range(1,int(game.sim.state.map.height)-1):
		for x: int in range(1,int(game.sim.state.map.width)-1): game.sim.state.map.tiles[y][x] = 0
	game.sim.hero().pos = Vector2i(13,9)
	game.sim.hero().base_stats = {"hearing":80,"sixth_sense":60}
	game.sim.recalculate(game.sim.hero())
	var enemy: Dictionary = game.sim.spawn_enemy("canon_goblin",Vector2i(16,9))
	game.sim.status(enemy,"concealed",10); game.sim.record_noise(enemy)
	# Both sides are hidden; enemy sight must not independently begin combat.
	game.sim.status(game.sim.hero(),"stealth",10)
	game.sim.state.combat = false; game.sim.update_visibility()
	check(not game.sim.unit_visible(enemy),"Concealed sound source remains unseen")
	check(game.sim.audible_contacts().size()==1 and game.sim.danger_warning(),"Actual sound and generic danger warning present")
	check(not game.sim.state.combat,"Sound and intuition do not start combat or expose targets")
	game.screen = "game"; game.overlay = ""; game.notice = ""
	for scale: float in [1.0,1.2]:
		game.settings.text_scale = scale; game.render()
		for frame: int in range(5): await process_frame
		if DisplayServer.get_name()!="headless":
			var filename: String = "38-senses-%d.png" % int(scale*100)
			await game.capture(filename)
			check(FileAccess.file_exists("res://screenshots/"+filename),"Rendered senses capture "+filename)
	game.queue_free()
	for frame: int in range(5): await process_frame
	print("STAT SENSES UI: %d checks, %d failures. Rendered anonymous sound/danger fixture at100/120%%; no parsed input or human playthrough claim; no save/settings writes." % [checks,failures])
	quit(1 if failures else 0)
