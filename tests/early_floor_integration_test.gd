extends SceneTree
## Actual campaign commands; funds, placement, levels and physical drops are
## explicit assisted fixtures. This does not establish a complete novel floor.
const Sim=preload("res://game/simulation.gd")
const World=preload("res://game/world.gd")
const Validation=preload("res://game/save_validation.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func fresh() -> GameSimulation:
	var sim:=Sim.new(); sim.new_campaign("Early-floor integration","barbarian","adventurer",74119)
	sim.state.gold=10000; sim.state.food=100; sim.state.water=100
	check(sim.enter_region(1),"Actual expedition entry reaches Crystal Cave")
	sim.state.units=[]; sim.state.combat=false
	return sim
func roundtrip(sim: GameSimulation, message: String) -> GameSimulation:
	var loaded:=Sim.new()
	var payload: Dictionary=JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored: bool=loaded.restore(payload)
	check(restored,message+": actual JSON restore succeeds"+("; "+str(Validation.validate(payload)) if not restored else ""))
	return loaded
func same_geometry(a: Dictionary, b: Dictionary) -> bool:
	if int(a.width)!=int(b.width) or int(a.height)!=int(b.height) or a.entrance!=b.entrance: return false
	for y: int in range(int(a.height)):
		for x: int in range(int(a.width)):
			if int(a.tiles[y][x])!=int(b.tiles[y][x]): return false
	return true
func gate_for(sim: GameSimulation, area: int) -> Dictionary:
	for gate: Dictionary in sim.state.map.get("area_portals",[]):
		if int(gate.region)==area: return gate
	return {}
func place_gate(sim: GameSimulation, area: int) -> Vector2i:
	var gate: Dictionary=gate_for(sim,area)
	check(not gate.is_empty(),"Real map contains destination-specific gate "+str(area))
	if gate.is_empty(): return Vector2i(-1,-1)
	sim.hero().pos=gate.pos; sim.state.combat=false; sim.update_visibility()
	check(sim.portal_choices()==[area],"At a real gate only its own destination is available")
	return gate.pos
func visit(sim: GameSimulation, area: int) -> Vector2i:
	var anchor: Vector2i=place_gate(sim,area)
	check(sim.travel_region(area),"Actual portal transition enters area "+str(area))
	sim.state.units=[]; sim.state.combat=false
	return anchor
func rejected_travel(sim: GameSimulation, area: int, message: String) -> void:
	var before: String=var_to_str([sim.state.region,sim.hero().pos,sim.state.time,sim.state.water,sim.state.food,sim.rng.state])
	check(not sim.travel_region(area),message+": rejected")
	check(var_to_str([sim.state.region,sim.hero().pos,sim.state.time,sim.state.water,sim.state.food,sim.rng.state])==before,message+": transition/resources/RNG unchanged")
func _initialize() -> void:
	_test_spatial_gates_and_memory()
	_test_lower_floor_closure()
	_test_water_and_flowers()
	_test_magic_torch()
	_test_pits()
	_test_death_fiend_and_summons()
	_test_corruption()
	print("EARLY FLOOR INTEGRATION: %d checks, %d failures. Actual four compass routes, five-area memory, water/flowers/pits, torch deadlines, summons and validated JSON; assisted setup, exact geography/numbers provisional." % [checks,failures])
	quit(1 if failures else 0)
func _test_spatial_gates_and_memory() -> void:
	var sim:=fresh()
	check(sim.region_defs.size()==9 and sim.region_data(5).name=="Den of Beasts","All four second-floor biomes are actual selectable runtime content")
	check(sim.state.map.area_portals.size()==4,"New Crystal Cave has four separate physical portals")
	var directions: Dictionary={2:"north",3:"west",4:"south",5:"east"}
	for gate: Dictionary in sim.state.map.area_portals:
		check(gate.direction==directions[int(gate.region)],"Portal destination follows researched compass identity")
	check(sim.state.map.central_memorial not in sim.state.map.area_portals.map(func(g: Dictionary)->Vector2i:return g.pos),"Central memorial is distinct from ordinary floor portals")
	sim.hero().pos=sim.state.map.central_memorial; sim.update_visibility()
	check(sim.portal_choices().is_empty() and sim.interact()=="memorial","Central monument opens only its sourced lore, not arbitrary floor travel")
	for area: int in [2,3,4,5]:
		rejected_travel(sim,area,"Remote transition from the memorial")
	for area: int in [2,3,4,5]:
		var anchor: Vector2i=place_gate(sim,area)
		for wrong: int in [2,3,4,5]:
			if wrong!=area: rejected_travel(sim,wrong,"Wrong destination at a physical gate")
		check(sim.interact()=="portal","Actual nearby portal interaction exposes travel")
		check(sim.travel_region(area) and sim.state.region==area and sim.floor_number()==2,"Actual gate enters its corresponding second-floor biome")
		sim.state.units=[]; sim.state.combat=false
		check(sim.portal_limit()==10*sim.MINUTES_PER_DAY,"Every second-floor biome has the ten-day deadline")
		check(World.validate(sim.state.map).is_empty(),"Actual generated biome validates")
		var remembered: Dictionary=sim.state.map.duplicate(true)
		if area==5:
			sim.state.essence_drops.append({"id":"canon_blade_wolf","pos":sim.hero().pos,"region":5,"expires_at":int(sim.state.time)+30})
			sim._recount_essence_drops()
		var loaded:=roundtrip(sim,"Area "+str(area))
		if loaded.state.is_empty(): return
		if area==5: check(loaded.state.essence_drops.any(func(drop: Dictionary)->bool:return int(drop.region)==5),"Loose Den essence retains the new area ID through JSON")
		check(loaded.state.region==area and loaded.state.floor_memory.has("1"),"Area ID and first-floor memory survive JSON")
		loaded.state.units=[]; loaded.state.combat=false; loaded.hero().pos=loaded.state.map.entrance
		check(loaded.portal_choices()==[1] and loaded.travel_region(1),"Return portal connects to first floor through actual commands")
		check(loaded.distance(loaded.hero().pos,anchor)<=1,"Return arrives beside the same compass gate used for ascent")
		check(loaded.state.floor_memory.has(str(area)),"Returning remembers the visited biome")
		place_gate(loaded,area)
		check(loaded.travel_region(area),"Revisiting uses the real destination-specific gate")
		check(same_geometry(loaded.state.map,remembered),"Revisit preserves actual geometry rather than rerolling")
		loaded.state.units=[]; loaded.state.combat=false; loaded.hero().pos=loaded.state.map.entrance
		check(loaded.travel_region(1),"Revisited biome returns safely")
		sim=loaded
	check(sim.state.visited_regions.size()==5,"Campaign records all five actual areas without inventing deeper floors: "+var_to_str(sim.state.visited_regions))
func _test_lower_floor_closure() -> void:
	var sim:=fresh(); visit(sim,5)
	sim.hero().pos=sim.state.map.entrance
	sim.advance_time(7*sim.MINUTES_PER_DAY-int(sim.state.time))
	check(sim.state.mode=="dungeon" and sim.state.region==5,"Den remains open after Crystal Cave closes")
	rejected_travel(sim,1,"Closed first-floor return")
	sim.add_item("mana_stone_rank_9",1,true)
	sim.advance_time(3*sim.MINUTES_PER_DAY)
	check(sim.state.mode=="city" and int(sim.state.time)==10*sim.MINUTES_PER_DAY,"Den closure returns survivors exactly at the ten-day deadline")
	check(int(sim.state.inventory.get("mana_stone_rank_9",0))==1,"Actual closure banks expedition loot")
	roundtrip(sim,"Den closure and remembered five-area route")
func _test_water_and_flowers() -> void:
	var sim:=fresh(); visit(sim,3)
	check(sim.state.map.get("corpse_flowers",[]).size()>0,"Actual Land of Dead contains corpse-flower sites")
	if sim.state.map.get("corpse_flowers",[]).is_empty(): return
	var flower: Vector2i=sim.state.map.corpse_flowers[0]
	sim.hero().pos=flower; sim.update_visibility()
	var water: int=sim.state.water; var time: int=sim.state.time
	check(not sim.collect_corpse_flower().is_empty() and sim.state.water==water and sim.state.time==time,"Day1 dormant flower grants no water or free time")
	sim.advance_time(sim.MINUTES_PER_DAY-int(sim.state.time)); sim.state.water=1
	water=sim.state.water
	check(sim.interact()=="flower" and int(sim.state.water)==water+4,"Day2 actual interaction splits a blossom and adds the estimated four water")
	var harvested: Array=sim.state.map.get("harvested_flowers",[]).duplicate(true)
	check(harvested.size()==1,"Harvested site persists exactly once")
	water=sim.state.water
	check(not sim.collect_corpse_flower().is_empty() and int(sim.state.water)==water and sim.state.map.harvested_flowers==harvested,"Repeated harvest cannot farm the same flower")
	var loaded:=roundtrip(sim,"Collected corpse flower and water")
	check(loaded.state.water==water and loaded.state.map.harvested_flowers==harvested,"Flower history and shared water survive actual save restore")
	loaded.state.units=[]; loaded.state.combat=false; loaded.hero().pos=loaded.state.map.entrance
	check(loaded.travel_region(1),"Harvested area can be left before closure")
	visit(loaded,3)
	check(loaded.state.map.get("harvested_flowers",[])==harvested,"Harvest history survives area memory/revisit")
	var daily:=fresh(); daily.state.water=10
	daily.advance_time(daily.MINUTES_PER_DAY)
	check(daily.state.water==9,"A full day consumes one estimated water per living nonsummon")
	var supplied:=Sim.new(); supplied.new_campaign("Water market","human","adventurer",34117); supplied.state.gold=100
	check(supplied.buy("water_skin").is_empty(),"Water supply is actually purchasable")
	water=int(supplied.state.get("water",10))
	check(supplied.use_item("water_skin").is_empty() and supplied.state.water==water+4 and not supplied.state.inventory.has("water_skin"),"Actual consumable adds four water and is consumed once")
func _test_pits() -> void:
	var sim:=fresh(); visit(sim,5)
	check(sim.state.map.get("sewage_pits",[]).size()>0 and sim.state.map.traps.is_empty(),"Den has sourced natural pits, not misplaced Goblin traps")
	if sim.state.map.get("sewage_pits",[]).is_empty(): return
	var pit: Vector2i=sim.state.map.sewage_pits[0]
	sim.hero().pos=pit
	var hp: int=sim.hero().hp
	sim.step_hazards(sim.hero())
	check(sim.hero().hp<hp and sim.state.disarmed.has(sim.pos_key(pit)),"Stepping into an uncleared pit applies actual damage and records it")
	hp=sim.hero().hp; sim.step_hazards(sim.hero())
	check(sim.hero().hp==hp,"An already recorded pit cannot repeatedly damage the same standing explorer")
	roundtrip(sim,"Triggered Den pit")
	var cleared:=fresh(); visit(cleared,5); pit=cleared.state.map.sewage_pits[0]; cleared.hero().pos=pit
	check(cleared.interact()=="trap" and cleared.state.disarmed.has(cleared.pos_key(pit)),"Actual interaction detects/marks a Den pit")
	hp=cleared.hero().hp; cleared.step_hazards(cleared.hero())
	check(cleared.hero().hp==hp,"A marked pit has safe counterplay before crossing")
func _test_death_fiend_and_summons() -> void:
	var sim:=fresh(); sim.state.level=2; sim.recalculate(sim.hero(),true)
	check(sim.essence_defs.has("canon_death_fiend"),"Death Fiend essence is an actual runtime definition")
	sim.state.essence_drops.append({"id":"canon_death_fiend","pos":sim.hero().pos,"region":1,"expires_at":int(sim.state.time)+30})
	sim._recount_essence_drops()
	check(sim.absorb("canon_death_fiend").is_empty(),"Actual physical drop absorption grants Death Fiend kit")
	check(sim.stat_value(sim.hero(),"natural_recovery")>1,"Physical Preservation consumes shared natural recovery")
	sim.recalculate(sim.hero(),true); sim.resolving_round=true; sim.update_visibility()
	check(sim.use_ability(0,sim.hero().pos),"Actual Call of the Dead skill can be cast")
	var summoned: Array=sim.allies().filter(func(u: Dictionary)->bool:return u.get("summon",false))
	check(summoned.size()==10 and summoned.all(func(u: Dictionary)->bool:return u.content_id=="canon_ghoul"),"Call of the Dead creates the documented ten Ghoul summons")
	var summon_load:=roundtrip(sim,"Ten allied Call of the Dead summons")
	check(summon_load.allies().filter(func(u: Dictionary)->bool:return u.get("summon",false)).size()==10,"Actual allied summons and ownership survive campaign JSON")
	var positions: Dictionary={}
	for unit: Dictionary in summoned:
		check(not positions.has(unit.pos) and World.walkable(sim.state.map,unit.pos),"Summons occupy distinct actual walkable cells")
		positions[unit.pos]=true
	var water: int=sim.state.water
	sim.advance_time(sim.MINUTES_PER_DAY-int(sim.state.time))
	check(sim.state.water==water-1,"Ghoul summons do not multiply living party water demand")
	var enemy: Dictionary=sim.spawn_enemy("canon_ghoul",sim.nearest_free(sim.hero().pos+Vector2i.RIGHT),true)
	var xp: int=sim.state.xp; var loot: Dictionary=sim.state.loot_items.duplicate(true); var drops: int=sim.state.essence_drops.size()
	enemy.hp=0; sim.on_death(enemy,sim.hero())
	check(sim.state.xp==xp and sim.state.loot_items==loot and sim.state.essence_drops.size()==drops,"Summoned enemies grant no XP, mana stones or essences")
func _test_corruption() -> void:
	var sim:=fresh(); visit(sim,5)
	var payload: Dictionary=JSON.parse_string(JSON.stringify(sim.snapshot()))
	for field: String in ["water","torch_until"]:
		for value: Variant in [-1,"5",null,[],1.5,1000000001]:
			var malformed: Dictionary=payload.duplicate(true); malformed[field]=value
			var target:=fresh(); var before: String=var_to_str([target.state,target.rng.state])
			check(not target.restore(malformed),"Malformed "+field+" rejects before state assignment")
			check(var_to_str([target.state,target.rng.state])==before,"Invalid resource/deadline restore preserves campaign and RNG")
	var legacy: Dictionary=payload.duplicate(true); legacy.erase("water")
	var migrated:=Sim.new()
	check(migrated.restore(legacy) and migrated.state.get("water") is int and migrated.state.water>=0,"Legacy saves gain a bounded water baseline without losing area5")

func _test_magic_torch() -> void:
	var sim:=Sim.new(); sim.new_campaign("Torch market","barbarian","adventurer",74119); sim.state.gold=100
	check(sim.buy("magic_torch").is_empty() and sim.buy("magic_torch").is_empty(),"Actual market supplies two affordable Magic Torches")
	var count: int=sim.state.inventory.get("magic_torch",0)
	check(not sim.use_item("magic_torch").is_empty() and sim.state.inventory.get("magic_torch",0)==count,"City lighting attempt preserves the purchased torch")
	sim.state.food=100; sim.state.water=100; check(sim.enter_region(1),"Torch supplies survive actual expedition entry")
	sim.state.units=[]; sim.state.combat=false; sim.hero().pos=sim.state.map.central_memorial; sim.advance_time(7); sim.update_visibility()
	var unlit: int=sim.state.visible.size(); var started: int=sim.state.time
	check(sim.use_item("magic_torch").is_empty(),"Actual consumable lights the Magic Torch")
	var expiry: int=int(sim.state.torch_until)
	check(expiry==started+4320 and sim.state.inventory.get("magic_torch",0)==count-1,"One torch starts an absolute three-day deadline and consumes one item")
	sim.update_visibility()
	check(sim.state.visible.size()>unlit,"Burning torch actually extends visibility in the dark memorial zone")
	var before: String=var_to_str([sim.state.inventory,sim.state.time,sim.state.torch_until,sim.rng.state])
	check(not sim.use_item("magic_torch").is_empty() and var_to_str([sim.state.inventory,sim.state.time,sim.state.torch_until,sim.rng.state])==before,"Already-burning rejection preserves spare, timer, time and RNG")
	visit(sim,5)
	check(int(sim.state.torch_until)==expiry,"Torch deadline is preserved while crossing to the Den")
	var loaded:=roundtrip(sim,"Lit torch on the fifth area")
	if loaded.state.is_empty(): return
	check(int(loaded.state.torch_until)==expiry and loaded.state.inventory.get("magic_torch",0)==1,"Timer and spare survive actual JSON restore")
	loaded.state.units=[]; loaded.state.combat=false; loaded.hero().pos=loaded.state.map.entrance
	check(loaded.travel_region(1),"A saved burning torch permits normal portal return")
	loaded.hero().pos=loaded.state.map.central_memorial; loaded.update_visibility()
	loaded.advance_time(expiry-int(loaded.state.time)-1)
	check(int(loaded.state.time)==expiry-1 and loaded.state.visible.size()>unlit,"Light remains effective one minute before the saved deadline")
	loaded.advance_time(1)
	check(int(loaded.state.time)==expiry and loaded.state.visible.size()==unlit,"Exact expiry removes the temporary dark-zone visibility benefit")
	check(loaded.use_item("magic_torch").is_empty() and int(loaded.state.torch_until)==expiry+4320,"A spare can be lit after expiry without stacking the previous duration")
