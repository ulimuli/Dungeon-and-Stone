extends SceneTree
## Artificial modifier rows below are integration fixtures, not novel content.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh() -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Stat integration fixture","human","adventurer",74119)
	sim.state.gold = 100000
	return sim

func mod(id: String, stat: String, op: String, value: float) -> Dictionary:
	return {"id":id,"source":"test_fixture","stat":stat,"op":op,"value":value}

func battlefield(sim: GameSimulation) -> Dictionary:
	check(sim.enter_region(1),"Actual expedition entry")
	sim.state.units = []; sim.state.combat = true; sim.resolving_round = true
	var unit: Dictionary = sim.hero()
	for y: int in range(-3,4):
		for x: int in range(-3,4):
			var tile: Vector2i = unit.pos+Vector2i(x,y)
			if tile.x > 0 and tile.y > 0 and tile.y < sim.state.map.tiles.size()-1 and tile.x < sim.state.map.tiles[tile.y].size()-1: sim.state.map.tiles[tile.y][tile.x] = DungeonWorld.FLOOR
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",unit.pos+Vector2i.RIGHT)
	target.hp = 1000; target.max_hp = 1000; target.armor = 0; target.resist = {}; target.evasion = 0; target.essences = []; target.statuses = {"stunned":99}
	unit.ap = 10; unit.attacked = false
	sim.update_visibility()
	return target

func seed_hit(sim: GameSimulation) -> void:
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1,10000):
		probe.seed = seed_value
		if probe.randi_range(1,100) <= 20: sim.rng.seed = seed_value; return

func _initialize() -> void:
	_test_shared_sources()
	_test_essence_attributes_and_sealing()
	_test_resistance_and_damage()
	_test_resource_and_action_consumers()
	_test_saved_modifiers()
	_test_content_invalidation_and_fractional_flats()
	_test_fractional_recovery()
	_test_ai_action_budgets()
	_test_signed_derived_stats()
	_test_enemy_damage_and_opportunity()
	_test_modified_numbered_cooldown_save()
	print("STAT INTEGRATION: %d checks, %d failures. Artificial modifiers verify consumers; coefficients remain explicit reconstruction rules." % [checks,failures])
	quit(1 if failures else 0)

func _test_shared_sources() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	unit.hp = 7; unit.energy = 2
	var legacy: Array = [unit.str,unit.agi,unit.wit,unit.vig]
	unit.base_stats = {"attack":10,"strength":10,"muscle_mass":20}
	unit.modifiers = [mod("fixture_increase","attack","increase",0.5)]
	# Existing data is changed only in this Simulation instance for a generic-item fixture.
	sim.item_defs.club.power = 0
	sim.item_defs.club.modifiers = [{"stat":"attack","op":"multiply","value":2},{"stat":"armor","op":"add","value":7}]
	sim.essence_defs.canon_goblin.modifiers = [{"stat":"attack","op":"add","value":5}]
	sim.add_item("club",1)
	check(sim.equip("club").is_empty(),"Actual equip accepts an item carrying generic short modifiers")
	sim.add_item("sealed_canon_goblin",1)
	check(sim.absorb_sealed("canon_goblin").is_empty(),"Actual essence absorption imports generic short modifiers")
	sim.recalculate(unit,false)
	check(sim.stat_value(unit,"attack",false) == 45 and int(unit.power) == 45,"Essence add, unit increase and equipped item multiplier compose in the live Attack alias")
	check(sim.stat_value(unit,"armor",false) >= 7 and int(unit.armor) == int(sim.stat_value(unit,"armor",false)),"Generic item Armor modifies the actual defense alias")
	check(sim.stat_value(unit,"strength",false) == 12,"Muscle Mass grants one percent total Strength per point")
	check([unit.str,unit.agi,unit.wit,unit.vig] == legacy,"Resolved stats preserve legacy base attributes")
	check(int(unit.hp) == 7 and int(unit.energy) == 2,"Repeated stat/equipment recalculation does not refill HP or SP")
	var detail: Dictionary = sim.stat_breakdown(unit)
	check(detail.errors.is_empty() and detail.values.attack == 45,"Live breakdown matches resolved gameplay values")
	var sources: Array = detail.breakdown.attack.sources
	var source_ids: Dictionary = {}
	var source_labels: Dictionary = {}
	for source: Dictionary in sources:
		source_ids[source.id] = true; source_labels[source.source] = true
	check(sources.size() >= 3 and source_ids.size() == sources.size() and source_labels.size() >= 3,"Item, essence and unit provenance remains distinct with unique stable IDs")
	var preview_before: String = var_to_str(sim.state)
	var rng_before: int = sim.rng.state
	var preview: Dictionary = sim.preview_equipment("spear")
	check(preview.errors.is_empty() and preview.before.attack == 45 and preview.after.attack != preview.before.attack,"Equipment preview resolves generic item removal and alternative weapon effects")
	check(preview.delta.attack == preview.after.attack-preview.before.attack,"Equipment preview exposes resolved stat delta")
	check(var_to_str(sim.state) == preview_before and sim.rng.state == rng_before,"Equipment preview never mutates campaign, resources or RNG")
	var pack_before: Dictionary = sim.state.inventory.duplicate(true)
	var hp: int = unit.hp; var energy: int = unit.energy
	unit.modifiers.append(mod("fixture_max_health","max_health","add",20))
	sim.recalculate(unit,false)
	check(unit.hp == hp and unit.energy == energy and sim.state.inventory == pack_before,"Stat maximum changes preserve existing resource amounts and inventory")
	var carrying: int = sim.capacity()
	unit.modifiers.append(mod("fixture_capacity","carry_capacity","add",13))
	sim.recalculate(unit,false)
	check(sim.capacity() == carrying+13,"Carrying limit consumes the shared capacity stat")

