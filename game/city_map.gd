class_name CityMap
extends Control
## Authored native-resolution city art. This control only presents/selects places;
## the parent owns every service, conversation, purchase, and simulation change.
signal location_selected(id: String)
signal npc_selected(id: String)

const EXTENT := Vector2(624, 306)
const PLACE_ORDER: Array[String] = ["inn", "guild", "portal", "sanctum", "companions", "market", "workshop", "storage"]
const PLACES: Dictionary = {
	"inn": {"name": "Inn", "rect": Rect2(63, 64, 103, 80), "anchor": Vector2(114, 105)},
	"guild": {"name": "Explorers Guild", "rect": Rect2(196, 40, 79, 94), "anchor": Vector2(235, 91)},
	"portal": {"name": "Dimensional Square", "rect": Rect2(308, 72, 85, 87), "anchor": Vector2(351, 113)},
	"sanctum": {"name": "Apothecary", "rect": Rect2(531, 57, 66, 100), "anchor": Vector2(564, 107)},
	"companions": {"name": "Recruitment", "rect": Rect2(63, 202, 94, 62), "anchor": Vector2(110, 235)},
	"market": {"name": "Market", "rect": Rect2(181, 202, 109, 62), "anchor": Vector2(235, 232)},
	"workshop": {"name": "Blacksmith", "rect": Rect2(354, 207, 94, 58), "anchor": Vector2(400, 235)},
	"storage": {"name": "Storage", "rect": Rect2(525, 211, 74, 52), "anchor": Vector2(562, 237)},
}
const NPC_SPOTS: Array[Vector2] = [Vector2(172, 155), Vector2(286, 181), Vector2(421, 161), Vector2(170, 250), Vector2(451, 199), Vector2(526, 189), Vector2(306, 262), Vector2(76, 183), Vector2(388, 185), Vector2(141, 185), Vector2(276, 139), Vector2(573, 281)]
const GROUND := Color("252c2a")
const COBBLE := Color("49504b")
const MORTAR := Color("222a29")
const STONE := Color("72796b")
const STONE_LIT := Color("a0a28a")
const STONE_DARK := Color("3c4743")
const WOOD := Color("5b4937")
const WOOD_LIT := Color("9a7950")
const GOLD := Color("d7bd76")
const BLUE := Color("85c5cd")
const INK := Color("111b1d")

var city_state: Dictionary = {}
var hero: Dictionary = {}
var location_buttons: Dictionary = {}
var npc_buttons: Dictionary = {}
var _npcs: Array[Dictionary] = []
var _npc_textures: Dictionary = {}
var _npc_positions: Array[Vector2] = []
var _hero_texture: Texture2D
var _font: Font
var _hot_location: String = ""
var _hot_npc: String = ""
var _clock: float = 0.0
var _frame: int = 0
var _character_art: Script

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = load("res://assets/vt323.ttf")
	custom_minimum_size = EXTENT
	if ResourceLoader.exists("res://game/character_art.gd"):
		_character_art = load("res://game/character_art.gd")
	if not city_state.is_empty(): configure(city_state, hero)
	else: _rebuild_hotspots()

func configure(next_city_state: Dictionary, next_hero: Dictionary) -> void:
	city_state = next_city_state.duplicate(true)
	hero = next_hero.duplicate(true)
	_npcs.clear()
	_npc_textures.clear()
	for record: Variant in city_state.get("npcs", []):
		if record is Dictionary and not str(record.get("id", "")).is_empty():
			_npcs.append(record.duplicate(true))
	# Appearance textures are cosmetic and never consume simulation randomness.
	if _character_art != null:
		_hero_texture = _character_art.call("sprite", hero, 0, 0) as Texture2D
		for npc: Dictionary in _npcs:
			_npc_textures[str(npc.id)] = _character_art.call("sprite", npc, 0, 0)
	if is_inside_tree(): _rebuild_hotspots()
	queue_redraw()

func focus_location(id: String) -> bool:
	if not location_buttons.has(id): return false
	location_buttons[id].grab_focus()
	return true

