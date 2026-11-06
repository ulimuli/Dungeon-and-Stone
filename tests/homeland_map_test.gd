extends SceneTree
const Map = preload("res://game/homeland_map.gd")
const Catalog = preload("res://game/homeland_catalog.gd")
var checks: int = 0
var failures: int = 0
var map: Control
var received: String = ""
var exits: int = 0
var positions: Array[Vector2i] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame: int in range(3): await process_frame

func keypress(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new(); event.keycode = code
	Input.parse_input_event(event)
	await settle()

func click_cell(cell: Vector2i) -> void:
	var p: Vector2 = map.get_global_transform()*map.cell_center(cell)
	var motion := InputEventMouseMotion.new()
	motion.position = p; motion.global_position = p
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = p; event.global_position = p
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = p; event.global_position = p; event.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(event)
	await settle()

func reachable_cells(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start:true}
	var frontier: Array[Vector2i] = [start]
	var cursor: int = 0
	while cursor<frontier.size():
		var cell: Vector2i = frontier[cursor]; cursor += 1
		for direction: Vector2i in Map.DIRECTIONS:
			var next: Vector2i = cell+direction
			if map._walkable(next) and not seen.has(next): seen[next] = true; frontier.append(next)
	return seen

func wide_square(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1)]:
		if not map._walkable(cell+offset): return false
	return true

func wide_routes() -> Dictionary:
	var start := Vector2i(18,14)
	var seen: Dictionary = {}
	if not wide_square(start): return seen
	seen[start] = true
	var frontier: Array[Vector2i] = [start]
	var cursor: int = 0
	while cursor<frontier.size():
		var cell: Vector2i = frontier[cursor]; cursor += 1
		for direction: Vector2i in Map.DIRECTIONS:
			var next: Vector2i = cell+direction
			if not seen.has(next) and wide_square(next): seen[next] = true; frontier.append(next)
	return seen

