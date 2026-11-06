extends SceneTree
## Parsed real homeland travel, walking, conversations, confirmations and creation.
## Funding, recruited actor and ring are assisted setup; no natural-balance claim.
## Settings and isolated slot99 bytes have a durable backup and bounded cleanup.
const MAIN = preload("res://main.tscn")
const PATHS: Array[String] = ["user://settings.json","user://settings.json.tmp","user://saves/slot_99.json","user://saves/slot_99.json.bak","user://saves/slot_99.json.tmp"]
const BACKUP: String = "user://test_backups/homeland-ui.json"
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}
var player_files: Dictionary = {}
const Catalog = preload("res://game/homeland_catalog.gd")
const Saves = preload("res://game/persistence.gd")

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
	check(false,"UI test exceeded180seconds; restoring original files")
	restore_files()
	quit(1)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.capture(filename)
	check(FileAccess.file_exists("res://screenshots/"+filename),"Captured "+filename)

func keypress(key: int) -> void:
	var down:=InputEventKey.new(); down.keycode=key; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up:=InputEventKey.new(); up.keycode=key; Input.parse_input_event(up); await settle()

func joypress(key: int) -> void:
	var down:=InputEventJoypadButton.new(); down.button_index=key; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up:=InputEventJoypadButton.new(); up.button_index=key; Input.parse_input_event(up); await settle()

func click_point(point: Vector2) -> void:
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion); await process_frame
	var down:=InputEventMouseButton.new(); down.position=point; down.global_position=point; down.button_index=MOUSE_BUTTON_LEFT; down.button_mask=MOUSE_BUTTON_MASK_LEFT; down.pressed=true; Input.parse_input_event(down); await process_frame
	var up:=InputEventMouseButton.new(); up.position=point; up.global_position=point; up.button_index=MOUSE_BUTTON_LEFT; Input.parse_input_event(up); await settle()

func home_point(id: String) -> Dictionary:
	if game.homeland_view==null or not is_instance_valid(game.homeland_view): return {}
	for point: Dictionary in game.homeland_view.interaction_points:
		if point.id==id: return point
	return {}

func visit_point(id: String) -> void:
	var point: Dictionary=home_point(id)
	check(not point.is_empty(),"Actual homeland point exists: "+id)
	if point.is_empty(): return
	await click_point(game.homeland_view.global_position+game.homeland_view.cell_center(point.cell))
	for frame: int in range(2400):
		if not game.overlay.is_empty(): break
		await process_frame
	check(not game.overlay.is_empty(),"Parsed point click walks to and opens activity: "+id)
	if game.homeland_view!=null and is_instance_valid(game.homeland_view):
		var distance: int=absi(game.homeland_view.player_cell.x-point.cell.x)+absi(game.homeland_view.player_cell.y-point.cell.y)
		check(distance<=1 and game.homeland_view.player_cell!=point.cell,"Interaction occurs beside rather than on its NPC/object cell: "+id)

func fresh(race: String,scale: float) -> void:
	game.sim.new_campaign("Homeland UI assisted fixture",race,"adventurer",74119)
	game.sim.state.gold=10000; game.sim.state.flags.assisted=true
	game.settings.text_scale=scale; game.screen="game"; game.overlay=""; game.selected_party="hero"
	game.jump_targeting=false; game.selected_ability=-1; game.notice=""; game.notice_time=0
	game.render(); await settle()

func travel(race: String) -> void:
	if not game.overlay.is_empty(): await click(button("CLOSE [Esc]"))
	if not str(game.sim.state.get("homeland",{}).get("location","")).is_empty(): await click(button("RAFDONIA"))
	await click(button("LANDS"))
	check(game.overlay=="homelands","Parsed LANDS button opens travel selection")
	for ancestry: String in Catalog.ANCESTRIES:
		check(button(Catalog.definitions()[ancestry].name)!=null,"Travel selection exposes destination "+ancestry)
	await click(button(Catalog.definitions()[race].name))
	check(game.overlay.is_empty() and game.sim.state.homeland.location==race,"Parsed destination enters "+race)
	visible_control(game.homeland_view,"Full homeland map "+race)
	check(game.homeland_view.layout.id==race and game.homeland_view.interaction_points.size()==6,"Actual map uses matching geometry and six interaction targets: "+race)

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
	check(backup!=null,"Durable original-file backup can be opened before scene launch")
	if backup==null: quit(1); return
	backup.store_string(JSON.stringify({"encoding":"base64","files":durable})); backup.close()
	check(FileAccess.file_exists(BACKUP),"Durable settings/slot99 backup exists")
	create_timer(180).timeout.connect(watchdog)
	# Embed engine popup windows so parsed events reach their actual GUI controls.
	root.gui_embed_subwindows=true
	root.size=Vector2i(640,360); root.content_scale_size=Vector2i(640,360); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=MAIN.instantiate(); root.add_child(game); game.save_slot=99
	game.settings.fullscreen=false; game.settings.muted=true; game.settings.reduced_motion=true; game.apply_settings()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	if "--actor-only" in OS.get_cmdline_user_args():
		await fresh("barbarian",1.0); await travel("dwarf"); await test_actor()
	else:
		await test_all_scales()
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle()
	restore_files()
	for path: String in player_files:
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null)==player_files[path],"Player slot1–3 remains byte-for-byte untouched: "+path)
	if "--actor-only" in OS.get_cmdline_user_args():
		print("HOMELAND UI ACTOR DIAGNOSTIC: %d checks, %d failures. Actual popup selection and inspection only; isolated files restored." % [checks,failures])
	else:
		print("HOMELAND UI: %d checks, %d failures. Parsed six-land travel/walking/lore/ritual/actor/creation controls at100/120%%; disk99 restore uses actual persistence API because UI exposes only player slots1–3. Assisted funding/actor/ring; settings/99 restored; player slots untouched." % [checks,failures])
	quit(1 if failures else 0)

