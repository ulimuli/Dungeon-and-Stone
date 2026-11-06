extends SceneTree
## Extra funds and deterministic seed selection are test assistance only.
## Every purchased item, contract, command and combat consumer is real content.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(ancestry: String = "fairy") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Spirit Stone integration",ancestry,"adventurer",34117)
	sim.state.gold=10000
	return sim
func seed_for(wanted: int) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,100000):
		probe.seed=candidate
		if probe.randi_range(1,100)==wanted: return candidate
	check(false,"Seed selector finds requested integer roll")
	return 1
func resources(unit: Dictionary) -> Array:
	return [unit.hp,unit.max_hp,unit.energy,unit.max_energy,unit.mana,unit.max_mana,unit.get("natural_energy_current"),unit.get("base_stats",{}).duplicate(true),unit.essences.duplicate(true)]
func first_contract() -> GameSimulation:
	var sim := fresh()
	check(sim.form_spirit_contract().is_empty(),"Actual Fairy first-contract command succeeds")
	return sim
func wind_contract(sim: GameSimulation, id: String = "hero") -> void:
	check(sim.buy("spirit_stone").is_empty(),"Actual Spirit Stone can be bought from current market")
	sim.rng.seed=seed_for(10)
	check(sim.attempt_spirit_stone(id).is_empty() and sim.unit_by_id(id).get("wind_contract",false),"Actual seeded Spirit Stone command grants Wind on roll10")
func armed() -> GameSimulation:
	var sim := first_contract(); wind_contract(sim)
	check(sim.buy("bow").is_empty() and sim.equip("bow").is_empty(),"Actual market bow equips before Wind Guidance")
	return sim
func battlefield(sim: GameSimulation) -> Dictionary:
	if int(sim.state.day)!=1: sim.wait_for_opening()
	check(sim.enter_region(1),"Actual expedition entry retains spirit contracts")
	sim.state.units=[]; sim.state.combat=true; sim.resolving_round=true
	var unit: Dictionary=sim.hero()
	for y: int in range(-4,5):
		for x: int in range(-4,5):
			var tile: Vector2i=unit.pos+Vector2i(x,y)
			if tile.x>0 and tile.y>0 and tile.y<sim.state.map.tiles.size()-1 and tile.x<sim.state.map.tiles[tile.y].size()-1: sim.state.map.tiles[tile.y][tile.x]=DungeonWorld.FLOOR
	var target: Dictionary=sim.spawn_enemy("canon_ghoul",unit.pos+Vector2i.RIGHT)
	target.hp=1000; target.max_hp=1000; target.armor=0; target.evasion=0; target.resist={}; target.essences=[]; target.statuses={"stunned":99}
	unit.ap=20; unit.attacked=false
	sim.update_visibility()
	return target
func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),label+" passes actual JSON save validation")
	return restored
func reject_attempt(sim: GameSimulation, label: String) -> void:
	var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	check(not sim.attempt_spirit_stone().is_empty(),label+" rejects")
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,label+" preserves state, inventory and RNG")
func _initialize() -> void:
	_test_market_and_attempts()
	_test_attempt_guards_and_replay()
	_test_toggle_guards()
	_test_actual_bow_consumers()
	_test_shared_exhaustion()
	_test_persistence_and_invalid_saves()
	print("SPIRIT STONE INTEGRATION: %d checks, %d failures. Actual market, commands, combat, clock and save validation exercised; funds and seed selection are explicit test assistance." % [checks,failures])
	quit(1 if failures else 0)
