class_name ThirdFloorWorld
extends RefCounted
## Source-backed landscape identities with authored compact geometry. Neither
## exact coordinates nor the novel's multiday scale are recovered here. This
## generator has no dependency on DungeonWorld, avoiding a dispatch cycle.
const WIDTH: int=96
const HEIGHT: int=64
const FLOOR: int=0
const WALL: int=1
const WATER: int=2
const DIRECTIONS: Array[Vector2i]=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const TERRAINS: Array[String]=["ironrock_hills","orc_colony","witch_forest","dark_estuary"]
const SOURCE_HILL: String="https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/"
const SOURCE_WITCH: String="https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-64-65-66/"
const SOURCE_WITCH_ENTRY: String="https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-63"
const SOURCE_ALTAR: String="https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Third_Floor"
const SOURCE_ESTUARY: String="https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-115"

static func generate(seed_value: int, area_id: int, definition: Dictionary) -> Dictionary:
	var terrain: String=str(definition.get("terrain",""))
	if terrain not in TERRAINS or area_id<6: return {}
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^(area_id*1000003)
	var tiles: Array=[]
	for y: int in range(HEIGHT):
		var row: Array=[]; row.resize(WIDTH); row.fill(WALL); tiles.append(row)
	var map: Dictionary={"width":WIDTH,"height":HEIGHT,"tiles":tiles,"area":area_id,"floor":3,"seed":seed_value,"generator_version":4,"terrain":terrain,"rooms":[],"corridors":[],"spawns":[],"traps":[],"entrance":Vector2i(8,55),"exit":Vector2i(87,8),"loop_count":0,"source_geometry_status":"authored_compact_topology","geometry_note":"Landscape identities and cited landmarks follow the novel. Grid coordinates, paths, feature counts, enemy density and compressed travel scale are provisional."}
	match terrain:
		"ironrock_hills": _ironrock(map,rng)
		"orc_colony": _orc_woodland(map,rng)
		"witch_forest": _witch_woodland(map,rng)
		"dark_estuary": _estuary(map,rng)
	map["connection_sites"]={"west":Vector2i(8,32),"east":Vector2i(87,32),"north":Vector2i(48,7),"south":Vector2i(48,56)}
	# Neutral geometrical sites are not assigned destination regions. The source
	# connection graph belongs to campaign rules, not arbitrary biome numbering.
	for point: Vector2i in map.connection_sites.values(): _anchor(map,point,5)
	_anchor(map,map.entrance,5); _anchor(map,map.exit,5)
	map["inward_boundary"]=map.exit
	if terrain=="witch_forest": map["central_spire"]=map.exit
	if terrain=="dark_estuary":
		map["water_channels"]=[]
		for y: int in range(1,HEIGHT-1):
			for x: int in range(1,WIDTH-1):
				if int(map.tiles[y][x])==WATER: map.water_channels.append(Vector2i(x,y))
		map["shelter_mounds"]=[]
		for mound: Rect2i in map.dry_mounds: map.shelter_mounds.append(mound.get_center())
	_place_spawns(map,rng,60 if terrain=="orc_colony" else 44 if terrain!="dark_estuary" else 42)
	return map

static func _ironrock(map: Dictionary,rng: RandomNumberGenerator) -> void:
	map["layout_identity"]="elevated_ridges_and_passes"; map["reference_urls"]=[SOURCE_HILL]
	map["ridge_bands"]=[]
	var levels: Array[int]=[11,31,52]
	for level: int in levels:
		var shift: int=rng.randi_range(-1,1)
		var terrace:=Rect2i(5,level-5+shift,86,11)
		_room(map,terrace)
	for y: int in [19,40]: map.ridge_bands.append(Rect2i(4,y-2,88,5))
	for step: int in range(levels.size()-1):
		for lane: int in [18,48,78]:
			var x: int=lane+rng.randi_range(-4,4)
			_corridor(map,Vector2i(x,levels[step]),Vector2i(x,levels[step+1]),3,true)
		map.loop_count+=2
	map["overlook"]=Vector2i(48,11)
	_anchor(map,map.overlook,5)
	map["landmarks"]=[{"id":"hill_overlook","pos":map.overlook,"kind":"overlook"}]

static func _orc_woodland(map: Dictionary,rng: RandomNumberGenerator) -> void:
	map["layout_identity"]="dense_orc_woodland_clearings"; map["reference_urls"]=[SOURCE_HILL,SOURCE_ALTAR]
	map["orc_altar"]=Vector2i(48,32)
	_room(map,Rect2i(37,23,23,19),true)
	var sites: Array[Vector2i]=[]
	for y: int in [11,32,53]:
		for x: int in [12,34,61,83]:
			var point:=Vector2i(x+rng.randi_range(-2,2),y+rng.randi_range(-2,2))
			var width: int=rng.randi_range(12,16); var height: int=rng.randi_range(9,12)
			_room(map,Rect2i(point-Vector2i(width/2,height/2),Vector2i(width,height)),true)
			sites.append(point)
	_connect_graph(map,rng,5,6)
	map["encounter_sites"]=sites
	map["landmarks"]=[{"id":"orc_altar","pos":map.orc_altar,"kind":"altar","reference_url":SOURCE_ALTAR,"source_status":"secondary_landmark_authored_geometry"}]