func _rebuild_hotspots() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	location_buttons.clear()
	npc_buttons.clear()
	_place_npcs()
	for id: String in PLACE_ORDER:
		var button: Button = _hotspot(PLACES[id].rect, str(PLACES[id].name))
		button.name = "Place_" + id
		button.set_meta("location_id", id)
		button.pressed.connect(func() -> void: location_selected.emit(id))
		button.mouse_entered.connect(func() -> void: _hot_location = id; _hot_npc = ""; queue_redraw())
		button.mouse_exited.connect(func() -> void: if _hot_location == id: _hot_location = ""; queue_redraw())
		button.focus_entered.connect(func() -> void: _hot_location = id; _hot_npc = ""; queue_redraw())
		button.focus_exited.connect(func() -> void: if _hot_location == id: _hot_location = ""; queue_redraw())
		location_buttons[id] = button
	for index in range(_npcs.size()):
		var npc: Dictionary = _npcs[index]
		var id: String = str(npc.id)
		var foot: Vector2 = _npc_position(index)
		var title: String = str(npc.get("name", "Traveler"))
		var button: Button = _hotspot(Rect2(foot - Vector2(10, 26), Vector2(20, 30)), title)
		button.name = "NPC_" + str(index)
		button.set_meta("npc_id", id)
		button.pressed.connect(func() -> void: npc_selected.emit(id))
		button.mouse_entered.connect(func() -> void: _hot_npc = id; _hot_location = ""; queue_redraw())
		button.mouse_exited.connect(func() -> void: if _hot_npc == id: _hot_npc = ""; queue_redraw())
		button.focus_entered.connect(func() -> void: _hot_npc = id; _hot_location = ""; queue_redraw())
		button.focus_exited.connect(func() -> void: if _hot_npc == id: _hot_npc = ""; queue_redraw())
		npc_buttons[id] = button
	# A stable two-row tour works with the native keyboard/controller UI actions.
	for index in range(PLACE_ORDER.size()):
		var button: Button = location_buttons[PLACE_ORDER[index]]
		button.focus_neighbor_left = button.get_path_to(location_buttons[PLACE_ORDER[(index + 7) % 8]])
		button.focus_neighbor_right = button.get_path_to(location_buttons[PLACE_ORDER[(index + 1) % 8]])
		button.focus_neighbor_top = button.get_path_to(location_buttons[PLACE_ORDER[(index + 4) % 8]])
		button.focus_neighbor_bottom = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_right
		button.focus_previous = button.focus_neighbor_left
	if not npc_buttons.is_empty():
		var ids: Array = npc_buttons.keys()
		for index in range(ids.size()):
			var button: Button = npc_buttons[ids[index]]
			button.focus_neighbor_left = button.get_path_to(npc_buttons[ids[(index + ids.size() - 1) % ids.size()]])
			button.focus_neighbor_right = button.get_path_to(npc_buttons[ids[(index + 1) % ids.size()]])
			button.focus_neighbor_top = button.get_path_to(location_buttons["market"])
			button.focus_neighbor_bottom = button.get_path_to(location_buttons["portal"])
		var market: Button = location_buttons["market"]
		market.focus_neighbor_bottom = market.get_path_to(npc_buttons[ids[0]])
		market.focus_next = market.focus_neighbor_bottom
	var selected: String = str(city_state.get("selected_location", ""))
	if location_buttons.has(selected): _hot_location = selected

func _hotspot(rectangle: Rect2, title: String) -> Button:
	var button := Button.new()
	add_child(button)
	button.position = rectangle.position
	button.size = rectangle.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Labels are drawn once in map coordinates; native tooltips would duplicate.
	button.set_meta("hover_label", title)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return button

func _npc_position(index: int) -> Vector2:
	return _npc_positions[index] if index < _npc_positions.size() else NPC_SPOTS[index % NPC_SPOTS.size()]

func _place_npcs() -> void:
	_npc_positions.clear()
	var neighborhoods: Dictionary = {
		"inn": [Vector2(88, 174), Vector2(174, 177)],
		"guild": [Vector2(272, 163), Vector2(211, 163)],
		"portal": [Vector2(370, 194)],
		"sanctum": [Vector2(555, 192)],
		"companions": [Vector2(111, 194), Vector2(151, 194)],
		"market": [Vector2(195, 195), Vector2(235, 195), Vector2(277, 195)],
		"workshop": [Vector2(412, 198)],
		"storage": [Vector2(551, 204)],
	}
	var counts: Dictionary = {}
	for index in range(_npcs.size()):
		var npc: Dictionary = _npcs[index]
		var location: String = str(npc.get("location_id", npc.get("location", ""))).to_lower()
		var count: int = int(counts.get(location, 0))
		counts[location] = count + 1
		var options: Array = neighborhoods.get(location, [])
		var desired: Vector2 = options[count % options.size()] if not options.is_empty() else NPC_SPOTS[index % NPC_SPOTS.size()]
		var chosen: Vector2 = desired
		var found: bool = false
		# Search complete perimeter rings. A crowded recruitment corner must spill
		# into nearby streets, never fall back onto another person's marker.
		for radius: int in range(105):
			if found: break
			var offsets: Array[Vector2] = []
			if radius == 0: offsets.append(Vector2.ZERO)
			else:
				for edge: int in range(-radius, radius + 1):
					offsets.append(Vector2(edge, -radius))
					offsets.append(Vector2(edge, radius))
				for edge: int in range(-radius + 1, radius):
					offsets.append(Vector2(-radius, edge))
					offsets.append(Vector2(radius, edge))
			for offset: Vector2 in offsets:
				var candidate: Vector2 = desired + offset * 6
				if _marker_clear(candidate): chosen = candidate; found = true; break
		if not found: push_error("City map has no free placement for " + str(npc.id))
		_npc_positions.append(chosen)

