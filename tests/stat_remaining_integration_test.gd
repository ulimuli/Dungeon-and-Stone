extends SceneTree
## Real consumers under assisted raw-stat fixtures. Unknown novel rules are provisional.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(race: String = "human") -> GameSimulation:
	var sim := Sim.new(); sim.new_campaign("Remaining stats fixture",race,"adventurer",74119); sim.state.gold=10000
	return sim
func arena(sim: GameSimulation) -> void:
	check(sim.enter_region(1),"Actual expedition entry")
	sim.state.units=[]; sim.state.combat=false; sim.resolving_round=true; sim.state.map.traps=[]; sim.hero().pos=Vector2i(12,12)
	for y: int in range(7,20):
		for x: int in range(7,20): sim.state.map.tiles[y][x]=DungeonWorld.FLOOR
	sim.update_visibility()
func _initialize() -> void:
	_test_morphology_and_recovery()
	_test_mental_and_indices()
	_test_pain_attachment()
	_test_jump_breath()
	_test_food_and_resource_validation()
	_test_actual_spirit_clock()
	print("REMAINING STATS: %d checks, %d failures. Actual consumers and persistence under assisted fixtures; provisional mechanics are not novel-exact rules." % [checks,failures])
	quit(1 if failures else 0)
func _test_morphology_and_recovery() -> void:
	var sim:=fresh(); var unit:Dictionary=sim.hero(); var hp:int=unit.hp; var oldmax:int=unit.max_hp
	unit.base_stats={"endurance":10,"bone_strength":20,"bone_density":100,"height":300,"absorption":100}
	sim.recalculate(unit,false)
	check(unit.max_hp==oldmax+10 and unit.hp==hp,"Endurance raises maximum health without healing")
	check(sim.stat_value(unit,"height")==280 and sim.stat_value(unit,"weight")==20,"Density changes resolved height and weight once")
	check(sim.stat_value(unit,"attack_range")==1,"Density shrinkage applies before height-derived reach")
	check(sim.stat_value(unit,"armor")==3,"Independent bone domains contribute armor with final rounding")
	unit.hp=1; sim.heal(unit,10)
	check(unit.hp==16,"Absorption changes actual received healing")
	unit.base_stats.erase("bone_density"); sim.recalculate(unit,false)
	check(sim.stat_value(unit,"attack_range")==2,"Sufficient height increases actual weapon reach")
	var rng_state:int=sim.rng.state; var before:String=var_to_str(sim.state)
	var preview:Dictionary=sim.preview_equipment("spear")
	check(preview.errors.is_empty() and preview.after.attack_range==3,"Equipment preview includes intrinsic reach and morphology")
	check(var_to_str(sim.state)==before and sim.rng.state==rng_state,"Morphology comparison never changes campaign or RNG")
func _test_mental_and_indices() -> void:
	var sim:=fresh(); var unit:Dictionary=sim.hero(); var original:Dictionary=sim.stat_breakdown(unit,false).values
	unit.base_stats={"perception":20,"cognition":20,"cognitive_interference":20,"dexterity":20,"obsession":20,"impulse":20,"distrust":100,"fighting_spirit":100,"mana_sensitivity":50}
	sim.recalculate(unit,false); var values:Dictionary=sim.stat_breakdown(unit,false).values
	check(values.accuracy!=original.accuracy and values.evasion>original.evasion and values.initiative>original.initiative,"Awareness, cognition, interference and dexterity reach actual combat outputs")
	check(values.attack>original.attack and values.critical_chance>original.critical_chance,"Recklessness/fixation have explicit damage, accuracy and critical tradeoffs")
	check(is_equal_approx(values.natural_recovery,0.5),"Distrust slows actual safe natural recovery")
	check(is_equal_approx(values.spell_damage_multiplier,1.5),"Mana Sensitivity reaches the shared spell multiplier")
	sim.status(unit,"frightened",4)
	check(unit.statuses.frightened==2,"Fighting Spirit shortens actual fear")
	unit.statuses={}; unit.base_stats["fighting_spirit"]=-100; sim.recalculate(unit,false); sim.status(unit,"frightened",4)
	check(unit.statuses.frightened>4,"Negative Fighting Spirit prolongs actual fear")
	unit.statuses={}
	var prior:Dictionary=sim.stat_breakdown(unit,false).values
	unit.modifiers=[{"id":"index_fixture","source":"fixture","stat":"body_index","op":"add","value":20}]
	var indexed:Dictionary=sim.stat_breakdown(unit,false).values
	check(is_equal_approx(indexed.body_index,prior.body_index+20) and is_equal_approx(indexed.combat_index,prior.combat_index+20),"Group index modifiers propagate once into the informational combat total")
	check(indexed.attack==prior.attack and indexed.armor==prior.armor and indexed.accuracy==prior.accuracy,"Index changes never reapply combat buffs")
	for id:String in ["body_index","mind_index","ability_index","combat_index"]: check(not sim.stat_breakdown(unit,false).breakdown[id].sources.is_empty(),"Informational index exposes its contributors: "+id)
