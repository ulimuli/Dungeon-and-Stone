class_name HomelandMap
extends Control
## A local walkable presentation. The parent owns travel, dialogue and services.
signal interaction_requested(pointid: String)
signal position_changed(pos: Vector2i)
signal exit_requested()

const Art = preload("res://game/character_art.gd")
const EXTENT := Vector2(624,306)
const GRID := Vector2i(38,17)
const TILE: int = 16
const ORIGIN := Vector2(8,0)
const STEP_SECONDS: float = 0.09
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const RACES: Array[String] = ["barbarian","fairy","dwarf","human","beastman","draconian"]
const PALETTES: Dictionary = {
	"barbarian":["373b2d","484735","77714b","a28557","ad7d4b","d4b67d"],
	"fairy":["172f2d","203c32","405440","678965","6d9d93","c6d9aa"],
	"dwarf":["2c2e36","383c43","4b5158","747875","a2724e","d1bd8b"],
	"human":["303b3e","424d4d","5c6461","8d9181","526a82","d2c8a5"],
	"beastman":["333a3c","434c49","626d61","8b9984","9a6c51","d3c49b"],
	"draconian":["26333b","33464d","49636a","769490","6b8e9d","c6d9d0"]
}

var entry: Dictionary = {}
var hero: Dictionary = {}
var layout: Dictionary = {}
var interaction_points: Array = []
var player_cell := Vector2i(19,15)
var reduced_motion: bool = false
var input_enabled: bool = true
var _path: Array[Vector2i] = []
var _pending_interaction: String = ""
var _hover: String = ""
var _elapsed: float = 0.0
var _step_clock: float = 0.0
var _direction: int = 0
var _frame: int = 0
var _font: Font
var _npc_textures: Dictionary = {}
var _hero_texture: Texture2D

static func _race(id: String) -> String:
	var race: String = {"beastfolk":"beastman","dragonkin":"draconian","dragonian":"draconian","elf":"fairy"}.get(id,id)
	return race if race in RACES else "human"

static func layout_for(id: String) -> Dictionary:
	var race: String = _race(id)
	# Six different site plans. Points are authored independently of buildings;
	# residents stand at their place of work rather than in a repeated grid.
	var designs: Dictionary = {
		"barbarian":[[3,2,6,4,"shaman"],[12,2,5,3,"hut"],[26,1,5,3,"tent"],[30,8,5,3,"tent"],[5,10,7,3,"ring"],[24,11,3,2,"memorial"],[3,7,3,1,"woodpile"],[19,7,3,2,"firepit"]],
		"fairy":[[13,1,12,5,"ancient_tree"],[2,5,6,4,"treehouse"],[29,3,6,4,"treehouse"],[27,11,7,2,"grove"],[5,11,6,2,"pool"]],
		"dwarf":[[2,2,11,6,"foundry"],[29,2,6,5,"toolshop"],[18,5,6,3,"anvil"],[3,11,7,2,"ore"],[29,11,5,2,"crane"]],
		"human":[[24,1,8,8,"mage_tower"],[3,3,10,5,"library"],[28,12,7,2,"guild"],[3,11,6,2,"garden"],[17,9,4,2,"fountain"]],
		"beastman":[[13,2,12,6,"council"],[3,3,6,3,"clan_office"],[29,3,6,3,"clan_office"],[3,11,7,2,"garden"],[28,11,7,2,"garden"]],
		"draconian":[[10,1,18,6,"dragon_temple"],[2,2,5,4,"scales"],[31,2,5,4,"scales"],[5,10,2,3,"gateway"],[30,10,2,3,"gateway"]]
	}
	var point_cells: Dictionary = {
		"barbarian":[Vector2i(6,6),Vector2i(12,11),Vector2i(14,5),Vector2i(27,13),Vector2i(7,13),Vector2i(21,15)],
		"fairy":[Vector2i(7,9),Vector2i(31,7),Vector2i(26,10),Vector2i(19,6),Vector2i(8,13),Vector2i(21,15)],
		"dwarf":[Vector2i(30,7),Vector2i(8,8),Vector2i(25,6),Vector2i(12,8),Vector2i(7,13),Vector2i(21,15)],
		"human":[Vector2i(26,9),Vector2i(30,9),Vector2i(29,14),Vector2i(23,7),Vector2i(19,11),Vector2i(21,15)],
		"beastman":[Vector2i(6,6),Vector2i(19,8),Vector2i(31,6),Vector2i(25,10),Vector2i(9,13),Vector2i(21,15)],
		"draconian":[Vector2i(19,9),Vector2i(9,6),Vector2i(29,6),Vector2i(11,7),Vector2i(31,13),Vector2i(21,15)]
	}
	var buildings: Array = []
	var blocked: Dictionary = {}
	var slots: Array[Vector2i] = []
	slots.assign(point_cells[race])
	for spec: Array in designs[race]:
		var rect := Rect2i(int(spec[0]),int(spec[1]),int(spec[2]),int(spec[3]))
		buildings.append({"rect":rect,"kind":str(spec[4])})
		for y: int in range(rect.position.y,rect.end.y):
			for x: int in range(rect.position.x,rect.end.x): blocked[Vector2i(x,y)] = true
	var entrance := Vector2i(19,15)
	var exit_cell := Vector2i(19,16)
	var walkable: Dictionary = {}
	for y: int in range(GRID.y):
		for x: int in range(GRID.x):
			var cell := Vector2i(x,y)
			if cell == exit_cell or (x>0 and x<GRID.x-1 and y>0 and y<GRID.y-1 and not blocked.has(cell)):
				walkable[cell] = true
	var result: Dictionary = {"id":race,"size":GRID,"tile_size":TILE,"entrance":entrance,"exit":exit_cell,"walkable":walkable,"blocked":blocked,"buildings":buildings,"slots":slots,"interactables":[]}
	# A static query includes catalog IDs once the separately owned catalog is available.
	if ResourceLoader.exists("res://game/homeland_catalog.gd"):
		var catalog: Script = load("res://game/homeland_catalog.gd")
		var entries: Dictionary = catalog.call("definitions")
		if entries.has(race): result.interactables = _place_points(entries[race],slots)
	return result

static func _place_points(data: Dictionary, slots: Array) -> Array:
	var result: Array = []
	var points: Array = data.get("points",[])
	if points.is_empty(): points = data.get("npcs",[])+data.get("landmarks",[])
	for index: int in range(mini(points.size(),slots.size())):
		if not points[index] is Dictionary: continue
		var point: Dictionary = points[index].duplicate(true)
		point["cell"] = slots[index]
		point["slot"] = index
		result.append(point)
	return result

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	custom_minimum_size = EXTENT
	_font = load("res://assets/vt323.ttf")
	if size == Vector2.ZERO: size = EXTENT
	if not entry.is_empty(): _textures()
	queue_redraw()