func _marker_clear(foot: Vector2) -> bool:
	var rectangle := Rect2(foot - Vector2(16, 28), Vector2(32, 32))
	if rectangle.intersects(Rect2(Vector2(317, 181) - Vector2(18, 30), Vector2(36, 36))): return false
	if not Rect2(8, 8, 608, 290).encloses(rectangle): return false
	for place: Dictionary in PLACES.values():
		if rectangle.intersects(place.rect): return false
	for existing: Vector2 in _npc_positions:
		if rectangle.intersects(Rect2(existing - Vector2(18, 30), Vector2(36, 36))): return false
	return true

func _process(delta: float) -> void:
	_clock += delta
	var next: int = int(_clock * 4.0)
	if next != _frame:
		_frame = next
		queue_redraw()

func _input(event: InputEvent) -> void:
	# Explicit gamepad support also works when a project has customized ui_accept.
	if not is_visible_in_tree() or not event is InputEventJoypadButton or not event.pressed: return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not focused is Button or not is_ancestor_of(focused): return
	var next: NodePath
	match event.button_index:
		JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
			return
		JOY_BUTTON_DPAD_LEFT: next = focused.focus_neighbor_left
		JOY_BUTTON_DPAD_RIGHT: next = focused.focus_neighbor_right
		JOY_BUTTON_DPAD_UP: next = focused.focus_neighbor_top
		JOY_BUTTON_DPAD_DOWN: next = focused.focus_neighbor_bottom
		_: return
	if not next.is_empty():
		var target: Node = focused.get_node_or_null(next)
		if target is Control: target.grab_focus()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	_ground()
	_roads()
	_canal()
	_walls()
	_plaza()
	_inn()
	_guild()
	_sanctum()
	_company()
	_market()
	_workshop()
	_storehouse()
	_dressing()
	_draw_people()
	if not _hot_location.is_empty(): _place_focus(_hot_location)
	if not _hot_npc.is_empty():
		for index in range(_npcs.size()):
			if str(_npcs[index].id) == _hot_npc:
				var foot: Vector2 = _npc_position(index)
				_marker(foot - Vector2(0, 33), GOLD)
				_caption(str(_npcs[index].get("name", "Traveler")), foot - Vector2(0, 39))
	draw_rect(Rect2(1, 1, 622, 304), Color("101a1b"), false, 2)
	draw_rect(Rect2(3, 3, 618, 300), Color("56605a"), false, 1)

func _ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, EXTENT), Color("17231f"))
	for y in range(4, 304, 6):
		for x in range(4, 624, 8):
			var noise: int = _noise(x, y)
			var color := Color("27352a") if noise % 5 == 0 else Color("202d25")
			draw_rect(Rect2(x, y, 6, 4), color)
	draw_rect(Rect2(35, 36, 554, 240), GROUND)
	for y in range(39, 274, 9):
		for x in range(39, 588, 11):
			if _noise(x, y) % 4 == 0: draw_rect(Rect2(x, y, 3, 1), Color("3b4135"))

func _roads() -> void:
	_road(Rect2(45, 152, 552, 38))
	_road(Rect2(293, 34, 43, 267))
	_road(Rect2(105, 122, 25, 107))
	_road(Rect2(221, 112, 24, 109))
	_road(Rect2(386, 170, 24, 72))
	_road(Rect2(550, 125, 23, 120))
	_road(Rect2(99, 244, 307, 21))

func _road(rectangle: Rect2) -> void:
	draw_rect(rectangle.grow(2), Color("1e2726"))
	draw_rect(rectangle, Color("3b413d"))
	for y in range(int(rectangle.position.y) + 2, int(rectangle.end.y) - 2, 6):
		var shift: int = 4 if y % 12 < 6 else 0
		for x in range(int(rectangle.position.x) + 2 + shift, int(rectangle.end.x) - 6, 9):
			var noise: int = _noise(x, y)
			var color: Color = [Color("4b5148"), Color("414942"), Color("50574c"), Color("39443d")][noise % 4]
			draw_rect(Rect2(x, y, 7, 4), color)
			if noise % 7 == 0: draw_rect(Rect2(x + 1, y, 4, 1), Color("606454"))

