extends SceneTree
## Parsed controls and actual rendered early-floor landmarks at100/120% text.
## Harness reveals map knowledge and places the hero beside features; ordinary
## discovery, travel balance and human playtesting are not claimed.
const MAIN=preload("res://main.tscn")
const PATHS: Array[String]=["user://settings.json","user://settings.json.tmp","user://saves/slot_95.json","user://saves/slot_95.json.bak","user://saves/slot_95.json.tmp"]
const BACKUP: String="user://test_backups/early-floor-ui.json"
var game: Control
var checks: int=0
var failures: int=0
var preserved: Dictionary={}
var player_files: Dictionary={}
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: _run.call_deferred()
func settle() -> void:
	for frame: int in range(5): await process_frame
func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text==text: return node
	return null
func label_containing(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text.contains(text): return node
	return null
func reveal(control: Control) -> void:
	if control==null: return
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await settle()
func fits(control: Control, message: String) -> void:
	check(control!=null,message+": exists")
	if control==null: return
	var visible: bool=control.is_visible_in_tree() and Rect2(0,0,640,360).encloses(control.get_global_rect())
	var ancestor: Node=control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(control.get_global_rect()): visible=false
		ancestor=ancestor.get_parent()
	check(visible,message+": fits viewport and clipping ancestors")
func click(control: Control) -> void:
	check(control!=null,"Expected parsed mouse target exists")
	if control==null: return
	await reveal(control); fits(control,"Mouse target "+str(control.get("text")))
	var point: Vector2=control.get_global_rect().get_center()
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion); await process_frame
	var down:=InputEventMouseButton.new(); down.position=point; down.global_position=point; down.button_index=MOUSE_BUTTON_LEFT; down.button_mask=MOUSE_BUTTON_MASK_LEFT; down.pressed=true
	Input.parse_input_event(down); await process_frame
	var up:=InputEventMouseButton.new(); up.position=point; up.global_position=point; up.button_index=MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()
func keypress(key: int) -> void:
	var down:=InputEventKey.new(); down.keycode=key; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up:=InputEventKey.new(); up.keycode=key; Input.parse_input_event(up); await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await game.capture(name)
	check(FileAccess.file_exists("res://screenshots/"+name),"Rendered screenshot exists: "+name)
func restore_files() -> void:
	for path: String in PATHS:
		if preserved.get(path)==null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(preserved[path]); file.close()
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null)==preserved.get(path),"Original isolated file bytes restored: "+path)
func watchdog() -> void:
	check(false,"Early-floor graphical test exceeded180seconds")
	restore_files(); quit(1)
func fresh(scale: float) -> void:
	game.sim.new_campaign("Early-floor UI assisted fixture","barbarian","adventurer",74119)
	game.sim.state.gold=10000; game.sim.state.food=100; game.sim.state.water=100; game.sim.state.flags.assisted=true
	check(game.sim.enter_region(1),"Actual scene enters the new first-floor map")
	game.sim.state.units=[]; game.sim.state.combat=false
	game.settings.text_scale=scale; game.screen="game"; game.overlay=""; game.selected_party="hero"
	game.notice=""; game.notice_time=0; game.selected_ability=-1; game.jump_targeting=false
	game.render(); await settle()
func gate_for(area: int) -> Dictionary:
	for gate: Dictionary in game.sim.state.map.get("area_portals",[]):
		if int(gate.region)==area: return gate
	return {}
func place_gate(area: int) -> Vector2i:
	var gate: Dictionary=gate_for(area)
	check(not gate.is_empty(),"Actual scene has matching gate "+str(area))
	if gate.is_empty(): return Vector2i(-1,-1)
	game.sim.hero().pos=gate.pos; game.sim.state.combat=false; game.sim.update_visibility(); game.overlay=""; game.render(); await settle()
	return gate.pos
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
		await fresh(scale); await test_memorial_and_map(scale); await test_gates_and_den(scale); await test_flowers(scale); await test_topple(scale); await test_magic_torch(scale); test_fiend_tooltip()
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle(); restore_files()
	for path: String in player_files:
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null)==player_files[path],"Player slot1–3 bytes untouched: "+path)
	print("EARLY FLOOR UI: %d checks, %d failures. Parsed restricted compass portals, memorial, corpse-flower/torch/Topple controls and rendered five-area/map markers at100/120%%; assisted knowledge/placement, isolated95/settings restored." % [checks,failures])
	quit(1 if failures else 0)