func configure(data: Dictionary, next_hero: Dictionary, savedpos: Vector2i = Vector2i(-1,-1)) -> void:
	entry = data.duplicate(true)
	hero = next_hero.duplicate(true)
	var records: Array = entry.get("points",entry.get("npcs",[]))
	var inferred: String = str(records[0].get("ancestry","human")) if not records.is_empty() and records[0] is Dictionary else "human"
	var id: String = str(entry.get("id",entry.get("ancestry",entry.get("race",inferred))))
	layout = layout_for(id)
	interaction_points = _place_points(entry,layout.slots)
	layout.interactables = interaction_points.duplicate(true)
	player_cell = savedpos if _walkable(savedpos) else layout.entrance
	_path.clear(); _pending_interaction = ""; _hover = ""; _step_clock = 0.0
	_textures()
	queue_redraw()

func _textures() -> void:
	_hero_texture = Art.sprite(hero,_direction,0)
	_npc_textures.clear()
	for point: Dictionary in interaction_points:
		if str(point.get("kind","npc")) != "npc": continue
		var npc: Dictionary = point.duplicate(true)
		npc["ancestry"] = npc.get("ancestry",layout.get("id","human"))
		var look: Dictionary = Art.seeded(str(npc.ancestry),int(str(npc.get("id","")).hash()))
		look["outfit"] = ["garnet","teal","ochre","navy","moss","plum"][int(point.slot)%6]
		look["accessory"] = ["headband","circlet","apron","hood","scarf","pauldron"][int(point.slot)%6]
		npc["appearance"] = point.get("appearance",look)
		_npc_textures[str(point.get("id",""))] = Art.sprite(npc,0,0)

func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN+Vector2(cell)*TILE+Vector2(8,8)

func _walkable(cell: Vector2i) -> bool:
	if layout.is_empty() or not layout.walkable.has(cell): return false
	for point: Dictionary in interaction_points:
		if point.cell == cell: return false
	return true

func move(direction: Vector2i) -> bool:
	if not input_enabled or absi(direction.x)+absi(direction.y)!=1: return false
	var destination: Vector2i = player_cell+direction
	if not _walkable(destination): return false
	_direction = 1 if direction.x<0 else (2 if direction.x>0 else (3 if direction.y<0 else 0))
	player_cell = destination
	_frame = 0 if reduced_motion else (_frame+1)%4
	_hero_texture = Art.sprite(hero,_direction,_frame)
	position_changed.emit(player_cell)
	queue_redraw()
	if player_cell == layout.exit: exit_requested.emit()
	return true

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func nearby_point() -> Dictionary:
	for point: Dictionary in interaction_points:
		if _distance(player_cell,point.cell)<=1: return point
	return {}

func activate_nearby() -> bool:
	if not input_enabled: return false
	var point: Dictionary = nearby_point()
	if not point.is_empty():
		_path.clear(); _pending_interaction = ""
		interaction_requested.emit(str(point.get("id","")))
		return true
	if not layout.is_empty() and _distance(player_cell,layout.exit)<=1:
		exit_requested.emit(); return true
	return false

func path_to(destination: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _walkable(destination): return result
	var frontier: Array[Vector2i] = [player_cell]
	var previous: Dictionary = {player_cell:player_cell}
	var cursor: int = 0
	while cursor<frontier.size():
		var cell: Vector2i = frontier[cursor]; cursor += 1
		if cell == destination: break
		for direction: Vector2i in DIRECTIONS:
			var candidate: Vector2i = cell+direction
			if _walkable(candidate) and not previous.has(candidate):
				previous[candidate] = cell; frontier.append(candidate)
	if not previous.has(destination): return result
	var cell: Vector2i = destination
	while cell != player_cell:
		result.push_front(cell); cell = previous[cell]
	return result

func request_path(destination: Vector2i) -> bool:
	if not input_enabled: return false
	_pending_interaction = ""
	_path = path_to(destination)
	_step_clock = 0.0
	queue_redraw()
	return not _path.is_empty() or destination == player_cell

func _approach(point: Dictionary) -> void:
	if _distance(player_cell,point.cell)<=1:
		_path.clear(); interaction_requested.emit(str(point.get("id",""))); return
	var best: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var path: Array[Vector2i] = path_to(point.cell+direction)
		if not path.is_empty() and (best.is_empty() or path.size()<best.size()): best = path
	_path = best
	_pending_interaction = str(point.get("id","")) if not best.is_empty() else ""
	_step_clock = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not input_enabled or not has_focus(): return
	if not reduced_motion: _elapsed += delta
	if not _path.is_empty():
		_step_clock += delta
		if _step_clock>=STEP_SECONDS:
			_step_clock = 0.0
			var next: Vector2i = _path.pop_front()
			if not move(next-player_cell): _path.clear(); _pending_interaction = ""
			if _path.is_empty() and not _pending_interaction.is_empty():
				var id: String = _pending_interaction; _pending_interaction = ""
				if str(nearby_point().get("id","")) == id: interaction_requested.emit(id)
	if not reduced_motion: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree(): return
	if event is InputEventMouseMotion:
		_hover = ""
		var cell := Vector2i((event.position-ORIGIN)/TILE)
		for point: Dictionary in interaction_points:
			if point.cell == cell: _hover = str(point.get("id",""))
		queue_redraw(); return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		var cell := Vector2i((event.position-ORIGIN)/TILE)
		for point: Dictionary in interaction_points:
			if point.cell == cell: _approach(point); accept_event(); return
		request_path(cell); accept_event(); return
	if not has_focus(): return
	var direction := Vector2i.ZERO
	var activate: bool = false
	var leave: bool = false
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W,KEY_UP: direction = Vector2i.UP
			KEY_A,KEY_LEFT: direction = Vector2i.LEFT
			KEY_S,KEY_DOWN: direction = Vector2i.DOWN
			KEY_D,KEY_RIGHT: direction = Vector2i.RIGHT
			KEY_E,KEY_ENTER,KEY_SPACE: activate = true
			KEY_ESCAPE: leave = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: direction = Vector2i.UP
			JOY_BUTTON_DPAD_LEFT: direction = Vector2i.LEFT
			JOY_BUTTON_DPAD_DOWN: direction = Vector2i.DOWN
			JOY_BUTTON_DPAD_RIGHT: direction = Vector2i.RIGHT
			JOY_BUTTON_A: activate = true
			JOY_BUTTON_B: leave = true
	if direction != Vector2i.ZERO:
		_path.clear(); _pending_interaction = ""; move(direction); accept_event()
	elif activate:
		activate_nearby(); accept_event()
	elif leave:
		_path.clear(); _pending_interaction = ""; exit_requested.emit(); accept_event()

func _draw() -> void:
	if layout.is_empty(): return
	var palette: Array = PALETTES[layout.id]
	_terrain(palette)
	_draw_boundary(palette)
	for building: Dictionary in layout.buildings: _building(building,palette)
	_draw_centerpiece(palette)
	for cell: Vector2i in _path:
		draw_rect(Rect2(cell_center(cell)-Vector2(1,1),Vector2(2,2)),Color(palette[5]).darkened(0.2))
	# Draw in foot order so the upper-row residents never overlap lower actors.
	var actors: Array = interaction_points.duplicate()
	actors.append({"kind":"hero","cell":player_cell})
	actors.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.cell.y<b.cell.y)
	for actor: Dictionary in actors:
		var foot: Vector2 = cell_center(actor.cell)+Vector2(0,7)
		if actor.kind == "hero":
			draw_rect(Rect2(foot+Vector2(-8,-2),Vector2(16,3)),Color(0,0,0,0.3))
			if _hero_texture != null: draw_texture(_hero_texture,foot-Vector2(16,28))
		elif actor.kind == "npc":
			var texture: Texture2D = _npc_textures.get(str(actor.get("id","")))
			if texture != null: draw_texture(texture,foot-Vector2(16,28))
		else:
			_object(foot,palette,int(actor.slot))
		if str(actor.get("id","")) == _hover or (actor.kind != "hero" and _distance(player_cell,actor.cell)<=1):
			draw_rect(Rect2(foot+Vector2(-7,0),Vector2(14,2)),Color(palette[5]))
	_prompt(palette)

