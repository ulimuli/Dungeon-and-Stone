extends SceneTree
## Actual graphical UI/input over assisted essence-drop fixtures.
## Internal slot96 and settings are preserved byte for byte.
const MAIN = preload("res://main.tscn")
const CITY_MAP = preload("res://game/city_map.gd")
const ESSENCE: String = "canon_goblin"
const EMPTY: String = "essence_test_tube"
const FILLED: String = "sealed_" + ESSENCE
const PATHS: Array[String] = ["user://settings.json","user://saves/slot_96.json","user://saves/slot_96.json.bak","user://saves/slot_96.json.tmp"]
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame: int in range(5): await process_frame

func keypress(key: int) -> void:
	var press := InputEventKey.new()
	press.keycode = key; press.pressed = true
	Input.parse_input_event(press); await process_frame
	var release := InputEventKey.new()
	release.keycode = key
	Input.parse_input_event(release); await settle()

func click(control: Control) -> void:
	if control == null: check(false,"Requested real mouse target exists"); return
	var point: Vector2 = control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await process_frame
	var press := InputEventMouseButton.new()
	press.position = point; press.global_position = point; press.button_index = MOUSE_BUTTON_LEFT; press.button_mask = MOUSE_BUTTON_MASK_LEFT; press.pressed = true
	Input.parse_input_event(press); await process_frame
	var release := InputEventMouseButton.new()
	release.position = point; release.global_position = point; release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release); await settle()