func test_memorial_and_map(scale: float) -> void:
	game.sim.hero().pos=game.sim.state.map.central_memorial; game.sim.update_visibility(); game.render(); await settle()
	await keypress(KEY_E)
	check(game.overlay!="portal" and label_containing("GREAT SAGE MEMORIAL")!=null,"Parsed E opens distinct memorial lore instead of arbitrary floor selection")
	for area: int in [2,3,4,5]: check(button(game.sim.region_data(area).name)==null,"Memorial offers no fake ordinary-floor destination")
	await click(button("CLOSE [Esc]"))
	for y: int in range(int(game.sim.state.map.height)):
		for x: int in range(int(game.sim.state.map.width)): game.sim.state.seen["%d,%d" % [x,y]]=true
	game.overlay="map"; game.map_zoom=0; game.map_pan=Vector2.ZERO; game.render(); await settle()
	fits(button("FIT"),"Map fit control")
	check(game.dungeon_markers().filter(func(marker: Dictionary)->bool:return marker.kind=="portal").size()==4,"Map presentation uses all four real portal markers")
	check(game.dungeon_markers().filter(func(marker: Dictionary)->bool:return marker.kind=="memorial").size()==1,"Memorial has its own distinct map marker")
	await capture("47-first-floor-portals-%d.png" % int(scale*100))
	if DisplayServer.get_name()!="headless":
		var rendered:=Image.load_from_file("res://screenshots/47-first-floor-portals-%d.png" % int(scale*100))
		check(rendered.get_width()==640 and rendered.get_height()==360,"Logical source capture preserves crisp640×360 scaling")
		var fit: int=maxi(1,int(minf(560.0/float(game.sim.state.map.width),230.0/float(game.sim.state.map.height))))
		var origin:=Vector2(40,62)+(Vector2(560,230)-Vector2(game.sim.state.map.width,game.sim.state.map.height)*fit)/2
		for gate: Dictionary in game.sim.state.map.area_portals:
			var pixel: Vector2i=Vector2i(origin+Vector2(gate.pos)*fit)+Vector2i.ONE
			var colour: Color=rendered.get_pixelv(pixel)
			check(colour.is_equal_approx(game.GOLD),"Rendered overview contains the actual "+str(gate.direction)+" gate marker")
	await click(button("CLOSE [Esc]"))
func test_gates_and_den(scale: float) -> void:
	for area: int in [2,3,4,5]:
		var anchor: Vector2i=await place_gate(area)
		await keypress(KEY_E)
		check(game.overlay=="portal","Parsed E opens a real boundary portal")
		fits(button(game.sim.region_data(area).name),"Matching destination button")
		for other: int in [2,3,4,5]:
			if other!=area: check(button(game.sim.region_data(other).name)==null,"Physical portal excludes unrelated destination")
		if area==5: await capture("48-den-portal-%d.png" % int(scale*100))
		await click(button(game.sim.region_data(area).name))
		check(game.sim.state.region==area and game.overlay.is_empty(),"Parsed destination enters the matching actual area")
		game.sim.state.units=[]; game.sim.state.combat=false; game.sim.hero().pos=game.sim.state.map.entrance; game.sim.update_visibility(); game.render(); await settle()
		if area==5:
			check(game.sim.state.map.get("beast_caves",[]).size()>0 and game.sim.state.map.get("sewage_pits",[]).size()>0,"Den render is backed by actual canyon/cave/pit geometry")
			var actor: Button=button("[ %s ]" % game.sim.hero().name)
			fits(actor,"Long-name dungeon actor control")
			check(actor.get_global_rect().size.x<=184 and actor.get_global_rect().end.x<=632,"Long actor name cannot stretch the fixed sidebar")
			for bar: Node in game.ui.find_children("*","ProgressBar",true,false): fits(bar,"Dungeon resource bar")
			await capture("49-den-of-beasts-%d.png" % int(scale*100))
		await keypress(KEY_E); await click(button("Return to Crystal Cave"))
		check(game.sim.state.region==1 and game.sim.distance(game.sim.hero().pos,anchor)<=1,"Parsed return restores the same compass anchor")
func test_flowers(scale: float) -> void:
	await place_gate(3); await keypress(KEY_E); await click(button(game.sim.region_data(3).name))
	game.sim.state.units=[]; game.sim.state.combat=false
	var flowers: Array=game.sim.state.map.get("corpse_flowers",[])
	check(not flowers.is_empty(),"Actual Dead map contains corpse-flower landmarks")
	if flowers.is_empty(): return
	game.sim.hero().pos=flowers[0]+Vector2i.UP; game.sim.update_visibility(); game.overlay=""; game.render(); await settle()
	var water: int=game.sim.state.water
	await keypress(KEY_E)
	check(game.sim.state.water==water and game.sim.state.map.get("harvested_flowers",[]).is_empty(),"Parsed Day1 dormant flower cannot be harvested")
	game.sim.advance_time(game.sim.MINUTES_PER_DAY-int(game.sim.state.time)); game.sim.state.water=1
	game.sim.update_visibility(); game.overlay=""; game.render(); await settle()
	await capture("50-corpse-flower-%d.png" % int(scale*100))
	await keypress(KEY_E)
	check(game.sim.state.water==5 and game.sim.state.map.get("harvested_flowers",[]).size()==1,"Parsed Day2 interaction harvests real water once")
	await keypress(KEY_E)
	check(game.sim.state.water==5 and game.sim.state.map.harvested_flowers.size()==1,"Repeated parsed interaction cannot refill the same flower")