func _terrain(palette: Array) -> void:
	var ground := Color(palette[0]); var path := Color(palette[2])
	draw_rect(Rect2(0,0,624,272),ground)
	# Small, deterministic patches replace a repeated checkerboard tile pattern.
	for y: int in range(0,272,8):
		for x: int in range(8,616,8):
			var n: int = (x*37+y*71+x*y)%101
			if n<24: draw_rect(Rect2(x,y,6+n%6,3+n%4),ground.lightened(0.035 if n%2 else 0.06))
	var natural: bool = layout.id in ["barbarian","fairy"]
	if natural:
		var trails: Array = []
		if layout.id == "barbarian":
			trails = [[Vector2i(19,15),Vector2i(18,12),Vector2i(21,9),Vector2i(17,7),Vector2i(10,7),Vector2i(7,6)],[Vector2i(18,12),Vector2i(12,11),Vector2i(7,13)],[Vector2i(18,7),Vector2i(21,5),Vector2i(28,4)],[Vector2i(21,9),Vector2i(28,9),Vector2i(30,11)],[Vector2i(21,12),Vector2i(27,13)]]
		else:
			trails = [[Vector2i(19,15),Vector2i(15,12),Vector2i(13,9),Vector2i(14,7),Vector2i(19,6),Vector2i(25,7),Vector2i(27,10),Vector2i(24,13),Vector2i(19,15)],[Vector2i(13,9),Vector2i(7,9)],[Vector2i(25,7),Vector2i(31,7)],[Vector2i(15,12),Vector2i(8,13)]]
		for trail: Array in trails:
			for index: int in range(1,trail.size()):
				var a: Vector2 = cell_center(trail[index-1]); var b: Vector2 = cell_center(trail[index])
				draw_line(a,b,path.darkened(0.14),30,false)
				draw_line(a,b,path.darkened(0.04),24,false)
				if layout.id == "fairy":
					var count: int = maxi(1,int(a.distance_to(b)/6))
					for i: int in range(count):
						var p: Vector2 = a.lerp(b,float(i)/count).floor()
						var normal: Vector2 = (b-a).normalized().orthogonal()*11
						draw_line((p-normal).floor(),(p+normal).floor(),Color("8a8060").darkened(0.25),1,false)
		# Scattered grass, fallen leaves and roots make clearings feel inhabited.
		for i: int in range(150):
			var p := Vector2(12+(i*71)%596,12+(i*47)%238)
			var tint := Color(palette[3]).darkened(0.2 if i%3 else 0.4)
			draw_line(p,p+Vector2(-2,-3),tint,1)
			draw_line(p+Vector2(2,0),p+Vector2(2,-4),tint,1)
	else:
		var court := Rect2(20,20,584,224)
		if layout.id == "human": court = Rect2(40,116,552,128)
		elif layout.id == "dwarf": court = Rect2(218,22,248,220)
		elif layout.id == "draconian": court = Rect2(138,104,352,144)
		elif layout.id == "beastman": court = Rect2(168,116,280,130)
		draw_rect(court.grow(5),Color(palette[1]).lightened(0.1))
		draw_rect(court,path.darkened(0.12))
		# Staggered small cobbles for Rafdonia; longer carved blocks elsewhere.
		var brick: Vector2i = Vector2i(12,7) if layout.id == "human" else Vector2i(24,12)
		for y: int in range(int(court.position.y),int(court.end.y)-brick.y,brick.y):
			for x: int in range(int(court.position.x),int(court.end.x)-brick.x,brick.x):
				var offset: int = (brick.x/2) if (y/brick.y)%2 else 0
				var p := Vector2(x+offset,y)
				if p.x+brick.x>court.end.x: continue
				var tint: Color = path.darkened(0.05+float((x*3+y)%11)/100)
				draw_rect(Rect2(p,Vector2(brick)-Vector2(1,1)),tint)
				draw_line(p+Vector2(1,1),p+Vector2(brick.x-3,1),tint.lightened(0.06),1)
		# An unambiguous southern approach is common; the site beyond differs.
		draw_rect(Rect2(cell_center(Vector2i(18,14))-Vector2(8,8),Vector2(48,48)),path.darkened(0.1))
	if layout.id == "fairy":
		for p: Vector2 in [Vector2(144,48),Vector2(450,26),Vector2(42,188),Vector2(552,202)]:
			_leaf_mass(p,50,22,Color("304b3c"))
	elif layout.id == "dwarf":
		# Ore rails connect the rear workshops to the court, not a city street.
		for y: int in [157,165]: draw_line(Vector2(32,y),Vector2(578,y),Color("798284"),2)
		for x: int in range(38,580,12): draw_rect(Rect2(x,153,4,17),Color("5c4d40"))
	elif layout.id == "beastman":
		for p: Vector2 in [Vector2(170,150),Vector2(446,150),Vector2(174,226),Vector2(442,226)]:
			_planter(p,palette)
	elif layout.id == "draconian":
		# Wide ceremonial stairs remain walkable in front of the temple.
		for i: int in range(4):
			var width: int = 114+i*12
			draw_rect(Rect2(312-width/2,111+i*6,width,5),Color(palette[3]).darkened(0.08+i*0.045))

