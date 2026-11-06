extends SceneTree
## Contract acquisition and numeric conversions are provisional reconstruction.
const Sim = preload("res://game/simulation.gd")
const Rules = preload("res://game/spirit_rules.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(ancestry: String = "fairy") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Spirit fixture",ancestry,"adventurer",34117)
	sim.state.gold=1000
	return sim
func contract(sim: GameSimulation) -> String:
	return sim.form_spirit_contract() if sim.has_method("form_spirit_contract") else Rules.form_contract(sim)
func toggle(sim: GameSimulation) -> String:
	return sim.toggle_spirit_light() if sim.has_method("toggle_spirit_light") else Rules.toggle(sim)
func rest_spirit(sim: GameSimulation) -> String:
	return sim.rest_spirit() if sim.has_method("rest_spirit") else Rules.rest(sim)
func expedition(sim: GameSimulation) -> void:
	if int(sim.state.day)!=1: sim.wait_for_opening()
	check(sim.enter_region(1),"Contracted Fairy enters the actual Labyrinth")
	sim.state.units=[]; sim.state.combat=false
func _initialize() -> void:
	_test_acquisition()
	_test_light_and_energy()
	_test_rest_and_closure()
	_test_save_and_validation()
	print("SPIRIT RULES: %d checks, %d failures. Contract lesson and all numerical conversions remain explicit reconstruction choices." % [checks,failures])
	quit(1 if failures else 0)
func _test_acquisition() -> void:
	var sim := fresh(); var unit: Dictionary=sim.hero()
	var hp: int=unit.hp; var soul: int=unit.energy; var mana: int=unit.mana; var essences: Array=unit.essences.duplicate(); var rng_before: int=sim.rng.state
	check(contract(sim).is_empty(),"Fairy completes provisional first Fire Spirit instruction")
	check(sim.state.gold==880 and sim.state.day==4,"Lesson charges exactly120 stones and three city days")
	check(unit.spirit=={"element":"fire","active":false} and unit.natural_energy_current==20,"Contract starts inactive with a separate20-point Natural Energy resource")
	check(unit.base_stats.has("natural_energy") and sim.stat_value(unit,"natural_energy")==20,"Acquisition creates a canonical Natural Energy baseline consumed by shared stats")
	check(unit.hp==hp and unit.energy==soul and unit.mana==mana and unit.essences==essences,"Spirit acquisition grants no HP refill, mana, Soul Power or essence")
	check(sim.rng.state==rng_before,"Deterministic lesson draws no hidden RNG")
	var before: String=var_to_str(sim.state)
	check(not contract(sim).is_empty() and var_to_str(sim.state)==before,"Duplicate contract rejects without charging or changing the calendar")
	var human := fresh("human"); before=var_to_str(human.state)
	check(not contract(human).is_empty() and var_to_str(human.state)==before,"Human cannot buy the Fairy contract")
	var poor := fresh(); poor.state.gold=119; before=var_to_str(poor.state)
	check(not contract(poor).is_empty() and var_to_str(poor.state)==before,"Unaffordable lesson rejects atomically")
	var fallen := fresh(); fallen.hero().hp=0
	check(not contract(fallen).is_empty(),"Fallen Fairy cannot form a contract")
	var outside := fresh(); expedition(outside); before=var_to_str(outside.state)
	check(not contract(outside).is_empty() and var_to_str(outside.state)==before,"Contract instruction requires city access")
	var mage := fresh(); mage.hero().profession="mage"
	check(contract(mage).is_empty(),"Contract checks Fairy ancestry without assuming explorer or mage profession")