func test_all_scales() -> void:
	for scale: float in [1.0,1.2]:
		print("HOMELAND UI: travel and maps at ",scale)
		await test_travel(scale)
		print("HOMELAND UI: rituals at ",scale)
		await test_rites(scale)
		await test_choices(scale)
		print("HOMELAND UI: character creation at ",scale)
		await test_creation(scale)

func test_travel(scale: float) -> void:
	await fresh("barbarian",scale)
	for race: String in Catalog.ANCESTRIES:
		await travel(race)
		var lore: String=""
		for point: Dictionary in game.homeland_view.interaction_points:
			if point.action=="lore" and point.kind=="landmark": lore=point.id; break
		await visit_point(lore)
		check(game.overlay=="homeland_dialog" and not game.homeland_dialog.message.is_empty(),"Real lore point opens readable conversation: "+race)
		var stopped: Vector2i=game.homeland_view.player_cell
		for frame: int in range(20): await process_frame
		check(game.homeland_view.player_cell==stopped and game.homeland_view._path.is_empty(),"Modal halts cached walking path: "+race)
		await click(button("CLOSE [Esc]"))
		await keypress(KEY_E)
		check(game.overlay=="homeland_dialog","Parsed E reopens nearby lore: "+race)
		await click(button("CLOSE [Esc]"))
		if race=="barbarian":
			await keypress(KEY_SPACE)
			check(game.overlay=="homeland_dialog","Space activates the nearby homeland point")
			await click(button("CLOSE [Esc]"))
			var original_interact: int=int(game.settings.bindings.interact)
			game.settings.bindings.interact=KEY_K
			await keypress(KEY_K)
			check(game.overlay=="homeland_dialog","Remapped interaction binding reaches the actual homeland point")
			await click(button("CLOSE [Esc]"))
			game.settings.bindings.interact=original_interact
		await capture("42-homeland-%s-%d.png" % [race,int(scale*100)])
		if race=="dwarf": await test_actor()
		if race=="fairy": await test_movement_and_save()
		await click(button("RAFDONIA"))
		check(game.sim.state.homeland.location.is_empty() and button("LANDS")!=null,"Actual return action restores city controls: "+race)
	check(game.sim.state.homeland.visited.size()==6,"All six visits share one campaign history")
	var operators: int=0
	for npc: Dictionary in game.sim.state.city_life.npcs.values():
		if not npc.has("companion_id"): operators+=1
	check(operators==12,"Homeland roles do not add fake companion operators to the existing city")

func test_actor() -> void:
	var recruit_id: String=""
	for id: String in game.sim.companion_defs:
		if game.sim.companion_defs[id].ancestry=="dwarf": recruit_id=id; break
	check(not recruit_id.is_empty() and game.sim.recruit(recruit_id).is_empty(),"Assisted setup recruits an actual generated Dwarf visitor")
	game.render(); await settle()
	var selector: OptionButton=null
	for candidate: Node in game.ui.find_children("*","OptionButton",true,false): selector=candidate; break
	check(selector!=null and selector.item_count==2,"Homeland actor selector includes the active party")
	await click(selector)
	check(selector.get_popup().visible,"Parsed actor control opens its real popup menu")
	var popup: PopupMenu=selector.get_popup()
	var before_position: Vector2i=game.homeland_view.player_cell
	for step: int in range(selector.item_count+1):
		if popup.get_focused_item()==selector.item_count-1: break
		await keypress(KEY_DOWN)
	check(popup.get_focused_item()==selector.item_count-1 and game.homeland_view.player_cell==before_position,"Popup navigation focuses the desired actor without moving the map visitor")
	await keypress(KEY_ENTER)
	check(game.sim.state.homeland.selected==game.sim.state.party[0].id,"Parsed actor dropdown selects the actual party member")
	check(game.homeland_view.hero.id==game.sim.state.party[0].id,"Selected party member becomes the visible visitor")
	await visit_point("dwarf_item_keeper")
	check(game.overlay=="homeland_dialog" and button("VIEW EQUIPMENT")!=null,"Dwarf artifact inspection exposes actual equipment navigation")
	await capture("43-forge-inspection-%d.png" % int(game.settings.text_scale*100))
	await click(button("CLOSE [Esc]"))