func _test_market_and_attempts() -> void:
	var sim := first_contract(); var unit: Dictionary=sim.hero()
	check(sim.item_defs.has("spirit_stone") and int(sim.item_defs.spirit_stone.price)==150,"Actual catalog contains Spirit Stone at compressed base150")
	var gold: int=sim.state.gold; var buying: int=sim.market_price("spirit_stone",true); var selling: int=sim.market_price("spirit_stone",false)
	check(sim.buy("spirit_stone").is_empty() and sim.state.inventory.get("spirit_stone",0)==1,"Actual purchase adds exactly one Spirit Stone")
	check(sim.state.gold==gold-buying,"Purchase charges the displayed market quote exactly")
	check(sim.sell("spirit_stone").is_empty() and not sim.state.inventory.has("spirit_stone"),"Actual sale consumes exactly the owned stone")
	check(sim.state.gold==gold-buying+selling,"Buy/sell conserves both quoted currency transfers")
	var before: String=var_to_str(sim.state)
	check(not sim.sell("spirit_stone").is_empty() and var_to_str(sim.state)==before,"Selling an absent stone cannot create currency")
	for roll: int in [11,10]:
		check(sim.buy("spirit_stone").is_empty(),"Attempt purchases its own real stone")
		sim.rng.seed=seed_for(roll)
		var probe := RandomNumberGenerator.new(); probe.state=sim.rng.state; probe.randi_range(1,100)
		var conserved: Array=resources(unit); gold=sim.state.gold; var day: int=sim.state.day
		check(sim.attempt_spirit_stone().is_empty(),"Actual attempt executes boundary roll"+str(roll))
		check(not sim.state.inventory.has("spirit_stone") and sim.rng.state==probe.state,"Success/failure consumes exactly one stone and one integer RNG draw")
		check(unit.get("wind_contract",false)==(roll==10),"Actual command includes roll10 and excludes roll11")
		check(resources(unit)==conserved and sim.state.gold==gold and sim.state.day==day,"Attempt adds no free HP,SP,mana,Natural Energy,essence,money or time")
func _test_attempt_guards_and_replay() -> void:
	var sim := first_contract(); reject_attempt(sim,"Missing inventory stone")
	check(sim.buy("spirit_stone").is_empty(),"Guard fixture purchases stone")
	sim.hero().hp=0; reject_attempt(sim,"Fallen Fairy"); sim.hero().hp=10
	sim.hero().dead=true; reject_attempt(sim,"Dead Fairy"); sim.hero().dead=false
	sim.hero().summon=true; reject_attempt(sim,"Summoned creature"); sim.hero().summon=false
	var first := fresh(); check(first.buy("spirit_stone").is_empty(),"Uncontracted fixture purchases stone"); reject_attempt(first,"Missing Fire contract")
	var human := fresh("human"); check(human.buy("spirit_stone").is_empty(),"Human fixture purchases stone"); reject_attempt(human,"Wrong ancestry")
	if int(sim.state.day)!=1: sim.wait_for_opening()
	check(sim.enter_region(1),"City-only guard enters actual dungeon"); reject_attempt(sim,"Attempt outside city")
	var original := first_contract(); check(original.buy("spirit_stone").is_empty(),"Replay fixture purchases stone"); original.rng.seed=seed_for(10)
	var restored := roundtrip(original,"Pending additional-contract attempt")
	check(original.attempt_spirit_stone().is_empty() and restored.attempt_spirit_stone().is_empty(),"Actual saved attempt executes after restore")
	check(restored.hero().wind_contract and restored.rng.state==original.rng.state and restored.state.inventory==JSON.parse_string(JSON.stringify(original.state.inventory)),"Saved RNG exactly replays actual success and stone consumption (wind=%s, RNG=%s/%s, inventory=%s/%s)" % [restored.hero().get("wind_contract"),restored.rng.state,original.rng.state,restored.state.inventory,original.state.inventory])
	check(restored.buy("spirit_stone").is_empty(),"Duplicate guard buys another stone"); reject_attempt(restored,"Already owns Wind")
func _test_toggle_guards() -> void:
	var first := first_contract(); var before: String=var_to_str(first.state); var rng_before: int=first.rng.state
	check(not first.toggle_wind_guidance().is_empty() and var_to_str(first.state)==before and first.rng.state==rng_before,"Actual Wind command requires an additional contract without changing state/RNG")
	var sim := armed(); var unit: Dictionary=sim.hero()
	unit.statuses.stunned=1; before=var_to_str(sim.state); rng_before=sim.rng.state
	check(not sim.toggle_wind_guidance().is_empty() and var_to_str(sim.state)==before and sim.rng.state==rng_before,"Actual Wind command rejects incapacitation atomically")
	unit.statuses={}; unit.natural_energy_current=0; before=var_to_str(sim.state)
	check(not sim.toggle_wind_guidance().is_empty() and var_to_str(sim.state)==before,"Actual Wind activation requires positive shared Natural Energy")
	before=var_to_str(sim.state); rng_before=sim.rng.state
	check(not sim.attempt_spirit_stone("missing_unit").is_empty() and var_to_str(sim.state)==before and sim.rng.state==rng_before,"Invalid target identity cannot consume a stone or RNG")
	var poor := fresh(); poor.state.gold=poor.market_price("spirit_stone")-1; before=var_to_str(poor.state)
	check(not poor.buy("spirit_stone").is_empty() and var_to_str(poor.state)==before,"Unaffordable actual market purchase preserves currency and inventory")