func _canal() -> void:
	draw_rect(Rect2(473, 19, 42, 268), Color("101d22"))
	draw_rect(Rect2(478, 19, 32, 268), Color("203d45"))
	for y in range(23, 284, 8):
		var x: int = 481 + _noise(y, 31) % 20
		draw_rect(Rect2(x, y, 5 + _noise(y, 19) % 9, 1), Color("467075"))
		if y % 3 == 0: draw_rect(Rect2(x - 1, y + 3, 8, 1), Color("2d555e"))
	_stone_rect(Rect2(469, 20, 8, 266))
	_stone_rect(Rect2(511, 20, 8, 266))
	# Broad timber bridge: readable as the city's main east-west crossing.
	draw_rect(Rect2(465, 153, 58, 40), Color("172326"))
	draw_rect(Rect2(466, 153, 56, 34), WOOD)
	for x in range(468, 521, 5):
		draw_rect(Rect2(x, 155, 3, 29), Color("8b7958"))
		draw_rect(Rect2(x, 162, 3, 1), Color("a3936a"))
	for y in [151, 185]:
		draw_rect(Rect2(464, y, 61, 3), Color("c0ac7b"))
		for x in [465, 478, 510, 522]: draw_rect(Rect2(x, y - 2, 3, 7), WOOD_LIT)
	# A handcart-sized footbridge links the warehouse quay.
	draw_rect(Rect2(468, 259, 56, 13), WOOD)
	for x in range(470, 522, 4): draw_rect(Rect2(x, 260, 2, 10), Color("968060"))

func _walls() -> void:
	_stone_rect(Rect2(21, 18, 582, 17))
	_stone_rect(Rect2(21, 27, 16, 257))
	_stone_rect(Rect2(587, 27, 16, 257))
	_stone_rect(Rect2(23, 278, 270, 15))
	_stone_rect(Rect2(337, 278, 265, 15))
	for x in range(23, 603, 12):
		draw_rect(Rect2(x, 13, 7, 8), STONE)
		draw_rect(Rect2(x, 13, 7, 2), STONE_LIT)
		if x < 288 or x > 337: draw_rect(Rect2(x, 275, 7, 7), STONE_LIT.darkened(0.15))
	for y in range(35, 281, 12):
		draw_rect(Rect2(17, y, 6, 7), STONE)
		draw_rect(Rect2(602, y, 5, 7), STONE)
	for p: Vector2 in [Vector2(18, 14), Vector2(581, 14), Vector2(18, 268), Vector2(581, 268)]:
		draw_rect(Rect2(p + Vector2(4, 6), Vector2(26, 27)), Color("172022"))
		_stone_rect(Rect2(p, Vector2(26, 26)))
		draw_rect(Rect2(p + Vector2(4, 4), Vector2(18, 17)), Color("343f3d"))
		for x in range(0, 27, 9): draw_rect(Rect2(p + Vector2(x, -3), Vector2(6, 7)), STONE_LIT)
	# Gate pillars frame the road instead of blocking it.
	_stone_rect(Rect2(282, 270, 13, 30))
	_stone_rect(Rect2(335, 270, 13, 30))
	_torch(Vector2(288, 274)); _torch(Vector2(341, 274))

func _plaza() -> void:
	_octagon(Vector2(350, 115), 47, Color("1b2528"))
	_octagon(Vector2(350, 112), 44, Color("68736a"))
	_octagon(Vector2(350, 112), 40, Color("343f3d"))
	for offset in [-31, -19, -7, 5, 17, 29]:
		draw_line(Vector2(316, 112 + offset), Vector2(384, 112 + offset), Color("4d5b53"), 1)
		draw_line(Vector2(350 + offset, 78), Vector2(350 + offset, 146), Color("45534d"), 1)
	_octagon(Vector2(350, 114), 29, Color("182b32"))
	_octagon(Vector2(350, 114), 24, Color("294a52"))
	# Carved runic ring and stepped portal arch; no blended particle cloud.
	for offset: Vector2 in [Vector2(-20, -13), Vector2(18, -13), Vector2(-25, 3), Vector2(23, 3), Vector2(-14, 21), Vector2(12, 21)]:
		draw_rect(Rect2(Vector2(349, 111) + offset, Vector2(3, 3)), BLUE)
	_stone_rect(Rect2(329, 81, 9, 43)); _stone_rect(Rect2(363, 81, 9, 43))
	_stone_rect(Rect2(335, 73, 31, 10))
	_stone_rect(Rect2(341, 68, 19, 7))
	draw_rect(Rect2(339, 84, 23, 37), Color("0b1922"))
	draw_rect(Rect2(342, 86, 17, 32), Color("1e5869"))
	draw_rect(Rect2(347, 84, 6, 37), Color("7bbac1") if _frame % 3 == 0 else Color("58939f"))
	draw_rect(Rect2(343, 97, 15, 3), Color("7caeb5"))
	draw_rect(Rect2(330, 126, 40, 4), STONE)
	draw_rect(Rect2(325, 131, 50, 4), STONE_LIT.darkened(0.18))
	for p: Vector2 in [Vector2(310, 93), Vector2(391, 93), Vector2(318, 146), Vector2(384, 146)]: _torch(p)

