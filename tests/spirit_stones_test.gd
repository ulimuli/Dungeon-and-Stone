extends SceneTree
## Next-stage helper tests use a local Spirit Stone item fixture only.
## The frozen runtime/catalog is not integrated or counted as new content here.
const Sim = preload("res://game/simulation.gd")
const Fire = preload("res://game/spirit_rules.gd")
const Rules = preload("res://game/spirit_stones.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(ancestry: String = "fairy") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Additional spirit helper fixture",ancestry,"adventurer",34117)
	sim.state.gold = 10000
	# A future catalog row is deliberately confined to this simulation instance.
	sim.item_defs[Rules.ITEM_ID] = {"name":"Spirit Stone fixture","kind":"supply","slot":"","price":Rules.PRICE,"weight":0.1,"market_unlocked":true,"reference_urls":[Rules.SOURCE]}
	return sim
func contracted() -> GameSimulation:
	var sim := fresh()
	check(Fire.form_contract(sim).is_empty(),"Fixture obtains the existing Fire Spirit contract")
	return sim
func seed_for(wanted: int) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,100000):
		probe.seed = candidate
		if probe.randi_range(1,100)==wanted: return candidate
	check(false,"A deterministic seed exists for requested integer roll")
	return 1
func conserved(unit: Dictionary) -> Array:
	return [unit.hp,unit.max_hp,unit.energy,unit.max_energy,unit.mana,unit.max_mana,unit.get("natural_energy_current"),unit.get("base_stats",{}).duplicate(true),unit.essences.duplicate(true)]
func rejected(sim: GameSimulation, label: String) -> void:
	var before: String = var_to_str(sim.state)
	var rng_before: int = sim.rng.state
	check(not Rules.attempt(sim).is_empty(),label+" reports rejection")
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,label+" preserves all state, inventory and RNG")
func _initialize() -> void:
	_test_attempts_and_price()
	_test_invalid_attempts()
	_test_replay()
	_test_guidance()
	_test_validation()
	print("SPIRIT STONES: %d checks, %d failures. Pure contract/guidance rules; actual market/combat integration is covered separately; Wind scope, compressed price and guidance coefficients are explicit reconstruction choices." % [checks,failures])
	quit(1 if failures else 0)
func _test_attempts_and_price() -> void:
	check(Rules.PRICE==150 and Rules.NOVEL_PRICE_QUOTE==150000 and Rules.SUCCESS_PERCENT==10,"Compressed price retains the sourced150,000 quote and exact10% attempt chance")
	var sim := contracted(); var unit: Dictionary = sim.hero()
	var gold: int = sim.state.gold; var quote: int = sim.market_price(Rules.ITEM_ID)
	check(sim.buy(Rules.ITEM_ID).is_empty(),"Existing market can purchase the local future-item fixture")
	check(sim.state.inventory.get(Rules.ITEM_ID,0)==1 and sim.state.gold==gold-quote,"Fixture purchase conserves the actual market quote and one stone")
	for roll: int in [1,10,11,100]:
		unit.erase("wind_contract"); unit.erase("wind_guidance")
		sim.state.inventory[Rules.ITEM_ID] = 3
		sim.rng.seed = seed_for(roll)
		var probe := RandomNumberGenerator.new(); probe.state = sim.rng.state
		check(probe.randi_range(1,100)==roll,"Boundary fixture uses the exact requested integer roll")
		var before: Array = conserved(unit); gold = sim.state.gold; var day: int = sim.state.day
		check(Rules.attempt(sim).is_empty(),"Valid attempt executes at integer boundary "+str(roll))
		check(sim.rng.state==probe.state,"Valid attempt consumes exactly one integer RNG draw")
		check(sim.state.inventory.get(Rules.ITEM_ID,0)==2,"Both successful and unsuccessful rolls consume exactly one stone")
		check(unit.get("wind_contract",false)==(roll<=10),"Success threshold includes10 and excludes11")
		if roll<=10: check(unit.has("wind_guidance") and unit.wind_guidance==false,"New Wind contract begins inactive")
		else: check(not unit.has("wind_contract") and not unit.has("wind_guidance"),"Failed attempt grants no partial contract flags")
		check(conserved(unit)==before and sim.state.gold==gold and sim.state.day==day,"Attempt never changes HP,SP,mana,Natural Energy capacity/current,essences,money or calendar")
	unit.erase("wind_contract"); unit.erase("wind_guidance"); sim.state.inventory[Rules.ITEM_ID]=1; sim.rng.seed=seed_for(100)
	check(Rules.attempt(sim).is_empty() and not sim.state.inventory.has(Rules.ITEM_ID),"A failed last-stone attempt removes the exhausted inventory row")
