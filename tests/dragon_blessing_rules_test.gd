extends SceneTree
const Rules = preload("res://game/dragon_blessing_rules.gd")
const Stats = preload("res://game/stat_rules.gd")
const Physiology = preload("res://game/stat_physiology.gd")
var checks: int = 0
var failures: int = 0

class FixtureSim extends RefCounted:
	var state: Dictionary = {"mode":"city","level":2,"gold":1000,"journal":[],"log":[]}
	var units: Dictionary = {
		"hero":{"id":"hero","name":"Dragon visitor","ancestry":"draconian","team":"ally","dead":false,"summon":false,"hp":12,"max_hp":40,"energy":3,"max_energy":24,"mana":2,"max_mana":10},
		"companion":{"id":"companion","name":"Dragon companion","ancestry":"draconian","team":"ally","dead":false,"summon":false,"hp":7,"max_hp":30,"energy":1,"max_energy":20,"mana":0,"max_mana":0}
	}
	var recalculations: Array = []
	var reject_stats: bool = false
	var rng := RandomNumberGenerator.new()
	func _init() -> void: rng.seed = 61421
	func unit_by_id(id: String) -> Dictionary: return units.get(id,{})
	func stat_breakdown(_candidate: Dictionary) -> Dictionary: return {"errors":["bad authored modifier"] if reject_stats else []}
	func recalculate(unit: Dictionary, refill: bool = false) -> void:
		recalculations.append({"id":unit.id,"refill":refill})
		if refill: unit.hp = unit.max_hp; unit.energy = unit.max_energy; unit.mana = unit.max_mana
	func journal(title: String, text: String) -> void: state.journal.append({"title":title,"text":text})
	func say(text: String) -> void: state.log.append(text)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func reject(sim: FixtureSim, label: String, blessing: String = "earth", unit_id: String = "hero") -> void:
	var before: String = var_to_str([sim.state,sim.units,sim.recalculations,sim.rng.state])
	check(not Rules.can_inscribe(sim,unit_id,blessing).is_empty(),label+": eligibility rejected")
	check(not Rules.inscribe(sim,unit_id,blessing).is_empty(),label+": commit rejected")
	check(var_to_str([sim.state,sim.units,sim.recalculations,sim.rng.state]) == before,label+": rejection preserves payment, unit, logs, recalculation and RNG")