func _test_essence_attributes_and_sealing() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	var base_agility: float = sim.stat_value(unit,"agility",false)
	var before_attributes: Dictionary = sim.stat_breakdown(unit).values.duplicate(true)
	sim.add_item("sealed_canon_goblin_archer",1)
	check(sim.absorb_sealed("canon_goblin_archer").is_empty(),"Actual Goblin Archer essence absorption")
	check(sim.stat_value(unit,"agility",false) == base_agility+2,"Verified Goblin Archer Agility+2 resolves")
	for entry: Array in [["flexibility",4],["vision",6],["smell",2],["perception",2],["cognitive_interference",6],["accuracy",8],["poison_resistance",4],["obsession",7]]:
		if entry[0] == "accuracy": continue # Tested separately with its derived Agility contribution.
		check(sim.stat_value(unit,str(entry[0]),false) == float(before_attributes[entry[0]])+float(entry[1]),"Verified Goblin Archer attribute resolves once: " + str(entry[0]))
	check(sim.stat_value(unit,"accuracy",false) == float(before_attributes.accuracy)+11,"Archer Accuracy+8 and Agility+2 combine with the provisional Perception/Obsession accuracy tradeoff")
	var attributes: Dictionary = sim.stat_breakdown(unit).values.duplicate(true)
	sim.add_item("frost_spirit_ring",1)
	check(sim.equip("frost_spirit_ring","hero","canon_goblin_archer").is_empty(),"Actual ring selects an essence to seal")
	check(not sim.active_essences(unit).has("canon_goblin_archer"),"Sealed essence loses skill access")
	for stat_id: String in ["agility","flexibility","vision","smell","perception","cognitive_interference","accuracy","poison_resistance","obsession"]:
		check(sim.stat_value(unit,stat_id,false) == float(attributes[stat_id]),"Sealing retains permanent attribute: " + stat_id)

func _test_resistance_and_damage() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var source: Dictionary = sim.hero()
	source.modifiers = [mod("out_all","damage_dealt_multiplier","multiply",2),mod("out_fire","fire_damage_dealt_multiplier","multiply",2)]
	target.modifiers = [mod("in_all","damage_taken_multiplier","multiply",0.5),mod("in_fire","fire_damage_taken_multiplier","multiply",0.5),mod("raw_fire","fire_resistance","add",100)]
	sim.recalculate(source,false)
	check(sim.stat_value(target,"fire_resistance") == 100,"Raw resistance keeps points rather than percentage units")
	check(sim.resistance(target,"fire") == 50,"Estimated curve maps one hundred raw points to fifty percent")
	check(sim.hit(source,target,20,"fire","Fixture damage",false,true) == 10,"Typed and global outgoing/incoming multipliers feed actual resisted damage")
	check(sim.hit(source,target,20,"physical","Fixture damage",false,true) == 20,"Typed fire modifiers do not alter ordinary physical damage")
	target.resist.fire = 10
	check(sim.resistance(target,"fire") == 60,"Legacy percent reduction stays separate and adds after raw-point conversion")
	target.modifiers = [mod("negative_raw","fire_resistance","add",-100)]; target.resist = {}
	check(sim.resistance(target,"fire") == -50,"Negative raw resistance preserves vulnerability and percentage lower bound")
	source.modifiers = []; source.statuses = {"weakened":2,"transformed":2}; source.status_power = {"transformed":5}; target.modifiers = []
	check(sim.hit(source,target,20,"physical","Fixture damage",false,true) == 18,"All flat damage changes precede weakening multiplier")