func _test_invalid_attempts() -> void:
	var sim := contracted()
	rejected(sim,"No Spirit Stone")
	sim.state.inventory[Rules.ITEM_ID]=1; sim.state.mode="dungeon"
	rejected(sim,"Attempt outside city")
	sim.state.mode="city"; sim.hero().hp=0
	rejected(sim,"Fallen Fairy")
	sim.hero().hp=10; sim.hero().dead=true
	rejected(sim,"Dead Fairy")
	sim.hero().dead=false; sim.hero().summon=true
	rejected(sim,"Summoned creature")
	var human := fresh("human"); human.state.inventory[Rules.ITEM_ID]=1
	rejected(human,"Wrong ancestry")
	var first := fresh(); first.state.inventory[Rules.ITEM_ID]=1
	rejected(first,"Missing first Fire contract")
	sim=contracted(); sim.state.inventory[Rules.ITEM_ID]=1; sim.hero()["wind_contract"]=true; sim.hero()["wind_guidance"]=false
	rejected(sim,"Already contracted Wind")
	sim.hero().wind_contract=1
	rejected(sim,"Malformed saved Wind flag")
	sim=contracted(); sim.state.inventory[Rules.ITEM_ID]=0.5
	rejected(sim,"Fractional inventory count")
func _test_replay() -> void:
	var original := contracted(); original.state.inventory[Rules.ITEM_ID]=2; original.rng.seed=seed_for(10)
	var replay := contracted(); replay.state.inventory[Rules.ITEM_ID]=2; replay.rng.state=original.rng.state
	check(Rules.attempt(original).is_empty() and Rules.attempt(replay).is_empty(),"Same valid fixtures replay the same additional-contract attempt")
	check(original.rng.state==replay.rng.state and original.hero().wind_contract==replay.hero().wind_contract and original.state.inventory==replay.state.inventory,"Equal RNG states exactly replay outcome and inventory conservation")
	var unit: Dictionary = original.hero()
	var decoded: Dictionary = original.decode(JSON.parse_string(JSON.stringify(original.encode(unit))))
	check(Rules.validate_unit(decoded).is_empty() and decoded.wind_contract and not decoded.wind_guidance,"New contract flags survive JSON serialization without relying on unfrozen runtime integration")