func test_topple(scale: float) -> void:
	game.sim.state.units=[]; game.sim.state.combat=true; game.sim.resolving_round=true
	game.sim.hero().ap=2; game.sim.hero().attacked=false
	var position: Vector2i=Vector2i(-1,-1)
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var candidate: Vector2i=game.sim.hero().pos+direction
		if DungeonWorld.walkable(game.sim.state.map,candidate): position=candidate; break
	check(position.x>=0,"Counterplay fixture has actual adjacent walkable terrain")
	if position.x<0: game.sim.resolving_round=false; return
	var target: Dictionary=game.sim.spawn_enemy("canon_death_fiend",position)
	game.sim.update_visibility(); game.sim.plan_intents(); game.overlay=""; game.render(); await settle()
	var point: Vector2=game.tile_point(position)+Vector2(8,8)
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var down:=InputEventMouseButton.new(); down.position=point; down.global_position=point; down.button_index=MOUSE_BUTTON_RIGHT; down.button_mask=MOUSE_BUTTON_MASK_RIGHT; down.pressed=true
	Input.parse_input_event(down); await process_frame
	var up:=InputEventMouseButton.new(); up.position=point; up.global_position=point; up.button_index=MOUSE_BUTTON_RIGHT
	Input.parse_input_event(up); await settle()
	check(game.overlay=="inspect" and game.inspect_id==target.id,"Parsed map right-click inspects actual visible Death Fiend")
	await reveal(button("TOPPLE")); fits(button("TOPPLE"),"Death Fiend counterplay button")
	await capture("51-death-fiend-counterplay-%d.png" % int(scale*100))
	await click(button("TOPPLE"))
	check(target.statuses.has("toppled") and target.ap==0 and game.sim.hero().attacked,"Parsed Topple consumes real attack and applies helpless counterplay: "+str([scale,target.statuses,target.ap,game.sim.hero().attacked,game.sim.hero().ap,game.sim.state.log[-1]]))
	game.sim.resolving_round=false

func test_magic_torch(scale: float) -> void:
	game.sim.new_campaign("Early-floor UI assisted fixture","barbarian","adventurer",74119)
	game.sim.state.gold=100; game.sim.state.food=100; game.sim.state.water=100; game.sim.state.flags.assisted=true
	game.screen="game"; game.city_location="market"; game.trading_npc=""; game.overlay="city_location"; game.render(); await settle()
	var price: int=game.sim.market_price("magic_torch",true,game.trading_npc)
	await click(button("Magic Torch / %d ST" % price)); await click(button("Magic Torch / %d ST" % price))
	check(game.sim.state.inventory.get("magic_torch",0)==2,"Parsed real market buys two physical torches")
	await click(button("CLOSE [Esc]"))
	check(game.sim.enter_region(1),"Market torches enter the actual expedition")
	game.sim.state.units=[]; game.sim.state.combat=false; game.sim.hero().pos=game.sim.state.map.central_memorial; game.sim.update_visibility()
	game.overlay=""; game.inventory_selected="magic_torch"; game.inventory_filter=""; game.inventory_storage=false; game.render(); await settle()
	var unlit: int=game.sim.state.visible.size()
	await keypress(KEY_I); await click(button("USE"))
	check(game.sim.state.inventory.get("magic_torch",0)==1 and int(game.sim.state.torch_until)>int(game.sim.state.time),"Parsed inventory USE lights a torch and preserves a spare: "+str([scale,game.sim.state.inventory,game.sim.state.torch_until,game.sim.state.log[-1],game.selected_party]))
	var deadline: int=game.sim.state.torch_until
	await click(button("USE"))
	check(game.sim.state.inventory.get("magic_torch",0)==1 and int(game.sim.state.torch_until)==deadline,"Repeated parsed USE cannot waste a spare or stack duration: "+str([scale,game.sim.state.inventory,game.sim.state.torch_until,game.sim.state.log[-1]]))
	await click(button("CLOSE [Esc]"))
	check(game.sim.state.visible.size()>unlit,"Actual game view receives the dark-zone visibility benefit")
	game.notice=""; game.notice_time=0; game.render(); await settle()
	await capture("52-magic-torch-%d.png" % int(scale*100))

func test_fiend_tooltip() -> void:
	var unit: Dictionary=game.sim.hero().duplicate(true)
	unit.id="tooltip_draconian_fixture"; unit.ancestry="draconian"; unit["dragon_blessing"]="volcano"; unit.essences=["canon_death_fiend"]
	var before: String=var_to_str([game.sim.state,game.sim.rng.state])
	var text: String=game.essence_tooltip("canon_death_fiend",unit)
	check(text.contains("Rank 8") and not text.contains("Rank 9"),"Death Fiend tooltip displays sourced rank8")
	check(text.contains("×2"),"Physical Preservation tooltip explains the actual shared recovery multiplier")
	check(text.contains("16") and not text.contains("Duration 0"),"Volcano tooltip exposes resolved16-round summon lifetime rather than base12 or absent duration")
	check(var_to_str([game.sim.state,game.sim.rng.state])==before,"Inspecting a build tooltip consumes no campaign resources or RNG")
