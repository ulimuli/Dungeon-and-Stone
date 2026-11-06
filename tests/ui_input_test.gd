extends SceneTree

const MAIN = preload("res://main.tscn")
var checks: int = 0
var failures: int = 0
var game: Control
var settings_before: String = ""
var had_settings: bool = false

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for index in range(4): await process_frame

func keypress(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = key
	released.pressed = false
	Input.parse_input_event(released)
	await settle()

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.position = point
	pressed.global_position = point
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.button_mask = MOUSE_BUTTON_MASK_LEFT
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.position = point
	released.global_position = point
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	Input.parse_input_event(released)
	await settle()

func find_button(text: String) -> Button:
	for node: Node in game.ui.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func _run() -> void:
	had_settings = FileAccess.file_exists("user://settings.json")
	if had_settings: settings_before = FileAccess.get_file_as_string("user://settings.json")
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate()
	root.add_child(game)
	await settle()
	game.settings.text_scale = 1.0
	game.settings.fullscreen = false
	game.settings.bindings = {"north": KEY_W, "south": KEY_S, "west": KEY_A, "east": KEY_D, "interact": KEY_E, "wait": KEY_SPACE, "inventory": KEY_I, "journal": KEY_J, "party": KEY_P, "camp": KEY_C}
	game.sim.new_campaign("UI input test", "barbarian", "adventurer", 74119)
	check(game.sim.enter_region(1), "UI test fixture enters the reference dungeon")
	game.sim.state.units = [] # Isolated input fixture, no enemy/stat grants.
	game.sim.state.combat = false
	game.screen = "game"
	game.overlay = ""
	game.render()
	await settle()
	print("UI VIEWPORT: " + str(root.get_visible_rect()) + " root=" + str(game.size))
	await _test_movement()
	await _test_space_and_modal_keys()
	await _test_mouse_inventory()
	await _test_layout_and_close()
	await _test_font_and_log()
	check(FileAccess.file_exists("user://settings.json") == had_settings and (not had_settings or FileAccess.get_file_as_string("user://settings.json") == settings_before), "Input/layout tests leave persisted settings untouched")
	print("ACTUAL SCENE INPUT/LAYOUT: %d checks, %d failures. Parsed keyboard/mouse events and scene-tree geometry; not human or screenshot testing." % [checks, failures])
	# Let the asynchronous dummy audio mixer release its playback before exit.
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	await create_timer(0.12).timeout
	game.queue_free()
	await settle()
	quit(0 if failures == 0 else 1)

func _test_movement() -> void:
	var origin: Vector2i = game.sim.hero().pos
	var focus: Button = find_button("MAP")
	check(focus != null, "Dungeon has a real focusable map button")
	if focus != null: focus.grab_focus()
	await keypress(KEY_W)
	check(game.sim.hero().pos == origin + Vector2i.UP, "W moves despite focused GUI button")
	await keypress(KEY_S)
	check(game.sim.hero().pos == origin, "S returns one tile without double dispatch")
	await keypress(KEY_UP)
	check(game.sim.hero().pos == origin + Vector2i.UP, "Up arrow moves despite focused GUI button")
	await keypress(KEY_DOWN)
	check(game.sim.hero().pos == origin, "Down arrow returns one tile")
	game.settings.bindings.north = KEY_K # In-memory binding; never writes settings.
	await keypress(KEY_K)
	check(game.sim.hero().pos == origin + Vector2i.UP, "Injected remapping changes actual parsed-key movement")
	await keypress(KEY_DOWN)
	await keypress(KEY_W)
	check(game.sim.hero().pos == origin, "Replaced W binding no longer moves")
	await keypress(KEY_UP)
	check(game.sim.hero().pos == origin + Vector2i.UP, "Arrow fallback remains available after remapping")
	await keypress(KEY_DOWN)
	game.settings.bindings.north = KEY_W

func _test_space_and_modal_keys() -> void:
	var activations: Dictionary = {"count": 0}
	var focus: Button = find_button("MAP")
	focus.pressed.connect(func() -> void: activations.count += 1)
	focus.grab_focus()
	game.sim.state.combat = true
	var previous: int = int(game.sim.state.round)
	await keypress(KEY_SPACE)
	check(int(game.sim.state.round) == previous + 1, "Space ends exactly one combat round through actual input")
	check(activations.count == 0 and game.overlay.is_empty(), "Gameplay Space does not also activate focused GUI button")
	await keypress(KEY_I)
	check(game.overlay == "inventory", "I opens inventory through actual key input")
	await keypress(KEY_ESCAPE)
	check(game.overlay.is_empty(), "Escape closes inventory modal")
	await keypress(KEY_ESCAPE)
	check(game.overlay == "pause", "Escape opens pause when no modal is present")
	await keypress(KEY_ESCAPE)
	check(game.overlay.is_empty(), "Escape closes pause")

func _test_mouse_inventory() -> void:
	await keypress(KEY_I)
	var slot: Button = null
	for node: Node in game.ui.find_children("*", "Button", true, false):
		if node.text.is_empty() and int(node.custom_minimum_size.x) == 38 and node.tooltip_text.begins_with(str(game.item_defs.healing_potion.name)):
			slot = node
			break
	check(slot != null, "Inventory exposes real potion item-slot control")
	if slot != null:
		print("INVENTORY SLOT GEOMETRY: rect=%s path=%s" % [slot.get_global_rect(), slot.get_path()])
		await click(slot)
		check(game.inventory_selected == "healing_potion", "Actual mouse item-slot click selects potion details")
		var use: Button = find_button("USE")
		check(use != null, "Selected consumable exposes Use control")
		if use != null:
			game.sim.hero().hp = int(game.sim.hero().max_hp) - 25 # Isolated healing fixture.
			var count: int = int(game.sim.state.inventory.get("healing_potion", 0))
			var hp: int = int(game.sim.hero().hp)
			await click(use)
			check(int(game.sim.state.inventory.get("healing_potion", 0)) == count - 1 and int(game.sim.hero().hp) == hp + 24, "Actual Use click consumes potion and applies simulation healing")
	await keypress(KEY_ESCAPE)

func _test_layout_and_close() -> void:
	var bounds := Rect2(0, 0, 640, 360)
	for scale: float in [1.0, 1.2]:
		game.settings.text_scale = scale
		for overlay: String in ["settings", "inventory"]:
			game.overlay = overlay
			game.render()
			await settle()
			var close: Button = find_button("CLOSE [Esc]")
			check(close != null, "%s %.0f%% has Close button" % [overlay, scale * 100])
			if close == null: continue
			var rectangle: Rect2 = close.get_global_rect()
			print("CLOSE GEOMETRY %s %.0f%%: rect=%s min=%s visible=%s parent=%s" % [overlay, scale * 100, rectangle, close.get_combined_minimum_size(), close.is_visible_in_tree(), close.get_path()])
			check(close.is_visible_in_tree() and bounds.encloses(rectangle), "%s %.0f%% Close is visible and wholly inside logical viewport" % [overlay, scale * 100])
			await click(close)
			check(game.overlay.is_empty(), "%s %.0f%% Close is not occluded and responds to actual mouse click" % [overlay, scale * 100])
	game.settings.text_scale = 1.0
	game.overlay = ""
	game.render()
	await settle()

func _test_font_and_log() -> void:
	check(game.ui.theme.default_font == game.mono_font and game.ui.theme.default_font_size == 14, "Game theme uses VT323 monospaced font at default 14 logical pixels")
	var font_mismatches: int = 0
	for node: Node in game.ui.find_children("*", "Label", true, false):
		if node.get_theme_font("font") != game.mono_font: font_mismatches += 1
	check(font_mismatches == 0, "All dungeon labels inherit the cohesive monospaced game font")
	game.sim.say("UI LOG VISIBLE 012345")
	game.render()
	await settle()
	var log: Label = null
	for node: Node in game.ui.find_children("*", "Label", true, false):
		if node.text == "UI LOG VISIBLE 012345": log = node; break
	check(log != null, "Latest combat log text exists as a real label")
	if log != null:
		print("LOG GEOMETRY: rect=%s min=%s line_height=%d visible=%s text=%s" % [log.get_global_rect(), log.get_combined_minimum_size(), log.get_line_height(), log.is_visible_in_tree(), log.text])
		var ancestor: Node = log.get_parent()
		while ancestor is Control and ancestor != game:
			print("LOG ANCESTOR %s: rect=%s min=%s" % [ancestor.get_class(), ancestor.get_global_rect(), ancestor.get_combined_minimum_size()])
			ancestor = ancestor.get_parent()
		check(log.is_visible_in_tree() and log.size.y >= float(log.get_line_height()) and Rect2(0, 0, 640, 360).encloses(log.get_global_rect()), "Latest log line has visible height inside logical viewport")
