extends SceneTree

const MAIN = preload("res://main.tscn")
const WORLD = preload("res://game/world.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var files_before: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame: int in range(5): await process_frame

func keypress(key: int) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = key; pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = key
	Input.parse_input_event(released)
	await settle()

func point_mouse(point: Vector2) -> void:
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(point)
		await settle()
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	Input.parse_input_event(motion)
	await settle()

func click_point(point: Vector2) -> void:
	await point_mouse(point)
	var pressed := InputEventMouseButton.new()
	pressed.position = point; pressed.global_position = point; pressed.button_index = MOUSE_BUTTON_LEFT; pressed.button_mask = MOUSE_BUTTON_MASK_LEFT; pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.position = point; released.global_position = point; released.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(released)
	await settle()

func find_button(text: String) -> Button:
	for node: Node in game.ui.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func find_label(text: String) -> Label:
	for node: Node in game.ui.find_children("*", "Label", true, false):
		if node.text == text: return node
	return null

func _run() -> void:
	for path: String in ["user://settings.json", "user://saves/slot_96.json", "user://saves/slot_96.json.bak", "user://saves/slot_96.json.tmp"]:
		files_before[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	root.size = Vector2i(640,360)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate()
	root.add_child(game)
	game.save_slot = 96
	game.settings.fullscreen = false
	game.settings.text_scale = 1.0
	game.settings.reduced_motion = true
	game.settings.muted = true
	game.sim.new_campaign("Magic UI test", "barbarian", "adventurer", 74119)
	game.sim.state.gold = 1000 # Explicit recruitment fixture budget.
	check(game.sim.recruit("human_mage").is_empty(), "Actual main simulation recruits a generated human mage")
	check(game.sim.enter_region(1), "Actual main simulation enters expedition")
	game.sim.state.units = []
	for y: int in range(1,int(game.sim.state.map.height)-1):
		for x: int in range(1,int(game.sim.state.map.width)-1): game.sim.state.map.tiles[y][x] = WORLD.FLOOR
	game.sim.state.map.traps = []
	# Controlled spell arena uses ambient light; darkness has separate floor tests.
	game.sim.state.map.dark_outskirts_width=1
	game.sim.state.map.memorial_radius_estimate=1
	game.sim.hero().pos = Vector2i(8,8)
	var caster: Dictionary = game.sim.state.party[0]
	caster.pos = Vector2i(9,8); caster.behavior = "manual"; caster.ap = 2
	game.sim.hero().ap = 2
	var target: Dictionary = game.sim.spawn_enemy("canon_ghoul", Vector2i(12,8))
	target.hp = 1000; target.max_hp = 1000
	game.sim.state.selected = caster.id
	game.sim.state.combat = true
	game.sim.state.time = 0
	game.sim.update_visibility()
	game.screen = "game"; game.overlay = ""; game.render()
	await settle()
	var technique: Button = find_button("1 Ice Spear")
	check(technique != null and technique.is_visible_in_tree(), "Actual HUD displays Ice Spear technique button")
	if technique != null:
		check(technique.tooltip_text.contains("3 Mana") and technique.tooltip_text.contains("Range 5"), "Spell tooltip describes its mana cost and range")
		technique.grab_focus()
	await keypress(KEY_1)
	check(int(game.selected_ability) == 0 and game.sim.selected().id == caster.id, "Parsed 1 selects wizard technique despite GUI focus")
	check(find_label("TARGET: Ice Spear. Click a tile; Escape cancels.") != null, "Targeting instruction names selected spell")
	var point: Vector2 = game.tile_point(target.pos) + Vector2(8,8)
	await point_mouse(point)
	check(game.hovered == target.pos and game.MAP_RECT.has_point(point), "Parsed mouse points at visible enemy tile")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://screenshots")
		await game.capture("19-ice-spear-targeting.png")
		check(FileAccess.file_exists("res://screenshots/19-ice-spear-targeting.png"), "Rendered targeting screenshot captured")
	var mana: int = int(caster.mana)
	var sp: int = int(caster.energy)
	var hp: int = int(target.hp)
	await click_point(point)
	check(int(caster.mana) == mana - 3 and int(caster.energy) == sp, "Actual enemy mouse click consumes mana and leaves SP unchanged")
	check(int(target.hp) < hp and int(game.selected_ability) == -1 and game.sim.state.mode == "dungeon", "Mouse targeting resolves damage and returns to command mode")
	await _test_map_mouse_commands(caster, target)
	await _test_hud_and_status(caster)
	for path: String in files_before:
		var current: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		check(current == files_before[path], "UI spell test performs no save/settings writes: " + path)
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	await create_timer(0.12).timeout
	game.queue_free(); await settle()
	print("MAGIC SCENE UI: %d checks, %d failures. Parsed keyboard/mouse, actual scene geometry and graphical targeting capture when available." % [checks,failures])
	quit(1 if failures else 0)

func _test_hud_and_status(caster: Dictionary) -> void:
	var bounds := Rect2(0,0,640,360)
	for scale: float in [1.0,1.2]:
		game.settings.text_scale = scale
		game.overlay = ""; game.render(); await settle()
		var mana: Label = find_label("MANA")
		check(mana != null and mana.is_visible_in_tree(), "Wizard HUD uses MANA label at %.0f%%" % (scale*100))
		if mana != null:
			var bar: HBoxContainer = mana.get_parent()
			check(bounds.encloses(bar.get_global_rect()), "Mana bar stays inside logical viewport at %.0f%%" % (scale*100))
			check(find_label("%d/%d" % [caster.mana,caster.max_mana]) != null, "HUD shows valid current/max mana")
		var attack_line: Label = null
		var inventory_heading: Label = null
		for node: Node in game.ui.find_children("*", "Label", true, false):
			if node.text.begins_with("ATK "): attack_line = node
			if node.text.begins_with("INVENTORY "): inventory_heading = node
		check(attack_line != null and inventory_heading != null and attack_line.get_global_rect().end.y <= inventory_heading.global_position.y, "HUD stats do not overlap inventory at %.0f%%" % (scale*100))
		var technique: Button = find_button("1 Ice Spear")
		check(technique != null and bounds.encloses(technique.get_global_rect()), "Technique button fits viewport at %.0f%%" % (scale*100))
		for node: Node in game.ui.find_children("*", "Label", true, false):
			if not node.is_visible_in_tree() or node.global_position.x < 448: continue
			check(bounds.encloses(node.get_global_rect()), "Visible HUD label fits: " + str(node.text))
			check(node.size.y >= node.get_line_count() * node.get_line_height(), "HUD text has enough line height: " + str(node.text))
			check(not node.text.contains("nan") and not node.text.contains("-1/"), "HUD resource/stat label has valid values")
		game.selected_party = caster.id
		await keypress(KEY_P)
		check(game.overlay == "party", "Parsed P opens wizard status modal")
		var soul_power: Label = null
		var wizard_mana: Label = null
		for node: Node in game.ui.find_children("*", "Label", true, false):
			if node.global_position.x < 199 or node.global_position.x >= 440: continue
			if node.text == "SP": soul_power = node
			if node.text == "MANA": wizard_mana = node
		check(soul_power == null and wizard_mana != null and wizard_mana.is_visible_in_tree(), "Wizard status shows usable mana without an unused SP bar at %.0f%%" % (scale*100))
		check(find_label("Ice Spear / Mana") != null, "Status lists wizard's sourced spell and resource")
		var close: Button = find_button("CLOSE [Esc]")
		check(close != null and bounds.encloses(close.get_global_rect()), "Status close remains visible at %.0f%%" % (scale*100))
		await keypress(KEY_ESCAPE)
		check(game.overlay.is_empty(), "Escape closes status without triggering a save")

func _test_map_mouse_commands(caster: Dictionary, target: Dictionary) -> void:
	caster.ap = 2
	var hero: Dictionary = game.sim.hero()
	await click_point(game.tile_point(hero.pos) + Vector2(8,8))
	check(game.sim.selected().id == "hero", "Actual map click selects a friendly unit")
	target.pos = hero.pos + Vector2i.DOWN
	target.statuses = {"paralyzed":3}
	game.sim.update_visibility(); game.render(); await settle()
	var hp: int = int(target.hp)
	var condition: int = int(hero.durability)
	await click_point(game.tile_point(target.pos) + Vector2(8,8))
	check(int(target.hp) < hp and int(hero.durability) == condition - 1 and int(hero.ap) == 1, "Actual adjacent enemy map click performs exactly one normal attack")
	var origin: Vector2i = hero.pos
	await click_point(game.tile_point(origin + Vector2i.UP) + Vector2(8,8))
	check(hero.pos == origin + Vector2i.UP and int(hero.ap) == 0, "Actual adjacent empty map click moves once and spends one AP")
	game.sim.state.selected = caster.id
	game.render(); await settle()