func _test_light_and_energy() -> void:
	var sim := fresh(); check(contract(sim).is_empty(),"Light fixture contracts"); expedition(sim)
	var unit: Dictionary=sim.hero(); var light: int=sim.state.light; var natural: float=sim.stat_value(unit,"natural_energy")
	check(Rules.visibility_bonus(sim,unit)==0,"Inactive spirit supplies no illumination")
	unit.statuses.stunned=1; var before: String=var_to_str(sim.state)
	check(not toggle(sim).is_empty() and var_to_str(sim.state)==before,"Incapacitated Fairy cannot command the spirit")
	unit.statuses={}
	check(toggle(sim).is_empty() and unit.spirit.active,"Living contracted Fairy can activate spirit illumination")
	check(Rules.visibility_bonus(sim,unit)==3,"Active Fire Spirit supplies the estimated nearby sight bonus")
	var observer: Dictionary=unit.duplicate(true); observer.pos=unit.pos+Vector2i.RIGHT*6
	check(Rules.visibility_bonus(sim,observer)==3,"Light reaches another observer at the inclusive six-tile boundary")
	observer.pos+=Vector2i.RIGHT
	check(Rules.visibility_bonus(sim,observer)==0,"Spirit illumination does not reach a distant party observer")
	check(sim.state.light==light and sim.stat_value(unit,"natural_energy")==natural,"Spirit light never rewrites the Light level or Natural Energy capacity")
	var soul: int=unit.energy; var mana: int=unit.mana
	Rules.advance_tick(sim)
	check(unit.natural_energy_current==19 and unit.energy==soul and unit.mana==mana,"One30-minute event spends only one Natural Energy")
	check(toggle(sim).is_empty() and not unit.spirit.active,"Spirit light can be dismissed")
	Rules.advance_tick(sim)
	check(unit.natural_energy_current==19,"Inactive contract does not drain energy")
	unit.natural_energy_current=1; check(toggle(sim).is_empty(),"One remaining Natural Energy permits activation")
	Rules.advance_tick(sim)
	check(unit.natural_energy_current==0 and not unit.spirit.active and Rules.visibility_bonus(sim,unit)==0,"Exhaustion disables light immediately without erasing the contract")
	before=var_to_str(sim.state)
	check(not toggle(sim).is_empty() and var_to_str(sim.state)==before,"Exhausted spirit cannot reactivate without rest")
func _test_rest_and_closure() -> void:
	var sim := fresh(); check(contract(sim).is_empty(),"Rest fixture contracts"); expedition(sim)
	var unit: Dictionary=sim.hero(); unit.natural_energy_current=2
	check(toggle(sim).is_empty(),"Rest fixture activates light")
	var clock: int=sim.state.time; var soul: int=unit.energy; var mana: int=unit.mana
	check(rest_spirit(sim).is_empty(),"Safe two-hour spirit rest completes")
	check(sim.state.time==clock+120 and not unit.spirit.active and unit.natural_energy_current==20,"Rest advances actual clock, dismisses light and restores capacity after time passes")
	check(unit.energy>=soul and unit.mana>=mana,"Spirit rest uses the actual clock's ordinary resource recovery")
	sim.state.combat=true; var before: String=var_to_str(sim.state)
	check(not rest_spirit(sim).is_empty() and var_to_str(sim.state)==before,"Combat blocks spirit rest without consuming time or dismissing light")
	sim.state.combat=false
	unit.base_stats["natural_energy"]=25; sim.recalculate(unit,false); unit.natural_energy_current=1
	check(rest_spirit(sim).is_empty() and unit.natural_energy_current==25,"Rest restores the resolved modified Natural Energy capacity")
	sim.state.time=sim.portal_limit()-60; unit.natural_energy_current=1; check(toggle(sim).is_empty(),"Closure fixture activates remaining light")
	check(not rest_spirit(sim).is_empty() and sim.state.mode=="city","Portal closure interrupts spirit rest through the actual deadline system")
	check(unit.natural_energy_current==1 and not unit.spirit.active,"Interrupted spirit rest cannot refill Natural Energy after extraction")
func _test_save_and_validation() -> void:
	var sim := fresh(); check(contract(sim).is_empty(),"Save fixture contracts"); expedition(sim); check(toggle(sim).is_empty(),"Save fixture activates spirit")
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Contract and separate current energy survive actual JSON save restoration")
	check(restored.hero().spirit==sim.hero().spirit and restored.hero().natural_energy_current==20,"Save restoration preserves active contract and current Natural Energy")
	check(Rules.validate_unit({}).is_empty(),"Legacy unit without a contract needs no spirit migration")
	check(Rules.validate_unit(sim.hero()).is_empty(),"Canonical contracted Fairy passes structural validation")
	for value: Variant in [null,[],{}, {"element":"cold","active":false},{"element":1,"active":false},{"element":"fire","active":1},{"element":"fire","active":false,"unknown":1}]:
		var unit: Dictionary=sim.hero().duplicate(true); unit.spirit=value
		check(not Rules.validate_unit(unit).is_empty(),"Malformed spirit record rejects: "+str(value))
	for value: Variant in [-1,1.5,INF,NAN,"20",1000001]:
		var unit: Dictionary=sim.hero().duplicate(true); unit.natural_energy_current=value
		check(not Rules.validate_unit(unit).is_empty(),"Malformed Natural Energy rejects")
	var invalid: Dictionary=sim.hero().duplicate(true); invalid.ancestry="human"
	check(not Rules.validate_unit(invalid).is_empty(),"Contract cannot migrate onto another ancestry")
	invalid=sim.hero().duplicate(true); invalid.natural_energy_current=0
	check(not Rules.validate_unit(invalid).is_empty(),"Exhausted active spirit is invalid")
	check(not Rules.validate_unit({"natural_energy_current":1}).is_empty(),"Orphaned current Natural Energy cannot exist without a contract")