func _test_resource_and_action_consumers() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.modifiers = [mod("healing","healing_received_multiplier","multiply",0.5),mod("mana_cost","mana_cost_multiplier","multiply",0.5),mod("soul_cost","soul_cost_multiplier","multiply",0.5),mod("cooldown","cooldown_multiplier","multiply",0.5),mod("movement","movement_cost","add",2),mod("attack_ap","attack_ap_cost","add",1)]
	unit.spells = ["ice_spear"]; unit.essences = ["canon_goblin"]
	sim.recalculate(unit,false)
	unit.hp = int(unit.max_hp)-20
	var hp: int = unit.hp
	sim.heal(unit,10)
	check(unit.hp == hp+5,"Healing consumes shared healing-received multiplier")
	unit.mana = unit.max_mana; unit.energy = unit.max_energy; unit.ap = 10
	var mana: int = unit.mana
	seed_hit(sim)
	check(sim._cast_spell(unit,"ice_spear",target.pos),"Actual spell casts with modified resource cost")
	check(unit.mana == mana-2 and int(unit.cooldowns.ice_spear) == 3,"Spell mana cost and cooldown use ceil-scaled stats")
	unit.ap = 10
	var energy: int = unit.energy
	var expected_soul_cost: int = ceili(float(sim.essence_defs.canon_goblin.ability.cost)*0.5)
	var expected_cooldown: int = ceili(float(sim.essence_defs.canon_goblin.ability.cooldown)*0.5)+1
	check(sim.use_ability(0,unit.pos),"Actual essence skill executes with modified Soul Power cost")
	check(unit.energy == energy-expected_soul_cost and int(unit.cooldowns.canon_goblin) == expected_cooldown,"Essence cost and cooldown use shared multipliers")
	unit.ap = 10; unit.attacked = false
	seed_hit(sim)
	check(sim.attack(unit,target) and unit.ap == 8,"Actual weapon attack consumes modified AP cost")
	unit.ap = 1; unit.attacked = false
	var target_hp: int = target.hp
	check(not sim.attack(unit,target) and target.hp == target_hp and unit.ap == 1,"Unaffordable attack rejects before damage or resource mutation")
	unit.ap = 10
	check(sim.move_unit(Vector2i.LEFT) and unit.ap == 7,"Actual movement consumes shared movement cost")
	unit.ap = 2
	var pos: Vector2i = unit.pos
	check(not sim.move_unit(Vector2i.LEFT) and unit.pos == pos and unit.ap == 2,"Unaffordable movement rejects without moving")
	unit.ap = 10; unit.attacked = false
	target.pos = unit.pos+Vector2i.RIGHT*2; sim.update_visibility()
	check(not sim.attack(unit,target),"Baseline melee cannot reach a target two tiles away")
	unit.modifiers.append(mod("range","attack_range","at_least",3)); sim.recalculate(unit,false); unit.ap = 10
	seed_hit(sim)
	check(sim.attack(unit,target) and int(unit.range) == 3,"Actual attack range consumes shared stat")