func _leaf_mass(center: Vector2, width: int, height: int, tint: Color) -> void:
	# Stepped native-pixel foliage; no smooth ellipse silhouettes.
	for band: int in range(0,height,4):
		var inset: int = 8 if band<4 or band>=height-4 else (4 if band<8 or band>=height-8 else 0)
		draw_rect(Rect2(center.x-width/2+inset,center.y-height/2+band,width-inset*2,4),tint.lightened(float(band%12)/160))
	for i: int in range(maxi(4,width/5)):
		var x: int = (i*17)%maxi(1,width-16)-width/2+8
		var y: int = (i*11)%maxi(1,height-8)-height/2+4
		draw_rect(Rect2(center+Vector2(x,y),Vector2(4,2)),tint.lightened(0.12))

func _planter(p: Vector2, palette: Array) -> void:
	draw_rect(Rect2(p+Vector2(-7,-4),Vector2(14,9)),Color(palette[3]).darkened(0.3))
	_leaf_mass(p+Vector2(0,-9),22,16,Color("637b58"))

func _draw_boundary(palette: Array) -> void:
	var natural: bool = layout.id in ["barbarian","fairy"]
	if natural:
		for i: int in range(10):
			var p := Vector2(14+i*64,8+(i%3)*3)
			_leaf_mass(p,58,24,Color("273d31") if layout.id=="fairy" else Color("424a32"))
		for y: int in range(28,270,28):
			for x: int in [9,610]: _leaf_mass(Vector2(x,y),24,36,Color(palette[1]).darkened(0.13))
		for x: int in range(24,600,24):
			if x in range(288,352): continue
			_leaf_mass(Vector2(x,265),28,16,Color(palette[1]))
	else:
		# Carved enclosing ledges with irregular joints, not checkerboard walls.
		draw_rect(Rect2(8,0,608,13),Color(palette[3]).darkened(0.5))
		draw_line(Vector2(8,13),Vector2(616,13),Color(palette[3]).darkened(0.1),2)
		for x: int in range(12,616,37):
			draw_line(Vector2(x,0),Vector2(x-4,12),Color(palette[0]),1)
		for x: int in [8,604]:
			draw_rect(Rect2(x,0,12,272),Color(palette[1]).darkened(0.35))
			for y: int in range(18,272,23): draw_line(Vector2(x,y),Vector2(x+11,y-3),Color(palette[3]).darkened(0.5),1)
		for x: int in [8,344]: draw_rect(Rect2(x,258,280 if x==8 else 272,14),Color(palette[1]).darkened(0.3))
	if layout.id == "dwarf":
		for x: int in [25,218,579]:
			draw_rect(Rect2(x,8,14,68),Color("53585c"))
			draw_rect(Rect2(x-3,8,20,9),Color("858b86"))
			draw_rect(Rect2(x+3,21,3,42),Color("737b79"))
	var exit_p: Vector2 = cell_center(layout.exit)
	draw_line(exit_p+Vector2(0,-4),exit_p+Vector2(0,4),Color(palette[5]),2)
	draw_line(exit_p+Vector2(-3,1),exit_p+Vector2(0,4),Color(palette[5]),2)
	draw_line(exit_p+Vector2(3,1),exit_p+Vector2(0,4),Color(palette[5]),2)