func _test_guidance() -> void:
	var sim := contracted(); var unit: Dictionary = sim.hero()
	unit["wind_contract"]=true; unit["wind_guidance"]=false
	check(not Rules.toggle(sim).is_empty() and not unit.wind_guidance,"Wind activation requires an equipped ranged bow")
	sim.add_item("bow",1); check(sim.equip("bow").is_empty(),"Fixture equips actual catalog bow")
	unit.statuses.stunned=1; var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	check(not Rules.toggle(sim).is_empty() and var_to_str(sim.state)==before and sim.rng.state==rng_before,"Unable-to-act state rejects activation atomically")
	unit.statuses={}; unit.natural_energy_current=0; before=var_to_str(sim.state)
	check(not Rules.toggle(sim).is_empty() and var_to_str(sim.state)==before,"Exhausted Natural Energy blocks activation")
	unit.natural_energy_current=3
	check(Rules.toggle(sim).is_empty() and unit.wind_guidance,"Living contracted Fairy activates Wind Guidance with bow and energy")
	var resource_before: Array=conserved(unit); rng_before=sim.rng.state
	check(Rules.attack_bonus(unit,sim.item_defs)==10 and Rules.attack_bonus(unit,sim.item_defs)==10,"Eligible bow Accuracy bonus is exactly the explicit+10 estimate")
	check(conserved(unit)==resource_before and sim.rng.state==rng_before,"Accuracy query spends no resource and rolls no RNG")
	unit.equipment.weapon="sword"
	check(Rules.attack_bonus(unit,sim.item_defs)==0 and Rules.validate_unit(unit).is_empty(),"Changing equipment suppresses the bonus without invalidating persisted contract flags")
	Rules.finish_attack(sim,unit)
	check(unit.natural_energy_current==3,"Non-ranged attacks cannot spend Wind energy")
	check(Rules.toggle(sim).is_empty() and not unit.wind_guidance,"Wind can be dismissed after unequipping the bow")
	unit.equipment.weapon="bow"; check(Rules.toggle(sim).is_empty(),"Bow permits guidance reactivation")
	var soul: int=unit.energy; var mana: int=unit.mana; var hp: int=unit.hp; var max_energy: float=sim.stat_value(unit,"natural_energy")
	# There is deliberately no hit/success parameter: the attack hook spends on
	# a normal attack attempt whether the accuracy roll hits or misses.
	Rules.finish_attack(sim,unit)
	check(unit.natural_energy_current==2 and unit.wind_guidance,"A guided attempted shot, including a miss, costs one Natural Energy")
	check(unit.energy==soul and unit.mana==mana and unit.hp==hp and sim.stat_value(unit,"natural_energy")==max_energy,"Guided shots do not spend HP,SP,mana or reduce Natural Energy capacity")
	if int(sim.state.day)!=1: sim.wait_for_opening()
	check(sim.enter_region(1),"Exhaustion fixture enters actual Labyrinth")
	sim.state.units=[]; sim.state.combat=false
	unit.natural_energy_current=1; unit.spirit.active=true
	check(Fire.visibility_bonus(sim,unit)==3,"Exhaustion fixture starts with actual Fire Spirit illumination")
	Rules.finish_attack(sim,unit)
	check(unit.natural_energy_current==0 and not unit.wind_guidance and not unit.spirit.active,"Last guided shot disables both Wind Guidance and Fire light at zero energy")
	check(Fire.visibility_bonus(sim,unit)==0 and Rules.attack_bonus(unit,sim.item_defs)==0,"Exhausted spirits supply neither visibility nor Accuracy bonus")
	Rules.finish_attack(sim,unit)
	check(unit.natural_energy_current==0,"Repeated finish hook cannot underflow an exhausted resource")
func _test_validation() -> void:
	check(Rules.validate_unit({}).is_empty(),"Legacy units need no Wind migration fields")
	var sim := contracted(); var good: Dictionary=sim.hero().duplicate(true)
	good["wind_contract"]=true; good["wind_guidance"]=false
	check(Rules.validate_unit(good).is_empty(),"Canonical Wind contract validates")
	for flags: Dictionary in [{"wind_contract":1,"wind_guidance":false},{"wind_contract":true,"wind_guidance":1},{"wind_contract":true},{"wind_guidance":false},{"wind_contract":false,"wind_guidance":true}]:
		var unit: Dictionary=sim.hero().duplicate(true); unit.merge(flags,true)
		check(not Rules.validate_unit(unit).is_empty(),"Malformed or contradictory Wind flags reject: "+str(flags))
	for record: Variant in [null,[],{}, {"element":1,"active":false},{"element":"cold","active":false},{"element":"fire","active":1}]:
		var unit: Dictionary=good.duplicate(true); unit.spirit=record
		check(not Rules.validate_unit(unit).is_empty(),"Wind contract requires a structurally valid first Fire contract")
	for value: Variant in [null,-1,0,0.5,INF,NAN,"1",1000001]:
		var unit: Dictionary=good.duplicate(true); unit.wind_guidance=true; unit.natural_energy_current=value
		check(not Rules.validate_unit(unit).is_empty(),"Active Wind requires finite positive integral current Natural Energy")
	var unit: Dictionary=good.duplicate(true); unit.ancestry="human"
	check(not Rules.validate_unit(unit).is_empty(),"Wind flags cannot persist on another ancestry")
	unit=good.duplicate(true); unit.equipment.weapon=""
	check(Rules.validate_unit(unit).is_empty(),"Unarmed saved Fairy retains an inactive valid Wind contract")