func _test_saved_modifiers() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	unit.base_stats = {"strength":12,"fire_resistance":100}
	unit.modifiers = [mod("saved_multiplier","attack","multiply",1.5)]
	sim.recalculate(unit,false); unit.hp = 7; unit.energy = 2
	var resolved: float = sim.stat_value(unit,"attack",false)
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Valid base overrides and modifier rows survive actual JSON restore")
	check(restored.stat_value(restored.hero(),"attack",false) == resolved and restored.hero().hp == 7 and restored.hero().energy == 2,"Restore preserves resolved stats without resource refill")
	for bad: Variant in [{"unknown_stat":1},{"strength":"12"},{"strength":true},{"strength":NAN},{"strength":INF}]:
		var raw: Dictionary = sim.snapshot(); raw.hero.base_stats = bad
		var before: String = var_to_str(restored.state); var rng_state: int = restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed saved base stats rejected")
		check(var_to_str(restored.state) == before and restored.rng.state == rng_state,"Invalid base stats leave campaign and RNG unchanged")
	for bad: Variant in [[mod("unknown","unknown_stat","add",1)],[mod("unknown","attack","invented",1)],[mod("duplicate","attack","add",1),mod("duplicate","armor","add",1)],[mod("nonfinite","attack","add",NAN)],[mod("infinite","attack","add",INF)],[mod("huge_a","attack","multiply",1.0e308),mod("huge_b","attack","multiply",1.0e308)],[mod("item:weapon:club:0","armor","add",1)],{"not":"array"}]:
		var raw: Dictionary = sim.snapshot(); raw.hero.modifiers = bad
		var before: String = var_to_str(restored.state); var rng_state: int = restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed saved modifier rows rejected")
		check(var_to_str(restored.state) == before and restored.rng.state == rng_state,"Invalid modifiers leave campaign and RNG unchanged")

	var level_raw: Dictionary = sim.snapshot()
	level_raw.level = 2
	level_raw.hero.modifiers = [mod("level_overflow","max_soul_power","multiply",1.0e307)]
	var stable_state: String = var_to_str(restored.state)
	var stable_rng: int = restored.rng.state
	check(not Validator.validate(level_raw).is_empty() and not restored.restore(level_raw),"Composed saved stats validate at actual campaign level before restoration")
	check(var_to_str(restored.state)==stable_state and restored.rng.state==stable_rng,"Level-dependent overflow leaves campaign and RNG unchanged")

func _test_content_invalidation_and_fractional_flats() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	check(unit.equipment.weapon == "club","Content invalidation fixture uses the ordinary starting club")
	var baseline: float = sim.stat_value(unit,"attack",false)
	var base_before: Array = [unit.str,unit.agi,unit.wit,unit.vig,unit.equipment.duplicate(true)]
	sim.item_defs.club.modifiers.append({"stat":"attack","op":"multiply","value":2})
	sim.recalculate(unit,false)
	check(sim.stat_value(unit,"attack",false) == baseline*2 and int(unit.power) == int(baseline*2),"Changing equipped item modifier content after cached resolution invalidates resolved Attack")
	sim.item_defs.club.modifiers[-1].value = 3
	sim.recalculate(unit,false)
	check(sim.stat_value(unit,"attack",false) == baseline*3 and int(unit.power) == int(baseline*3),"Changing an existing content modifier value invalidates a second cached result")
	check([unit.str,unit.agi,unit.wit,unit.vig,unit.equipment] == base_before,"Cache invalidation needs no base attribute or equipment ID mutation")
	unit.base_stats = {"attack":10}
	unit.modifiers = [mod("fractional_unit_flat","attack","add",0.6)]
	sim.item_defs.club.modifiers = [{"stat":"attack","op":"add","value":0.6}]
	sim.recalculate(unit,false)
	check(sim.stat_value(unit,"attack",false) == 11 and int(unit.power) == 11,"Ordinary item fractional flat and unit fractional flat accumulate before final stat flooring")
	check(is_equal_approx(float(sim.stat_breakdown(unit).breakdown.attack.flat),1.2),"Breakdown preserves the unrounded sum of fractional flat sources")

func _test_fractional_recovery() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	unit.modifiers = [mod("half_recovery","natural_recovery","multiply",0.5)]
	sim.recalculate(unit,false); unit.hp = 7
	sim.natural_recovery_tick(unit)
	check(unit.hp == 7 and is_equal_approx(float(unit.recovery_remainder),0.5),"First half-point recovery tick retains a fraction without inventing a whole heal")
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Fractional natural recovery survives actual validated JSON restore")
	check(restored.hero().hp == 7 and is_equal_approx(float(restored.hero().recovery_remainder),0.5),"Restore preserves both health and fractional recovery carry")
	restored.natural_recovery_tick(restored.hero())
	sim.natural_recovery_tick(unit)
	check(unit.hp == 8 and is_zero_approx(float(unit.recovery_remainder)),"Two half-point recovery ticks heal exactly one HP")
	check(restored.hero().hp == unit.hp and is_equal_approx(float(restored.hero().recovery_remainder),float(unit.recovery_remainder)),"Reload between fractional ticks preserves the same eventual healing")

