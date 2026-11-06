extends SceneTree
const World = preload("res://game/world.gd")
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func clear_center(map: Dictionary, point: Vector2i) -> bool:
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			if not World.walkable(map,point+Vector2i(x,y)): return false
	return true
func wide_route(map: Dictionary) -> bool:
	var queue: Array[Vector2i] = [map.entrance]
	var seen: Dictionary = {map.entrance:true}
	var index: int = 0
	while index < queue.size():
		var point: Vector2i = queue[index]; index += 1
		if point == map.exit: return true
		for direction: Vector2i in World.DIRECTIONS:
			var next: Vector2i = point+direction
			if not seen.has(next) and clear_center(map,next): seen[next] = true; queue.append(next)
	return false
func _init() -> void:
	var variants: Dictionary = {}
	for area: int in range(1,5):
		for seed_value: int in range(20):
			var map: Dictionary = World.generate(seed_value,area)
			check(map.width == 96 and map.height == 64,"Expanded96x64 dimensions")
			check(World.validate(map).is_empty(),"Connected legal geography and placements")
			check(wide_route(map),"A3x3 party footprint reaches the exit without a one-person choke")
			check(map.rooms.size() >= 12 and int(map.loop_count) >= 3,"Varied packed chambers and alternate routes")
			var distances: Dictionary = World.reachable(map,map.entrance)
			check(int(distances.get(map.exit,0)) >= 70,"Expanded objective is substantially separated from arrival")
			variants[JSON.stringify(map.rooms)] = true
	check(variants.size() > 60,"Seeds produce varied packing instead of a repeated room grid")
	var sim := Sim.new(); sim.new_campaign("Large-save fixture","human","adventurer",74119)
	check(sim.enter_region(1),"Actual expedition uses expanded geography")
	sim.state.units = []; sim.state.combat = false
	# Fully explored map exceeds the previous4096-key visibility limit.
	for y: int in range(64):
		for x: int in range(96): sim.state.seen["%d,%d" % [x,y]] = true
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	check(Validator.validate(encoded).is_empty(),"Full6144-tile knowledge saves within a bounded payload budget")
	var loaded := Sim.new()
	check(loaded.restore(encoded) and loaded.state.seen.size() == 6144,"Large fog knowledge survives a real JSON restore")
	# Preserve a real legacy-sized map while upgrading its quarter-hour clock.
	var old: Dictionary = {"width":38,"height":25,"tiles":[],"entrance":Vector2i(4,20),"exit":Vector2i(32,4),"spawns":[],"traps":[],"rooms":[Rect2i(1,1,36,23)],"seed":1,"area":1}
	for y: int in range(25):
		var row: Array = []
		for x: int in range(38): row.append(World.WALL if x == 0 or y == 0 or x == 37 or y == 24 else World.FLOOR)
		old.tiles.append(row)
	sim.state.map = old; sim.state.seen = {}; sim.state.visible = {}; sim.hero().pos = old.entrance
	sim.state.time = 4; sim.state.version = 2
	check(loaded.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Legacy38x25 expedition still loads safely")
	check(loaded.state.map.width == 38 and loaded.state.time == 60,"Legacy geography retained while clock migrates once")
	print("DUNGEON WIDTH: %d checks, %d failures;80 seeded wide-route maps,3x3 footprint connectivity and legacy/large saves." % [checks,failures])
	quit(1 if failures else 0)
