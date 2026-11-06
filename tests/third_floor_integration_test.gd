extends SceneTree
## Actual simulation commands with assisted placement/resources. Not human playtesting.
const Sim=preload("res://game/simulation.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,message: String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func fresh()->GameSimulation:
	var sim:=Sim.new(); sim.new_campaign("Third floor","barbarian","adventurer",19351)
	sim.state.food=200; sim.state.water=200; sim.state.gold=10000
	check(sim.enter_region(1),"Enter expedition through ordinary opening")
	sim.state.units=[]; sim.state.combat=false
	return sim
func gate(sim: GameSimulation,destination: int)->void:
	var found: bool=false
	for portal: Dictionary in sim.state.map.get("area_portals",[])+sim.state.map.get("floor_portals",[]):
		if int(portal.region)==destination: sim.hero().pos=portal.pos; found=true; break
	if not found and destination==1: sim.hero().pos=sim.state.map.entrance; found=true
	check(found,"Physical connection to "+str(destination))
	sim.state.combat=false; sim.update_visibility(); sim.state.combat=false
func travel(sim: GameSimulation,destination: int)->void:
	gate(sim,destination)
	var before: int=sim.state.time
	check(sim.travel_region(destination),"Actual travel to "+str(destination))
	check(sim.state.region==destination and sim.state.time==before+1,"Travel preserves absolute clock")
	check(DungeonWorld.validate(sim.state.map).is_empty(),"Connected valid generated destination")
	sim.state.units=[]; sim.state.combat=false
func load_json(sim: GameSimulation)->GameSimulation:
	var payload: Dictionary=JSON.parse_string(JSON.stringify(sim.snapshot()))
	var errors: Array[String]=SaveValidation.validate(payload)
	check(errors.is_empty(),"JSON validates: "+str(errors))
	var copy:=Sim.new(); check(copy.restore(payload),"JSON save restores")
	return copy
func arena(area: int=6)->GameSimulation:
	var sim:=fresh(); travel(sim,5); travel(sim,6)
	if area!=6:
		sim.state.region=area; sim.state.map=DungeonWorld.generate(19351,area); sim.state.seen={}; sim.state.visible={}; sim.state.units=[]
	var origin: Vector2i=sim.state.map.entrance
	sim.hero().pos=origin; sim.state.combat=false
	# A controlled open combat square independent of procedurally placed cover.
	for y: int in range(origin.y-3,origin.y+4):
		for x: int in range(origin.x-3,origin.x+7): sim.state.map.tiles[y][x]=DungeonWorld.FLOOR
	sim.update_visibility(); sim.resolving_round=true
	return sim
func _initialize()->void:
	_test_graph()
	_test_environment()
	_test_combat()
	_test_summons()
	print("THIRD FLOOR INTEGRATION: %d checks, %d failures. Actual travel, field/refuge/tide clock, defenses, essence, XP and JSON; assisted fixtures, compressed geography." % [checks,failures])
	quit(1 if failures else 0)
func _test_graph()->void:
	var sim:=fresh()
	travel(sim,5); travel(sim,6)
	check(sim.floor_number()==3 and sim.portal_limit()==15*1440,"Third floor15day closure")
	check(sim.state.units.is_empty(),"Fixture population cleared after real travel")
	travel(sim,7); travel(sim,8); travel(sim,9); travel(sim,3); travel(sim,1)
	check(["1","3","5","6","7","8","9"].all(func(id: String)->bool:return sim.state.floor_memory.has(id)),"Every entered area memory persists")
	var copy:=load_json(sim)
	check(copy.state.visited_regions.has(8) and copy.state.visited_regions.has(9),"Thirdfloor discoveries persist")
	travel(sim,3); travel(sim,9)
	sim.state.time=10*1440
	gate(sim,3); check(not sim.travel_region(3) and sim.state.region==9,"Closed secondfloor cannot be reentered")
	sim.advance_time(5*1440)
	check(sim.state.mode=="city","Day15 automatically extracts without fourthfloor softlock")
	check(SaveValidation.validate(sim.snapshot()).is_empty(),"City after thirdfloor extraction validates")
	# Every ordinary species plus the actual Eye event can cross the documented30XP threshold.
	var xp:=fresh(); xp.state.units=[]
	for id: String in xp.monster_defs:
		var enemy: Dictionary=xp.spawn_enemy(id,xp.hero().pos+Vector2i.RIGHT); enemy.hp=0; xp.on_death(enemy,xp.hero())
	check(xp.state.xp==55 and xp.state.level==3,"35species actual first-kill rewards reach55XP/level3")
	var repeated: Dictionary=xp.spawn_enemy("canon_iron_tusk",xp.hero().pos+Vector2i.RIGHT); repeated.hp=0; xp.on_death(repeated,xp.hero())
	check(xp.state.xp==55 and xp.state.loot_items.get("mana_stone_rank_7",0)>=1,"Repeat kills give noXP; rank7 mana stone is real loot")
func _test_environment()->void:
	var sim:=fresh(); travel(sim,5); travel(sim,6); travel(sim,7); travel(sim,8)
	check(ThirdFloorRules.FIELD_STATUSES.all(func(id: String)->bool:return sim.hero().statuses.has(id)),"Arrival applies all three field effects")
	var plain: Dictionary=sim.stat_breakdown(sim.hero(),false).values
	var field: Dictionary=sim.stat_breakdown(sim.hero()).values
	check(field.perception<=plain.perception and field.pain_resistance<plain.pain_resistance,"Field uses master stat rules")
	sim.status(sim.hero(),"ward",3); check(not sim.hero().statuses.has("ward"),"Witch field blocks nonfield statuses")
	var loaded:=load_json(sim); check(loaded.hero().statuses.has("field_pain"),"Field persists/reapplies after JSON")
	# An actual purple tree allows a late arrival only the remaining appearance window.
	sim.state.time=240; sim.hero().pos=ThirdFloorRules.active_hut_site(sim); sim.state.combat=false
	check(sim.interact()=="hut" and sim.enter_witch_hut().is_empty(),"Actual tree enters refuge")
	check(ThirdFloorRules.in_refuge(sim) and sim.state.hut_until==480 and sim.hero().statuses.is_empty(),"Late arrival cannot reset appearance expiry")
	loaded=load_json(sim); check(ThirdFloorRules.in_refuge(loaded),"Protected refuge survives save")
	var enemy: Dictionary=sim.spawn_enemy("canon_woodman",sim.hero().pos+Vector2i.RIGHT)
	enemy.alert=true
	var hp: int=sim.hero().hp; sim.enemy_turn(enemy)
	check(sim.hero().hp==hp and not sim.attack(sim.hero(),enemy),"Refuge blocks attacks in both directions")
	sim.state.units=[]; sim.state.combat=false
	check(sim.camp() and sim.state.time==480,"Camp stops at remaining4hour refuge expiry")
	check(not ThirdFloorRules.in_refuge(sim) and sim.hero().statuses.has("field_pain"),"Cabin expiry reapplies field")
	check(not sim.camp(),"Unsafe forest rejects long rest")
	sim.state.units=[]; sim.state.combat=false
	var before: int=sim.state.time
	sim.advance_time(60)
	check(sim.enemies().any(func(u: Dictionary)->bool:return u.get("witch_eye",false)) and sim.state.combat,"Stationaryhour triggers actual Carnivaro pursuit")
	check(sim.state.time==before+60,"Pursuit respects one absolute clock")
	check(SaveValidation.validate(sim.snapshot()).is_empty(),"Pursuit flags and field enemies validate")
	# Endpoints and no artificial drowning: high tide instead constrains camp choice.
	var est:=fresh(); travel(est,3); travel(est,9)
	est.state.time=20
	check(not est.camp(),"Estuary highwater rejects unprotected camp")
	est.hero().pos=est.state.map.shelter_mounds[0]
	check(est.camp(),"Dry red mound permits actual camp")
func _test_combat()->void:
	var sim:=arena()
	var frog: Dictionary=sim.spawn_enemy("canon_frogman",sim.hero().pos+Vector2i.RIGHT)
	var before: int=frog.hp; var random_before: int=sim.rng.state
	check(sim.hit(sim.hero(),frog,10,"physical","Attack",false,true,-1,{"category":"weapon"})==0 and frog.hp==before,"Mobile Frogman absolutely evades blunt club")
	check(sim.rng.state==random_before,"Absolute defense consumes no RNG")
	sim.hit(sim.hero(),frog,1,"cold","Ice Spear",false,true,-1,{"category":"spell"})
	check(frog.statuses.has("chilled"),"Cold stiffens mucus through actual damage hook")
	check(sim.hit(sim.hero(),frog,10,"physical","Attack",false,true,-1,{"category":"weapon"})>0,"Chilled Frogman can be struck with blunt weapon")
	var wraith: Dictionary=sim.spawn_enemy("canon_wraith",sim.hero().pos+Vector2i(2,0))
	check(sim.hit(sim.hero(),wraith,20,"physical","Attack",false,true,-1,{"category":"weapon"})==0,"Wraith actual physical immunity")
	check(sim.hit(sim.hero(),wraith,5,"cold","Ice Spear",false,true,-1,{"category":"spell"})>0,"Elemental spell bypasses incorporeal immunity")
	var orc: Dictionary=sim.spawn_enemy("canon_orc_warrior",sim.hero().pos+Vector2i(3,0))
	var sorcerer: Dictionary=sim.spawn_enemy("canon_orc_sorcerer",sim.hero().pos+Vector2i(4,0)); sorcerer.alert=true
	var resistance: float=sim.stat_value(orc,"physical_resistance")
	sim.enemy_turn(sorcerer)
	check(orc.statuses.has("frenzy") and sim.stat_value(orc,"physical_resistance")==resistance*3,"OrcSorcerer AI uses shared3xresistance status")
	check(sorcerer.cooldowns.get("frenzy",0)>0,"Support action has bounded cooldown")
	var tusk: Dictionary=sim.spawn_enemy("canon_iron_tusk",sim.hero().pos+Vector2i(1,1)); tusk.alert=true
	sim.enemy_turn(tusk)
	check(tusk.statuses.has("anchored") and ThirdFloorCombat.blocks_displacement(tusk),"Native IronTusk uses temporary Counterweight")
	# Loose essence through ordinary explicit absorb API, no developer bypass for activation.
	sim.state.units=[]; sim.state.combat=false; sim.hero().energy=sim.hero().max_energy
	sim.state.essence_drops=[{"id":"canon_iron_tusk","pos":sim.hero().pos,"region":6,"expires_at":sim.state.time+30}]; sim._recount_essence_drops()
	check(sim.absorb("canon_iron_tusk").is_empty(),"Actual IronTusk drop absorption")
	check(sim.use_ability(0,sim.hero().pos) and sim.hero().statuses.has("anchored"),"Absorbed Counterweight uses actual resource/cooldown pipeline")
	check(sim.hero().energy<int(sim.hero().max_energy),"Counterweight pays SoulPower")
	var loaded:=load_json(sim); check(loaded.hero().essences.has("canon_iron_tusk") and loaded.hero().statuses.has("anchored"),"Essence and active Counterweight persist")
	# Damaged/expired summoned units are recycled without reusing IDs or removing ordinary death records.
func _test_summons()->void:
	var sim:=arena(); sim.state.units=[]
	var ordinary: Dictionary=sim.spawn_enemy("canon_woodman",sim.hero().pos+Vector2i.RIGHT); ordinary.hp=0; ordinary.dead=true
	var last_id: String=""
	for repetition: int in range(50):
		var unit: Dictionary=sim.spawn_enemy("canon_ghoul",sim.hero().pos+Vector2i(2,0),true)
		check(unit.id!=last_id,"Summon stable ID never reused"); last_id=unit.id; unit.hp=0
		sim.prune_summons()
		check(sim.state.units.size()==1 and sim.state.units[0].id==ordinary.id,"Expired summons do not accumulate or erase ordinary death record")