func _test_actual_bow_consumers() -> void:
	var sim := armed()
	# One real essence is granted solely to exercise its normal bow on-hit proc.
	sim.add_item("sealed_canon_goblin_archer",1)
	check(sim.absorb_sealed("canon_goblin_archer").is_empty(),"Actual Goblin Archer essence absorption enables its source-backed bow poison")
	var target: Dictionary=battlefield(sim); var unit: Dictionary=sim.hero()
	var baseline: float=sim.stat_value(unit,"accuracy")
	check(sim.toggle_wind_guidance().is_empty(),"Actual Wind Guidance command activates with the equipped bow")
	check(sim.stat_value(unit,"accuracy")==baseline+10,"Shared combat Accuracy gains exactly the estimated+10 Wind bonus")
	var detail: Dictionary=sim.stat_breakdown(unit)
	check(detail.breakdown.accuracy.sources.any(func(row: Dictionary)->bool:return row.source=="spirit:wind"),"Actual breakdown exposes Wind Accuracy provenance")
	for roll: int in [1,100]:
		unit.ap=20; unit.attacked=false; sim.rng.seed=seed_for(roll)
		var nature: int=unit.natural_energy_current; var soul: int=unit.energy; var mana: int=unit.mana; var hp: int=target.hp
		check(sim.attack(unit,target),"Actual guided bow attack executes, including a miss")
		check((target.hp<hp)==(roll==1),"Selected RNG creates a real hit followed by a real miss")
		check(unit.natural_energy_current==nature-1 and unit.energy==soul and unit.mana==mana,"Hit and miss each spend exactly one shared Natural Energy and no SP/mana")
		if roll==1: check(target.statuses.has("poison"),"Actual successful bow hit triggers Goblin Archer poison without another Wind cost")
	var nature: int=unit.natural_energy_current
	sim.hit(unit,target,5,"cold","Secondary component fixture",false,true,-1,{"attack_resolved":true,"category":"weapon","secondary":true})
	check(unit.natural_energy_current==nature,"Additional damage resolution cannot double-charge Wind Nature outside the normal attack command")
	check(sim.toggle_wind_guidance().is_empty(),"Actual command dismisses guidance")
	unit.ap=20; unit.attacked=false; sim.rng.seed=seed_for(1)
	check(sim.attack(unit,target) and unit.natural_energy_current==nature,"Normal bow attack without guidance spends no Natural Energy")
	check(sim.stat_value(unit,"accuracy")==baseline,"Dismissing guidance restores original combat Accuracy")
	check(sim.toggle_wind_guidance().is_empty(),"Guidance reactivates before an equipment change")
	sim.state.combat=false; sim.add_item("sword",1); check(sim.equip("sword").is_empty(),"Actual equipment command swaps bow for sword")
	sim.state.combat=true; unit.ap=20; unit.attacked=false; sim.rng.seed=seed_for(1)
	var permanent_accuracy: float=sim.stat_value(unit,"accuracy",false)
	check(sim.stat_value(unit,"accuracy")==permanent_accuracy,"Persisted Wind flag grants no Accuracy with a non-bow weapon")
	check(sim.attack(unit,target) and unit.natural_energy_current==nature,"Actual non-bow attack does not consume Wind Nature")
	check(sim.toggle_wind_guidance().is_empty(),"Wind can be dismissed after switching equipment")
	check(not sim.toggle_wind_guidance().is_empty(),"Actual activation rejects a non-bow weapon")
