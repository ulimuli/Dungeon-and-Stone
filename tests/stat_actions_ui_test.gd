extends SceneTree
## Parsed real UI over assisted generic modifiers, funds and a bound essence.
## Settings and isolated slot99 bytes have a durable backup and bounded cleanup.
const MAIN = preload("res://main.tscn")
const PATHS: Array[String] = ["user://settings.json","user://settings.json.tmp","user://saves/slot_99.json","user://saves/slot_99.json.bak","user://saves/slot_99.json.tmp"]
const BACKUP: String = "user://test_backups/stat-actions-ui-preserved.json"
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: _run.call_deferred()

func settle() -> void:
	for frame: int in range(5): await process_frame

func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func label_exact(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text == text: return node
	return null

func label_containing(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text.contains(text): return node
	return null

func reveal(control: Control) -> void:
	if control == null: return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await settle()

func visible_control(control: Control, label: String) -> void:
	check(control != null,label+" exists")
	if control == null: return
	var visible: bool = control.is_visible_in_tree() and Rect2(0,0,640,360).encloses(control.get_global_rect())
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(control.get_global_rect()): visible = false
		ancestor = ancestor.get_parent()
	check(visible,label+" fits viewport and ancestor scroll clipping")

func hover(control: Control) -> void:
	if control == null: return
	await reveal(control)
	var point: Vector2 = control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await process_frame

func click(control: Control) -> void:
	check(control != null,"Actual mouse target exists")
	if control == null: return
	await reveal(control)
	visible_control(control,"Mouse target "+str(control.get("text")))
	await hover(control)
	var point: Vector2 = control.get_global_rect().get_center()
	var down := InputEventMouseButton.new(); down.position = point; down.global_position = point; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true
	Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new(); up.position = point; up.global_position = point; up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()

func resources() -> String:
	var state: Dictionary = game.sim.state.duplicate(true)
	state.erase("log")
	return var_to_str([state,game.sim.rng.state])

func restore_files() -> void:
	for path: String in PATHS:
		if preserved[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(preserved[path]); file.close()
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null) == preserved[path],"Original bytes restored: "+path)

func watchdog() -> void:
	check(false,"UI test exceeded90seconds; restoring original files")
	restore_files()
	quit(1)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.capture(filename)
	check(FileAccess.file_exists("res://screenshots/"+filename),"Captured "+filename)

func modifier(id: String, stat: String, op: String, value: float) -> Dictionary:
	return {"id":"fixture:"+id,"source":"fixture:stat_ui","stat":stat,"op":op,"value":value}

func _run() -> void:
	var durable: Dictionary = {}
	for path: String in PATHS:
		preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		durable[path] = Marshalls.raw_to_base64(preserved[path]) if preserved[path] != null else null
	DirAccess.make_dir_recursive_absolute("user://test_backups")
	var backup := FileAccess.open(BACKUP,FileAccess.WRITE)
	backup.store_string(JSON.stringify({"encoding":"base64","files":durable})); backup.close()
	create_timer(90).timeout.connect(watchdog)
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game); game.save_slot = 99
	game.settings.fullscreen = false; game.settings.muted = true; game.settings.reduced_motion = true; game.apply_settings()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for scale: float in [1.0,1.2]:
		print("STAT ACTION UI: parsed controls at ",scale)
		await test_scale(scale)
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle()
	restore_files()
	print("STAT ACTION UI: %d checks, %d failures. Actual jump targeting and spirit confirmation controls at100/120%%; assisted modifier fixture; all registered stats have consumers, with provisional effects disclosed; settings/slot99 restored." % [checks,failures])
	quit(1 if failures else 0)

func keypress(key: int) -> void:
	var down:=InputEventKey.new(); down.keycode=key; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up:=InputEventKey.new(); up.keycode=key; Input.parse_input_event(up); await settle()

func map_click(tile: Vector2i) -> void:
	var point:Vector2=game.tile_point(tile)+Vector2(8,8)
	var down:=InputEventMouseButton.new(); down.position=point; down.global_position=point; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
	Input.parse_input_event(down); await process_frame
	var up:=InputEventMouseButton.new(); up.position=point; up.global_position=point; up.button_index=MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()

