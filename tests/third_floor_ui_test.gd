extends "res://tests/early_floor_ui_test.gd"
## Reuses the isolated file-preserving input harness; actual third-floor commands.
func _run() -> void:
	var durable: Dictionary={}
	for path: String in PATHS:
		preserved[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		durable[path]=Marshalls.raw_to_base64(preserved[path]) if preserved[path]!=null else null
	for slot: int in range(1,4):
		for suffix: String in ["",".bak",".tmp"]:
			var path: String="user://saves/slot_%02d.json%s" % [slot,suffix]
			player_files[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	DirAccess.make_dir_recursive_absolute("user://test_backups")
	var backup:=FileAccess.open(BACKUP,FileAccess.WRITE)
	check(backup!=null,"Durable settings/slot95 backup opens before scene launch")
	if backup==null: quit(1); return
	backup.store_string(JSON.stringify({"encoding":"base64","files":durable})); backup.close()
	create_timer(180).timeout.connect(watchdog)
	root.gui_embed_subwindows=true; root.size=Vector2i(640,360); root.content_scale_size=Vector2i(640,360); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=MAIN.instantiate(); root.add_child(game)
	if not game.has_method("render"):
		check(false,"Main scene script failed to load; restoring isolated files immediately")
		game.queue_free(); await settle(); restore_files(); quit(1); return
	game.save_slot=95
	game.settings.fullscreen=false; game.settings.muted=true; game.settings.reduced_motion=true; game.settings.bindings.interact=KEY_E; game.settings.bindings.inventory=KEY_I; game.apply_settings(); root.size=Vector2i(640,360)
	if DisplayServer.get_name()!="headless": DirAccess.make_dir_recursive_absolute("res://screenshots")
	for scale: float in [1.0,1.2]:
		await fresh(scale); await test_third_scene(scale)
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle(); restore_files()
	for path: String in player_files:
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null)==player_files[path],"Player slot1–3 bytes untouched: "+path)
	print("THIRD FLOOR UI: %d checks, %d failures. Parsed thirdfloor travel/refuge controls and rendered fourregion terrain/maps at100/120%%; assisted knowledge/placement, isolated95/settings restored." % [checks,failures])
	quit(1 if failures else 0)

func clear_encounters()->void:
	game.sim.state.units=[]; game.sim.state.combat=false; game.overlay=""; game.sim.update_visibility(); game.render()
func scene_travel(destination: int)->void:
	var found: bool=false
	for gate: Dictionary in game.sim.state.map.get("area_portals",[])+game.sim.state.map.get("floor_portals",[]):
		if int(gate.region)==destination: game.sim.hero().pos=gate.pos; found=true; break
	check(found,"Rendered region has physical route to "+str(destination))
	clear_encounters(); await settle(); await keypress(KEY_E)
	check(game.overlay=="portal","Parsed E opens only nearby route")
	await click(button(game.sim.region_data(destination).name))
	check(int(game.sim.state.region)==destination and game.overlay.is_empty(),"Parsed route enters actual destination "+str(destination))
	clear_encounters(); await settle()
func test_third_scene(scale: float)->void:
	await scene_travel(5); await scene_travel(6)
	await capture("53-ironrock-hill-%d.png" % int(scale*100))
	await scene_travel(7)
	for id: String in ["canon_orc_warrior","canon_orc_archer","canon_orc_sorcerer"]:
		var position: Vector2i=game.sim.nearest_free(game.sim.hero().pos+Vector2i(3,0))
		game.sim.spawn_enemy(id,position)
	game.sim.update_visibility(); game.render(); await settle()
	await capture("54-orc-colony-%d.png" % int(scale*100))
	await scene_travel(8)
	check(game.sim.hero().statuses.has("field_pain"),"Rendered Witch field is actual simulation status")
	game.sim.state.time=240; game.sim.hero().pos=ThirdFloorRules.active_hut_site(game.sim)+Vector2i.DOWN; clear_encounters(); await settle()
	await capture("55-witch-forest-%d.png" % int(scale*100))
	await keypress(KEY_E)
	check(game.overlay=="witch_hut" and ThirdFloorRules.in_refuge(game.sim),"Parsed purpletree enters actual refuge")
	fits(button("REST"),"Refuge rest control"); fits(button("LEAVE"),"Refuge leave control")
	await capture("56-witch-cabin-%d.png" % int(scale*100))
	await click(button("LEAVE"))
	check(not ThirdFloorRules.in_refuge(game.sim) and game.overlay.is_empty(),"Parsed Leave removes actual protection")
	await scene_travel(9)
	game.sim.hero().pos=game.sim.state.map.shelter_mounds[0]; game.sim.update_visibility(); game.render(); await settle()
	await capture("57-dark-river-estuary-%d.png" % int(scale*100))
	for y: int in range(64):
		for x: int in range(96): game.sim.state.seen["%d,%d" % [x,y]]=true
	game.overlay="map"; game.map_zoom=0; game.map_pan=Vector2.ZERO; game.render(); await settle()
	fits(button("FIT"),"Thirdfloor overview fits")
	check(game.dungeon_markers().size()==2,"Estuary map shows only actual paths/portal, no fake fourthfloor exit")
	await capture("58-third-floor-map-%d.png" % int(scale*100))
	await click(button("CLOSE [Esc]"))
