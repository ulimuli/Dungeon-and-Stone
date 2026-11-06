extends SceneTree
## The sources establish biome routes and dark landmarks, not this compact
## grid, meter conversion, feature counts, packing or encounter density.
const World=preload("res://game/world.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func clear_center(map: Dictionary, point: Vector2i) -> bool:
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			if not World.walkable(map,point+Vector2i(x,y)): return false
	return true
func wide_reached(map: Dictionary) -> Dictionary:
	var candidates: Dictionary={}
	for y: int in range(1,int(map.height)-1):
		for x: int in range(1,int(map.width)-1):
			var point:=Vector2i(x,y)
			if clear_center(map,point): candidates[point]=true
	var queue: Array[Vector2i]=[map.entrance]; var seen: Dictionary={map.entrance:true}; var index: int=0
	while index<queue.size():
		var point: Vector2i=queue[index]; index+=1
		for direction: Vector2i in World.DIRECTIONS:
			var next: Vector2i=point+direction
			if candidates.has(next) and not seen.has(next): seen[next]=true; queue.append(next)
	return seen
func distance(a: Vector2i,b: Vector2i) -> int: return absi(a.x-b.x)+absi(a.y-b.y)
func _initialize() -> void:
	var generated: int=0
	for area: int in range(1,6):
		for seed_value: int in range(20):
			var map: Dictionary=World.generate(seed_value*7919+17,area); generated+=1
			check(World.validate(map).is_empty(),"New early-floor map validates area%d seed%d: %s" % [area,seed_value,World.validate(map)])
			check(map.area==area and map.width==96 and map.height==64 and map.generator_version==3,"Stable five-area IDs and logical dimensions")
			check(map.spawns.size()==32+area*4,"All planned encounter positions are obtainable on this layout")
			var reached: Dictionary=wide_reached(map)
			check(reached.has(map.exit),"Wide party footprint reaches mandatory exit")
			if seed_value<2: check(JSON.stringify(map)==JSON.stringify(World.generate(seed_value*7919+17,area)),"Geography, landmarks and optional features are deterministic")
			if area==1:
				check(not World.is_dark_zone(map,map.entrance),"Ordinary Crystal Cave entry is lit; the exceptional dark spawn is not made universal")
				check(map.area_portals.size()==4 and map.area_portals.any(func(gate: Dictionary)->bool:return gate.pos==map.exit),"Compatibility exit aliases a real cardinal route, never the memorial")
				check(World.is_dark_zone(map,map.central_memorial) and map.central_memorial!=map.exit,"Central Great Sage memorial is dark and distinct from ordinary portals")
				check(map.crystal_lights.size()>0,"Ordinary inner cave passages have crystal landmarks")
				check(map.traps.size()==6 and map.traps.all(func(point: Vector2i)->bool:return World.first_floor_sector(map,point)=="north"),"Crystal Cave goblin traps follow the northern habitat")
				for point: Vector2i in map.crystal_lights: check(not World.is_dark_zone(map,point),"Crystal dressing does not light the documented dark landmarks")
				var expected: Dictionary={"north":2,"west":3,"south":4,"east":5}
				for gate: Dictionary in map.area_portals:
					check(gate.region==expected[gate.direction] and gate.direction_verified,"Sourced compass-biome association")
					check(reached.has(gate.pos),"Every ordinary second-floor route supports a three-person-wide approach")
					check(World.first_floor_sector(map,gate.pos)==gate.direction and World.is_dark_zone(map,gate.pos),"Portal sits in its correct dark outskirts sector")
					for point: Vector2i in map.spawns+map.traps: check(distance(point,gate.pos)>=6,"No ordinary encounter/trap overlaps safe portal arrival")
			elif area==3:
				check(map.corpse_flowers.size()==6,"Six optional, reachable corpse-flower positions")
				var hazards: int=0
				for row: Array in map.tiles:
					for tile: int in row:
						if tile==World.HAZARD: hazards+=1
				check(hazards==0,"New Land of the Dead contains no invented choking-mist terrain")
			elif area==5:
				check(map.layout_identity=="cliff_canyons_and_caves" and map.beast_caves.size()>=12,"Den has its own cliff/cave geography")
				var cave_spawns: int=0
				for point: Vector2i in map.spawns:
					for cave: Rect2i in map.beast_caves:
						if cave.has_point(point): cave_spawns+=1; break
				check(cave_spawns>map.spawns.size()/2,"Most Den monsters live in cliff-side cave chambers")
				check(map.sewage_pits.size()==5 and map.traps.is_empty(),"Den optional pits are separate from goblin trap terrain")
				var avoid: Dictionary=map.duplicate(true)
				for point: Vector2i in map.sewage_pits: avoid.tiles[point.y][point.x]=World.WALL
				check(World.reachable(avoid,avoid.entrance).has(avoid.exit),"All Den pits can be avoided without blocking the mandatory route")
	_test_metadata_corruption()
	print("EARLY FLOOR WORLD: %d checks, %d failures; %d seeded maps across five areas, cardinal routes, dark memorial, cave habitats and optional environmental features. Geometry/counts/grid scales provisional." % [checks,failures,generated])
	quit(1 if failures else 0)
func reject(map: Dictionary, label: String) -> void:
	var before: String=var_to_str(map)
	check(not World.validate(map).is_empty(),label+" rejects")
	check(var_to_str(map)==before,label+" validation is pure")
func _test_metadata_corruption() -> void:
	var map: Dictionary=World.generate(17,1)
	var numeric_json: Dictionary=map.duplicate(true)
	for key: String in ["dark_outskirts_width","memorial_radius_estimate"]: numeric_json[key]=float(numeric_json[key])
	for gate: Dictionary in numeric_json.area_portals: gate.region=float(gate.region)
	check(World.validate(numeric_json).is_empty(),"JSON-equivalent integral numeric metadata remains valid")
	for bad: Variant in [null,0,"portals",{},[1]]:
		var corrupted: Dictionary=map.duplicate(true); corrupted.area_portals=bad; reject(corrupted,"Malformed cardinal list")
	for key: String in ["dark_outskirts_width","memorial_radius_estimate"]:
		for bad: Variant in [null,"6",[],{},-1,0,21,NAN,INF]:
			var corrupted: Dictionary=map.duplicate(true); corrupted[key]=bad; reject(corrupted,"Malformed dark-zone bound")
	var wrong: Dictionary=map.duplicate(true); wrong.erase("area_portals"); reject(wrong,"Incomplete optional landmark metadata")
	wrong=map.duplicate(true); wrong.area_portals[0].region=5; reject(wrong,"Wrong north-biome assignment")
	wrong=map.duplicate(true); wrong.area_portals[0].pos=Vector2i(1,1); reject(wrong,"Inaccessible cardinal gate")
	wrong=map.duplicate(true); wrong.area_portals[0].direction="up"; reject(wrong,"Unknown cardinal direction")
	wrong=map.duplicate(true); wrong.area_portals[0]=wrong.area_portals[1].duplicate(true); reject(wrong,"Duplicate cardinal route")
	wrong=map.duplicate(true); wrong.central_memorial=Vector2i(1,1); reject(wrong,"Unreachable memorial")
	wrong=map.duplicate(true); wrong.crystal_lights.append(map.central_memorial); reject(wrong,"Crystal lighting in the dark memorial")
	var legacy: Dictionary=map.duplicate(true)
	for key: String in ["area_portals","central_memorial","memorial_radius_estimate","dark_outskirts_width","crystal_lights"]: legacy.erase(key)
	check(World.validate(legacy).is_empty(),"Existing saves without new optional landmark metadata remain loadable")
	for pair: Array in [[3,"corpse_flowers"],[5,"sewage_pits"]]:
		var feature_map: Dictionary=World.generate(17,pair[0]); var field: String=pair[1]
		wrong=feature_map.duplicate(true); wrong[field]=42; reject(wrong,"Malformed optional feature list")
		wrong=feature_map.duplicate(true); wrong[field].append(wrong[field][0]); reject(wrong,"Duplicate optional feature")
		wrong=feature_map.duplicate(true); wrong[field][0]=wrong.spawns[0]; reject(wrong,"Optional feature overlaps enemy spawn")
		wrong=feature_map.duplicate(true); wrong[field][0]=wrong.entrance; reject(wrong,"Optional feature overlaps area arrival")

	var den: Dictionary=World.generate(18,5)
	for malformed: Variant in [null,5,"caves",{},[Vector2i(1,1)],[Rect2i(-2,-2,5,5)]]:
		wrong=den.duplicate(true); wrong.beast_caves=malformed; reject(wrong,"Malformed Den cave bounds")