func test_scale(scale: float) -> void:
	game.sim.new_campaign("Action UI fixture","human","adventurer",74119)
	check(game.sim.enter_region(1),"Jump fixture enters the actual expedition")
	game.sim.state.units=[]; game.sim.state.combat=false; game.sim.state.map.traps=[]; game.sim.hero().pos=Vector2i(13,9)
	for y:int in range(4,17):
		for x:int in range(6,23): game.sim.state.map.tiles[y][x]=DungeonWorld.FLOOR
	game.sim.update_visibility()
	game.screen="game"; game.overlay=""; game.settings.text_scale=scale; game.notice_time=0; game.render(); await settle()
	game.sim.state.level=3; game.sim.hero().essences=["canon_goblin","canon_goblin_archer","canon_gnome"]; game.sim.recalculate(game.sim.hero(),false); game.render(); await settle()
	var command_row:Control=button("JUMP").get_parent()
	check(command_row.get_global_rect().end.x<=440 and command_row.get_global_rect().end.y<=294,"Full three-technique command row fits its viewport at current scale")
	var start:Vector2i=game.sim.hero().pos
	await click(button("JUMP"))
	check(game.jump_targeting,"Parsed JUMP control enters targeting")
	await capture("39-jump-%d.png" % int(scale*100))
	await keypress(KEY_ESCAPE)
	check(not game.jump_targeting and game.overlay.is_empty() and game.sim.hero().pos==start,"Escape cancels jump without movement or opening Pause")
	await click(button("JUMP")); await map_click(start+Vector2i.RIGHT*2)
	check(game.sim.hero().pos==start+Vector2i.RIGHT*2 and not game.jump_targeting,"Parsed landing click executes the actual jump")
	game.sim.new_campaign("Spirit UI fixture","fairy","adventurer",74119); game.sim.state.gold=1000
	game.screen="game"; game.overlay="party"; game.selected_party="hero"; game.render(); await settle()
	await click(button("SPIRIT LESSON / 120 ST"))
	check(game.overlay=="confirm" and game.confirm_text.contains("provisional"),"Spirit instruction presents explicit provisional acquisition confirmation")
	await click(button("CANCEL"))
	check(not game.sim.hero().has("spirit") and game.sim.state.gold==1000,"Cancelled lesson does not grant a contract or consume currency")
	game.overlay="party"; game.render(); await settle()
	await click(button("SPIRIT LESSON / 120 ST")); await click(button("CONFIRM"))
	check(game.sim.hero().has("spirit") and game.sim.state.gold==880 and game.sim.state.day==4,"Confirmed lesson changes actual contract, gold and calendar")
	check(label_containing("Natural Energy 20/20")!=null,"Spirit panel shows the independent Natural Energy pool")
	await click(button("SPIRIT LIGHT"))
	check(game.sim.hero().spirit.active,"Parsed spirit control activates light")
	await click(button("DISMISS FIRE SPIRIT"))
	check(not game.sim.hero().spirit.active,"Parsed spirit control dismisses light")
	await reveal(button("SPIRIT LIGHT"))
	await capture("40-spirit-%d.png" % int(scale*100))
	game.sim.wait_for_opening(); check(game.sim.enter_region(1),"Trained Fairy enters next opening")
	game.sim.state.units=[]; game.sim.state.combat=false; game.sim.hero().natural_energy_current=1
	game.overlay="party"; game.render(); await settle()
	await click(button("REST SPIRIT / 2H"))
	check(game.sim.hero().natural_energy_current==20 and game.sim.state.time==120,"Parsed spirit rest advances real expedition time and restores its resource")
	await test_stones(scale)

func seed_contract(success: bool) -> void:
	var probe:=RandomNumberGenerator.new()
	for candidate:int in range(1,10000):
		probe.seed=candidate
		if (probe.randi_range(1,100)<=10)==success: game.sim.rng.seed=candidate; return
	check(false,"Deterministic contract outcome exists")

func test_stones(scale: float) -> void:
	# City setup is assisted; market, confirmations, failure/success and guidance use parsed inputs.
	game.sim.state.mode="city"; game.sim.state.combat=false; game.sim.state.gold=1000
	game.open_city_location("market"); await settle()
	var price:int=game.sim.market_price("spirit_stone",true,"merchant")
	await click(button("Spirit Stone / %d ST" % price)); await click(button("Spirit Stone / %d ST" % price))
	check(game.sim.state.inventory.get("spirit_stone",0)==2 and game.sim.state.gold==1000-2*price,"Parsed market purchase gives exactly two Spirit Stones at the displayed cost")
	game.overlay="party"; game.render(); await settle()
	await click(button("SPIRIT STONE / 10%"))
	check(game.confirm_text.contains("10%") and game.confirm_text.contains("Consumed on success or failure"),"Confirmation explains exact odds and both-outcome consumption")
	var stream:int=game.sim.rng.state
	await click(button("CANCEL"))
	check(game.sim.state.inventory.get("spirit_stone",0)==2 and game.sim.rng.state==stream,"Cancelled contract does not consume a stone or draw RNG")
	game.overlay="party"; game.render(); await settle(); seed_contract(false)
	await click(button("SPIRIT STONE / 10%")); await click(button("CONFIRM"))
	check(game.sim.state.inventory.get("spirit_stone",0)==1 and not game.sim.hero().get("wind_contract",false),"Actual failed attempt consumes exactly one stone")
	seed_contract(true)
	await click(button("SPIRIT STONE / 10%")); await click(button("CONFIRM"))
	check(game.sim.hero().wind_contract and game.sim.state.inventory.get("spirit_stone",0)==0,"Actual successful attempt consumes the remaining stone and unlocks Wind")
	await click(button("WIND GUIDANCE"))
	check(not game.sim.hero().wind_guidance,"Guidance cannot activate with the current Club")
	game.open_city_location("market"); await settle()
	await click(button("Bow / %d ST" % game.sim.market_price("bow",true,"merchant")))
	game.overlay="inventory"; game.inventory_selected="bow"; game.render(); await settle()
	await click(button("EQUIP"))
	check(game.sim.hero().equipment.weapon=="bow","Parsed inventory equips an actual purchased bow")
	game.overlay="party"; game.render(); await settle()
	var accuracy:float=game.sim.stat_value(game.sim.hero(),"accuracy")
	await click(button("WIND GUIDANCE"))
	check(game.sim.hero().wind_guidance and game.sim.stat_value(game.sim.hero(),"accuracy")==accuracy+10,"Parsed Wind control feeds the actual shared Accuracy calculation")
	check(game.notice.is_empty() and game.notice_time==0,"Successful guidance clears a stale prior equipment error")
	await reveal(button("DISMISS WIND GUIDANCE")); await capture("41-wind-%d.png" % int(scale*100))
	await click(button("DISMISS WIND GUIDANCE"))
	check(not game.sim.hero().wind_guidance and game.sim.stat_value(game.sim.hero(),"accuracy")==accuracy,"Dismissing Wind restores the unboosted Accuracy")