static func _witch_woodland(map: Dictionary,rng: RandomNumberGenerator) -> void:
	map["layout_identity"]="mist_forest_looped_clearings"; map["reference_urls"]=[SOURCE_WITCH,SOURCE_WITCH_ENTRY]
	map.entrance=Vector2i(8,32); map.exit=Vector2i(48,32)
	var ring: Array[Vector2i]=[]
	for index: int in range(12):
		var angle: float=TAU*index/12.0
		var point:=Vector2i(48+roundi(cos(angle)*34)+rng.randi_range(-2,2),32+roundi(sin(angle)*20)+rng.randi_range(-2,2))
		_room(map,Rect2i(point-Vector2i(5,4),Vector2i(11,9)),true); ring.append(point)
	for index: int in range(ring.size()): _corridor(map,ring[index],ring[(index+1)%ring.size()],5,index%2==0)
	_room(map,Rect2i(42,26,13,13),true)
	for index: int in [0,4,8]: _corridor(map,ring[index],map.exit,5,index%2==0)
	map.loop_count=4
	map["hut_sites"]=[]
	for index: int in [1,3,5,7,9,11]: map.hut_sites.append(ring[index])
	# Purple trees lead into the separate cabin space; these are possible
	# forest entrances, not multiple simultaneous cottages or a ritual grant.
	map["witch_tree_sites"]=map.hut_sites.duplicate()
	map["witch_tree"]=map.hut_sites[rng.randi_range(0,map.hut_sites.size()-1)]
	map["landmarks"]=[{"id":"witch_tree","pos":map.witch_tree,"kind":"purple_tree"}]

static func _estuary(map: Dictionary,rng: RandomNumberGenerator) -> void:
	map["layout_identity"]="shallow_dark_channels_and_red_mounds"; map["reference_urls"]=[SOURCE_ESTUARY]
	_room(map,Rect2i(4,4,88,56))
	var river_points: Array[Vector2i]=[]
	for y: int in range(7,58,8): river_points.append(Vector2i(40+rng.randi_range(-8,8),y))
	for index: int in range(river_points.size()-1): _water_corridor(map,river_points[index],river_points[index+1],5)
	for y: int in [15,31,47]:
		_water_corridor(map,Vector2i(6,y+rng.randi_range(-3,3)),Vector2i(88,y+rng.randi_range(-3,3)),3)
	map["dry_mounds"]=[]
	for point: Vector2i in [Vector2i(15,13),Vector2i(70,12),Vector2i(20,34),Vector2i(77,36),Vector2i(28,51),Vector2i(64,52)]:
		var mound:=Rect2i(point-Vector2i(4,3),Vector2i(9,7)); _room(map,mound,true); map.dry_mounds.append(mound)
	map["water_channels"]=[]
	for y: int in range(1,HEIGHT-1):
		for x: int in range(1,WIDTH-1):
			if int(map.tiles[y][x])==WATER: map.water_channels.append(Vector2i(x,y))
	map["landmarks"]=[]
	for index: int in range(map.dry_mounds.size()): map.landmarks.append({"id":"dry_mound_"+str(index),"pos":map.dry_mounds[index].get_center(),"kind":"dry_mound"})
	map.loop_count=4

static func _room(map: Dictionary,rectangle: Rect2i,bevel: bool=false) -> void:
	var room: Rect2i=rectangle.intersection(Rect2i(1,1,WIDTH-2,HEIGHT-2))
	map.rooms.append(room)
	for y: int in range(room.position.y,room.end.y):
		for x: int in range(room.position.x,room.end.x):
			if bevel and mini(x-room.position.x,room.end.x-1-x)+mini(y-room.position.y,room.end.y-1-y)<2: continue
			map.tiles[y][x]=FLOOR

static func _anchor(map: Dictionary,point: Vector2i,width: int) -> void:
	var nearest: Vector2i=map.rooms[0].get_center(); var best: int=100000
	for room: Rect2i in map.rooms:
		var length: int=_distance(point,room.get_center())
		if length<best: best=length; nearest=room.get_center()
	_room(map,Rect2i(point-Vector2i(3,3),Vector2i(7,7)))
	_corridor(map,point,nearest,width,true)