func test_movement_and_save() -> void:
	var view: Control=game.homeland_view
	var start: Vector2i=view.player_cell
	var direction: Vector2i=Vector2i.ZERO
	for candidate: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
		if view._walkable(start+candidate): direction=candidate; break
	check(direction!=Vector2i.ZERO,"Walking fixture has a legitimate adjacent tile")
	var key: int={Vector2i.RIGHT:KEY_D,Vector2i.LEFT:KEY_A,Vector2i.DOWN:KEY_S,Vector2i.UP:KEY_W}.get(direction,KEY_D)
	await keypress(key)
	check(game.homeland_view.player_cell==start+direction,"Parsed WASD moves exactly one walkable tile")
	var reverse: int={Vector2i.RIGHT:KEY_LEFT,Vector2i.LEFT:KEY_RIGHT,Vector2i.DOWN:KEY_UP,Vector2i.UP:KEY_DOWN}.get(direction,KEY_LEFT)
	await keypress(reverse)
	check(game.homeland_view.player_cell==start,"Arrow key returns exactly one tile without double input")
	var original: int=int(game.settings.bindings.east)
	if game.homeland_view._walkable(start+Vector2i.RIGHT):
		game.settings.bindings.east=KEY_L; await keypress(KEY_L)
		check(game.homeland_view.player_cell==start+Vector2i.RIGHT,"Remapped movement reaches the homeland controller")
		await joypress(JOY_BUTTON_DPAD_LEFT)
		check(game.homeland_view.player_cell==start,"Gamepad D-pad moves exactly one tile")
	game.settings.bindings.east=original
	var landing: Vector2i=start
	for cell: Vector2i in game.homeland_view.layout.walkable:
		if game.homeland_view.path_to(cell).size()>=4: landing=cell; break
	await click_point(game.homeland_view.global_position+game.homeland_view.cell_center(landing))
	check(not game.homeland_view._path.is_empty(),"Parsed ground click queues a real walk route")
	await keypress(KEY_P)
	check(game.overlay=="party","Character modal interrupts active homeland walking")
	var paused: Vector2i=game.homeland_view.player_cell
	for frame: int in range(30): await process_frame
	check(game.homeland_view.player_cell==paused and game.homeland_view._path.is_empty(),"Opening a modal clears the old route and freezes position")
	await click(button("CLOSE [Esc]"))
	await keypress(KEY_F5)
	var saved: Dictionary=Saves.load_campaign_slot(99)
	check(saved.ok,"Parsed F5 writes a healthy isolated slot99")
	if saved.ok:
		var saved_position: Vector2i=game.sim.homeland_position()
		check(game.sim.restore(saved.state),"Real disk snapshot restores through the actual save validator")
		game.overlay=""; game.render(); await settle()
		check(game.sim.state.homeland.location=="fairy" and game.homeland_view.player_cell==saved_position,"Reload redraws the same homeland at its recorded walking position")

func test_rites(scale: float) -> void:
	await fresh("barbarian",scale); await travel("barbarian")
	await visit_point("barbarian_shaman")
	check(game.overlay=="confirm" and game.confirm_text.contains("800") and not game.sim.hero().has("racial"),"Undying confirmation discloses its fee before mutation")
	var before: String=resources()
	await click(button("CANCEL"))
	check(resources()==before,"Cancelled homeland Undying preserves progression, currency and RNG")
	await keypress(KEY_E); await capture("43-undying-confirm-%d.png" % int(scale*100))
	await click(button("CONFIRM"))
	check(game.sim.hero().get("racial",{}).get("engraving_path","")=="undying" and game.sim.state.gold==9200,"Actual homeland confirmation purchases the permanent engraving once")
	await fresh("fairy",scale); await travel("fairy")
	await visit_point("fairy_tutor")
	check(game.overlay=="confirm" and game.confirm_text.contains("120") and game.confirm_text.contains("3 city days"),"Fairy homeland lesson discloses price and elapsed days")
	before=resources(); await click(button("CANCEL"))
	check(resources()==before and not game.sim.hero().has("spirit"),"Cancelled homeland lesson preserves resources and unset contract")
	await keypress(KEY_E); await click(button("CONFIRM"))
	check(game.sim.hero().has("spirit") and game.sim.state.gold==9880 and game.sim.state.day==4,"Actual Fairy teacher grants the supported contract through the normal command")
	await click(button("P")); await click(button("SPIRIT LIGHT"))
	check(game.sim.hero().spirit.active,"Character panel remains connected to actual spirit controls from homeland")
	await reveal(button("DISMISS FIRE SPIRIT")); await capture("43-fairy-contract-%d.png" % int(scale*100))
	await click(button("CLOSE [Esc]"))
	await fresh("beastman",scale)
	game.sim.add_item("frost_spirit_ring",1)
	check(game.sim.equip("frost_spirit_ring").is_empty(),"Assisted setup equips an owned ritual ring")
	await travel("beastman"); await visit_point("beastman_soul_keeper")
	check(game.overlay=="confirm" and game.confirm_text.contains("ALL WORN EQUIPMENT") and game.confirm_text.contains("Club"),"Homeland Skadia confirmation names actual destructive gear loss")
	before=resources(); await click(button("CANCEL"))
	check(resources()==before and not game.sim.hero().has("racial"),"Cancelled homeland Skadia preserves all equipment and unset contract")
	await keypress(KEY_E); await click(button("CONFIRM"))
	check(game.sim.hero().get("racial",{}).get("soul_beast","")=="skadia" and game.sim.hero().equipment.weapon.is_empty() and game.sim.hero().equipment.charm.is_empty(),"Actual homeland Skadia confirmation applies the real destructive ritual")