func _test_ai_action_budgets() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	target.pos = unit.pos+Vector2i.RIGHT*3
	unit.modifiers = [mod("ai_movement_cost","movement_cost","add",2)]
	sim.recalculate(unit,false); sim.update_visibility()
	var origin: Vector2i = unit.pos
	unit.ap = 2
	sim.ally_ai(unit)
	check(unit.pos == origin,"Ally AI cannot move when two AP cannot afford a three-AP step")
	unit.ap = 4; unit.attacked = false
	var target_hp: int = target.hp
	sim.ally_ai(unit)
	check(sim.distance(origin,unit.pos) == 1 and int(target.hp) == target_hp,"Ally AI with four AP takes one three-AP step and cannot move a second step or attack out of reach")
	# Enemy fixtures exercise the actual turn budget instead of calling attack directly.
	unit.pos = origin; unit.modifiers = []; sim.recalculate(unit,false)
	target.pos = origin+Vector2i.RIGHT; target.alert = true; target.statuses = {}; target.role = "ambusher"
	target.base_stats = {"action_points":1,"attack_ap_cost":2,"movement_cost":3,"attack_range":1}
	sim.recalculate(target,false)
	var hp: int = unit.hp
	sim.enemy_turn(target)
	check(unit.hp == hp and int(target.ap) == 1,"Enemy AI cannot attack an adjacent target with an unaffordable attack AP cost")
	target.base_stats.action_points = 2; sim.recalculate(target,false); seed_hit(sim)
	sim.enemy_turn(target)
	check(unit.hp < hp and int(target.ap) == 0,"Enemy AI spends its exact two-AP budget on one affordable adjacent attack")
	target.pos = origin+Vector2i.RIGHT*2
	target.base_stats.action_points = 4; sim.recalculate(target,false)
	var enemy_origin: Vector2i = target.pos; hp = unit.hp
	sim.enemy_turn(target)
	check(target.pos == enemy_origin and unit.hp == hp,"Enemy AI reserves attack AP and does not take a move whose combined action cost exceeds its budget")
	target.base_stats.action_points = 5; sim.recalculate(target,false); seed_hit(sim)
	sim.enemy_turn(target)
	check(sim.distance(target.pos,enemy_origin) == 1 and unit.hp < hp and int(target.ap) == 0,"Enemy AI can spend exactly three movement AP plus two attack AP")
	target.pos = origin+Vector2i.RIGHT*2
	target.base_stats.action_points = 2; target.base_stats.attack_range = 3; sim.recalculate(target,false)
	enemy_origin = target.pos; hp = unit.hp; seed_hit(sim)
	sim.enemy_turn(target)
	check(target.pos == enemy_origin and unit.hp < hp and int(target.ap) == 0,"Enemy AI consumes shared attack range and attacks without an unaffordable movement step (reach=%s, AP=%s, HP=%s -> %s)" % [sim.stat_value(target,"attack_range"),target.ap,hp,unit.hp])

func _test_signed_derived_stats() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats = {"armor":-5,"evasion":0}
	sim.recalculate(unit,false)
	var evasion_before: float = sim.stat_value(unit,"evasion",false)
	unit.statuses = {"marked":2}
	check(sim.stat_value(unit,"armor") == -5 and sim.stat_value(unit,"evasion") == evasion_before-15 and sim.stat_value(unit,"evasion") < 0,"Negative Armor and Marked Evasion survive canonical stat bounds (armor=%s, evasion=%s)" % [sim.stat_value(unit,"armor"),sim.stat_value(unit,"evasion")])
	check(sim.hit(target,unit,20,"physical","Signed armor fixture",false,true) == 25,"Negative resolved Armor increases actual physical damage by its signed amount")
	target.base_stats = {"armor":-5}; sim.recalculate(target,false)
	check(sim.stat_value(target,"armor") == -5 and sim.hit(unit,target,20,"physical","Enemy signed armor fixture",false,true) == 25,"Canonical negative enemy Armor survives compatibility handling and actual damage resolution")
	var capacity_before: int = sim.capacity()
	unit.modifiers = [mod("negative_carry","carry_bonus","add",-7)]
	sim.recalculate(unit,false)
	check(sim.stat_value(unit,"carry_bonus",false) == -7 and sim.capacity() == capacity_before-7,"Negative carry bonus lowers the actual shared carrying allowance")