static func _connect_graph(map: Dictionary,rng: RandomNumberGenerator,width: int,extra: int) -> void:
	var connected: Dictionary={0:true}; var edges: Dictionary={}
	while connected.size()<map.rooms.size():
		var a_best: int=-1; var b_best: int=-1; var score: int=100000
		for a: int in connected:
			for b: int in range(map.rooms.size()):
				if connected.has(b): continue
				var value: int=_distance(map.rooms[a].get_center(),map.rooms[b].get_center())+rng.randi_range(0,5)
				if value<score: score=value; a_best=a; b_best=b
		_corridor(map,map.rooms[a_best].get_center(),map.rooms[b_best].get_center(),width,rng.randf()<0.5)
		connected[b_best]=true; edges[_edge(a_best,b_best)]=true
	for attempt: int in range(extra*8):
		if int(map.loop_count)>=extra: break
		var a: int=rng.randi_range(0,map.rooms.size()-1); var b: int=rng.randi_range(0,map.rooms.size()-1)
		if a==b or edges.has(_edge(a,b)): continue
		_corridor(map,map.rooms[a].get_center(),map.rooms[b].get_center(),width,rng.randf()<0.5)
		edges[_edge(a,b)]=true; map.loop_count+=1

static func _edge(a: int,b: int) -> String: return "%d:%d" % [mini(a,b),maxi(a,b)]
static func _distance(a: Vector2i,b: Vector2i) -> int: return absi(a.x-b.x)+absi(a.y-b.y)
static func _corridor(map: Dictionary,from: Vector2i,to: Vector2i,width: int,horizontal: bool) -> void:
	_paint_path(map.tiles,from,to,width,FLOOR,horizontal)
	map.corridors.append({"from":from,"to":to,"width":width,"bend":Vector2i(to.x,from.y) if horizontal else Vector2i(from.x,to.y)})
static func _water_corridor(map: Dictionary,from: Vector2i,to: Vector2i,width: int) -> void: _paint_path(map.tiles,from,to,width,WATER,true)
static func _paint_path(tiles: Array,from: Vector2i,to: Vector2i,width: int,value: int,horizontal: bool) -> void:
	var point: Vector2i=from
	while true:
		for y: int in range(point.y-width/2,point.y+width/2+1):
			for x: int in range(point.x-width/2,point.x+width/2+1):
				if x>0 and y>0 and x<WIDTH-1 and y<HEIGHT-1: tiles[y][x]=value
		if point==to: break
		if (horizontal and point.x!=to.x) or point.y==to.y: point.x+=signi(to.x-point.x)
		else: point.y+=signi(to.y-point.y)

static func _walkable(map: Dictionary,point: Vector2i) -> bool:
	return point.x>=0 and point.y>=0 and point.x<int(map.width) and point.y<int(map.height) and int(map.tiles[point.y][point.x]) in [FLOOR,WATER]
static func _clear(map: Dictionary,point: Vector2i) -> bool:
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			if not _walkable(map,point+Vector2i(x,y)): return false
	return true
static func reached(map: Dictionary,start: Vector2i,wide: bool=false) -> Dictionary:
	var seen: Dictionary={}
	if not _walkable(map,start) or (wide and not _clear(map,start)): return seen
	seen[start]=0; var queue: Array[Vector2i]=[start]; var cursor: int=0
	while cursor<queue.size():
		var point: Vector2i=queue[cursor]; cursor+=1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i=point+direction
			if seen.has(next) or not _walkable(map,next) or (wide and not _clear(map,next)): continue
			seen[next]=int(seen[point])+1; queue.append(next)
	return seen

static func _place_spawns(map: Dictionary,rng: RandomNumberGenerator,target: int) -> void:
	var reserved: Array[Vector2i]=[map.entrance,map.exit]
	reserved.append_array(map.connection_sites.values())
	reserved.append_array(map.get("hut_sites",[]))
	for point: Variant in [map.get("orc_altar"),map.get("overlook"),map.get("witch_tree")]:
		if point is Vector2i: reserved.append(point)
	var candidates: Array[Vector2i]=[]
	for y: int in range(3,HEIGHT-3):
		for x: int in range(3,WIDTH-3):
			var point:=Vector2i(x,y)
			if int(map.tiles[y][x])!=FLOOR or not _clear(map,point): continue
			var clear: bool=true
			for anchor: Vector2i in reserved:
				if _distance(point,anchor)<8: clear=false; break
			if clear: candidates.append(point)
	for index: int in range(candidates.size()-1,0,-1):
		var other: int=rng.randi_range(0,index); var value: Vector2i=candidates[index]; candidates[index]=candidates[other]; candidates[other]=value
	for point: Vector2i in candidates:
		var clear: bool=true
		for occupied: Vector2i in map.spawns:
			if _distance(point,occupied)<4: clear=false; break
		if clear: map.spawns.append(point)
		if map.spawns.size()==target: break
	map["encounter_count_estimate"]=target