func _test_shared_exhaustion() -> void:
	var sim := armed(); var target: Dictionary=battlefield(sim); var unit: Dictionary=sim.hero()
	unit.natural_energy_current=1
	check(sim.toggle_wind_guidance().is_empty() and sim.toggle_spirit_light().is_empty(),"Last-energy fixture activates both spirits sharing one Natural Energy")
	sim.rng.seed=seed_for(1)
	check(sim.attack(unit,target),"Actual last-energy bow attack resolves")
	check(unit.natural_energy_current==0 and not unit.wind_guidance and not unit.spirit.active,"One shot exhausts shared energy and disables both Wind and Fire")
	check(sim.stat_value(unit,"accuracy")==sim.stat_value(unit,"accuracy",false),"Last-energy attack removes Wind combat bonus immediately")
	roundtrip(sim,"Attack-exhausted spirits")
	var clock := armed(); battlefield(clock); var clock_unit: Dictionary=clock.hero(); clock_unit.natural_energy_current=1
	check(clock.toggle_wind_guidance().is_empty() and clock.toggle_spirit_light().is_empty(),"Clock fixture activates both spirits")
	clock.advance_time(29)
	check(clock_unit.natural_energy_current==1 and clock_unit.wind_guidance and clock_unit.spirit.active,"Fire energy remains until the actual30-minute deadline")
	clock.advance_time(1)
	check(clock_unit.natural_energy_current==0 and not clock_unit.wind_guidance and not clock_unit.spirit.active,"Actual Fire deadline exhausts shared energy and clears Wind too")
	roundtrip(clock,"Clock-exhausted spirits")
	var capacity := armed(); var capacity_unit: Dictionary=capacity.hero()
	check(capacity.toggle_wind_guidance().is_empty() and capacity.toggle_spirit_light().is_empty(),"Capacity fixture activates both spirits")
	capacity_unit.base_stats["natural_energy"]=0; capacity.recalculate(capacity_unit,false)
	check(capacity_unit.natural_energy_current==0 and not capacity_unit.wind_guidance and not capacity_unit.spirit.active,"Resolved capacity0 clamps current energy and disables both consumers")
	roundtrip(capacity,"Zero-capacity spirits")
func _test_persistence_and_invalid_saves() -> void:
	var sim := armed(); check(sim.toggle_wind_guidance().is_empty(),"Save fixture activates Wind")
	var restored := roundtrip(sim,"Active additional contract")
	check(restored.hero().wind_contract and restored.hero().wind_guidance and restored.hero().natural_energy_current==20,"JSON roundtrip preserves contract, activation and shared resource")
	var companion := fresh("human"); check(companion.recruit("fairy_archer").is_empty(),"Actual generated Fairy archer recruits")
	var member: Dictionary=companion.state.party[0]; var member_id: String=member.id
	check(companion.form_spirit_contract(member_id).is_empty(),"Recruited Fairy receives first spirit lesson")
	wind_contract(companion,member_id)
	check(companion.toggle_wind_guidance(member_id).is_empty(),"Recruited Fairy activates its equipped bow's guidance")
	member.natural_energy_current=7; companion.dismiss(member_id)
	check(companion.state.benched.fairy_archer.wind_contract and companion.state.benched.fairy_archer.wind_guidance,"Actual dismissal preserves the complete Fairy's Wind build")
	var benched := roundtrip(companion,"Benched additional-contract Fairy")
	check(benched.recruit("fairy_archer").is_empty(),"Actual bench rejoin succeeds")
	check(benched.state.party[0].wind_contract and benched.state.party[0].wind_guidance and benched.state.party[0].natural_energy_current==7,"Rejoin preserves Wind and partially spent Natural Energy without a refill")
	for changes: Dictionary in [{"wind_contract":1},{"wind_guidance":"true"},{"wind_contract":false},{"natural_energy_current":0},{"natural_energy_current":21},{"ancestry":"human"},{"spirit":null}]:
		var raw: Dictionary=sim.snapshot(); raw.hero.merge(changes,true)
		var before: String=var_to_str(restored.state); var rng_before: int=restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed saved Wind flags/resources reject before assignment: "+str(changes))
		check(var_to_str(restored.state)==before and restored.rng.state==rng_before,"Failed Wind save restoration preserves campaign and RNG atomically")
	for key: String in ["wind_contract","wind_guidance"]:
		var raw: Dictionary=sim.snapshot(); raw.hero.erase(key)
		var before: String=var_to_str(restored.state); var rng_before: int=restored.rng.state
		check(not restored.restore(raw) and var_to_str(restored.state)==before and restored.rng.state==rng_before,"Missing paired Wind flag rejects atomically")