func _building(building: Dictionary, palette: Array) -> void:
	var r := Rect2(ORIGIN+Vector2(building.rect.position)*16,Vector2(building.rect.size)*16)
	var kind: String = building.kind
	var stone := Color(palette[3]); var dark := Color(palette[1]); var accent := Color(palette[4]); var light := Color(palette[5])
	draw_rect(Rect2(r.position+Vector2(4,7),r.size),Color(0,0,0,0.25))
	if kind == "ancient_tree": _ancient_tree(r,palette); return
	if kind == "council": _council(r,palette); return
	if kind == "mage_tower": _mage_tower(r,palette); return
	if kind == "dragon_temple": _dragon_temple(r,palette); return
	if kind == "foundry": _foundry(r,palette); return
	if kind == "fountain": _fountain(r,palette); return
	if kind == "gateway":
		draw_rect(r,stone.darkened(0.2))
		draw_rect(Rect2(r.position+Vector2(6,3),Vector2(5,r.size.y-4)),light.darkened(0.25))
		draw_rect(Rect2(r.position-Vector2(5,3),Vector2(r.size.x+10,9)),accent)
		draw_rect(Rect2(r.position+Vector2(3,r.size.y-6),Vector2(r.size.x-6,6)),light.darkened(0.2))
		return
	if kind == "memorial":
		for offset: Vector2 in [Vector2(-9,1),Vector2(12,5)]:
			var p: Vector2 = r.get_center()+offset
			draw_rect(Rect2(p+Vector2(-3,-27),Vector2(7,38)),Color("75634a"))
			draw_line(p+Vector2(0,-22),p+Vector2(-13,-30),Color("75634a"),4)
			_leaf_mass(p+Vector2(0,-34),38,24,Color("6d7451"))
			draw_rect(Rect2(p+Vector2(6,2),Vector2(3,8)),Color("c6bb93"))
		return
	if kind == "woodpile":
		for x: int in range(0,int(r.size.x)-8,8):
			draw_rect(Rect2(r.position+Vector2(x,4+(x%3)),Vector2(7,7)),Color("a2855a"))
			draw_rect(Rect2(r.position+Vector2(x+2,6+(x%3)),Vector2(3,3)),Color("65533d"))
		return
	if kind == "firepit": _fire(r.get_center(),palette); return
	if kind == "crane":
		draw_rect(Rect2(r.position+Vector2(8,-8),Vector2(8,r.size.y+8)),Color("8e7857"))
		draw_rect(Rect2(r.position+Vector2(4,-8),Vector2(r.size.x-7,7)),Color("ad9770"))
		draw_line(r.position+Vector2(12,-2),r.position+Vector2(r.size.x-9,-2),dark,2)
		draw_line(r.position+Vector2(r.size.x-12,-2),r.position+Vector2(r.size.x-12,22),light,1)
		draw_rect(Rect2(r.position+Vector2(r.size.x-25,21),Vector2(27,11)),dark.lightened(0.1))
		return
	if kind in ["tent","shaman","hut"]:
		var roof := PackedVector2Array([r.position+Vector2(-4,r.size.y*0.6),r.position+Vector2(r.size.x/2,-5),r.position+Vector2(r.size.x+4,r.size.y*0.6)])
		draw_colored_polygon(roof,accent)
		for y: int in range(3,int(r.size.y*0.6),6):
			var span: int = int((float(y+5)/(r.size.y*0.6+5))*r.size.x/2)
			draw_line(r.position+Vector2(r.size.x/2-span,y),r.position+Vector2(r.size.x/2+span,y),accent.darkened(0.12),1)
		for shift: int in [-14,14]:
			draw_line(r.position+Vector2(r.size.x/2+shift/3,-1),r.position+Vector2(r.size.x/2+shift*2,r.size.y*0.6),accent.lightened(0.13),1)
		draw_rect(Rect2(r.position+Vector2(5,r.size.y*0.55),Vector2(r.size.x-10,r.size.y*0.45)),stone.darkened(0.25))
		for y: int in range(int(r.size.y*0.6),int(r.size.y),5): draw_line(r.position+Vector2(6,y),r.position+Vector2(r.size.x-6,y),dark.lightened(0.1),1)
		draw_line(r.position+Vector2(r.size.x/2,-4),r.position+Vector2(r.size.x/2,r.size.y-1),light.darkened(0.25),2)
		draw_rect(Rect2(r.position+Vector2(r.size.x/2-7,r.size.y-22),Vector2(14,22)),dark.darkened(0.5))
		if kind == "shaman":
			for offset: int in [-18,16]:
				draw_line(r.position+Vector2(r.size.x/2+offset,18),r.position+Vector2(r.size.x/2+offset,r.size.y-5),light,1)
				draw_rect(Rect2(r.position+Vector2(r.size.x/2+offset-3,23),Vector2(7,2)),light)
	elif kind in ["tree","treehouse","grove"]:
		var trunk := Rect2(r.position+Vector2(r.size.x/2-6,14),Vector2(12,r.size.y-14))
		draw_rect(trunk,Color("67543d"))
		for offset: Vector2 in [Vector2(0,5),Vector2(-18,14),Vector2(18,10)]:
			_leaf_mass(r.position+Vector2(r.size.x/2,13)+offset,48,32,Color(palette[2]).lightened(0.08 if offset.x==0 else 0))
		if kind == "treehouse":
			draw_rect(Rect2(r.position+Vector2(13,23),Vector2(r.size.x-26,22)),Color("94754e"))
			for y: int in range(25,45,4): draw_line(r.position+Vector2(14,y),r.position+Vector2(r.size.x-14,y),Color("674f38"),1)
			draw_rect(Rect2(r.position+Vector2(10,43),Vector2(r.size.x-20,5)),Color("baa67c"))
			draw_rect(Rect2(r.position+Vector2(r.size.x/2-5,29),Vector2(10,16)),dark)
			for y: int in range(42,int(r.size.y),5): draw_line(r.position+Vector2(r.size.x/2-5,y),r.position+Vector2(r.size.x/2+5,y),light,1)
		elif kind == "grove":
			for offset: int in [8,20,34,49]: draw_rect(Rect2(r.position+Vector2(offset,27+(offset%3)*4),Vector2(2,3)),light)
	elif kind in ["ring","pool","garden","circle","pyre","ore","anvil","scales"]:
		draw_rect(r,stone.darkened(0.4))
		draw_rect(Rect2(r.position+Vector2(4,4),r.size-Vector2(8,8)),dark)
		if kind == "ring":
			for x: int in range(4,int(r.size.x),12):
				draw_line(r.position+Vector2(x,3),r.position+Vector2(x,15),light,2)
				draw_line(r.position+Vector2(x,r.size.y-8),r.position+Vector2(x,r.size.y+3),light,2)
			draw_line(r.position+Vector2(4,8),r.position+Vector2(r.size.x-4,8),accent,1)
		elif kind == "pool":
			draw_rect(Rect2(r.position+Vector2(7,7),r.size-Vector2(14,14)),Color("497f80"))
			for x: int in [18,45,74]: draw_rect(Rect2(r.position+Vector2(x,16),Vector2(15,1)),light)
		elif kind == "circle":
			draw_arc(r.get_center(),18,0,TAU,24,accent,2)
			draw_arc(r.get_center(),11,0,TAU,16,light,1)
			for offset: Vector2 in [Vector2(-28,0),Vector2(28,0),Vector2(0,18),Vector2(0,-18)]: draw_rect(Rect2(r.get_center()+offset-Vector2(2,2),Vector2(4,4)),light)
		elif kind == "anvil":
			for x: int in range(18,int(r.size.x)-12,34):
				draw_rect(Rect2(r.position+Vector2(x,15),Vector2(13,16)),stone)
				draw_rect(Rect2(r.position+Vector2(x-7,11),Vector2(28,6)),light)
		elif kind == "pyre":
			for x: int in range(12,int(r.size.x)-8,18): draw_rect(Rect2(r.position+Vector2(x,13),Vector2(9,25)),Color("78654a"))
		elif kind == "scales":
			for y: int in [9,21,33]:
				for x: int in range(12,int(r.size.x)-8,18): draw_arc(r.position+Vector2(x+(5 if y==21 else 0),y),7,0,PI,5,accent,2)
		else:
			for x: int in range(12,int(r.size.x)-8,16): draw_rect(Rect2(r.position+Vector2(x,14+(x%3)*4),Vector2(8,12)),accent if kind=="ore" else Color("64875e"))
	else:
		# Carved halls, domes and city masonry share construction, not silhouettes.
		draw_rect(r,stone.darkened(0.22))
		for y: int in range(8,int(r.size.y),10):
			draw_line(r.position+Vector2(0,y),r.position+Vector2(r.size.x,y),dark,1)
			for x: int in range(0,int(r.size.x),18): draw_line(r.position+Vector2(x+(8 if y%20 else 0),y-8),r.position+Vector2(x+(8 if y%20 else 0),y),dark,1)
		if kind in ["dome","council"]:
			var dome := PackedVector2Array()
			for index: int in range(13):
				var angle: float = PI+PI*float(index)/12.0
				dome.append(r.position+Vector2(r.size.x/2,14)+Vector2(cos(angle)*r.size.x/2,sin(angle)*minf(28,r.size.y*0.55)))
			draw_colored_polygon(dome,accent)
			draw_rect(Rect2(r.position+Vector2(0,15),r.size-Vector2(0,15)),stone.darkened(0.2))
		elif kind == "tower":
			draw_colored_polygon(PackedVector2Array([r.position+Vector2(-4,9),r.position+Vector2(r.size.x/2,-13),r.position+Vector2(r.size.x+4,9)]),accent)
			for y: int in [20,39]: draw_rect(Rect2(r.position+Vector2(r.size.x/2-4,y),Vector2(8,12)),light)
		elif kind in ["forge","chimney"]:
			draw_rect(Rect2(r.position+Vector2(7,-11),Vector2(15,23)),dark.lightened(0.15))
			draw_rect(Rect2(r.position+Vector2(8,r.size.y-25),Vector2(27,19)),Color("3c2829"))
			draw_rect(Rect2(r.position+Vector2(12,r.size.y-20),Vector2(18,12)),Color("d88c50"))
		elif kind == "sanctuary":
			for x: int in [4,int(r.size.x)-12]: draw_rect(Rect2(r.position+Vector2(x,2),Vector2(8,r.size.y)),light.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([r.position+Vector2(-4,8),r.position+Vector2(r.size.x/2,-10),r.position+Vector2(r.size.x+4,8)]),accent)
		else:
			draw_rect(Rect2(r.position-Vector2(3,3),Vector2(r.size.x+6,11)),accent)
			for x: int in range(10,int(r.size.x)-8,19): draw_rect(Rect2(r.position+Vector2(x,18),Vector2(9,12)),light.darkened(0.2))
		draw_rect(Rect2(r.position+Vector2(r.size.x/2-7,r.size.y-18),Vector2(14,18)),dark.darkened(0.3))