func _inn() -> void:
	_house(Rect2(72, 74, 85, 60), Color("754c42"), Color("b3a180"))
	_house(Rect2(70, 59, 36, 39), Color("83594b"), Color("a79b79"))
	_chimney(Vector2(132, 67), true)
	# Warm glazing, wrought sign, and benches tell the inn apart at map scale.
	_window(Vector2(81, 113), true); _window(Vector2(137, 113), true)
	draw_rect(Rect2(156, 91, 2, 28), Color("35342b"))
	draw_rect(Rect2(156, 91, 14, 2), WOOD_LIT)
	draw_rect(Rect2(161, 96, 14, 17), WOOD)
	draw_rect(Rect2(164, 100, 8, 2), GOLD)
	draw_rect(Rect2(164, 102, 2, 6), GOLD)
	draw_rect(Rect2(169, 102, 3, 4), GOLD)
	_bench(Vector2(79, 142)); _bench(Vector2(139, 142))

func _guild() -> void:
	_house(Rect2(202, 61, 65, 64), Color("4e6464"), Color("8d9484"))
	_stone_rect(Rect2(222, 43, 24, 34))
	draw_rect(Rect2(220, 41, 28, 6), Color("3b5558"))
	draw_rect(Rect2(225, 36, 18, 6), Color("617c77"))
	draw_rect(Rect2(230, 25, 2, 14), WOOD_LIT)
	draw_rect(Rect2(232, 26, 14, 9), Color("a3915f"))
	draw_rect(Rect2(232, 26, 3, 9), Color("d1be7f"))
	_window(Vector2(228, 52), false)
	for x in [206, 254]:
		draw_rect(Rect2(x, 98, 7, 22), Color("93754f"))
		draw_rect(Rect2(x + 2, 101, 3, 12), GOLD)
	_stone_rect(Rect2(217, 126, 36, 5))
	_stone_rect(Rect2(214, 131, 42, 4))
	# Notice board beside the steps.
	draw_rect(Rect2(268, 115, 16, 20), WOOD)
	draw_rect(Rect2(271, 118, 10, 12), Color("bcaf83"))
	draw_rect(Rect2(272, 121, 6, 1), WOOD)

func _sanctum() -> void:
	_house(Rect2(536, 89, 53, 61), Color("456b61"), Color("999b86"))
	_house(Rect2(550, 64, 24, 49), Color("4c776d"), Color("939b8b"))
	draw_rect(Rect2(560, 48, 3, 17), Color("a4aaa0"))
	draw_rect(Rect2(554, 54, 15, 3), Color("a4aaa0"))
	_window(Vector2(557, 79), true)
	draw_rect(Rect2(556, 126, 12, 17), Color("233334"))
	draw_rect(Rect2(559, 129, 6, 10), Color("6aa7a1"))
	_stone_rect(Rect2(543, 150, 39, 5))
	_tree(Vector2(528, 61), 0); _tree(Vector2(592, 180), 1)

func _company() -> void:
	_house(Rect2(70, 210, 78, 43), Color("5a6552"), Color("93896d"))
	for x in [68, 146]:
		draw_rect(Rect2(x, 203, 2, 21), WOOD_LIT)
		draw_rect(Rect2(x + 2, 204, 9, 12), Color("8b8259"))
	# Practice yard: spear rack, training dummy, and a gathering table.
	for x in [80, 86, 92]:
		draw_rect(Rect2(x, 196, 1, 14), Color("c3bea0"))
		draw_rect(Rect2(x - 1, 194, 3, 3), STONE_LIT)
	draw_rect(Rect2(78, 203, 17, 2), WOOD)
	draw_rect(Rect2(123, 191, 2, 15), WOOD_LIT)
	draw_rect(Rect2(118, 195, 12, 7), Color("aa9270"))
	draw_rect(Rect2(121, 188, 6, 6), Color("b09c70"))

func _market() -> void:
	# The open market is made of stalls, not a single warehouse silhouette.
	for data: Array in [[Vector2(187, 208), Color("8b5149")], [Vector2(238, 208), Color("677b60")], [Vector2(210, 243), Color("a08b58")]]:
		var p: Vector2 = data[0]
		var color: Color = data[1]
		draw_rect(Rect2(p + Vector2(3, 5), Vector2(42, 27)), Color("192223"))
		draw_rect(Rect2(p + Vector2(2, 17), Vector2(39, 12)), WOOD)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(41, 19)), color)
		for x in range(1, 41, 10): draw_rect(Rect2(p + Vector2(x, 1), Vector2(5, 19)), color.lightened(0.22))
		draw_rect(Rect2(p + Vector2(1, 16), Vector2(41, 4)), color.darkened(0.16))
		for x in [3, 38]: draw_rect(Rect2(p + Vector2(x, 17), Vector2(2, 14)), WOOD_LIT)
		for x in [9, 18, 27]: draw_rect(Rect2(p + Vector2(x, 22), Vector2(5, 4)), [Color("b6a25c"), Color("a15d49"), Color("698461")][x / 9 - 1])
	_crates(Vector2(182, 243)); _barrel(Vector2(278, 240))

