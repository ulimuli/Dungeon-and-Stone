class_name DungeonWorld
extends RefCounted
## Nine researched areas use provisional, reproducible procedural geography.
## This module places terrain, safe portals, encounters and environmental points.
## Campaign interaction/resource/hazard resolution belongs to the simulation.
const WIDTH: int = 96
const HEIGHT: int = 64
const MIN_CORRIDOR_WIDTH: int = 3
const FLOOR: int = 0
const WALL: int = 1
const WATER: int = 2
const HAZARD: int = 3
const DOOR: int = 4
const SECRET: int = 5
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const AREA_NAMES: Array[String] = ["Crystal Cave", "Goblin Forest", "Land of the Dead", "Black Rock Mountain", "Den of Beasts"]

static func generate(seed_value: int, area: int) -> Dictionary:
	if area>=6:
		var third_map: Dictionary=ThirdFloorWorld.generate(seed_value,area,ThirdFloorContent.regions().values()[area-6])
		FloorConnections.attach(third_map,area)
		return third_map
	var area_index: int = clampi(area, 1, 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ (area_index * 1000003)
	var tiles: Array = []
	for y: int in range(HEIGHT):
		var row: Array = []; row.resize(WIDTH); row.fill(WALL); tiles.append(row)
	# Two authored portal chambers anchor a variable room graph. Room packing,
	# spanning connections and loops vary independently of a fixed room grid.
	var corner: int = rng.randi_range(0,3)
	var start: Vector2i = Vector2i(4 if corner%2 == 0 else WIDTH-14, HEIGHT-13 if corner < 2 else 3)
	# Ordinary first-floor arrivals are crystal-lit; the novel's dark spawn is
	# exceptional. Keep seeded corner variety without spawning in outer darkness.
	if area_index==1: start=Vector2i(8 if corner%2==0 else WIDTH-18,HEIGHT-17 if corner<2 else 7)
	var destination: Vector2i = Vector2i(WIDTH-18 if corner%2 == 0 else 4, 4 if corner < 2 else HEIGHT-15)
	var rooms: Array[Rect2i] = [Rect2i(start,Vector2i(10,10)),Rect2i(destination,Vector2i(13,11))]
	var target_rooms: int = rng.randi_range(17,22) if area_index!=5 else rng.randi_range(16,19)
	for attempt: int in range(650):
		if rooms.size() >= target_rooms: break
		var width: int = rng.randi_range(10, 17) if area_index == 2 else rng.randi_range(8, 15)
		var height: int = rng.randi_range(8, 13) if area_index == 2 else rng.randi_range(7, 12)
		var candidate := Rect2i(rng.randi_range(3, WIDTH-width-4), rng.randi_range(3, HEIGHT-height-4), width, height)
		var clear: bool = true
		for room: Rect2i in rooms:
			if candidate.grow(2).intersects(room): clear = false; break
		if clear: rooms.append(candidate)
	for room: Rect2i in rooms:
		if area_index==5: _carve_beast_cave(tiles,room)
		else: _carve_room(tiles, room)
	# Cover leaves at least three lanes on every side. Corridors are carved
	# afterward so a pillar can never pinch a mandatory route.
	if area_index in [3,4]:
		for index: int in range(2, rooms.size()):
			var room: Rect2i = rooms[index]
			if room.size.x >= 12 and room.size.y >= 10 and index % 2 == 0:
				for y: int in range(room.position.y+3, room.position.y+5):
					for x: int in range(room.position.x+4, room.position.x+6): tiles[y][x] = WALL
	var corridors: Array = []
	var edges: Dictionary = {}
	var connected: Dictionary = {0:true}
	while connected.size() < rooms.size():
		var best_a: int = -1; var best_b: int = -1; var best: int = 100000
		for a: int in connected:
			for b: int in range(rooms.size()):
				if connected.has(b): continue
				var score: int = _distance(rooms[a].get_center(), rooms[b].get_center()) + rng.randi_range(0,8)
				if score < best: best = score; best_a = a; best_b = b
		_connect_rooms(tiles,rooms,best_a,best_b,area_index,rng,corridors,edges)
		connected[best_b] = true
	var loops: int = 0
	for attempt: int in range(120):
		if loops >= maxi(3, rooms.size()/3): break
		var a: int = rng.randi_range(0,rooms.size()-1); var b: int = rng.randi_range(0,rooms.size()-1)
		if a == b or edges.has(_edge_key(a,b)) or _distance(rooms[a].get_center(),rooms[b].get_center()) > 52: continue
		_connect_rooms(tiles,rooms,a,b,area_index,rng,corridors,edges); loops += 1
	var entrance: Vector2i = rooms[0].get_center()
	var map: Dictionary = {"width":WIDTH,"height":HEIGHT,"tiles":tiles,"entrance":entrance,"exit":rooms[1].get_center(),"spawns":[],"traps":[],"rooms":rooms,"seed":seed_value,"area":area_index,"corridors":corridors,"loop_count":loops,"generator_version":3}
	# The four outskirts steles are separate ordinary routes. The memorial at
	# the center is a dark landmark, never a fifth ordinary region selector.
	if area_index==1: _add_first_floor_landmarks(map)
	if area_index==5:
		map["beast_caves"]=[]
		for index: int in range(2,rooms.size()): map.beast_caves.append(rooms[index])
		map["layout_identity"]="cliff_canyons_and_caves"
	var distances: Dictionary = reachable(map,entrance)
	var farthest: int = -1
	for point: Vector2i in distances:
		if point.x < 4 or point.x >= WIDTH-4 or point.y < 4 or point.y >= HEIGHT-4: continue
		if int(distances[point]) > farthest and _clear_square(map,point,1): map.exit = point; farthest = int(distances[point])
	if area_index==1:
		# Compatibility view for older UI/tests aliases an actual outskirts gate.
		farthest=-1
		for gate: Dictionary in map.area_portals:
			if int(distances.get(gate.pos,0))>farthest: map.exit=gate.pos; farthest=int(distances.get(gate.pos,0))
	_carve_room(tiles,Rect2i(map.exit-Vector2i(3,3),Vector2i(7,7)))
	var candidates: Array[Vector2i] = []
	for y: int in range(3,HEIGHT-3):
		for x: int in range(3,WIDTH-3):
			var point := Vector2i(x,y)
			if _distance(point,entrance)<14 or _distance(point,map.exit)<10 or not _clear_square(map,point,1): continue
			if not _clear_of_landmarks(map,point,10): continue
			candidates.append(point)
	_shuffle(candidates,rng)
	if area_index==5:
		var cave_points: Array[Vector2i]=[]; var roaming: Array[Vector2i]=[]
		for point: Vector2i in candidates:
			var in_cave: bool=false
			for cave: Rect2i in map.beast_caves:
				if cave.grow(-1).has_point(point): in_cave=true; break
			if in_cave: cave_points.append(point)
			else: roaming.append(point)
		candidates=cave_points+roaming
	var trap_count: int = 6 if area_index == 1 else 10 if area_index == 2 else 0
	if area_index==1:
		# Ordinary goblin traps belong to their northern first-floor habitat.
		for point: Vector2i in candidates:
			if first_floor_sector(map,point)=="north": map.traps.append(point)
			if map.traps.size()==trap_count: break
		candidates=candidates.filter(func(point: Vector2i)->bool:return not map.traps.has(point))
	else:
		for index: int in range(trap_count): map.traps.append(candidates.pop_back())
	var spawn_count: int = 32 + area_index * 4
	for point: Vector2i in candidates:
		if map.spawns.size() >= spawn_count: break
		var clear: bool = true
		for occupied: Vector2i in map.spawns:
			if _distance(point,occupied) < 4: clear = false; break
		if clear: map.spawns.append(point)
	# Newly generated Land of the Dead contains no invented choking-mist
	# hazard. Legacy HAZARD saves and the generic breath consumer remain valid.

	_add_optional_features(map,rng)
	FloorConnections.attach(map,area_index)
	return map


static func _add_first_floor_landmarks(map: Dictionary) -> void:
	var center:=Vector2i(WIDTH/2,HEIGHT/2)
	map["central_memorial"]=center
	map["memorial_radius_estimate"]=6
	map["dark_outskirts_width"]=10
	map["layout_identity"]="crystal_cave_four_cardinal_routes"
	map["area_portals"]=[
		{"pos":Vector2i(WIDTH/2,6),"region":2,"direction":"north","direction_verified":true},
		{"pos":Vector2i(6,HEIGHT/2),"region":3,"direction":"west","direction_verified":true},
		{"pos":Vector2i(WIDTH/2,HEIGHT-7),"region":4,"direction":"south","direction_verified":true},
		{"pos":Vector2i(WIDTH-7,HEIGHT/2),"region":5,"direction":"east","direction_verified":true}
	]
	# Geometry, tile dimensions and crystal spacing are authored estimates.
	# Direction/biome associations follow original chapters11/12/23/27/50.
	var anchors: Array[Vector2i]=[center]
	for gate: Dictionary in map.area_portals: anchors.append(gate.pos)
	for point: Vector2i in anchors:
		var nearest: Vector2i=map.rooms[0].get_center(); var shortest: int=100000
		for room: Rect2i in map.rooms:
			var length: int=_distance(point,room.get_center())
			if length<shortest: shortest=length; nearest=room.get_center()
		_carve_room(map.tiles,Rect2i(point-Vector2i(4,4),Vector2i(9,9)))
		_carve_wide_corridor(map.tiles,point,nearest,true,3)
	map["crystal_lights"]=[]
	for room: Rect2i in map.rooms:
		var point: Vector2i=room.get_center()
		if not is_dark_zone(map,point): map.crystal_lights.append(point)

static func _clear_of_landmarks(map: Dictionary, point: Vector2i, margin: int) -> bool:
	for gate: Dictionary in map.get("area_portals",[]):
		if _distance(point,gate.pos)<margin: return false
	if map.get("central_memorial") is Vector2i and _distance(point,map.central_memorial)<3: return false
	return true

static func is_dark_zone(map: Dictionary, point: Vector2i) -> bool:
	if int(map.get("area",0))!=1: return false
	# Legacy maps retain their old presentation unless new metadata is present.
	if not map.has("area_portals"): return false
	var margin: int=int(map.get("dark_outskirts_width",10))
	if point.x<margin or point.y<margin or point.x>=int(map.width)-margin or point.y>=int(map.height)-margin: return true
	if map.get("central_memorial") is Vector2i:
		var delta: Vector2i=point-map.central_memorial
		var radius: int=int(map.get("memorial_radius_estimate",6))
		if delta.length_squared()<=radius*radius: return true
	return false

static func first_floor_sector(map: Dictionary, point: Vector2i) -> String:
	var center: Vector2i=map.get("central_memorial",Vector2i(int(map.width)/2,int(map.height)/2))
	var delta: Vector2i=point-center
	if delta.length_squared()<=int(map.get("memorial_radius_estimate",6))*int(map.get("memorial_radius_estimate",6)): return "center"
	# Normalize for this rectangular logical map; exact borders are estimates.
	if absf(float(delta.x)/float(map.width))>absf(float(delta.y)/float(map.height)): return "east" if delta.x>0 else "west"
	return "south" if delta.y>0 else "north"

static func _carve_beast_cave(tiles: Array, room: Rect2i) -> void:
	# Beveled cave pockets sit behind thick rock faces rather than square halls.
	for y: int in range(room.position.y,room.end.y):
		for x: int in range(room.position.x,room.end.x):
			var edge_x: int=mini(x-room.position.x,room.end.x-1-x)
			var edge_y: int=mini(y-room.position.y,room.end.y-1-y)
			if edge_x+edge_y>=2: tiles[y][x]=FLOOR


static func _add_optional_features(map: Dictionary, rng: RandomNumberGenerator) -> void:
	var field: String="corpse_flowers" if int(map.area)==3 else "sewage_pits" if int(map.area)==5 else ""
	if field.is_empty(): return
	var target: int=6 if int(map.area)==3 else 5
	map[field]=[]
	var candidates: Array[Vector2i]=[]
	for room: Rect2i in map.rooms:
		for y: int in range(room.position.y+2,room.end.y-2):
			for x: int in range(room.position.x+2,room.end.x-2):
				var point:=Vector2i(x,y)
				if tile_at(map,point)!=FLOOR or not _clear_square(map,point,1) or _distance(point,map.entrance)<10 or _distance(point,map.exit)<8: continue
				var clear: bool=true
				for occupied: Vector2i in map.spawns+map.traps:
					if _distance(point,occupied)<3: clear=false; break
				if clear: candidates.append(point)
	_shuffle(candidates,rng)
	for point: Vector2i in candidates:
		var clear: bool=true
		for occupied: Vector2i in map[field]:
			if _distance(point,occupied)<8: clear=false; break
		if clear: map[field].append(point)
		if map[field].size()==target: break

static func tile_at(map: Dictionary, point: Vector2i) -> int:
	if point.x<0 or point.y<0 or point.y>=int(map.get("height",0)) or point.x>=int(map.get("width",0)): return WALL
	return int(map.tiles[point.y][point.x])

static func _edge_key(a: int,b: int) -> String:
	return "%d:%d" % [mini(a,b),maxi(a,b)]

static func _connect_rooms(tiles: Array, rooms: Array[Rect2i], a: int, b: int, area: int, rng: RandomNumberGenerator, corridors: Array, edges: Dictionary) -> void:
	var from: Vector2i = rooms[a].get_center(); var to: Vector2i = rooms[b].get_center()
	var wide: int = 5 if area == 2 else MIN_CORRIDOR_WIDTH
	var horizontal: bool = rng.randf() < 0.5
	_carve_wide_corridor(tiles,from,to,horizontal,wide)
	corridors.append({"from":from,"to":to,"bend":Vector2i(to.x,from.y) if horizontal else Vector2i(from.x,to.y),"width":wide})
	edges[_edge_key(a,b)] = true

static func _carve_wide_corridor(tiles: Array, from: Vector2i, to: Vector2i, horizontal_first: bool, width: int) -> void:
	var point: Vector2i = from; var radius: int = width/2
	while true:
		for y: int in range(point.y-radius,point.y+radius+1):
			for x: int in range(point.x-radius,point.x+radius+1):
				if x > 0 and y > 0 and y < tiles.size()-1 and x < tiles[0].size()-1: tiles[y][x] = FLOOR
		if point == to: break
		if (horizontal_first and point.x != to.x) or point.y == to.y: point.x += signi(to.x-point.x)
		else: point.y += signi(to.y-point.y)

static func _clear_square(map: Dictionary, center: Vector2i, radius: int) -> bool:
	for y: int in range(center.y-radius,center.y+radius+1):
		for x: int in range(center.x-radius,center.x+radius+1):
			if not walkable(map,Vector2i(x,y)): return false
	return true

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _carve_room(tiles: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x): tiles[y][x] = FLOOR

static func _carve_corridor(tiles: Array, from: Vector2i, to: Vector2i, horizontal_first: bool, broad: bool) -> void:
	var p := from
	while true:
		tiles[p.y][p.x] = FLOOR
		if broad and p.x + 1 < 37: tiles[p.y][p.x + 1] = FLOOR
		if p == to: break
		if (horizontal_first and p.x != to.x) or p.y == to.y: p.x += signi(to.x - p.x)
		else: p.y += signi(to.y - p.y)

static func _shuffle(values: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[other]; values[other] = temporary

static func walkable(map: Dictionary, pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= int(map.get("width", 0)) or pos.y >= int(map.get("height", 0)): return false
	return int(map.tiles[pos.y][pos.x]) in [FLOOR, WATER, HAZARD, DOOR]

static func reachable(map: Dictionary, start: Vector2i, block_doors: bool = false) -> Dictionary:
	var result: Dictionary = {}
	if not walkable(map,start): return result
	var width: int = int(map.width); var height: int = int(map.height)
	var tiles: Array = map.tiles
	var distances := PackedInt32Array(); distances.resize(width*height); distances.fill(-1)
	var queue: Array[Vector2i] = [start]
	distances[start.y*width+start.x] = 0; result[start] = 0
	var cursor: int = 0
	while cursor < queue.size():
		var point: Vector2i = queue[cursor]; cursor += 1
		var next_distance: int = distances[point.y*width+point.x]+1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = point+direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height: continue
			var index: int = next.y*width+next.x
			if distances[index] >= 0: continue
			var tile: int = int(tiles[next.y][next.x])
			if tile != FLOOR and tile != WATER and tile != HAZARD and tile != DOOR: continue
			if block_doors and tile == DOOR: continue
			distances[index] = next_distance; result[next] = next_distance; queue.append(next)
	return result

static func line_of_sight(map: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	if from.x < 0 or from.y < 0 or to.x < 0 or to.y < 0 or from.x >= int(map.width) or to.x >= int(map.width) or from.y >= int(map.height) or to.y >= int(map.height): return false
	var p := from
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var error := dx + dy
	while true:
		if p == to: return true
		if p != from and _opaque(map, p): return false
		var twice := error * 2
		if twice >= dy and twice <= dx:
			if _opaque(map, p + Vector2i(sx, 0)) and _opaque(map, p + Vector2i(0, sy)): return false
		if twice >= dy: error += dy; p.x += sx
		if twice <= dx: error += dx; p.y += sy
	return false

static func _opaque(map: Dictionary, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= int(map.width) or p.y >= int(map.height): return true
	return int(map.tiles[p.y][p.x]) in [WALL, SECRET, DOOR]

static func validate(map: Dictionary) -> Array[String]:
	if int(map.get("area",0))>=6: return ThirdFloorWorld.validate(map)
	var errors: Array[String] = []
	var width: int = int(map.get("width", 0))
	var height: int = int(map.get("height", 0))
	if width < 3 or height < 3 or map.get("tiles", []).size() != height:
		errors.append("Invalid map dimensions or row count"); return errors
	for row in map.tiles:
		if row.size() != width: errors.append("Invalid map row width"); return errors
	for y in range(height):
		for x in range(width):
			if int(map.tiles[y][x]) < FLOOR or int(map.tiles[y][x]) > SECRET: errors.append("Unknown tile at %s" % Vector2i(x, y))
			if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and int(map.tiles[y][x]) != WALL: errors.append("Open map boundary at %s" % Vector2i(x, y))
	if not map.has("entrance") or not map.has("exit"):
		errors.append("Missing area portal coordinates"); return errors
	var seen := reachable(map, map.entrance)
	if not seen.has(map.exit) or map.entrance == map.exit: errors.append("Area portals must be distinct and connected")
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if walkable(map, p) and not seen.has(p): errors.append("Disconnected walkable tile at %s" % p)
	var landmark_errors: Array[String]=validate_landmarks(map,seen)
	errors.append_array(landmark_errors)
	if not landmark_errors.is_empty(): return errors
	errors.append_array(validate_optional_features(map,seen))
	var occupied: Dictionary = {map.entrance: true, map.exit: true}
	for field in ["spawns", "traps"]:
		for p: Vector2i in map.get(field, []):
			if not seen.has(p) or int(map.tiles[p.y][p.x]) != FLOOR: errors.append("%s must be on reachable floor at %s" % [field, p])
			if occupied.has(p): errors.append("Overlapping %s at %s" % [field, p])
			if _distance(p, map.entrance) < 6 or _distance(p, map.exit) < 6 or not _clear_of_landmarks(map,p,6): errors.append("%s placed too close to an area portal or landmark" % field)
			occupied[p] = true
	return errors

static func validate_landmarks(map: Dictionary, seen: Dictionary = {}) -> Array[String]:
	var errors: Array[String]=[]
	if not map.has("area_portals"):
		for field: String in ["central_memorial","memorial_radius_estimate","dark_outskirts_width","crystal_lights"]:
			if map.has(field): errors.append("Incomplete Crystal Cave landmark metadata: missing area_portals")
		return errors
	if int(map.get("area",0))!=1: errors.append("Cardinal portals belong only to Crystal Cave")
	if not map.area_portals is Array: errors.append("area_portals must be an array"); return errors
	if map.area_portals.size()!=4: errors.append("Crystal Cave requires four cardinal portals")
	var reached: Dictionary=seen if not seen.is_empty() else reachable(map,map.get("entrance",Vector2i(-1,-1)))
	var positions: Dictionary={}; var regions: Dictionary={}; var directions: Dictionary={}
	var expected: Dictionary={"north":2,"west":3,"south":4,"east":5}
	for gate: Variant in map.area_portals:
		if not gate is Dictionary: errors.append("Cardinal portal must be an object"); continue
		if not gate.get("pos") is Vector2i: errors.append("Cardinal portal pos must be Vector2i"); continue
		if not gate.get("direction") is String or not expected.has(gate.get("direction")): errors.append("Unknown cardinal portal direction"); continue
		if not (gate.get("region") is int or gate.get("region") is float) or not is_finite(float(gate.get("region",0))) or float(gate.region)!=float(expected[gate.direction]): errors.append("Cardinal portal has wrong region for direction")
		if not gate.get("direction_verified") is bool or gate.direction_verified!=true: errors.append("Cardinal direction provenance must be explicit")
		if first_floor_sector({"width":map.width,"height":map.height},gate.pos)!=str(gate.direction): errors.append("Cardinal portal is outside its declared compass sector")
		if positions.has(gate.pos) or regions.has(gate.get("region")) or directions.has(gate.direction): errors.append("Duplicate cardinal portal position, region or direction")
		positions[gate.pos]=true; regions[gate.get("region")]=true; directions[gate.direction]=true
		if not reached.has(gate.pos) or not _clear_square(map,gate.pos,1): errors.append("Cardinal portal requires a reachable safe3x3 arrival")
	if not map.get("central_memorial") is Vector2i or not reached.has(map.get("central_memorial")): errors.append("Central memorial must be reachable")
	elif not _clear_square(map,map.central_memorial,1): errors.append("Central memorial requires clear approach space")
	var valid_dark_bounds: bool=true
	for key: String in ["dark_outskirts_width","memorial_radius_estimate"]:
		var value: Variant=map.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or float(value)<1 or float(value)>20:
			errors.append("Invalid dark-zone bound: "+key); valid_dark_bounds=false
	if not map.get("crystal_lights") is Array: errors.append("Crystal light positions must be an array")
	else:
		for point: Variant in map.crystal_lights:
			if not point is Vector2i or not reached.has(point): errors.append("Crystal light must be on reachable ground")
			elif valid_dark_bounds and is_dark_zone(map,point): errors.append("Crystal light cannot illuminate a documented dark zone")
	return errors

static func validate_optional_features(map: Dictionary, seen: Dictionary = {}) -> Array[String]:
	var errors: Array[String]=[]
	var reached: Dictionary=seen if not seen.is_empty() else reachable(map,map.get("entrance",Vector2i(-1,-1)))
	if map.has("beast_caves"):
		if int(map.get("area",0))!=5: errors.append("Beast caves belong to Den of Beasts")
		if not map.beast_caves is Array: errors.append("beast_caves must be an array")
		elif map.beast_caves.size()>64: errors.append("Too many beast caves")
		else:
			for cave: Variant in map.beast_caves:
				if not cave is Rect2i: errors.append("Beast cave must have rectangle bounds"); continue
				if cave.position.x<1 or cave.position.y<1 or cave.size.x<3 or cave.size.y<3 or cave.end.x>=int(map.width) or cave.end.y>=int(map.height): errors.append("Invalid beast cave bounds")
				elif not reached.has(cave.get_center()): errors.append("Beast cave center must be reachable")
	for field: String in ["corpse_flowers","sewage_pits"]:
		if not map.has(field): continue
		if int(map.get("area",0))!=(3 if field=="corpse_flowers" else 5): errors.append(field+" belongs to its documented biome")
		if not map[field] is Array: errors.append(field+" must be an array"); continue
		if map[field].size()>64: errors.append("Too many "+field); continue
		var occupied: Dictionary={}
		for point: Variant in map[field]:
			if not point is Vector2i: errors.append(field+" must contain coordinates"); continue
			if occupied.has(point): errors.append("Duplicate "+field+" coordinate")
			occupied[point]=true
			if not reached.has(point) or tile_at(map,point)!=FLOOR: errors.append(field+" must be on reachable floor")
			if map.get("spawns",[]).has(point) or map.get("traps",[]).has(point): errors.append(field+" cannot overlap a spawn or trap")
			if _distance(point,map.entrance)<6 or _distance(point,map.exit)<6: errors.append(field+" too close to an area portal")
	return errors