func _ancient_tree(r: Rect2, palette: Array) -> void:
	var center: Vector2 = r.position+Vector2(r.size.x/2,44)
	# Root buttresses and the old divided trunk anchor the whole northern grove.
	for side: int in [-1,1]:
		for i: int in range(3):
			var start: Vector2 = center+Vector2(side*14,20+i*5)
			var end: Vector2 = center+Vector2(side*(46+i*17),43+i*3)
			draw_line(start,end,Color("695b43"),10-i*2,false)
			draw_line(start+Vector2(0,-2),end+Vector2(0,-2),Color("8a7953"),2,false)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-24,42),center+Vector2(-15,-35),center+Vector2(18,-35),center+Vector2(28,42)]),Color("786044"))
	for x: int in [-16,-7,4,14]: draw_line(center+Vector2(x,-20),center+Vector2(x+3,36),Color("4a4434"),2)
	for side: int in [-1,1]: draw_line(center+Vector2(side*8,-10),center+Vector2(side*71,-30),Color("6c5940"),13)
	for i: int in range(11):
		var p: Vector2 = center+Vector2((i*43)%208-104,-38+(i%3)*11)
		_leaf_mass(p,76+(i%3)*8,36+(i%2)*8,Color(["385e43","426a4b","4d7451","33533d"][i%4]))
	for i: int in range(9):
		var p: Vector2 = center+Vector2((i*29)%152-76,-25+(i%4)*8)
		draw_rect(Rect2(p,Vector2(2,3)),Color("b3d9a2"))
	draw_rect(Rect2(center+Vector2(-7,17),Vector2(14,20)),Color("233b31"))
	draw_line(center+Vector2(-4,20),center+Vector2(4,20),Color("a9bc83"),2)

func _council(r: Rect2, palette: Array) -> void:
	var stone := Color(palette[3]); var roof := Color("8f6f56")
	# A single broad, ribbed dome rises above the assembly hall.
	for y: int in range(0,50,2):
		var ratio: float = float(48-y)/48.0
		var half_width: int = int(sqrt(maxf(0,1-ratio*ratio))*r.size.x/2)/2*2
		draw_rect(Rect2(r.position+Vector2(r.size.x/2-half_width,y-8),Vector2(half_width*2,2)),roof.lightened(0.08 if y%10<4 else 0))
	for side: int in [-1,1]:
		var points := PackedVector2Array()
		for y: int in range(0,49,4):
			var ratio: float = float(48-y)/48.0
			points.append((r.position+Vector2(r.size.x/2+side*sqrt(maxf(0,1-ratio*ratio))*r.size.x*0.25,y-8)).floor())
		draw_polyline(points,roof.darkened(0.25),2,false)
	draw_rect(Rect2(r.position+Vector2(-4,40),Vector2(r.size.x+8,7)),stone.lightened(0.1))
	draw_rect(Rect2(r.position+Vector2(0,47),Vector2(r.size.x,r.size.y-47)),stone.darkened(0.2))
	for x: int in range(7,int(r.size.x)-4,24):
		draw_rect(Rect2(r.position+Vector2(x,51),Vector2(12,24)),Color("38473f"))
		draw_rect(Rect2(r.position+Vector2(x+2,53),Vector2(3,18)),Color("bdc8a0"))
	draw_rect(Rect2(r.position+Vector2(r.size.x/2-15,r.size.y-34),Vector2(30,34)),Color("3e4a42"))
	for x: int in [-11,0,11]: draw_line(r.position+Vector2(r.size.x/2+x,r.size.y-29),r.position+Vector2(r.size.x/2+x,r.size.y-3),Color("aa9c73"),1)
	for i: int in range(7):
		var p: Vector2 = r.position+Vector2(10+i*27,85)
		draw_rect(Rect2(p+Vector2(-1,-5),Vector2(2,18)),Color("c2b58e"))
		draw_rect(Rect2(p+Vector2(2,-4),Vector2(12,10)),Color(["935c4e","62877b","918750","667c91","9a7886","b39a68","777e6b"][i]))
		draw_rect(Rect2(p+Vector2(6,-2),Vector2(3,5)),Color("dbd1af"))
	for i: int in range(3): draw_rect(Rect2(r.position+Vector2(r.size.x/2-34-i*5,r.size.y+i*3),Vector2(68+i*10,2)),stone.darkened(0.15+i*0.06))

