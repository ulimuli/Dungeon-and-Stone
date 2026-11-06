extends SceneTree

const MAIN = preload("res://main.tscn")
const CITY_MAP = preload("res://game/city_map.gd")
const ART = preload("res://game/character_art.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame in range(4): await process_frame

func keypress(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = key
	Input.parse_input_event(release)
	await settle()

func click(control: Control) -> void:
	var p: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = p; motion.global_position = p
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = p; event.global_position = p; event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventMouseButton.new()
	release.position = p; release.global_position = p; release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await settle()

func city() -> Control:
	for node: Node in game.ui.get_children():
		if node.get_script() == CITY_MAP: return node
	return null

func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func _run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "user://saves/slot_98.json" + suffix
		if FileAccess.file_exists(path): preserved[path] = FileAccess.get_file_as_bytes(path)
	root.size = Vector2i(640, 360); root.content_scale_size = Vector2i(640, 360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game)
	game.save_slot = 98
	game.settings.text_scale = 1.0
	game.settings.bindings = {"north": KEY_W, "south": KEY_S, "west": KEY_A, "east": KEY_D, "interact": KEY_E, "wait": KEY_SPACE, "inventory": KEY_I, "journal": KEY_J, "party": KEY_P, "camp": KEY_C}
	game.sim.new_campaign("City UI fixture", str(GameContent.ancestries().keys()[0]), str(GameContent.backgrounds().keys()[0]), 74119)
	game.screen = "game"; game.overlay = ""; game.render()
	await settle()
	check(city() != null and game.sim.state.mode == "city", "Actual main scene uses interactive city map")
	await _test_locations()
	await _test_city_keyboard_and_npcs()
	await _test_customization()
	await _test_portal_entry()
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	await create_timer(0.12).timeout
	game.queue_free(); await settle()
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "user://saves/slot_98.json" + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for path: String in preserved:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(preserved[path]); file.close()
	print("ACTUAL CITY UI: %d checks, %d failures. Real parsed input, actual services and isolated slot98; no human playtest claim." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_locations() -> void:
	for id: String in ["inn", "market", "companions", "workshop", "sanctum", "guild", "storage", "portal"]:
		var map: Control = city()
		if map == null: check(false, "City map exists before location " + id); return
		await click(map.location_buttons[id])
		check(game.city_location == id and game.overlay == ("inventory" if id == "storage" else "city_location"), "Main location click opens correct service modal: " + id)
		check(button("CLOSE [Esc]") != null, "Service modal has accessible Close: " + id)
		await keypress(KEY_ESCAPE)
		check(game.overlay.is_empty(), "Escape closes service modal: " + id)

func _test_city_keyboard_and_npcs() -> void:
	var map: Control = city()
	map.focus_location("inn")
	await keypress(KEY_RIGHT)
	check(root.gui_get_focus_owner() == map.location_buttons.guild, "Normal-city arrow input navigates map instead of dungeon commands")
	var time: int = int(game.sim.state.time)
	await keypress(KEY_SPACE)
	check(game.overlay == "city_location" and game.city_location == "guild" and int(game.sim.state.time) == time, "Normal-city Space activates location without advancing dungeon time")
	await keypress(KEY_ESCAPE)
	map = city()
	check(map.npc_buttons.has("innkeeper"), "City NPC roster is integrated into actual main map")
	if not map.npc_buttons.has("innkeeper"): return
	await click(map.npc_buttons.innkeeper)
	check(game.overlay == "npc" and game.selected_npc == "innkeeper", "Actual NPC click opens that NPC dialogue")
	var close: Button = button("CLOSE [Esc]")
	check(root.gui_get_focus_owner() == close, "NPC modal owns keyboard focus rather than city underlay")
	var underlay_events: Dictionary = {"count": 0}
	map = city()
	map.npc_selected.connect(func(_id: String) -> void: underlay_events.count += 1)
	if close != null: close.grab_focus()
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A; joy.pressed = true
	Input.parse_input_event(joy); await process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = JOY_BUTTON_A
	Input.parse_input_event(released); await settle()
	check(underlay_events.count == 0 and game.selected_npc == "innkeeper", "Background NPC does not steal controller A while modal owns focus")
	if not game.overlay.is_empty(): await keypress(KEY_ESCAPE)
	check(game.overlay.is_empty(), "NPC modal closes with Escape")

func _test_customization() -> void:
	# A deterministic UI fixture budget allows the real paid service to execute.
	if int(game.sim.state.gold) < 10: game.sim.state.gold = 10
	for scale: float in [1.0, 1.2]:
		game.settings.text_scale = scale
		game.begin_customization("hero")
		await settle()
		var apply: Button = button("APPLY / 5 ST")
		check(apply != null and Rect2(0, 0, 640, 360).encloses(apply.get_global_rect()), "Customization Apply is visible at %.0f%%" % (scale * 100))
		var count: int = 0
		for field: String in ART.options():
			var found: OptionButton = null
			for node: Node in game.ui.find_children("*", "Label", true, false):
				if node.text != field.replace("_", " ").capitalize(): continue
				for sibling: Node in node.get_parent().get_children():
					if sibling is OptionButton: found = sibling
			if found != null:
				count += 1
				print("CITY CUSTOM %.0f%% %s rect=%s" % [scale * 100, field, found.get_global_rect()])
				check(found.is_visible_in_tree() and Rect2(0, 0, 640, 360).encloses(found.get_global_rect()) and (apply == null or not found.get_global_rect().intersects(apply.get_global_rect())), "Choice visible without Apply overlap at %.0f%%: %s" % [scale * 100, field])
		check(count == 10, "All ten appearance choices exposed at %.0f%%" % (scale * 100))
		var before: Dictionary = game.appearance_draft.duplicate(true)
		var before_pixels: String = ART.portrait(game.appearance_preview_unit()).get_image().get_data().hex_encode().sha256_text()
		var randomize: Button = button("RANDOMIZE")
		check(randomize != null, "Customization has actual Randomize control")
		if randomize == null or apply == null: await keypress(KEY_ESCAPE); continue
		await click(randomize)
		check(game.appearance_draft != before and ART.portrait(game.appearance_preview_unit()).get_image().get_data().hex_encode().sha256_text() != before_pixels, "Actual customization input changes draft and preview pixels")
		var expected: Dictionary = game.appearance_draft.duplicate(true)
		var gold: int = int(game.sim.state.gold)
		apply = button("APPLY / 5 ST")
		await click(apply)
		check(game.overlay.is_empty() and game.sim.hero().appearance == expected and int(game.sim.state.gold) == gold - 5, "Actual Apply changes character appearance and charges exactly five stones")
		check(FileAccess.file_exists("user://saves/slot_98.json"), "Actual customization saves only to isolated internal slot98")
	game.settings.text_scale = 1.0
	game.render(); await settle()

func _test_portal_entry() -> void:
	var map: Control = city()
	if map == null: check(false, "City map remains after paid customization"); return
	await click(map.location_buttons.portal)
	check(game.overlay == "city_location" and game.city_location == "portal", "Actual portal location opens expedition preparation")
	var enter: Button = button("ENTER LABYRINTH")
	check(enter != null and enter.is_visible_in_tree(), "First monthly opening exposes actual Enter control")
	if enter != null:
		await click(enter)
		check(game.sim.state.mode == "dungeon" and game.overlay.is_empty(), "Actual Enter click starts reference dungeon expedition")