func _workshop() -> void:
	_house(Rect2(362, 217, 78, 43), Color("605a51"), Color("8e8870"))
	_chimney(Vector2(414, 204), true)
	draw_rect(Rect2(366, 243, 18, 15), Color("202329"))
	draw_rect(Rect2(370, 245, 9, 11), Color("bd6940"))
	draw_rect(Rect2(373, 247, 4, 8), Color("e6b563") if _frame % 2 == 0 else Color("d78b47"))
	draw_rect(Rect2(395, 264, 6, 4), WOOD)
	draw_rect(Rect2(389, 259, 18, 4), Color("8a9188"))
	draw_rect(Rect2(393, 256, 10, 4), Color("b4b3a1"))
	# Alchemical bottles under the side awning.
	draw_rect(Rect2(443, 230, 20, 4), Color("718065"))
	draw_rect(Rect2(445, 245, 16, 4), WOOD)
	for x in [446, 452, 458]:
		draw_rect(Rect2(x, 238, 3, 7), BLUE if x == 452 else Color("8da468"))
		draw_rect(Rect2(x + 1, 236, 1, 2), GOLD)
	_barrel(Vector2(351, 255))

func _storehouse() -> void:
	_house(Rect2(532, 215, 61, 43), Color("686858"), Color("8a8e75"))
	draw_rect(Rect2(550, 241, 22, 16), Color("3f3a2c"))
	for x in [551, 558, 565, 572]: draw_rect(Rect2(x, 243, 1, 13), WOOD_LIT)
	_crates(Vector2(520, 243)); _barrel(Vector2(579, 266)); _barrel(Vector2(589, 263))
	# Moored narrowboat and dock ropes.
	draw_rect(Rect2(489, 226, 12, 26), Color("111d23"))
	draw_rect(Rect2(487, 230, 13, 18), Color("826345"))
	draw_rect(Rect2(490, 233, 7, 12), Color("3a352b"))
	draw_line(Vector2(499, 234), Vector2(512, 230), Color("af9a6b"), 1)

func _dressing() -> void:
	for p: Vector2 in [Vector2(48, 53), Vector2(47, 116), Vector2(183, 53), Vector2(434, 53), Vector2(450, 120), Vector2(53, 259), Vector2(454, 276)]: _tree(p, int(p.x) % 2)
	for p: Vector2 in [Vector2(182, 143), Vector2(286, 200), Vector2(425, 190), Vector2(525, 195)]: _torch(p)
	for p: Vector2 in [Vector2(189, 183), Vector2(448, 136), Vector2(536, 162)]: _bench(p)
	for p: Vector2 in [Vector2(162, 73), Vector2(440, 209), Vector2(91, 259)]: _barrel(p)
	# Rain gutter and tiny flowers break up straight foundations.
	for x in range(53, 448, 15):
		if _noise(x, 17) % 3 == 0:
			draw_rect(Rect2(x, 271, 3, 2), Color("777d50"))
			draw_rect(Rect2(x + 2, 269, 2, 2), Color("c4b67c"))

func _house(rectangle: Rect2, roof: Color, plaster: Color) -> void:
	var x: int = int(rectangle.position.x)
	var y: int = int(rectangle.position.y)
	var w: int = int(rectangle.size.x)
	var h: int = int(rectangle.size.y)
	var rh: int = maxi(22, int(h * 0.65))
	draw_rect(Rect2(x + 4, y + 8, w + 5, h + 3), Color("152021"))
	_stone_rect(Rect2(x - 1, y + h - 10, w + 2, 14))
	draw_rect(Rect2(x + 3, y + rh - 1, w - 6, h - rh + 9), plaster.darkened(0.22))
	for beam_x in [x + 5, x + w / 2, x + w - 8]: draw_rect(Rect2(beam_x, y + rh, 3, h - rh + 6), WOOD)
	draw_rect(Rect2(x + 3, y + h - 6, w - 6, 3), WOOD)
	draw_rect(Rect2(x + w / 2 - 5, y + h - 11, 10, 13), Color("343b31"))
	draw_rect(Rect2(x + w / 2 + 1, y + h - 8, 1, 2), GOLD)
	draw_rect(Rect2(x - 3, y + 9, w + 6, rh - 2), roof.darkened(0.18))
	var ridge: PackedVector2Array = [Vector2(x - 3, y + 9), Vector2(x + w / 2, y), Vector2(x + w + 3, y + 9)]
	draw_colored_polygon(ridge, roof.lightened(0.12))
	for row_y in range(y + 12, y + rh + 5, 5):
		draw_line(Vector2(x - 2, row_y), Vector2(x + w + 2, row_y), roof.darkened(0.28), 1)
		for tile_x in range(x + ((row_y / 5) % 2) * 4, x + w, 8):
			draw_rect(Rect2(tile_x, row_y - 3, 1, 3), roof.lightened(0.08))
	draw_line(Vector2(x - 4, y + 9), Vector2(x + w / 2, y - 1), roof.lightened(0.38), 1)
	draw_line(Vector2(x + w / 2, y - 1), Vector2(x + w + 4, y + 9), roof.lightened(0.25), 1)
	draw_rect(Rect2(x - 4, y + rh + 4, w + 8, 3), roof.darkened(0.4))
	if w > 40:
		_window(Vector2(x + 9, y + h - 12), false)
		_window(Vector2(x + w - 18, y + h - 12), false)

