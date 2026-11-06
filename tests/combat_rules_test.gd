extends SceneTree
## These checks protect implementation arithmetic and interaction invariants.
## They do not establish the novel's unverified combat coefficients.

const Simulation = preload("res://game/simulation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh() -> GameSimulation:
	var sim := Simulation.new()
	sim.new_campaign("Combat rules test", "barbarian", "adventurer", 74119)
	sim.enter_region(1)
	sim.state.units = []
	sim.state.combat = true
	return sim

func enemy(sim: GameSimulation) -> Dictionary:
	var target: Dictionary = sim.spawn_enemy("canon_ghoul", sim.hero().pos + Vector2i.RIGHT)
	target.hp = 1000; target.max_hp = 1000
	target.armor = 5; target.resist = {}
	return target

func _initialize() -> void:
	_test_damage_boundaries()
	_test_hit_resolution()
	_test_status_lifecycle()
	_test_poison_and_paralysis()
	_test_bow_passive()
	_test_trigger_budget()
	print("COMBAT RULES: %d checks, %d failures. Current numerical algorithms and interactions; combat coefficients remain provisional. No save files used." % [checks, failures])
	quit(1 if failures else 0)

func _test_damage_boundaries() -> void:
	var sim := fresh()
	# Arithmetic boundaries protect ordering, rounding, and prevention of immunity.
	check(sim.damage_amount(20,5,50,true) == 8,"Physical armor subtraction precedes resistance, with fractional damage rounded upward")
	check(sim.damage_amount(20,500,50,false) == 10,"Nonphysical damage ignores armor")
	check(sim.damage_amount(20,5,0,true) == 15,"Physical armor has an actual damage effect")
	check(sim.damage_amount(20,5,-50,true) == 23,"Negative resistance amplifies post-armor damage")
	check(sim.damage_amount(20,5,-500,true) == 23,"Vulnerability cannot exceed its lower resistance bound")
	check(sim.damage_amount(20,5,80,true) == 3 and sim.damage_amount(20,5,500,true) == 3,"Extreme resistance cannot exceed its mitigation bound")
	check(sim.damage_amount(2,500,80,true) == 1,"Overwhelming armor and resistance retain minimum one damage")
	check(sim.damage_amount(0,0,80,false) == 1,"Zero nominal damage never heals or creates a negative hit")
	var target: Dictionary = enemy(sim)
	target.resist = {"cold":1000,"fire":-1000}
	check(sim.resistance(target,"cold") == 80 and sim.resistance(target,"fire") == -50,"Saved resistance values receive the same bounds as direct damage calculations")
	check(sim.resistance(target,"poison") == 0,"An unspecified resistance has no implicit mitigation")

func _test_hit_resolution() -> void:
	var sim := fresh()
	var target: Dictionary = enemy(sim)
	var source: Dictionary = sim.hero()
	target.resist = {"physical":50,"cold":50}
	check(sim.hit(source,target,20,"physical","Numeric fixture",false,true) == 8 and int(target.hp) == 992,"Guaranteed hit applies expected post-armor/resistance damage to actual HP")
	target.guard = true
	check(sim.hit(source,target,20,"physical","Guard fixture",false,true) == 6,"Guard adds effective physical armor")
	check(sim.hit(source,target,20,"cold","Guard magic fixture",false,true) == 10,"Guard does not grant an implicit magic resistance")
	target.guard = false
	sim.status(target,"ward",2,7)
	check(sim.hit(source,target,20,"physical","Ward fixture",false,true) == 4,"Ward potency participates in physical armor calculation")
	check(sim.hit(source,target,20,"cold","Ward magic fixture",false,true) == 10,"Ward armor preserves nonphysical armor bypass")
	target.statuses = {}; target.status_power = {}; target.resist = {}; target.armor = 0
	source.statuses = {"weakened":2}
	check(sim.hit(source,target,20,"physical","Weakness fixture",false,true) == 15,"Weakened changes actual outgoing damage")
	source.statuses.transformed = 2; source.status_power.transformed = 5
	check(sim.hit(source,target,20,"physical","Transformation fixture",false,true) == 18,"Unified stat ordering applies flat transformation before weakness multiplier")
	var before: int = int(target.hp)
	var dealt: int = sim.hit(source,target,100000,"physical","Lethal fixture",false,true)
	check(dealt > before and int(target.hp) == 0 and bool(target.dead),"Overkill clamps actual HP and executes one death transition")
	var kills: int = int(sim.state.killed.canon_ghoul)
	check(sim.hit(source,target,100000,"physical","Repeated lethal fixture",false,true) == 0 and int(sim.state.killed.canon_ghoul) == kills,"Already-dead target cannot yield repeated damage, death or rewards")

func _test_status_lifecycle() -> void:
	var sim := fresh()
	var unit: Dictionary = sim.hero()
	sim.status(unit,"ward",3,6)
	sim.status(unit,"ward",2,4)
	check(int(unit.statuses.ward) == 3 and int(unit.status_power.ward) == 6,"Weaker reapplication does not stack or shorten a status")
	sim.status(unit,"ward",5,9)
	check(int(unit.statuses.ward) == 5 and int(unit.status_power.ward) == 9,"Stronger reapplication refreshes to max duration and potency")
	unit.statuses.ward = 1
	unit.cooldowns = {"ice_spear":2,"canon_goblin":0}
	sim.tick_unit(unit)
	check(not unit.statuses.has("ward") and not unit.status_power.has("ward"),"Final status tick removes both duration and associated potency")
	check(int(unit.cooldowns.ice_spear) == 1 and int(unit.cooldowns.canon_goblin) == 0,"Cooldown ticks once and never falls below zero")
	sim.tick_unit(unit)
	check(int(unit.cooldowns.ice_spear) == 0,"Cooldown becomes available on its exact final tick")
	var before: Dictionary = unit.statuses.duplicate(true)
	sim.status(unit,"",3); sim.status(unit,"poison",0)
	check(unit.statuses == before,"Empty or zero-duration statuses do not create invalid effects")
	unit.hp = 0
	sim.status(unit,"poison",3)
	check(unit.statuses == before,"Dead units cannot gain new statuses")

func _test_poison_and_paralysis() -> void:
	var sim := fresh()
	var unit: Dictionary = sim.hero()
	unit.armor = 100
	unit.resist = {"poison":50}
	unit.energy = 1
	var hp: int = int(unit.hp)
	sim.status(unit,"poison",2)
	sim.tick_unit(unit)
	check(int(unit.hp) == hp - 2 and int(unit.energy) == 1,"Poison ignores heavy armor, respects poison resistance and suppresses SP recovery while active")
	check(int(unit.statuses.poison) == 1 and not unit.statuses.has("paralyzed"),"Poison duration is independent of paralysis")
	sim.tick_unit(unit)
	check(int(unit.hp) == hp - 4 and not unit.statuses.has("poison"),"Poison deals its final tick before expiring")
	check(int(unit.energy) == 2,"Recovery resumes after poison expires")
	unit.resist = {}; unit.statuses = {}; unit.energy = 1
	sim.status(unit,"paralyzed",2)
	var before_hp: int = int(unit.hp)
	sim.tick_unit(unit)
	check(int(unit.hp) == before_hp and int(unit.energy) == 2,"Paralysis itself causes no poison damage or SP suppression")
	var target: Dictionary = enemy(sim)
	check(not sim.attack(unit,target),"Paralysis prevents direct weapon attacks")
	unit.statuses = {}
	sim.status(unit,"poison",2)
	check(sim.attack(unit,target),"Poison does not itself prevent a valid direct weapon attack")

func _test_bow_passive() -> void:
	var sim := fresh()
	var source: Dictionary = sim.hero()
	var target: Dictionary = enemy(sim)
	source.essences = ["canon_goblin_archer"]
	source.equipment.weapon = "bow"; sim.recalculate(source)
	sim.hit(source,target,1,"physical","Attack",true,true)
	check(int(target.statuses.get("poison",0)) == 3 and not target.statuses.has("paralyzed"),"Goblin Archer essence bow attack inflicts poison rather than Goblin melee paralysis")
	target.statuses = {}
	sim.hit(source,target,1,"physical","Opportunity",true,true)
	check(target.statuses.has("poison"),"Recognized weapon opportunity attack can activate its compatible bow passive")
	for condition: String in ["no_essence","wrong_weapon","unarmed","spell_label","disabled_triggers"]:
		target.statuses = {}
		source.essences = [] if condition == "no_essence" else ["canon_goblin_archer"]
		source.equipment.weapon = "club" if condition == "wrong_weapon" else "" if condition == "unarmed" else "bow"
		sim.recalculate(source)
		sim.hit(source,target,1,"physical","Ice Spear" if condition == "spell_label" else "Attack",condition != "disabled_triggers",true)
		check(not target.statuses.has("poison"),"Bow passive requires compatible essence, weapon and triggering hit: " + condition)

func _test_trigger_budget() -> void:
	var sim := fresh()
	var source: Dictionary = sim.hero()
	var target: Dictionary = enemy(sim)
	source.essences = ["canon_goblin"]
	source.equipment.weapon = "club"; sim.recalculate(source)
	sim.trigger_depth = sim.MAX_TRIGGER_DEPTH
	var hp: int = int(target.hp)
	sim.hit(source,target,4,"physical","Attack",true,true)
	check(int(target.hp) < hp and not target.statuses.has("paralyzed"),"Exhausted trigger budget still resolves base hit without recursively activating passives")
	check(sim.trigger_depth == sim.MAX_TRIGGER_DEPTH,"Budget-limited hit does not corrupt caller trigger depth")
	sim.trigger(source,"on_hit",target,1,true)
	check(not target.statuses.has("paralyzed"),"Direct trigger dispatch obeys the same maximum depth")
	sim.trigger_depth = sim.MAX_TRIGGER_DEPTH - 1
	sim.trigger(source,"on_hit",target,1,true)
	check(target.statuses.has("paralyzed"),"A direct trigger can resolve while budget remains")
	target.statuses = {}; sim.trigger_depth = 0
	sim.hit(source,target,1,"physical","Attack",true,true)
	check(target.statuses.has("paralyzed") and sim.trigger_depth == 0,"Ordinary triggered hit restores depth after effect dispatch")
	target.statuses = {}
	for event: String in ["on_hurt","on_kill","turn_start"]: sim.trigger(source,event,target,1,true)
	sim.trigger(source,"on_hit",target,0,true)
	check(target.statuses.is_empty(),"Unmatched event and zero-damage dispatch cannot create a weapon proc")
