extends SceneTree

const MAP = preload("res://game/city_map.gd")
var checks: int = 0
var failures: int = 0
var map: Control
var events: Dictionary = {"place": "", "npc": ""}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame in range(3): await process_frame

func keypress(key: int) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = key; pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = key
	Input.parse_input_event(released)
	await settle()

func mouseclick(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.position = point; pressed.global_position = point
	pressed.button_index = MOUSE_BUTTON_LEFT; pressed.button_mask = MOUSE_BUTTON_MASK_LEFT; pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.position = point; released.global_position = point; released.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(released)
	await settle()

func _run() -> void:
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background := ColorRect.new()
	background.color = Color("080e11"); background.size = Vector2(640, 360); background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var title := Label.new()
	title.text = "RAFDONIA · DISTRICT 7"
	title.position = Vector2(12, 10)
	title.add_theme_font_override("font", load("res://assets/vt323.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ded8be"))
	root.add_child(title)
	map = MAP.new()
	var locations: Array[String] = ["inn", "market", "guild", "companions", "workshop", "sanctum", "portal", "market", "inn", "guild", "companions", "market"]
	var npcs: Array = []
	for index in range(12):
		npcs.append({"id": "town_%d" % index, "name": ["Innkeeper", "Merchant", "Clerk", "Scout", "Smith", "Herbalist", "Gate Guard", "Tailor", "Cook", "Scholar", "Veteran", "Appraiser"][index], "role": "townsperson", "ancestry": ["barbarian", "fairy", "dwarf", "human"][index % 4], "location_id": locations[index]})
	# Public contract also works when configured before entering the scene tree.
	map.configure({"npcs": npcs}, {"id": "hero", "name": "Adventurer", "ancestry": "barbarian"})
	root.add_child(map)
	map.position = Vector2(8, 44); map.size = Vector2(624, 306)
	map.location_selected.connect(func(id: String) -> void: events.place = id)
	map.npc_selected.connect(func(id: String) -> void: events.npc = id)
	await settle()
	check(map.location_buttons.size() == 8, "All eight service locations are integrated")
	check(map.npc_buttons.size() == 12, "Twelve named city NPCs get individual markers")
	for id: String in map.location_buttons:
		var button: Button = map.location_buttons[id]
		check(Rect2(0, 0, 624, 306).encloses(Rect2(button.position, button.size)), "Location fits local city bounds: " + id)
		check(button.focus_mode == Control.FOCUS_ALL, "Location supports native keyboard/controller focus: " + id)
		await mouseclick(button)
		check(events.place == id, "Actual mouse hotspot selects correct location: " + id)
	for id: String in map.npc_buttons:
		var button: Button = map.npc_buttons[id]
		for location: String in map.location_buttons:
			check(not Rect2(button.position, button.size).intersects(Rect2(map.location_buttons[location].position, map.location_buttons[location].size)), "NPC does not obscure service hotspot: %s/%s" % [id, location])
		await mouseclick(button)
		check(events.npc == id, "Actual mouse marker selects correct NPC: " + id)
	check(map.focus_location("inn"), "Parent can focus a stable location ID")
	await keypress(KEY_RIGHT)
	check(root.gui_get_focus_owner() == map.location_buttons.guild, "Right arrow navigates to authored neighbor")
	await keypress(KEY_ENTER)
	check(events.place == "guild", "Enter activates focused city location")
	await keypress(KEY_DOWN)
	check(root.gui_get_focus_owner() == map.location_buttons.market, "Down arrow reaches lower row")
	await keypress(KEY_DOWN)
	check(root.gui_get_focus_owner() == map.npc_buttons[map.npc_buttons.keys()[0]], "Native focus navigation reaches NPC markers")
	var direction := InputEventJoypadButton.new()
	direction.button_index = JOY_BUTTON_DPAD_RIGHT; direction.pressed = true
	Input.parse_input_event(direction)
	await process_frame
	var direction_release := InputEventJoypadButton.new()
	direction_release.button_index = JOY_BUTTON_DPAD_RIGHT
	Input.parse_input_event(direction_release)
	await settle()
	check(root.gui_get_focus_owner() == map.npc_buttons[map.npc_buttons.keys()[1]], "Controller D-pad navigates between NPC markers")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A; joy.pressed = true
	Input.parse_input_event(joy)
	await process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_A
	Input.parse_input_event(release)
	await settle()
	check(events.npc == str(map.npc_buttons.keys()[1]), "Controller A activates focused NPC")
	map.focus_location("portal")
	await settle()
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://verification")
		var path: String = ProjectSettings.globalize_path("res://verification/city-map.png")
		check(image != null and image.save_png(path) == OK, "Authored city fixture renders to a screenshot")
		print("CITY SCREENSHOT: " + path)
	print("CITY MAP: %d checks, %d failures. Authored geometry and native mouse/key/controller events; no service simulation claims." % [checks, failures])
	quit(0 if failures == 0 else 1)
