class_name FloorConnections
extends RefCounted
## Source-backed itineraries, compact connector positions. Not a complete third-floor graph.
## Den→Hill and Dead→Estuary are direct routes. Hill→Orcs→Witch and
## Estuary→Witch compress documented journeys; distances/adjacency are estimates.
const THIRD_NEIGHBORS: Dictionary={6:{5:"entrance",7:"north"},7:{6:"south",8:"west"},8:{7:"east",9:"south"},9:{3:"entrance",8:"north"}}
static func attach(map: Dictionary, area: int) -> void:
	map["floor_portals"]=[]
	if area==3: map.floor_portals.append({"pos":map.exit,"region":9})
	elif area==5: map.floor_portals.append({"pos":map.exit,"region":6})
	elif THIRD_NEIGHBORS.has(area):
		for destination: int in THIRD_NEIGHBORS[area]:
			var anchor: String=THIRD_NEIGHBORS[area][destination]
			map.floor_portals.append({"pos":map.entrance if anchor=="entrance" else map.connection_sites[anchor],"region":destination})
static func choices(sim: RefCounted) -> Array[int]:
	var result: Array[int]=[]
	if int(sim.state.get("region",1))<6: result=EarlyFloorRules.portal_choices(sim)
	if sim.state.get("mode","")!="dungeon": return result
	for gate: Dictionary in sim.state.map.get("floor_portals",[]):
		if sim.distance(sim.hero().pos,gate.pos)<=1 and not result.has(int(gate.region)): result.append(int(gate.region))
	return result
static func arrival(map: Dictionary, departed: int) -> Vector2i:
	for gate: Dictionary in map.get("area_portals",[])+map.get("floor_portals",[]):
		if int(gate.region)==departed: return gate.pos
	return map.entrance
