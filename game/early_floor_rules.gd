class_name EarlyFloorRules
extends RefCounted
## Spatial floor connections and source-backed environmental interactions.
## Exact grid geometry, water quantities and damage are reconstruction estimates.
const FLOWER_YIELD: int=4
const WATER_START: int=10
const DEN_SOURCE: String="https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/"
const DEAD_SOURCE: String="https://martialrealm.com/novel/sgb/chapter-22-23-24/"
static func den_region() -> Dictionary:
	return {"name":"Den of Beasts","subtitle":"Second Floor · Eastern Route","floor":2,"level":2,"color":"9b7c60","wall":"342d2a","terrain":"canyon","hazard_desc":"Cliff caves shelter beasts. Hidden sewage pits interrupt the canyon paths.","enemy_ids":EarlyFloorContent.region_pools().canon_den_of_beasts,"resource":"mana_stone_rank_8","lore":"The eastern route enters maze-like canyons and cliff caves. Deeper black cliffs shelter rank-eight predators. Exact geography, encounter frequency and combat values are provisional.","portal_closes_after_days":10,"reference_urls":[DEN_SOURCE],"verified_novel_directly":false,"primary_text_evidence":[{"url":DEN_SOURCE,"chapter":50,"claims":["Eastern portal enters the beast canyon.","Cliff caves, hidden sewage pits and stronger deeper creatures are described."]}],"playable":true,"experimental_numeric_fields":["geometry","encounter_count","pit_damage","depth_boundary"]}
static func portal_choices(sim: RefCounted) -> Array[int]:
	var result: Array[int]=[]
	if sim.state.get("mode","")!="dungeon": return result
	var map: Dictionary=sim.state.map
	if int(sim.state.region)==1:
		if map.has("area_portals"):
			for gate: Dictionary in map.area_portals:
				if sim.distance(sim.hero().pos,gate.pos)<=1: result.append(int(gate.region))
		elif sim.distance(sim.hero().pos,map.exit)<=1:
			for id: int in range(2,6): result.append(id)
	elif sim.distance(sim.hero().pos,map.entrance)<=1 or (int(map.get("generator_version",0))<3 and sim.distance(sim.hero().pos,map.exit)<=1): result.append(1)
	return result
static func return_anchor(map: Dictionary, region: int) -> Vector2i:
	for gate: Dictionary in map.get("area_portals",[]):
		if int(gate.region)==region: return gate.pos
	return map.exit
static func flower_error(sim: RefCounted) -> String:
	if sim.state.get("mode","")!="dungeon" or int(sim.state.region)!=3: return "Corpse flowers grow among the Land of the Dead’s ruins."
	if sim.state.combat: return "Break contact before opening a corpse flower."
	if int(sim.state.time)<sim.MINUTES_PER_DAY: return "The vines have not bloomed. Return from expedition day2."
	for point: Vector2i in sim.state.map.get("corpse_flowers",[]):
		if sim.distance(sim.hero().pos,point)<=1 and not sim.state.map.get("harvested_flowers",[]).has(point): return ""
	return "No unharvested corpse flower within reach."
static func collect_flower(sim: RefCounted) -> String:
	var failure: String=flower_error(sim)
	if not failure.is_empty(): return failure
	for point: Vector2i in sim.state.map.corpse_flowers:
		if sim.distance(sim.hero().pos,point)>1 or sim.state.map.get("harvested_flowers",[]).has(point): continue
		if not sim.state.map.has("harvested_flowers"): sim.state.map["harvested_flowers"]=[]
		sim.state.map.harvested_flowers.append(point)
		sim.state["water"]=mini(1000000000,int(sim.state.get("water",WATER_START))+FLOWER_YIELD)
		sim.journal("Corpse flowers","The vines on stone ruins bloom from the second expedition day. Open blossoms provide drinking water. Current yield4 and once-per-expedition harvesting are provisional; the water source and delayed bloom follow chapter24.")
		sim.say("Corpse flower opened: +%d water." % FLOWER_YIELD)
		sim.cue.emit("loot"); sim.advance_time(1)
		return ""
	return "No unharvested corpse flower within reach."
static func daily_water(sim: RefCounted) -> void:
	var due: int=0
	for unit: Dictionary in sim.allies():
		if unit.hp>0 and not unit.get("summon",false): due+=1
	var supplied: int=int(sim.state.get("water",WATER_START))
	sim.state["water"]=maxi(0,supplied-due)
	if supplied>=due: return
	sim.state.fatigue+=1
	sim.say("Drinking water ran out. Dehydration wounds the party; fill supplies in the city or find water.")
	for unit: Dictionary in sim.allies():
		if sim.state.mode!="dungeon": return
		if unit.hp>0 and not unit.get("summon",false): sim.hit({"name":"Dehydration","accuracy":100,"statuses":{}},unit,2,"dehydration","Dehydration",false,true,2)
static func population(sim: RefCounted) -> void:
	var area: int=int(sim.state.region)
	var positions: Array=sim.state.map.spawns.duplicate()
	if area==2:
		# Three estimated encounter sites, each with the documented~15 goblins.
		for group: int in range(3):
			var anchor: Vector2i=positions[mini(group*12,positions.size()-1)]
			var cells: Array[Vector2i]=_group_cells(sim,anchor,15)
			for cell: Vector2i in cells:
				var progress: int=sim.distance(cell,sim.state.map.entrance)
				var roll: int=sim.rng.randi_range(0,99)
				var id: String="canon_goblin" if roll<(60 if progress>40 else 90) else ("canon_goblin_archer" if roll%2==0 else "canon_goblin_swordsman")
				var unit: Dictionary=sim.spawn_enemy(id,cell)
				unit["encounter_group"]="forest_%d" % group
		return
	var reached: Dictionary=DungeonWorld.reachable(sim.state.map,sim.state.map.entrance)
	if area in [3,5]: positions.sort_custom(func(a: Vector2i,b: Vector2i)->bool:return int(reached.get(a,0))<int(reached.get(b,0)))
	for index: int in range(positions.size()):
		var position: Vector2i=positions[index]
		var pool: Array=sim.region_data().enemy_ids
		if area==1 and sim.state.map.has("area_portals"):
			match DungeonWorld.first_floor_sector(sim.state.map,position):
				"north": pool=["canon_goblin"]
				"west": pool=["canon_ghoul"]
				"south": pool=["canon_gnome"]
				"east": pool=["canon_blade_wolf"]
		elif area==5:
			var bands: Dictionary=EarlyFloorContent.den_bands()
			pool=bands.deep if index>=positions.size()/2 else bands.ordinary
		elif area==3:
			pool=pool.filter(func(id: String)->bool:return id!="canon_death_fiend")
			if index==positions.size()-1: pool=["canon_death_fiend"]
		sim.spawn_enemy(str(pool[sim.rng.randi_range(0,pool.size()-1)]),position)
static func _group_cells(sim: RefCounted, anchor: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var queue: Array[Vector2i]=[anchor]; var visited: Dictionary={anchor:true}; var cursor: int=0
	while cursor<queue.size() and result.size()<count:
		var point: Vector2i=queue[cursor]; cursor+=1
		if sim.unit_at(point).is_empty() and sim.distance(point,sim.state.map.entrance)>10 and sim.distance(point,sim.state.map.exit)>6 and not sim.state.map.traps.has(point): result.append(point)
		for delta: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i=point+delta
			if not visited.has(next) and DungeonWorld.walkable(sim.state.map,next): visited[next]=true; queue.append(next)
	return result
