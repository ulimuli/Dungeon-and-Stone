extends SceneTree
## Pure geometry/metadata tests; no player saves. These layouts are authored
## compact representations, not exact novel coordinate or travel-scale claims.
const Third=preload("res://game/third_floor_world.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(terrain: String,seed_value: int=74119) -> Dictionary:
	return Third.generate(seed_value,6+Third.TERRAINS.find(terrain),{"terrain":terrain})
func _initialize() -> void:
	var signatures: Dictionary={}; var count: int=0
	for terrain: String in Third.TERRAINS:
		for seed_value: int in range(20):
			var map: Dictionary=fresh(terrain,seed_value*7927+17); count+=1
			var errors: Array[String]=Third.validate(map)
			check(errors.is_empty(),"Third-floor %s seed%d validates: %s" % [terrain,seed_value,errors])
			check(map.width==96 and map.height==64 and map.floor==3 and map.generator_version==4,"Stable bounded third-floor geometry")
			check(map.spawns.size()==map.encounter_count_estimate,"All configured encounter positions are reachable and obtainable")
			var wide: Dictionary=Third.reached(map,map.entrance,true)
			check(wide.has(map.exit),"A three-person-wide route reaches the inward boundary")
			for point: Vector2i in map.connection_sites.values(): check(wide.has(point),"Every neutral connection site has a broad safe approach")
			if seed_value<2: check(JSON.stringify(map)==JSON.stringify(fresh(terrain,seed_value*7927+17)),"Fixed seed reproduces topology, routes, landmarks and encounter placements")
			if terrain=="ironrock_hills":
				check(map.ridge_bands.size()==2 and wide.has(map.overlook),"Elevated ridge terraces have accessible overlook and connecting passes")
			elif terrain=="orc_colony":
				check(map.encounter_sites.size()>=10 and wide.has(map.orc_altar),"Woodland encounter clearings surround a reachable altar")
			elif terrain=="witch_forest":
				check(map.hut_sites.size()==6 and map.hut_sites.has(map.witch_tree),"One purple-tree entrance has multiple prepared locations")
				for point: Vector2i in map.hut_sites:
					check(wide.has(point),"Every possible witch-tree location has broad approach space")
					check(map.spawns.all(func(spawn: Vector2i)->bool:return Third._distance(spawn,point)>=6),"Initial encounters leave possible purple-tree arrivals clear")
				check(map.central_spire==map.exit,"Only the central Witch Forest exposes the spire boundary")
			elif terrain=="dark_estuary":
				check(map.water_channels.size()>300 and map.shelter_mounds.size()==6,"Estuary has branching shallow channels and six dry red mound refuges")
				check(map.water_channels.all(func(point: Vector2i)->bool:return Third._walkable(map,point)),"Documented knee-deep water remains wadable without invented instant drowning")
				for point: Vector2i in map.shelter_mounds: check(wide.has(point) and map.tiles[point.y][point.x]==Third.FLOOR,"All dry refuge mounds remain reachable")
			else: check(not map.has("central_spire"),"Ordinary3Fsubregions do not invent a separate fourth-floor portal")
			signatures[JSON.stringify(map.tiles)]=true
	check(signatures.size()>60,"Independent seeds and distinct landscape types yield varied physical topology")
	var state: Dictionary=fresh("witch_forest")
	var before: String=var_to_str(state); check(Third.validate(state).is_empty() and var_to_str(state)==before,"Validation does not mutate a generated map")
	seed(817); var expected: int=randi(); seed(817); fresh("orc_colony"); check(randi()==expected,"World generation never consumes global/combat randomness")
	check(Third.generate(1,1,{"terrain":"orc_colony"}).is_empty() and Third.generate(1,6,{"terrain":"unknown"}).is_empty(),"Unknown layouts fail explicitly rather than becoming renamed generic rooms")
	_test_invalid_metadata()
	print("THIRD FLOOR WORLD: %d checks, %d failures; %d seeded authored maps with distinct ridge/woodland/mist/estuary topology, broad routes, safe landmarks and deterministic placement. Exact coordinates/scale/counts provisional." % [checks,failures,count])
	quit(1 if failures else 0)
func reject(map: Dictionary,label: String) -> void:
	var before: String=var_to_str(map)
	check(not Third.validate(map).is_empty(),label+" rejects")
	check(var_to_str(map)==before,label+" validation is pure")
func _test_invalid_metadata() -> void:
	var map: Dictionary=fresh("witch_forest")
	for bad: Variant in [null,"96",true,NAN,[],{}]:
		var malformed: Dictionary=map.duplicate(true); malformed.width=bad; reject(malformed,"Malformed numeric dimensions")
	for bad: Variant in [null,"0",true,NAN,[],{}]:
		var malformed: Dictionary=map.duplicate(true); malformed.tiles[2][2]=bad; reject(malformed,"Malformed terrain value")
	var broken: Dictionary=map.duplicate(true); broken.tiles[broken.exit.y][broken.exit.x]=Third.WALL; reject(broken,"Blocked inward boundary")
	broken=map.duplicate(true); broken.hut_sites.append(broken.hut_sites[0]); reject(broken,"Duplicate witch-tree location")
	broken=map.duplicate(true); broken.witch_tree=Vector2i(1,1); reject(broken,"Unprepared purple-tree location")
	broken=map.duplicate(true); broken.connection_sites.north=Vector2i(1,1); reject(broken,"Blocked neutral connection")
	broken=map.duplicate(true); broken.spawns.append(broken.spawns[0]); reject(broken,"Duplicate encounter placement")
	var estuary: Dictionary=fresh("dark_estuary")
	broken=estuary.duplicate(true); broken.water_channels.append(broken.entrance); reject(broken,"Water metadata cannot mislabel a dry arrival")
	broken=estuary.duplicate(true); broken.shelter_mounds[0]=Vector2i(1,1); reject(broken,"Inaccessible flood refuge")
	broken=estuary.duplicate(true); broken.dry_mounds=[Rect2i(-3,-3,9,7)]; reject(broken,"Out-of-bounds dry mound")
	var json_numeric: Dictionary=map.duplicate(true)
	for field: String in ["width","height","area","floor","generator_version"]: json_numeric[field]=float(json_numeric[field])
	check(Third.validate(json_numeric).is_empty(),"JSON-equivalent integral numeric metadata remains accepted")