static func validate(map: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	if map.get("terrain") not in TERRAINS: errors.append("Unsupported third-floor terrain")
	for field: String in ["width","height","area","floor","generator_version"]:
		if not _integer(map.get(field)): errors.append("Invalid third-floor integer: "+field)
	if not errors.is_empty(): return errors
	if int(map.floor)!=3 or int(map.area)<6 or int(map.generator_version)!=4: errors.append("Invalid third-floor identity/version")
	if int(map.width)!=WIDTH or int(map.height)!=HEIGHT or not map.get("tiles") is Array or map.tiles.size()!=HEIGHT: errors.append("Third-floor dimensions must be96x64"); return errors
	for row: Variant in map.tiles:
		if not row is Array or row.size()!=WIDTH: errors.append("Invalid third-floor tile row"); return errors
		for tile: Variant in row:
			if not _integer(tile) or int(tile) not in [FLOOR,WALL,WATER]: errors.append("Unsupported third-floor hazard or tile"); return errors
	if not map.get("entrance") is Vector2i or not map.get("exit") is Vector2i: errors.append("Missing third-floor route coordinates"); return errors
	var connected: Dictionary=reached(map,map.entrance)
	if not connected.has(map.exit) or map.entrance==map.exit: errors.append("Third-floor routes must be connected and distinct")
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var point:=Vector2i(x,y)
			if (x==0 or y==0 or x==WIDTH-1 or y==HEIGHT-1) and int(map.tiles[y][x])!=WALL: errors.append("Open third-floor boundary")
			if _walkable(map,point) and not connected.has(point): errors.append("Disconnected third-floor terrain")
	if not map.get("connection_sites") is Dictionary: errors.append("Connection sites must be named coordinates")
	else:
		for direction: Variant in map.connection_sites:
			var point: Variant=map.connection_sites[direction]
			if direction not in ["north","south","east","west"] or not point is Vector2i: errors.append("Invalid neutral connection site"); continue
			if not connected.has(point) or not _clear(map,point): errors.append("Connection site must have a clear reachable arrival")
	for field: String in ["hut_sites","witch_tree_sites","shelter_mounds","water_channels","encounter_sites"]:
		if not map.has(field): continue
		if not map[field] is Array or map[field].size()>WIDTH*HEIGHT: errors.append("Invalid third-floor coordinate array: "+field); continue
		var seen: Dictionary={}
		for point: Variant in map[field]:
			if not point is Vector2i: errors.append("Invalid "+field+" position"); continue
			if not connected.has(point) or seen.has(point): errors.append("Unreachable/duplicate "+field+" position")
			seen[point]=true
			if field=="water_channels" and connected.has(point) and int(map.tiles[point.y][point.x])!=WATER: errors.append("Water-channel position must contain shallow water")
			if field in ["hut_sites","shelter_mounds"] and (not _clear(map,point) or int(map.tiles[point.y][point.x])!=FLOOR): errors.append(field+" requires a clear dry approach")
	for field: String in ["orc_altar","overlook","witch_tree","central_spire","inward_boundary"]:
		if not map.has(field): continue
		var point: Variant=map[field]
		if not point is Vector2i or not connected.has(point): errors.append("Unreachable third-floor landmark: "+field)
	if map.has("witch_tree") and (not map.get("hut_sites") is Array or not map.hut_sites.has(map.witch_tree)): errors.append("Active purple tree must use a prepared entrance site")
	if map.has("central_spire") and map.terrain!="witch_forest": errors.append("The central spire route belongs to Witch Forest")
	if map.has("dry_mounds"):
		if not map.dry_mounds is Array or map.dry_mounds.size()>64: errors.append("Invalid dry mound bounds")
		else:
			for mound: Variant in map.dry_mounds:
				if not mound is Rect2i: errors.append("Dry mound requires rectangle bounds"); continue
				if mound.position.x<1 or mound.position.y<1 or mound.end.x>=WIDTH or mound.end.y>=HEIGHT or mound.size.x<3 or mound.size.y<3 or not connected.has(mound.get_center()): errors.append("Invalid/unreachable dry mound")
	var occupied: Dictionary={map.entrance:true,map.exit:true}
	if not map.get("spawns") is Array: errors.append("Third-floor spawns must be coordinates"); return errors
	for point: Variant in map.spawns:
		if not point is Vector2i: errors.append("Invalid third-floor encounter coordinate"); continue
		if not connected.has(point) or int(map.tiles[point.y][point.x])!=FLOOR: errors.append("Encounter must be on reachable dry terrain")
		if occupied.has(point): errors.append("Overlapping third-floor encounter")
		if _distance(point,map.entrance)<6 or _distance(point,map.exit)<6: errors.append("Encounter too close to a route")
		occupied[point]=true
	return errors

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