func _initialize() -> void:
	var defs: Dictionary = Rules.definitions()
	check(defs.keys() == ["earth","volcano","sea"],"Exactly three stable blessing IDs")
	check(Rules.INSCRIPTION_COST == 500 and Rules.MIN_LEVEL == 2,"Access uses explicit current reconstruction constants")
	for id: String in defs:
		var row: Dictionary = defs[id]
		check(row.id == id and not str(row.name).is_empty() and not str(row.description).is_empty(),"Blessing has stable named description: "+id)
		check(row.source == Rules.SOURCE and row.reference_urls == [Rules.SOURCE] and not str(row.source_lines).is_empty(),"Effect provenance cites chapter202 precisely: "+id)
		check(str(row.access_note).contains("provisional") and str(row.access_note).contains("foreigner"),"Provisional fee/level and unavailable foreigner exception are disclosed: "+id)
	check(defs.earth.effect_value == 1.2 and defs.sea.effect_value == 100 and defs.volcano.effect_value == 1.3,"Sourced effect amounts are kept intact")
	check(defs.earth.numerical_confidence == "exact_source_value" and defs.sea.numerical_confidence == "exact_source_value" and defs.volcano.numerical_confidence == "approximate_source_value","Source approximates Volcano30%, not Earth20% or Sea100")
	defs.earth.reference_urls.clear()
	check(Rules.definitions().earth.reference_urls == [Rules.SOURCE],"Returned definitions cannot corrupt future source metadata")
	for blessing: String in Rules.IDS:
		var sim := FixtureSim.new()
		var unit: Dictionary = sim.units.hero
		var before: String = var_to_str([sim.state,sim.units,sim.recalculations])
		check(Rules.can_inscribe(sim,"hero",blessing).is_empty() and var_to_str([sim.state,sim.units,sim.recalculations]) == before,"Eligibility is pure for "+blessing)
		var resources: Array = [unit.hp,unit.energy,unit.mana]
		var combat_rng: int = sim.rng.state
		seed(31827); var expected: int = randi(); seed(31827)
		check(Rules.inscribe(sim,"hero",blessing).is_empty(),"Eligible native may inscribe "+blessing)
		check(sim.state.gold == 500 and unit.dragon_blessing == blessing,"Successful rite charges exactly once and persists one top-level String ID")
		check([unit.hp,unit.energy,unit.mana] == resources and sim.recalculations == [{"id":"hero","refill":false}],"Rite recalculates without refilling HP, Soul Power or mana")
		check(sim.state.journal.size() == 1 and sim.state.log.size() == 1 and str(sim.state.journal[0].text).contains("provisional"),"Successful rite journals the access estimate and emits one message")
		check(sim.rng.state == combat_rng and randi() == expected,"Rite consumes neither simulation nor global RNG")
		check(Rules.validate_unit(unit).is_empty(),"Inscribed native passes unit validation")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(unit))
		check(restored.dragon_blessing == blessing and Rules.validate_unit(restored).is_empty(),"Top-level blessing survives JSON persistence")
		check(Rules.essence_scale(restored) == (1.2 if blessing=="earth" else 1) and Rules.skill_scale(restored) == (1.3 if blessing=="volcano" else 1),"Restored blessing preserves only its own source effect")
		for other: String in Rules.IDS: reject(sim,"Existing blessing cannot be overwritten or bought again: "+other,other)
	var companion := FixtureSim.new()
	check(Rules.inscribe(companion,"companion","sea").is_empty() and not companion.units.hero.has("dragon_blessing") and companion.units.companion.dragon_blessing == "sea","Selected living native companion receives its own single slot")
	var exact_fee := FixtureSim.new(); exact_fee.state.gold = 500
	check(Rules.inscribe(exact_fee,"hero","earth").is_empty() and exact_fee.state.gold == 0,"Exact fee is sufficient without negative currency")
	var invalid_stats := FixtureSim.new(); invalid_stats.reject_stats = true
	var original: String = var_to_str([invalid_stats.state,invalid_stats.units,invalid_stats.recalculations])
	check(not Rules.inscribe(invalid_stats,"hero","volcano").is_empty() and var_to_str([invalid_stats.state,invalid_stats.units,invalid_stats.recalculations]) == original,"Composed-stat preflight rejects before charging or applying the blessing")
	for mode: String in ["dungeon","defeat","victory",""]:
		var sim := FixtureSim.new(); sim.state.mode = mode
		reject(sim,"Noncity mode "+mode)
	for level: Variant in [0,1,-1,NAN,INF,"2",null,true]:
		var sim := FixtureSim.new(); sim.state.level = level
		reject(sim,"Unavailable/malformed level "+str(level))
	for gold: Variant in [0,499,-1,NAN,INF,"500",null,true]:
		var sim := FixtureSim.new(); sim.state.gold = gold
		reject(sim,"Insufficient/malformed fee "+str(gold))
	for race: String in ["human","barbarian","fairy","dwarf","beastman","dragonkin","unknown",""]:
		var sim := FixtureSim.new(); sim.units.hero.ancestry = race
		reject(sim,"No native or foreigner exception for "+race)
	for health: Variant in [0,-1,NAN,INF,"12",null,true]:
		var sim := FixtureSim.new(); sim.units.hero.hp = health
		reject(sim,"Nonliving/malformed HP "+str(health))
	for field: String in ["dead","summon"]:
		for value: Variant in [true,"false",0,null,[]]:
			var sim := FixtureSim.new(); sim.units.hero[field] = value
			reject(sim,"Death/summon boundary "+field+str(value))
	var enemy := FixtureSim.new(); enemy.units.hero.team = "enemy"
	reject(enemy,"Enemy cannot receive a party rite")
	reject(FixtureSim.new(),"Unknown blessing","storm")
	reject(FixtureSim.new(),"Absent character","earth","missing")
	for value: Variant in [null,"",[],{},true,0,"unknown",["earth","sea"]]:
		var sim := FixtureSim.new(); sim.units.hero["dragon_blessing"] = value
		reject(sim,"Existing malformed record blocks paid retry "+str(value))
		check(not Rules.validate_unit(sim.units.hero).is_empty(),"Malformed blessing save is invalid "+str(value))
		check(Rules.derived_modifiers(sim.units.hero).is_empty() and Rules.essence_scale(sim.units.hero) == 1 and Rules.skill_scale(sim.units.hero) == 1,"Malformed record grants no effect "+str(value))
	var plain: Dictionary = FixtureSim.new().units.hero
	check(Rules.validate_unit(plain).is_empty() and Rules.derived_modifiers(plain).is_empty() and Rules.essence_scale(plain) == 1 and Rules.skill_scale(plain) == 1,"Missing blessing is valid and neutral")
	var fallen: Dictionary = plain.duplicate(true)
	fallen["dragon_blessing"] = "sea"; fallen.dead = true; fallen.hp = 0
	check(Rules.validate_unit(fallen).is_empty(),"Dead native retains a valid blessing as persistent history")
	for race: String in ["human","barbarian","fairy","dwarf","beastman"]:
		var other: Dictionary = fallen.duplicate(true); other.ancestry = race
		check(not Rules.validate_unit(other).is_empty() and Rules.derived_modifiers(other).is_empty(),"Foreign persisted blessing is invalid and inactive: "+race)
	for summon: Variant in [true,0,"false",null]:
		var other: Dictionary = fallen.duplicate(true); other.summon = summon
		check(not Rules.validate_unit(other).is_empty(),"Summon/malformed summon blessing save is invalid")
	var registry: Dictionary = {"soul_power":{"default":0,"min":-1000000,"max":1000000,"rounding":"none"},"skill_power_multiplier":{"default":1,"min":0,"max":100,"rounding":"none"}}
	for blessing: String in Rules.IDS:
		var unit: Dictionary = plain.duplicate(true); unit["dragon_blessing"] = blessing
		var snapshot: String = var_to_str(unit)
		var rows: Array = Rules.derived_modifiers(unit)
		check(Stats.validate_modifiers(rows,registry).is_empty(),"Blessing emits valid canonical modifiers: "+blessing)
		var resolved: Dictionary = Stats.evaluate({},rows,registry)
		check(resolved.values.soul_power == (100 if blessing=="sea" else 0) and resolved.values.skill_power_multiplier == (1.3 if blessing=="volcano" else 1),"Sea and Volcano target only their distinct shared-stat consumers")
		if blessing=="sea":
			var capacity: Dictionary = Stats.evaluate({},Physiology.derived_modifiers(resolved.values),{"max_soul_power":{"default":24,"min":0,"max":1000000,"rounding":"none"}})
			check(capacity.values.max_soul_power == 124,"Sea Soul Power passes through the existing capacity provider exactly once")
		if blessing=="earth": check(rows.is_empty() and Rules.essence_scale(unit) == 1.2,"Earth delegates only essence attributes and emits no generic gear/all-stat modifier")
		for row: Dictionary in rows: check(str(row.id).begins_with("derived:dragon_blessing:") and str(row.source).begins_with("dragon_blessing:"),"Blessing provenance is stable and specific")
		check(var_to_str(unit) == snapshot,"Effect queries never mutate unit history")
	print("DRAGON BLESSING RULES: %d checks, %d failures. Three sourced effects; provisional native rite access; atomic fee and no resource refill or RNG." % [checks,failures])
	quit(1 if failures else 0)