func _run() -> void:
	root.size = Vector2i(640,360)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background := ColorRect.new()
	background.size = Vector2(640,360); background.color = Color("101c23")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var title := Label.new()
	title.position = Vector2(12,9)
	title.add_theme_font_override("font",load("res://assets/vt323.ttf"))
	title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("dacb9c"))
	root.add_child(title)
	map = Map.new()
	var hero: Dictionary = {"id":"test_visitor","name":"Visitor","ancestry":"barbarian"}
	map.configure(Catalog.definitions().barbarian,hero)
	root.add_child(map)
	map.position = Vector2(8,44); map.size = Vector2(624,306)
	map.interaction_requested.connect(func(id: String) -> void: received = id)
	map.position_changed.connect(func(cell: Vector2i) -> void: positions.append(cell))
	map.exit_requested.connect(func() -> void: exits += 1)
	await settle()
	check(map.layout.id == "barbarian","Catalog entries configure before tree without explicit ancestry wrapper")
	var fingerprints: Dictionary = {}
	var image_hashes: Dictionary = {}
	for race: String in Catalog.ANCESTRIES:
		var data: Dictionary = Catalog.definitions()[race]
		var snapshot: String = var_to_str(data)
		map.configure(data,hero)
		map.reduced_motion = true
		map.grab_focus()
		title.text = str(data.name).to_upper()+"    ·    VISITOR"
		await settle()
		check(map.layout.id == race and map.interaction_points.size() == 6,"Each ancestry selects its own layout and six exact catalog points: "+race)
		check(Map.layout_for(race).interactables.size() == 6,"Static layout includes catalog point placement metadata: "+race)
		check(var_to_str(Map.layout_for(race)) == var_to_str(Map.layout_for(race)),"Layout and point placement are deterministic: "+race)
		var geometry: Array = []
		for building: Dictionary in map.layout.buildings: geometry.append(building.rect)
		fingerprints[var_to_str([geometry,map.layout.slots])] = true
		var reachable: Dictionary = reachable_cells(map.layout.entrance)
		check(reachable.has(map.layout.exit),"Entrance connects to southern exit: "+race)
		for cell: Vector2i in map.layout.walkable:
			if map._walkable(cell): check(reachable.has(cell),"Every open cell is connected: %s %s" % [race,cell])
		var wide: Dictionary = wide_routes()
		check(wide.size()>70,"Main routes support a connected two-by-two clearance footprint: "+race)
		var used_cells: Dictionary = {}
		var ids: Dictionary = {}
		for point: Dictionary in map.interaction_points:
			check(not used_cells.has(point.cell) and not ids.has(point.id),"Interaction cells and catalog IDs are unique: "+point.id)
			used_cells[point.cell] = true; ids[point.id] = true
			check(not map._walkable(point.cell),"NPC/object cell cannot be walked through: "+point.id)
			check(Rect2(Vector2.ZERO,Vector2(624,272)).has_point(map.cell_center(point.cell)),"Interaction marker fits logical landscape: "+point.id)
			var approach := Vector2i(-1,-1)
			for direction: Vector2i in Map.DIRECTIONS:
				if reachable.has(point.cell+direction): approach = point.cell+direction; break
			check(approach != Vector2i(-1,-1),"Each catalog point has a reachable adjacent cell: "+point.id)
			var wide_near: bool = false
			for anchor: Vector2i in wide:
				if map._distance(anchor,point.cell)<=3: wide_near = true; break
			check(wide_near,"Broad main route reaches the interaction neighborhood: "+point.id)
			var path: Array[Vector2i] = map.path_to(approach)
			for step: Vector2i in path:
				check(map.move(step-map.player_cell),"Path takes valid cardinal steps: "+point.id)
			received = ""
			check(map.activate_nearby() and received == point.id,"Nearby interaction emits original catalog ID: "+point.id)
		check(var_to_str(data) == snapshot,"Configure, walking and interactions never mutate catalog records: "+race)
		map.configure(data,hero)
		map.grab_focus()
		await keypress(KEY_A)
		check(map.player_cell == Vector2i(18,15),"Actual focused WASD moves visitor: "+race)
		await keypress(KEY_RIGHT)
		check(map.player_cell == Vector2i(19,15),"Actual focused arrow moves visitor: "+race)
		await click_cell(Vector2i(16,15))
		for frame: int in range(5): map._process(0.1); await process_frame
		check(map.player_cell == Vector2i(16,15),"Actual mouse click walks a path over updates: "+race)
		map.configure(data,hero)
		map.grab_focus()
		var first: Dictionary = map.interaction_points[0]
		received = ""
		await click_cell(first.cell)
		for frame: int in range(80):
			if not received.is_empty(): break
			map._process(0.1); await process_frame
		check(received == first.id and map._distance(map.player_cell,first.cell) == 1,"Clicking distant resident approaches then emits interaction: "+race)
		received = ""
		await keypress(KEY_E)
		check(received == first.id,"Actual E interacts only with nearby resident: "+race)
		var here: Vector2i = map.player_cell
		map.configure(data,hero,here)
		check(map.player_cell == here,"Saved visitor position resumes unchanged: "+race)
		map.configure(data,hero,Vector2i(-100,-100))
		check(map.player_cell == map.layout.entrance,"Invalid saved position falls back to safe entrance: "+race)
		map.configure(data,hero,first.cell)
		check(map.player_cell == map.layout.entrance,"Occupied saved position falls back to safe entrance: "+race)
		map.grab_focus()
		if OS.get_cmdline_user_args().has("--capture"):
			await settle()
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			check(image != null and not image.is_empty(),"Actual rendered frame exists: "+race)
			if image != null and not image.is_empty():
				image_hashes[image.get_data().hex_encode().sha256_text()] = true
				DirAccess.make_dir_recursive_absolute("res://verification")
				var path: String = ProjectSettings.globalize_path("res://verification/homeland-"+race+".png")
				check(image.save_png(path) == OK,"Rendered homeland frame saves: "+race)
				print("HOMELAND FRAME: "+path)
	check(fingerprints.size() == 6,"Six maps have distinct authored scenery and silhouettes")
	var council: Array = Map.layout_for("beastman").buildings.filter(func(row: Dictionary) -> bool: return row.kind == "council")
	check(council.size() == 1 and council[0].rect == Rect2i(13,2,12,6),"Beastman site has one large central domed council, not offset repeated domes")
	check(Map.layout_for("draconian").buildings[0].kind == "dragon_temple" and Map.layout_for("fairy").buildings[0].kind == "ancient_tree","Dragon Temple and ancient-tree grove anchor separate authored geographies")
	if OS.get_cmdline_user_args().has("--capture"): check(image_hashes.size() == 6,"Six rendered homeland frames are visually distinct")
	map.configure(Catalog.definitions().barbarian,hero)
	map.grab_focus()
	await settle()
	var before: Vector2i = map.player_cell
	map.input_enabled = false
	await keypress(KEY_A)
	await click_cell(Vector2i(16,15))
	check(map.player_cell == before and not map.move(Vector2i.LEFT) and not map.activate_nearby(),"Disabled overlay map rejects keys, clicks, movement and activation")
	map.input_enabled = true
	var other := Button.new()
	other.text = "Other"; other.position = Vector2(500,4); other.size = Vector2(100,28)
	root.add_child(other); other.grab_focus()
	await keypress(KEY_A)
	check(map.player_cell == before,"Map does not steal keys from another focused control")
	map.grab_focus()
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_DPAD_LEFT; joy.pressed = true
	Input.parse_input_event(joy)
	await settle()
	check(map.player_cell == before+Vector2i.LEFT,"Controller D-pad walks the focused map")
	var joy_release := InputEventJoypadButton.new()
	joy_release.button_index = JOY_BUTTON_DPAD_LEFT
	Input.parse_input_event(joy_release)
	var count: int = exits
	await keypress(KEY_ESCAPE)
	check(exits == count+1,"Focused Escape requests return to parent")
	map.configure(Catalog.definitions().barbarian,hero)
	count = exits
	check(map.move(Vector2i.DOWN) and exits == count+1,"Walking through the authored exit requests return")
	check(not map.move(Vector2i.DOWN) and not map.move(Vector2i(1,1)),"Map rejects out-of-bounds and diagonal movement")
	map.configure(Catalog.definitions().barbarian,hero)
	map.reduced_motion = true; map.grab_focus()
	var clock: float = map._elapsed
	map._process(5)
	check(map._elapsed == clock,"Reduced motion freezes decorative animation")
	seed(9265); var expected: int = randi(); seed(9265)
	map.configure(Catalog.definitions().fairy,hero)
	Map.layout_for("dwarf")
	check(randi() == expected,"Layout and cosmetic NPC generation never consume simulation randomness")
	check(not positions.is_empty(),"Successful movement emits persistent position updates")
	print("HOMELAND MAP: %d checks, %d failures. Six connected authored layouts, exact catalog IDs, focused native input and optional rendered-frame capture." % [checks,failures])
	quit(1 if failures else 0)