func _stone_rect(rectangle: Rect2) -> void:
	draw_rect(rectangle, STONE_DARK)
	for y in range(int(rectangle.position.y), int(rectangle.end.y) - 1, 5):
		for x in range(int(rectangle.position.x) - ((y / 5) % 2) * 4, int(rectangle.end.x), 9):
			var start: float = maxf(x, rectangle.position.x)
			var end: float = minf(x + 8, rectangle.end.x)
			if end > start: draw_rect(Rect2(start, y, end - start, minf(4, rectangle.end.y - y)), STONE if _noise(x, y) % 3 else STONE.darkened(0.15))
	draw_line(rectangle.position, rectangle.position + Vector2(rectangle.size.x - 1, 0), STONE_LIT, 1)

func _tree(p: Vector2, variant: int) -> void:
	draw_rect(Rect2(p + Vector2(-10, 4), Vector2(24, 12)), Color("17211e"))
	draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 16)), WOOD)
	var green: Color = Color("41563a") if variant == 0 else Color("4c5b3d")
	for part: Rect2 in [Rect2(-9, -13, 18, 19), Rect2(-15, -8, 29, 12), Rect2(-5, -18, 12, 13)]: draw_rect(Rect2(p + part.position, part.size), green.darkened(0.18))
	for offset: Vector2 in [Vector2(-8, -12), Vector2(2, -17), Vector2(-13, -5), Vector2(2, -4)]:
		draw_rect(Rect2(p + offset, Vector2(9, 6)), green)
		draw_rect(Rect2(p + offset + Vector2(1, 0), Vector2(5, 2)), green.lightened(0.15))

func _window(p: Vector2, warm: bool) -> void:
	draw_rect(Rect2(p - Vector2.ONE, Vector2(10, 9)), WOOD.darkened(0.3))
	draw_rect(Rect2(p, Vector2(8, 7)), Color("d5aa67") if warm else Color("47656a"))
	draw_rect(Rect2(p + Vector2(3, 0), Vector2(1, 7)), WOOD)
	draw_rect(Rect2(p + Vector2(0, 3), Vector2(8, 1)), WOOD)

func _chimney(p: Vector2, smoke: bool) -> void:
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(10, 18)), Color("25302d"))
	_stone_rect(Rect2(p, Vector2(10, 17)))
	draw_rect(Rect2(p + Vector2(-2, -2), Vector2(14, 4)), STONE_LIT)
	draw_rect(Rect2(p + Vector2(1, -1), Vector2(8, 2)), Color("2a2b29"))
	if smoke:
		var shift: int = (_frame / 2) % 3
		draw_rect(Rect2(p + Vector2(2 + shift, -9), Vector2(7, 5)), Color("777f73"))
		draw_rect(Rect2(p + Vector2(6 + shift, -16), Vector2(8, 5)), Color("5c6a61"))

func _torch(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-6, -1), Vector2(13, 7)), Color("494a31"))
	draw_rect(Rect2(p + Vector2(-1, -9), Vector2(3, 12)), Color("42413a"))
	draw_rect(Rect2(p + Vector2(-3, -11), Vector2(7, 3)), WOOD_LIT)
	draw_rect(Rect2(p + Vector2(-2, -16), Vector2(5, 6)), Color("c48248"))
	draw_rect(Rect2(p + Vector2(0, -17 - _frame % 2), Vector2(2, 6)), Color("f0ce87"))

func _bench(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(1, 3), Vector2(18, 5)), Color("1a2623"))
	draw_rect(Rect2(p, Vector2(19, 4)), WOOD_LIT)
	draw_rect(Rect2(p + Vector2(2, 4), Vector2(2, 4)), WOOD)
	draw_rect(Rect2(p + Vector2(15, 4), Vector2(2, 4)), WOOD)

func _barrel(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(10, 11)), WOOD)
	draw_rect(Rect2(p + Vector2(1, -2), Vector2(6, 3)), WOOD_LIT)
	draw_rect(Rect2(p + Vector2(-1, 3), Vector2(10, 2)), STONE_DARK)
	draw_rect(Rect2(p + Vector2(-1, 8), Vector2(10, 2)), STONE_DARK)
	draw_rect(Rect2(p + Vector2(2, 1), Vector2(1, 8)), WOOD_LIT)