func _mage_tower(r: Rect2, palette: Array) -> void:
	var stone := Color(palette[3]); var blue := Color("526d86")
	var p: Vector2 = r.position+Vector2(r.size.x/2-30,26)
	draw_rect(Rect2(r.position+Vector2(2,77),Vector2(r.size.x-4,r.size.y-77)),stone.darkened(0.3))
	for side: int in [-1,1]:
		var wing: Vector2 = r.position+Vector2(r.size.x/2+side*47-12,72)
		draw_rect(Rect2(wing,Vector2(24,56)),stone.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([wing+Vector2(-4,0),wing+Vector2(12,-19),wing+Vector2(28,0)]),blue.darkened(0.1))
		draw_rect(Rect2(wing+Vector2(8,12),Vector2(8,16)),Color("d3c9a3"))
	draw_rect(Rect2(p,Vector2(60,r.size.y-26)),stone)
	draw_rect(Rect2(p,Vector2(10,r.size.y-26)),stone.darkened(0.2))
	draw_rect(Rect2(p+Vector2(51,0),Vector2(9,r.size.y-26)),stone.darkened(0.35))
	for y: int in range(3,int(r.size.y)-26,13):
		draw_line(p+Vector2(0,y),p+Vector2(60,y),stone.darkened(0.18),1)
		for x: int in [15,38]: draw_line(p+Vector2(x+(6 if y%2 else 0),y-11),p+Vector2(x+(6 if y%2 else 0),y),stone.darkened(0.15),1)
	for y: int in [12,37,62]:
		draw_rect(Rect2(p+Vector2(23,y),Vector2(14,18)),Color("354b5d"))
		draw_rect(Rect2(p+Vector2(26,y+3),Vector2(8,12)),Color("b4d3c9"))
		draw_line(p+Vector2(30,y+3),p+Vector2(30,y+15),blue,1)
	for y: int in range(0,38,3):
		var span: int = 4+y
		draw_rect(Rect2(p+Vector2(30-span,y-35),Vector2(span*2,3)),blue.lightened(float(y%9)/90))
	draw_rect(Rect2(p+Vector2(28,-43),Vector2(4,11)),Color("cab880"))
	draw_rect(Rect2(p+Vector2(20,r.size.y-47),Vector2(20,21)),Color("34444e"))
	for side: int in [-1,1]:
		var flag: Vector2 = p+Vector2(30+side*24,72)
		draw_rect(Rect2(flag,Vector2(9,17)),Color("526c99"))
		draw_rect(Rect2(flag+Vector2(3,3),Vector2(3,7)),Color("d2c69a"))

func _dragon_temple(r: Rect2, palette: Array) -> void:
	var stone := Color(palette[3]); var accent := Color(palette[4]); var light := Color(palette[5])
	draw_rect(r,stone.darkened(0.24))
	draw_rect(Rect2(r.position+Vector2(5,22),r.size-Vector2(10,25)),Color("344c55"))
	for x: int in range(13,int(r.size.x)-10,43):
		draw_rect(Rect2(r.position+Vector2(x-5,25),Vector2(19,r.size.y-29)),stone.darkened(0.15))
		draw_rect(Rect2(r.position+Vector2(x,25),Vector2(5,r.size.y-31)),light.darkened(0.15))
		draw_rect(Rect2(r.position+Vector2(x-8,21),Vector2(25,8)),stone.lightened(0.13))
		draw_rect(Rect2(r.position+Vector2(x-8,r.size.y-8),Vector2(25,8)),stone.lightened(0.06))
	draw_rect(Rect2(r.position-Vector2(6,0),Vector2(r.size.x+12,23)),accent.darkened(0.08))
	for i: int in range(4):
		draw_rect(Rect2(r.position+Vector2(-8+i*8,-4-i*5),Vector2(r.size.x+16-i*16,5)),accent.lightened(0.04*i))
	# A carved dragon crest has a horned head and paired wings, not text.
	var crest: Vector2 = r.position+Vector2(r.size.x/2,8)
	draw_rect(Rect2(crest-Vector2(5,6),Vector2(10,12)),light)
	for side: int in [-1,1]:
		draw_line(crest+Vector2(side*3,-2),crest+Vector2(side*9,-8),light,2)
		draw_line(crest+Vector2(side*6,2),crest+Vector2(side*27,-3),light.darkened(0.1),3)
		draw_line(crest+Vector2(side*17,-1),crest+Vector2(side*21,6),light.darkened(0.1),2)
	draw_rect(Rect2(r.position+Vector2(r.size.x/2-16,44),Vector2(32,r.size.y-44)),Color("1e333e"))
	for x: int in [-10,8]: draw_line(r.position+Vector2(r.size.x/2+x,48),r.position+Vector2(r.size.x/2+x,r.size.y-3),accent,2)

func _foundry(r: Rect2, palette: Array) -> void:
	var stone := Color(palette[3]); var dark := Color("292e34")
	draw_rect(r,stone.darkened(0.28))
	for y: int in range(7,int(r.size.y),11):
		draw_line(r.position+Vector2(0,y),r.position+Vector2(r.size.x,y),dark,1)
		for x: int in range(4,int(r.size.x),26): draw_line(r.position+Vector2(x+(11 if y%2 else 0),y-9),r.position+Vector2(x+(11 if y%2 else 0),y),dark,1)
	draw_rect(Rect2(r.position+Vector2(-5,-5),Vector2(r.size.x+10,12)),Color("8b8c7a"))
	for x: int in [8,int(r.size.x)-23]:
		draw_rect(Rect2(r.position+Vector2(x,-13),Vector2(17,r.size.y+13)),Color("4b5154"))
		draw_rect(Rect2(r.position+Vector2(x+3,-10),Vector2(4,r.size.y+8)),stone)
	var furnace: Vector2 = r.position+Vector2(43,32)
	draw_rect(Rect2(furnace-Vector2(7,6),Vector2(77,60)),Color("6c6254"))
	draw_rect(Rect2(furnace,Vector2(63,48)),Color("392d2c"))
	draw_rect(Rect2(furnace+Vector2(5,7),Vector2(53,36)),Color("bd6840"))
	draw_rect(Rect2(furnace+Vector2(10,13),Vector2(43,25)),Color("e1a15b"))
	for x: int in range(3,61,10): draw_rect(Rect2(furnace+Vector2(x,3),Vector2(4,45)),Color("4c4340"))
	for y: int in [3,44]: draw_rect(Rect2(furnace+Vector2(0,y),Vector2(63,4)),Color("90836b"))
	var stack: Vector2 = r.position+Vector2(r.size.x-50,-17)
	draw_rect(Rect2(stack,Vector2(24,43)),Color("585d5e"))
	for y: int in range(5,42,8): draw_line(stack+Vector2(1,y),stack+Vector2(23,y),dark,1)
	draw_rect(Rect2(stack-Vector2(3,2),Vector2(30,7)),Color("909187"))
	for i: int in range(4): draw_rect(Rect2(stack+Vector2(-5+i*5,-9-i*5),Vector2(19-i*2,5)),Color("686d6e").darkened(i*0.05))
	# Bellows, a water barrel, tongs and hanging hammers.
	draw_rect(Rect2(r.position+Vector2(12,52),Vector2(20,33)),Color("866344"))
	for y: int in [59,72,81]: draw_line(r.position+Vector2(12,y),r.position+Vector2(31,y),Color("b1986b"),2)
	for x: int in [28,145,159]:
		draw_line(r.position+Vector2(x,22),r.position+Vector2(x,42),Color("bba77b"),2)
		draw_rect(Rect2(r.position+Vector2(x-5,21),Vector2(12,5)),Color("a3aaa0"))