func test_creation(scale: float) -> void:
	for race: String in Catalog.ANCESTRIES:
		game.screen="create"; game.overlay=""; game.save_slot=99; game.settings.text_scale=scale
		game.new_name="Homeland creation fixture"; game.new_seed="74119"; game.render(); await settle()
		var name: String=GameContent.ancestries()[race].name
		await click(button(("> " if game.ancestry_id==race else "")+name))
		await click(button("BEGIN GAME"))
		if game.overlay=="confirm": await click(button("CONFIRM"))
		check(game.screen=="game" and game.sim.hero().ancestry==race and game.sim.state.homeland.location==race,"Actual BEGIN GAME starts the chosen race in its own explorable home: "+race)
		check(game.homeland_view.layout.id==race and game.save_slot==99,"Creation displays the correct map and preserves isolated save selection: "+race)

func test_choices(scale: float) -> void:
	await fresh("barbarian",scale); await travel("barbarian")
	await visit_point("barbarian_weapon_circle")
	check(game.overlay=="homeland_choice","Parsed weapon circle opens a choice instead of granting equipment")
	for id: String in ComingOfAgeRules.options():
		check(button(game.item_defs[id].name)!=null and not button(game.item_defs[id].name).disabled,"Every starting weapon has an available real choice")
	await capture("44-coming-of-age-%d.png" % int(scale*100))
	var before: String=resources()
	await click(button("Spear"))
	check(game.overlay=="confirm" and game.confirm_text.contains("starting club") and resources()==before,"Weapon preview explicitly reviews exchange before mutation")
	await click(button("CANCEL"))
	check(resources()==before,"Cancelling the weapon choice preserves equipment and one-time opportunity")
	await keypress(KEY_E); await click(button("Spear")); await click(button("CONFIRM"))
	check(game.sim.hero().equipment.weapon=="spear" and game.sim.state.flags.coming_of_age_complete,"Parsed confirmation commits actual opening weapon choice")
	await keypress(KEY_E)
	check(button("Club").disabled and button("Spear").disabled,"Completed ceremony cannot be repeated through the UI")
	await fresh("draconian",scale); await travel("draconian"); await visit_point("draconian_language_guide")
	check(game.overlay=="homeland_choice" and button("Blessing of the Sea Dragon").disabled,"Early visitor can inspect blessings while level requirement disables purchase")
	await click(button("CLOSE [Esc]"))
	game.sim.state.level=2; game.sim.recalculate(game.sim.hero(),false); game.sim.hero().energy=2
	await keypress(KEY_E)
	await capture("45-dragon-blessings-%d.png" % int(scale*100))
	before=resources(); await click(button("Blessing of the Sea Dragon"))
	check(game.overlay=="confirm" and game.confirm_text.contains("500") and resources()==before,"Blessing review discloses actual fee and does not charge early")
	await capture("46-dragon-confirm-%d.png" % int(scale*100))
	await click(button("CANCEL")); check(resources()==before,"Cancelled Dragon blessing preserves slot, resources and currency")
	await keypress(KEY_E); await click(button("Blessing of the Sea Dragon")); await click(button("CONFIRM"))
	check(game.sim.hero().get("dragon_blessing","")=="sea" and game.sim.state.gold==9500 and game.sim.hero().energy==2,"Parsed confirmation buys actual Sea blessing without resource refill")
	await keypress(KEY_E)
	check(button("Blessing of the Earth Dragon").disabled,"All alternate blessings lock after permanent choice")