func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func prefix_button(prefix: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text.begins_with(prefix): return node
	return null

func label_containing(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text.contains(text): return node
	return null

func recipient() -> OptionButton:
	for node: Node in game.ui.find_children("*","OptionButton",true,false): return node
	return null

func city_map() -> Control:
	for node: Node in game.ui.get_children():
		if node.get_script() == CITY_MAP: return node
	return null

func resources() -> String:
	return var_to_str({"inventory":game.sim.state.inventory,"drops":game.sim.state.essence_drops,"time":game.sim.state.time,"hero":game.sim.hero(),"party":game.sim.state.party,"rng":str(game.sim.rng.state)})

func visible_control(control: Control, text: String) -> void:
	check(control != null,text + " exists")
	if control == null: return
	var visible: bool = control.is_visible_in_tree() and Rect2(0,0,640,360).encloses(control.get_global_rect())
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(control.get_global_rect()): visible = false
		ancestor = ancestor.get_parent()
	check(visible,text + " fits viewport and clipping ancestors")

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.capture(filename)
	check(FileAccess.file_exists("res://screenshots/" + filename),"Captured " + filename)

func _run() -> void:
	for path: String in PATHS: preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game)
	game.save_slot = 96
	game.settings.fullscreen = false; game.settings.text_scale = 1.0; game.settings.reduced_motion = true; game.settings.muted = true
	game.settings.bindings = {"north":KEY_W,"south":KEY_S,"west":KEY_A,"east":KEY_D,"interact":KEY_E,"wait":KEY_SPACE,"inventory":KEY_I,"journal":KEY_J,"party":KEY_P,"camp":KEY_C}
	game.sim.new_campaign("Preservation UI", "barbarian", "adventurer", 74119)
	game.screen = "game"; game.overlay = ""; game.render(); await settle()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	check(game.sim.companion_defs.size() == 12,"New campaign has twelve available generated adventurers")
	var map: Control = city_map()
	check(map != null,"Fresh campaign displays actual city map")
	if map != null:
		check(map.npc_buttons.size() == 12,"City displays only twelve service operators")
		var companion_marker: bool = false
		for id: String in map.npc_buttons:
			if id.begins_with("companion_"): companion_marker = true
		check(not companion_marker,"City map excludes companion figures while recruitment remains available")
		_test_city_marker_geometry(map)
		await capture("20-city-generated-adventurers.png")
		await click(map.location_buttons.companions)
		var joins: int = 0
		for node: Node in game.ui.find_children("*","Button",true,false):
			if node.text.begins_with("JOIN /"): joins += 1
		check(joins == 12,"Recruitment modal contains twelve real joining controls")
		await capture("21-generated-recruitment.png")
		await keypress(KEY_ESCAPE)
	# Assisted supplies/drop isolate confirmation behavior, not drop probability.
	game.sim.state.gold = 4000
	check(game.sim.recruit("human_mage").is_empty(),"Recruit real generated mage")
	check(game.sim.buy(EMPTY).is_empty(),"Purchase empty tube through actual market command")
	check(game.sim.enter_region(1),"Enter actual expedition")
	game.sim.state.units = []; game.sim.state.combat = false
	var mage: Dictionary = game.sim.state.party[0]
	mage.pos = game.sim.hero().pos + Vector2i.RIGHT
	game.sim.state.essence_drops = [{"id":ESSENCE,"pos":game.sim.hero().pos,"region":1,"expires_at":int(game.sim.state.time)+30}]
	game.sim._recount_essence_drops(); game.sim.update_visibility()
	game.selected_party = "hero"; game.overlay = "essences"; game.render(); await settle()
	await _test_recipient_dropdown(mage)
	await _test_sealing_confirmation(mage)
	# The actual closure/extraction command, with test-only food stock.
	game.sim.state.food = 100
	game.sim.advance_time(game.sim.portal_limit() - int(game.sim.state.time))
	game.overlay = ""; game.render(); await settle()
	check(game.sim.state.mode == "city" and int(game.sim.state.inventory.get(FILLED,0)) == 1,"Filled tube survives actual timed return to city")
	await _test_inventory_and_absorption()
	var saved: Dictionary = SaveStore.load_campaign_slot(96)
	check(saved.ok and saved.state.hero.essences.has(ESSENCE) and not saved.state.inventory.has(FILLED),"Confirmation saves absorbed essence and consumed container to isolated slot")
	await _cleanup()
	print("PRESERVATION SCENE UI: %d checks, %d failures. Actual parsed mouse/keyboard confirmation and recipient flow; assisted drop/supply fixtures, not a human playthrough." % [checks,failures])
	quit(1 if failures else 0)

func select_recipient(index: int) -> void:
	var choices: OptionButton = recipient()
	if choices == null: return
	await click(choices)
	var popup: PopupMenu = choices.get_popup()
	for step: int in range(choices.item_count + 1):
		if popup.get_focused_item() == index: break
		await keypress(KEY_DOWN)
	await keypress(KEY_ENTER)

func _test_city_marker_geometry(map: Control) -> void:
	var rectangles: Array[Rect2] = []
	var hero_rect := Rect2(Vector2(317,181) - Vector2(16,28),Vector2(32,32))
	for point: Vector2 in map._npc_positions:
		var rectangle := Rect2(point - Vector2(16,28),Vector2(32,32))
		check(Rect2(Vector2.ZERO,map.size).encloses(rectangle),"City NPC sprite lies entirely inside map")
		check(not rectangle.intersects(hero_rect),"City NPC sprite does not cover hero")
		for previous: Rect2 in rectangles:
			check(not rectangle.intersects(previous),"City NPC sprites have distinct nonoverlapping placement")
		rectangles.append(rectangle)

func _test_recipient_dropdown(mage: Dictionary) -> void:
	var choices: OptionButton = recipient()
	check(choices != null and choices.item_count == 2,"Essence recipient dropdown lists hero and mage")
	if choices == null: return
	await select_recipient(1)
	check(game.selected_party == mage.id,"Actual dropdown input selects mage recipient")
	check(label_containing("cannot absorb essences") != null,"Mage recipient explicitly displays zero absorption capacity")
	var absorb: Button = button("ABSORB")
	check(absorb != null and absorb.disabled,"Loose absorption button disabled for mage")
	choices = recipient()
	await select_recipient(0)
	check(game.selected_party == "hero","Actual dropdown input restores hero recipient")

func _test_sealing_confirmation(mage: Dictionary) -> void:
	for scale: float in [1.0,1.2]:
		game.settings.text_scale = scale
		game.overlay = "essences"; game.render(); await settle()
		var before: String = resources()
		await click(button("SEAL / " + str(mage.name)))
		check(game.overlay == "confirm","Mouse Seal opens explicit confirmation")
		check(game.confirm_text.contains("Consumes one test tube") and game.confirm_text.contains("15 minutes") and game.confirm_text.contains("survives extraction"),"Sealing confirmation explains cost, time and persistence")
		visible_control(button("CONFIRM"),"Seal Confirm %.0f%%" % (scale*100))
		visible_control(button("CANCEL"),"Seal Cancel %.0f%%" % (scale*100))
		await capture("22-seal-confirm-100.png" if scale == 1.0 else "23-seal-confirm-120.png")
		await keypress(KEY_ESCAPE)
		check(game.overlay.is_empty() and resources() == before,"Escape cancels seal without resource or clock changes")
	game.settings.text_scale = 1.0
	game.overlay = "essences"; game.render(); await settle()
	await click(button("SEAL / " + str(mage.name)))
	await click(button("CONFIRM"))
	check(game.overlay == "essences" and int(game.sim.state.inventory.get(FILLED,0)) == 1 and int(game.sim.state.inventory.get(EMPTY,0)) == 0,"Actual Confirm seals exactly one tube")
	check(game.sim.state.essence_drops.is_empty() and int(game.sim.state.time) == 15,"Confirmed sealing consumes physical drop and exactly fifteen minutes")

func _test_inventory_and_absorption() -> void:
	game.selected_party = "comp_nonexistent" # Regression: dismissed/dead selection must not survive into commands.
	await keypress(KEY_I)
	check(game.selected_party == "hero","Inventory normalizes stale recipient to living hero before commands")
	var choices: OptionButton = recipient()
	check(choices != null and choices.get_item_text(choices.selected) == str(game.sim.hero().name),"Inventory recipient display agrees with normalized command recipient")
	var slot: Button = null
	var name: String = str(game.item_defs[FILLED].name)
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text.is_empty() and int(node.custom_minimum_size.x) == 38 and node.tooltip_text.begins_with(name): slot = node; break
	visible_control(slot,"Filled tube inventory slot")
	if slot == null: return
	check(slot.tooltip_text.to_lower().contains("tube is destroyed"),"Filled tube tooltip explicitly explains container consumption")
	var icon_found: bool = false
	for child: Node in slot.get_children():
		if child is TextureRect and child.texture != null: icon_found = true
	check(icon_found,"Filled tube slot has an actual rendered icon texture")
	await click(slot)
	check(game.inventory_selected == FILLED,"Actual mouse item-slot selects filled tube")
	await capture("24-sealed-tube-inventory.png")
	for scale: float in [1.0,1.2]:
		game.settings.text_scale = scale
		game.overlay = "inventory"; game.render(); await settle()
		var before: String = resources()
		await click(button("ABSORB"))
		check(game.overlay == "confirm" and game.confirm_text.contains(str(game.sim.hero().name)),"Inventory Absorb confirms actual selected hero")
		check(game.confirm_text.contains("tube is destroyed") and game.confirm_text.contains("Permanent"),"Absorption confirmation explains permanent slot and tube destruction")
		visible_control(button("CONFIRM"),"Absorb Confirm %.0f%%" % (scale*100))
		visible_control(button("CANCEL"),"Absorb Cancel %.0f%%" % (scale*100))
		await capture("25-sealed-absorption-confirm-100.png" if scale == 1.0 else "26-sealed-absorption-confirm-120.png")
		await keypress(KEY_ESCAPE)
		check(game.overlay.is_empty() and resources() == before,"Escape cancels sealed absorption without consuming tube or slot")
	game.settings.text_scale = 1.0
	game.overlay = "inventory"; game.render(); await settle()
	await click(button("ABSORB")); await click(button("CONFIRM"))
	check(game.sim.hero().essences.has(ESSENCE),"Actual absorption Confirm applies essence to selected hero")
	check(int(game.sim.state.inventory.get(FILLED,0)) == 0 and int(game.sim.state.inventory.get(EMPTY,0)) == 0,"Actual absorption consumes container without empty refund")

func _cleanup() -> void:
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	await create_timer(0.12).timeout
	game.queue_free(); await settle()
	for path: String in PATHS:
		if preserved[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_buffer(preserved[path]); file.close()
		var current: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		check(current == preserved[path],"Restored original bytes: " + path)