func _fountain(r: Rect2, palette: Array) -> void:
	var p: Vector2 = r.get_center()
	draw_rect(Rect2(p-Vector2(31,13),Vector2(62,26)),Color("6b7974"))
	draw_rect(Rect2(p-Vector2(27,10),Vector2(54,20)),Color("426b76"))
	draw_rect(Rect2(p-Vector2(23,8),Vector2(46,14)),Color("71a5a7"))
	draw_rect(Rect2(p-Vector2(5,22),Vector2(10,22)),Color(palette[3]))
	draw_rect(Rect2(p-Vector2(14,24),Vector2(28,6)),Color("b0b59e"))
	for side: int in [-1,1]:
		draw_line(p+Vector2(side*9,-18),p+Vector2(side*20,-2),Color("a9d1c3"),2)
		draw_rect(Rect2(p+Vector2(side*15,3),Vector2(8,1)),Color("b9d6ca"))

func _fire(p: Vector2, palette: Array) -> void:
	for offset: Vector2 in [Vector2(-14,-2),Vector2(-9,10),Vector2(5,12),Vector2(14,3),Vector2(7,-10),Vector2(-6,-11)]: draw_rect(Rect2(p+offset-Vector2(3,2),Vector2(6,4)),Color(palette[3]).darkened(0.15))
	for side: int in [-1,1]: draw_line(p+Vector2(side*-9,6),p+Vector2(side*8,-2),Color("8f6946"),4)
	var pulse: int = 0 if reduced_motion else int(sin(_elapsed*5)*2)
	draw_rect(Rect2(p+Vector2(-6,-9-pulse),Vector2(12,14+pulse)),Color("bb6441"))
	draw_rect(Rect2(p+Vector2(-3,-15+pulse),Vector2(6,19-pulse)),Color("e7a35e"))
	draw_rect(Rect2(p+Vector2(-2,-5),Vector2(4,9)),Color("f0d88c"))

func _draw_centerpiece(palette: Array) -> void:
	if layout.id == "barbarian":
		for p: Vector2 in [Vector2(280,136),Vector2(390,154)]:
			draw_rect(Rect2(p,Vector2(25,6)),Color("766043"))
			draw_rect(Rect2(p+Vector2(3,1),Vector2(19,2)),Color("9a7d52"))
	elif layout.id == "fairy":
		for p: Vector2 in [Vector2(194,154),Vector2(450,170),Vector2(342,208),Vector2(244,180)]:
			draw_rect(Rect2(p,Vector2(2,3)),Color("c5dfa8"))
			draw_rect(Rect2(p+Vector2(-2,3),Vector2(6,1)),Color("6f9d88"))
	elif layout.id == "dwarf":
		for p: Vector2 in [Vector2(259,190),Vector2(443,186)]:
			draw_rect(Rect2(p,Vector2(28,15)),Color("7d6648"))
			for x: int in [3,13,22]: draw_rect(Rect2(p+Vector2(x,0),Vector2(2,15)),Color("b7a483"))
	elif layout.id == "human":
		for p: Vector2 in [Vector2(235,155),Vector2(362,208)]:
			draw_rect(Rect2(p,Vector2(27,5)),Color("988466"))
			for x: int in [3,21]: draw_rect(Rect2(p+Vector2(x,5),Vector2(3,7)),Color("514d43"))
	elif layout.id == "beastman":
		for p: Vector2 in [Vector2(202,169),Vector2(424,169)]:
			draw_rect(Rect2(p+Vector2(-2,-19),Vector2(4,27)),Color("a1977a"))
			draw_rect(Rect2(p+Vector2(-5,-26),Vector2(10,9)),Color("d1c39b"))
			draw_rect(Rect2(p+Vector2(-3,-24),Vector2(6,5)),Color("e5d7a7"))
		var p := Vector2(312,191)
		for i: int in range(7):
			var angle: float = TAU*float(i)/7
			var q: Vector2 = (p+Vector2(cos(angle)*28,sin(angle)*16)).floor()
			draw_rect(Rect2(q-Vector2(3,2),Vector2(6,4)),Color(palette[3]).lightened(0.1))
	elif layout.id == "draconian":
		var p: Vector2 = cell_center(Vector2i(19,12))
		for radius: int in [22,31]:
			var ring := PackedVector2Array()
			for i: int in range(17):
				var angle: float = TAU*float(i)/16
				ring.append((p+Vector2(cos(angle)*radius,sin(angle)*radius*0.55)).floor())
			draw_polyline(ring,Color("94c2be"),1,false)
		for offset: Vector2 in [Vector2(-39,0),Vector2(39,0),Vector2(0,-23),Vector2(0,23)]:
			draw_rect(Rect2(p+offset-Vector2(2,2),Vector2(4,4)),Color("b4d4c9"))
		for pylon: Vector2 in [Vector2(102,158),Vector2(502,158)]:
			draw_rect(Rect2(pylon+Vector2(-10,-4),Vector2(20,7)),Color(palette[5]).darkened(0.2))

func _object(foot: Vector2, palette: Array, slot: int) -> void:
	draw_rect(Rect2(foot+Vector2(-8,-12),Vector2(16,12)),Color(palette[3]).darkened(0.2))
	if layout.id == "fairy":
		draw_circle(foot+Vector2(0,-18),6,Color(palette[4]))
		draw_rect(Rect2(foot+Vector2(-1,-21),Vector2(2,5)),Color(palette[5]))
	elif layout.id == "dwarf":
		draw_rect(Rect2(foot+Vector2(-12,-18),Vector2(24,5)),Color(palette[5]))
	else:
		draw_rect(Rect2(foot+Vector2(-5,-22),Vector2(10,12)),Color(palette[4]))
		draw_line(foot+Vector2(-3,-18),foot+Vector2(3,-18+slot%3),Color(palette[5]),1)

func _prompt(palette: Array) -> void:
	if _font == null: return
	draw_rect(Rect2(0,274,624,32),Color("121e25"))
	var point: Dictionary = nearby_point()
	if not _hover.is_empty():
		for candidate: Dictionary in interaction_points:
			if str(candidate.get("id","")) == _hover: point = candidate
	var text: String = "WASD / arrows: walk    E: interact    click: walk"
	if not point.is_empty(): text = ("E  " if _distance(player_cell,point.cell)<=1 else "Walk to  ")+str(point.get("name",""))
	draw_string(_font,Vector2(12,294),text,HORIZONTAL_ALIGNMENT_LEFT,600,17,Color(palette[5]))