func _crates(p: Vector2) -> void:
	for offset: Vector2 in [Vector2.ZERO, Vector2(9, 6)]:
		draw_rect(Rect2(p + offset, Vector2(12, 12)), WOOD_LIT)
		draw_rect(Rect2(p + offset + Vector2.ONE, Vector2(10, 10)), WOOD)
		draw_line(p + offset + Vector2.ONE, p + offset + Vector2(10, 10), WOOD_LIT, 1)
		draw_line(p + offset + Vector2(10, 1), p + offset + Vector2(1, 10), WOOD_LIT, 1)

func _draw_people() -> void:
	for index in range(_npcs.size()):
		var npc: Dictionary = _npcs[index]
		var foot: Vector2 = _npc_position(index)
		draw_rect(Rect2(foot + Vector2(-7, -1), Vector2(14, 5)), Color("1b2625"))
		var texture: Texture2D = _npc_textures.get(str(npc.id)) as Texture2D
		if texture != null: draw_texture_rect(texture, Rect2(foot - Vector2(16, 28), Vector2(32, 32)), false)
		else: _person(foot, str(npc.id).hash())
	var hero_foot := Vector2(317, 181)
	draw_rect(Rect2(hero_foot + Vector2(-7, -1), Vector2(14, 5)), Color("18211f"))
	if _hero_texture != null: draw_texture_rect(_hero_texture, Rect2(hero_foot - Vector2(16, 28), Vector2(32, 32)), false)
	else: _person(hero_foot, 17)
	_marker(hero_foot - Vector2(0, 31), BLUE)

func _person(foot: Vector2, seed_value: int) -> void:
	var color: Color = [Color("8d7053"), Color("586f66"), Color("786a7c"), Color("92916d")][absi(seed_value) % 4]
	draw_rect(Rect2(foot + Vector2(-5, -14), Vector2(10, 13)), Color("182120"))
	draw_rect(Rect2(foot + Vector2(-4, -15), Vector2(8, 10)), color)
	draw_rect(Rect2(foot + Vector2(-3, -21), Vector2(6, 7)), Color("bd9e79"))
	draw_rect(Rect2(foot + Vector2(-4, -23), Vector2(8, 4)), Color("3c3a31"))
	draw_rect(Rect2(foot + Vector2(-4, -3), Vector2(3, 5)), Color("353d38"))
	draw_rect(Rect2(foot + Vector2(1, -3), Vector2(3, 5)), Color("353d38"))

func _place_focus(id: String) -> void:
	if not PLACES.has(id): return
	var place: Dictionary = PLACES[id]
	var rectangle: Rect2 = place.rect
	var p: Vector2 = rectangle.position
	var end: Vector2 = rectangle.end
	for corner: Vector2 in [p, Vector2(end.x, p.y), Vector2(p.x, end.y), end]:
		var direction := Vector2(1 if corner.x == p.x else -1, 1 if corner.y == p.y else -1)
		draw_line(corner, corner + Vector2(direction.x * 7, 0), GOLD, 1)
		draw_line(corner, corner + Vector2(0, direction.y * 7), GOLD, 1)
	_marker(Vector2(place.anchor.x, rectangle.position.y - 4), GOLD)
	_caption(str(place.name), Vector2(place.anchor.x, rectangle.position.y - 12))

func _caption(text: String, center: Vector2) -> void:
	if _font == null: return
	var width: float = minf(245, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16)
	var x: float = clampf(roundf(center.x - width / 2), 8, 616 - width)
	var y: float = clampf(center.y - 16, 7, 276)
	draw_rect(Rect2(x + 2, y + 2, width, 22), Color("101819"))
	draw_rect(Rect2(x, y, width, 22), Color("1b2729"))
	draw_rect(Rect2(x, y, width, 22), Color("9eaa8d"), false, 1)
	draw_string(_font, Vector2(x + 8, y + 16), text, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 16, Color("eee6c8"))

func _marker(p: Vector2, color: Color) -> void:
	draw_rect(Rect2(p + Vector2(-3, -3), Vector2(7, 2)), Color("142024"))
	draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 2)), color)
	draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 2)), color)
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 1)), color)

func _octagon(center: Vector2, radius: int, color: Color) -> void:
	var inset: int = int(radius * 0.4)
	var points: PackedVector2Array = [center + Vector2(-inset, -radius), center + Vector2(inset, -radius), center + Vector2(radius, -inset), center + Vector2(radius, inset), center + Vector2(inset, radius), center + Vector2(-inset, radius), center + Vector2(-radius, inset), center + Vector2(-radius, -inset)]
	draw_colored_polygon(points, color)

func _noise(x: int, y: int) -> int:
	return absi((x * 374761 + y * 668265 + 12739) ^ ((x + y) * 73471))