func _test_enemy_damage_and_opportunity() -> void:
	var sim := fresh(); var enemy: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats = {"max_health":1000,"armor":0,"evasion":0}; sim.recalculate(unit,false); unit.hp = 1000
	enemy.statuses = {}; enemy.role = "ambusher"; enemy.alert = true
	var baseline: int = int(sim.stat_value(enemy,"attack",false))
	enemy.modifiers = [mod("enemy_attack_bonus","attack","add",10)]
	enemy.base_stats = {"action_points":2,"attack_ap_cost":1,"attack_range":1}
	sim.recalculate(enemy,false)
	var attack: int = int(sim.stat_value(enemy,"attack"))
	check(attack == baseline+10,"Generic enemy Attack bonus survives canonical source composition")
	var hp: int = unit.hp; seed_hit(sim)
	sim.enemy_turn(enemy)
	check(unit.hp == hp-sim.damage_amount(attack,int(sim.stat_value(unit,"armor")),sim.resistance(unit,"physical"),true),"Actual enemy attack consumes its resolved Attack bonus exactly once")
	var origin: Vector2i = unit.pos
	enemy.pos = origin+Vector2i.RIGHT*2; enemy.base_stats.attack_range = 2; enemy.reacted = false
	sim.recalculate(enemy,false); sim.update_visibility(); unit.ap = 10
	@warning_ignore("integer_division")
	var opportunity_power: int = maxi(1,attack/2)
	var expected: int = sim.damage_amount(opportunity_power,int(sim.stat_value(unit,"armor")),sim.resistance(unit,"physical"),true)
	hp = unit.hp; seed_hit(sim)
	check(sim.move_unit(Vector2i.LEFT) and enemy.reacted and unit.hp == hp-expected,"Leaving resolved two-tile melee reach triggers one opportunity using half resolved Attack without reapplying its modifier")
	unit.pos = origin; enemy.pos = origin+Vector2i.RIGHT*2; enemy.reacted = false; enemy.statuses = {"suppressed":2}; unit.ap = 10
	hp = unit.hp; seed_hit(sim)
	check(sim.move_unit(Vector2i.LEFT) and unit.hp == hp and not enemy.reacted,"Suppressed enemies cannot make opportunity attacks")
	unit.pos = origin; enemy.pos = origin+Vector2i.RIGHT*2; enemy.reacted = false; enemy.statuses = {}; enemy.role = "ranged"; unit.ap = 10
	hp = unit.hp; seed_hit(sim)
	check(sim.move_unit(Vector2i.LEFT) and unit.hp == hp and not enemy.reacted,"Ranged enemy reach does not create a melee opportunity threat")

func _test_modified_numbered_cooldown_save() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	check(sim.buy("guardians_braces").is_empty() and sim.equip("guardians_braces").is_empty(),"Modified cooldown fixture buys and equips actual Guardian's Braces")
	unit.modifiers = [mod("double_numbered_cooldown","cooldown_multiplier","multiply",2)]
	sim.recalculate(unit,false)
	check(sim.enter_region(1),"Modified Numbered cooldown fixture enters actual expedition")
	sim.state.units = []; sim.state.combat = false
	check(sim.activate_numbered("guardians_braces").is_empty(),"Actual Numbered Item activation consumes shared cooldown multiplier")
	check(int(sim.numbered_record("guardians_braces").cooldown) == 13,"Doubled six-round cooldown stores twelve rounds plus the activation tick")
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Modified Numbered cooldown above the unmodified base passes validated JSON restore")
	check(int(restored.numbered_record("guardians_braces").cooldown) == 13,"Saved modified Numbered cooldown is preserved rather than truncated or reset")