func _test_pain_attachment() -> void:
	var sim:=fresh(); arena(sim); var unit:Dictionary=sim.hero()
	unit.base_stats={"max_health":100,"armor":0}; sim.recalculate(unit,true)
	var source:Dictionary=sim.spawn_enemy("canon_goblin",unit.pos+Vector2i.RIGHT)
	check(sim.hit(source,unit,25,"physical","Attack",false,true,-1,{"category":"weapon","attack_resolved":true})==25 and unit.statuses.has("pained"),"A painful direct hit disrupts actions without altering HP damage")
	check(sim.stat_value(unit,"movement_cost")==2,"Pain increases actual movement cost")
	unit.statuses={}; unit.hp=100; unit.base_stats["pain_resistance"]=100; sim.recalculate(unit,false)
	check(sim.hit(source,unit,25,"physical","Attack",false,true,-1,{"category":"weapon","attack_resolved":true})==25 and not unit.statuses.has("pained"),"Pain Resistance prevents disruption while preserving the same HP loss")
	sim.state.combat=false; unit.base_stats["possessiveness"]=80; sim.recalculate(unit,false)
	check(sim.unequip("weapon").is_empty() and unit.statuses.get("distressed",0)==4,"Equipment removal triggers explicit attachment distress")
	check(is_equal_approx(sim.stat_value(unit,"soul_recovery"),0.5) and is_equal_approx(sim.stat_value(unit,"mana_recovery"),0.5),"Attachment affects SP and mana recovery, not damage resistance")
	var restored:=Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"New pain/attachment state survives actual validated JSON restoration")
func _test_jump_breath() -> void:
	var sim:=fresh(); arena(sim); var unit:Dictionary=sim.hero(); var start:Vector2i=unit.pos
	var before:String=var_to_str(sim.state); var stream:int=sim.rng.state
	check(not sim.jump(start+Vector2i.RIGHT*3),"Ordinary jump cannot exceed its actual range")
	# A rejected command may append an explanation, but never spends resources/RNG.
	check(unit.pos==start and sim.state.time==0 and sim.rng.state==stream,"Rejected jump preserves position, time and RNG")
	unit.base_stats={"jumping_power":50,"leg_power":50}; sim.recalculate(unit,false)
	sim.state.map.traps=[start+Vector2i.RIGHT]
	check(sim.jump_range(unit)==4 and sim.jump(start+Vector2i.RIGHT*3),"Jumping Power and Leg Power increase usable landing range")
	check(not sim.state.disarmed.has(sim.pos_key(start+Vector2i.RIGHT)),"Jump crosses an intermediate trap without stepping on it")
	var wall:Vector2i=unit.pos+Vector2i.UP; sim.state.map.tiles[wall.y][wall.x]=DungeonWorld.WALL
	check(not sim.jump_error(unit.pos+Vector2i.UP*2).is_empty(),"Walls still block airborne traversal")
	sim.state.map.tiles[wall.y][wall.x]=DungeonWorld.FLOOR
	sim.state.map.tiles[unit.pos.y][unit.pos.x]=DungeonWorld.HAZARD; unit.base_stats={"lung_capacity":100}; sim.recalculate(unit,false)
	var hp:int=unit.hp
	sim.advance_time(2)
	check(unit.hp==hp and unit.breath_remaining==0,"Lung Capacity extends breath holding through actual hazardous time")
	sim.advance_time(1)
	check(unit.hp<hp,"Expired breath takes poison exposure through the damage pipeline")
	check(not sim.camp(),"Choking terrain cannot be rested through safely")
	var restored:=Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Breath reserve survives actual JSON save restoration")
	unit.pos+=Vector2i.LEFT; sim.advance_time(1)
	check(not unit.has("breath_remaining"),"Fresh air clears the depleted reserve")
func _test_food_and_resource_validation() -> void:
	var sim:=fresh(); arena(sim); var unit:Dictionary=sim.hero(); sim.state.food=10
	unit.base_stats={"appetite":50}; sim.recalculate(unit,false); sim.advance_time(1440)
	check(sim.state.food==8,"Appetite changes actual daily shared food demand")
	var light:=fresh(); arena(light); light.hero().base_stats={"appetite":-25}; light.recalculate(light.hero(),false); light.state.food=10
	light.advance_time(1440)
	check(light.state.food==10 and is_equal_approx(float(light.state.hunger_remainder),0.5),"Fractional hunger accumulates without rounding up every day")
	var restored:=Sim.new(); check(restored.restore(JSON.parse_string(JSON.stringify(light.snapshot()))),"Fractional food demand survives save restoration")
	light.advance_time(1440); restored.advance_time(1440)
	check(light.state.food==9 and restored.state.food==9,"Reload preserves eventual ration conservation")
	for key:String in ["hunger_remainder","breath_remaining"]:
		for bad:Variant in [-1,INF,NAN,"1",null]:
			var raw:Dictionary=light.snapshot()
			if key=="hunger_remainder": raw[key]=bad
			else: raw.hero[key]=bad
			var old:String=var_to_str(restored.state); var rng_before:int=restored.rng.state
			check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed saved fraction/reserve rejects: "+key)
			check(var_to_str(restored.state)==old and restored.rng.state==rng_before,"Malformed reserve does not mutate campaign or RNG")
func _test_actual_spirit_clock() -> void:
	var sim:=fresh("fairy"); check(sim.form_spirit_contract().is_empty(),"Actual first-contract service completes")
	sim.wait_for_opening(); arena(sim); var unit:Dictionary=sim.hero()
	check(sim.toggle_spirit_light().is_empty(),"Actual spirit command activates illumination")
	sim.advance_time(35)
	check(unit.natural_energy_current==19,"World clock spends Natural Energy at the30-minute deadline")
	var restored:=Sim.new(); check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Active spirit restores between deadline ticks")
	sim.advance_time(29); restored.advance_time(29)
	check(unit.natural_energy_current==18 and restored.hero().natural_energy_current==18,"Reload preserves spirit drain chronology")
	var raw:Dictionary=sim.snapshot(); raw.hero.natural_energy_current=21
	check(not Validator.validate(raw).is_empty(),"Current Natural Energy cannot exceed the resolved capacity")
