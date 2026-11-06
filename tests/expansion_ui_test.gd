extends SceneTree
const MAIN = preload("res://main.tscn")
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}
const PATHS: Array[String] = ["user://saves/slot_96.json","user://saves/slot_96.json.bak","user://saves/slot_96.json.tmp"]
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func settle() -> void:
	for frame: int in range(5): await process_frame
func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text == text: return node
	return null
func click(control: Control) -> void:
	check(control != null,"Expected actual control exists")
	if control == null: return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await settle()
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point; Input.parse_input_event(move)
	await settle()
	var down := InputEventMouseButton.new(); down.position = point; down.global_position = point; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true
	Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new(); up.position = point; up.global_position = point; up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for path: String in PATHS: preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game); game.save_slot = 96
	game.settings.fullscreen = false; game.settings.muted = true; game.settings.reduced_motion = true
	game.sim.new_campaign("Expansion UI","barbarian","adventurer",74119)
	game.sim.state.gold = 1800; game.sim.state.flags.assisted = true
	game.screen = "game"; game.selected_party = "hero"
	for scale: float in [1.0,1.2]:
		game.settings.text_scale = scale; game.overlay = "party"; game.render(); await settle()
		await click(button("SOUL ENGRAVING"))
		check(game.overlay == "racial","Character status routes to actual sanctuary service")
		await click(button("ENGRAVE / 800 ST"))
		check(game.overlay == "confirm" and game.confirm_text.contains("permanent"),"Irreversible purchase asks explicit confirmation")
		check(button("CONFIRM") != null and Rect2(0,0,640,360).encloses(button("CONFIRM").get_global_rect()),"Sanctuary confirmation fits at enlarged text")
		await click(button("CANCEL"))
		check(int(game.sim.state.gold) == 1800 and not game.sim.hero().has("racial"),"Cancel preserves gold and unset path")
	game.settings.text_scale = 1.0; game.overlay = "racial"; game.render(); await settle()
	await click(button("ENGRAVE / 800 ST")); await click(button("CONFIRM"))
	check(int(game.sim.state.gold) == 1000 and game.sim.hero().racial.engraving_path == "undying","Actual confirmed sanctuary transaction applies saved path and exact fee")
	await game.capture("30-sanctuary-undying.png")
	check(game.sim.enter_region(1),"Scene enters actual expanded expedition")
	game.sim.state.units = []; game.sim.state.combat = false
	game.overlay = ""; game.render(); await settle()
	check(game.sim.state.map.width == 96 and game.sim.state.map.height == 64,"Actual scene uses expanded map dimensions")
	await game.capture("27-wide-crystal-cave.png")
	game.overlay = "map"; game.render(); await settle()
	await click(button("+"))
	check(game.map_zoom == 1,"Real map zoom control changes scale")
	await game.capture("28-expanded-map-zoom.png")
	await click(button("FIT"))
	for y: int in range(int(game.sim.state.map.height)):
		for x: int in range(int(game.sim.state.map.width)): game.sim.state.seen["%d,%d" % [x,y]] = true
	game.render(); await settle(); await game.capture("31-wide-dungeon-layout.png")
	check(game.map_zoom == 0 and game.map_pan == Vector2.ZERO,"Fit resets map zoom and pan")
	# A sourced fourth-area encounter fixture exercises the actual controller art
	# and telegraph; placement/essence grant are assisted, not normal rewards.
	game.sim.hero().pos = EarlyFloorRules.return_anchor(game.sim.state.map,4); game.sim.state.combat = false
	check(game.sim.travel_region(4),"Actual portal route reaches Black Rock Mountain")
	game.sim.state.units = []; game.sim.hero().pos = game.sim.state.map.entrance
	var position: Vector2i = game.sim.nearest_free(game.sim.hero().pos+Vector2i(3,0))
	var golem: Dictionary = game.sim.spawn_enemy("canon_stone_golem",position)
	game.sim.update_visibility(); game.sim.plan_intents()
	game.overlay = ""; game.render(); await settle()
	check(golem.intent.get("kind","") == "suppression","Actual Stone Golem shows planned Suppression")
	check(game.tex("classic_monster_stone_golem") != null and game.tex("classic_monster_stone_golem").get_size() == Vector2(32,32),"Golem has a native32px sprite rather than a missing-asset square")
	await game.capture("29-stone-golem-suppression.png")
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle()
	for path: String in PATHS:
		if preserved[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(preserved[path]); file.close()
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null) == preserved[path],"Test save bytes restored")
	print("EXPANSION SCENE UI: %d checks, %d failures. Parsed sanctuary/map controls and rendered expanded cave/golem; assisted fixtures." % [checks,failures])
	quit(1 if failures else 0)
