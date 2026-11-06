extends SceneTree
## Catalog contracts and corruption boundaries; no simulation or user files.
const Catalog = preload("res://game/stat_catalog.gd")
const ACTIVE: Array[String] = ["strength","agility","wit","vigor","attack","armor","accuracy","evasion","max_health","max_soul_power","max_mana","attack_range","sight","carry_bonus","carry_capacity","initiative","physical_resistance","fire_resistance","cold_resistance","poison_resistance","dark_resistance","mana_resistance","damage_dealt_multiplier","damage_taken_multiplier","healing_received_multiplier","soul_cost_multiplier","mana_cost_multiplier","cooldown_multiplier","natural_recovery","action_points","movement_cost","attack_ap_cost","soul_recovery","mana_recovery","muscle_mass","flexibility","vision","smell","natural_regeneration","soul_power","soul_regeneration","weight","hearing","sixth_sense","luck","control","adaptability","cold_sensitivity","cutting_force","critical_chance","critical_damage_multiplier","ground_resistance","solar_resistance","lightning_resistance","armor_penetration","resistance_penetration","weapon_damage_multiplier","spell_damage_multiplier"]
const NEW_ACTIVE: Array[String] = ["body_index","mind_index","ability_index","perception","cognitive_interference","obsession","possessiveness","endurance","bone_strength","bone_density","height","jumping_power","natural_energy","dexterity","impulse","distrust","mana_sensitivity"]
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func reject(entries: Dictionary, expected: String, label: String) -> void:
	var before: String = var_to_str(entries)
	var errors: Array[String] = Catalog.validate_entries(entries)
	check(not errors.is_empty() and errors.any(func(error: String) -> bool: return error.contains(expected)),label+" yields actionable diagnostic: "+str(errors))
	check(var_to_str(entries) == before,label+" validation does not mutate definitions")

func _initialize() -> void:
	var definitions: Dictionary = Catalog.definitions()
	check(Catalog.validate().is_empty(),"Bundled stat catalog validates")
	var aliases: Dictionary = {}
	for id: String in ACTIVE:
		check(definitions.has(id) and definitions[id].implemented,"Consumed stat is registered as functional: "+id)
	for id: String in NEW_ACTIVE:
		check(definitions.has(id) and definitions[id].implemented,"Newly consumed stat is functional: "+id)
		check(not definitions[id].formula_note.contains("Research only"),"Live stat no longer claims absent gameplay: "+id)
	for id: String in definitions:
		var row: Dictionary = definitions[id]
		check(row.experimental_balance and not row.formula_note.is_empty() and not row.reference_urls.is_empty(),"Default/bounds/formula estimates retain context: "+id)
		for alias: String in row.aliases:
			check(not aliases.has(alias) and not definitions.has(alias),"Legacy alias has one unambiguous owner: "+alias)
			aliases[alias] = id
	check(aliases.get("str") == "strength" and aliases.get("agi") == "agility" and aliases.get("vig") == "vigor","Legacy attribute adapter has unique canonical targets")
	check(aliases.get("power") == "attack" and aliases.get("max_hp") == "max_health" and aliases.get("max_energy") == "max_soul_power","Legacy combat/resource fields map to normal stat names")
	check(definitions.attack.name == "Attack" and definitions.wit.aliases.is_empty(),"Normal Attack name and already-canonical Wit need no invented labels")
	for kind: String in ["physical","fire","cold","poison","dark","mana"]:
		var row: Dictionary = definitions[kind+"_resistance"]
		check(float(row.min) == -1000 and float(row.max) == 1000000 and float(row.default) == 0 and row.unit == "points" and row.formula_note.contains("not percentages"),"Raw resistance points never masquerade as damage percentages: "+kind)
		for direction: String in ["dealt","taken"]:
			var factor: Dictionary = definitions[kind+"_damage_"+direction+"_multiplier"]
			check(factor.implemented and float(factor.default) == 1 and float(factor.min) == 0 and float(factor.max) == 100,"Per-category factor uses neutral multiplier and explicit domain: "+kind+"/"+direction)
		var percent: Dictionary = definitions[kind+"_damage_reduction"]
		check(percent.implemented and float(percent.min) == -50 and float(percent.max) == 80 and percent.unit == "percent", "Legacy percent reduction has separate bounded stat: "+kind)
	for id: String in ["damage_dealt_multiplier","damage_taken_multiplier","healing_received_multiplier","soul_cost_multiplier","mana_cost_multiplier","cooldown_multiplier","natural_recovery"]:
		var row: Dictionary = definitions[id]
		check(float(row.default) == 1 and float(row.min) == 0 and float(row.max) == 100 and row.rounding == "none","Neutral multiplicative identity and finite domain: "+id)
	check(definitions.muscle_mass.implemented and float(definitions.muscle_mass.strength_increase_per_point) == 0.01 and definitions.muscle_mass.reference_urls.has(Catalog.MUSCLE_SOURCE),"Verified Muscle Mass relationship has exact source and an explicit live provider")
	check(float(definitions.possessiveness.novel_coefficient) == 0 and definitions.possessiveness.coefficient_implemented and definitions.possessiveness.qualitative_estimate,"Zero verified aggregate coefficient is independent of provisional attachment distress")
	check(float(definitions.action_points.default) == 2,"Normal combat action budget defaults to2")
	check(float(definitions.dexterity.novel_coefficient) == 0.5 and definitions.dexterity.coefficient_implemented,"Verified Dexterity coefficient is implemented only as an informational aggregate weight")
	check(float(definitions.mana_resistance.novel_coefficient) == 3 and definitions.mana_resistance.coefficient_implemented,"Aggregate Magic Resistance coefficient remains separate from tactical percentages")
	check(float(definitions.distrust.novel_coefficient) == -0.6 and float(definitions.distrust.novel_coefficient_magnitude) == 0.6 and int(definitions.distrust.novel_coefficient_sign) == -1 and definitions.distrust.coefficient_implemented,"Negative Distrust coefficient preserves source sign/magnitude distinction")
	check(definitions.size() == 102,"Selected catalog preserves its102 declared stats without generating placeholder rows")
	for id: String in definitions:
		check(definitions[id].implemented and not definitions[id].formula_note.contains("Research only"),"Every registered stat has a live consumer or informational resolver: "+id)
		check(definitions[id].aggregate_group in ["none","physical","mental","ability"] and definitions[id].has("aggregate_weight") and definitions[id].has("aggregate_note") and definitions[id].has("combat_index_weight"),"Every row has explicit aggregate inclusion/exclusion metadata: "+id)
	for id: String in ["perception","cognition","cognitive_interference","obsession","impulse","distrust","possessiveness","dexterity","fighting_spirit","endurance","bone_strength","bone_density","height","appetite","absorption","mana_sensitivity","pain_resistance","natural_energy"]:
		check(definitions[id].qualitative_estimate and definitions[id].formula_note.contains("PROVISIONAL"),"Provisional qualitative interpretation is disclosed: "+id)
	check(definitions.height.default == 180 and definitions.height.min == 30 and definitions.height.max == 1000,"Absolute Height uses an explicit ordinary baseline and finite bounds")
	check(definitions.natural_energy.formula_note.contains("contract") and definitions.absorption.formula_note.contains("healing"),"Spirit permission and provisional healing uptake retain their limits")
	for id: String in ["body_index","mind_index","ability_index","combat_index"]:
		check(definitions[id].name.begins_with("Estimated ") and definitions[id].source_status == "informational_estimate" and definitions[id].aggregate_group == "none","Estimated summary cannot recursively buff or feed itself: "+id)
	var known: Dictionary = {"dexterity":0.5,"mana_resistance":3.0,"distrust":-0.6,"possessiveness":0.0}
	for id: String in known:
		check(definitions[id].aggregate_weight_verified and definitions[id].aggregate_weight == known[id],"Verified aggregate coefficient is preserved in executable metadata: "+id)
	check(not definitions.strength.aggregate_weight_verified and definitions.strength.aggregate_note.contains("PROVISIONAL"),"Unverified aggregate coefficients remain estimates")
	# Corruption checks exercise semantic boundaries, not a mirror of each row.
	for invalid: Variant in [null,true,"1",[],{},NAN,INF,-INF]:
		var entries: Dictionary = definitions.duplicate(true)
		entries.attack.default = invalid
		reject(entries,"Stat attack: default","Malformed numeric default "+str(invalid))
	var reversed: Dictionary = definitions.duplicate(true)
	reversed.attack.min = 10; reversed.attack.max = 1
	reject(reversed,"Stat attack: min exceeds max","Reversed numeric domain")
	var outside: Dictionary = definitions.duplicate(true)
	outside.attack.default = -1
	reject(outside,"Stat attack: default is outside bounds","Default outside legal domain")
	var rounding: Dictionary = definitions.duplicate(true)
	rounding.attack.rounding = "random"
	reject(rounding,"Stat attack: rounding","Unsupported numeric rounding")
	var duplicate: Dictionary = definitions.duplicate(true)
	duplicate.armor.aliases.append("power")
	reject(duplicate,"duplicate alias power","Cross-stat legacy alias collision")
	var canonical: Dictionary = definitions.duplicate(true)
	canonical.armor.aliases.append("attack")
	reject(canonical,"collides with a canonical stat ID","Alias cannot shadow canonical stat")
	var bad_name: Dictionary = definitions.duplicate(true)
	bad_name.attack.name = " "
	reject(bad_name,"Stat attack: name","Missing display name")
	var duplicate_name: Dictionary = definitions.duplicate(true)
	duplicate_name.armor.name = "Attack"
	reject(duplicate_name,"duplicate display name","Ambiguous display names")
	var no_source: Dictionary = definitions.duplicate(true)
	no_source.dexterity.reference_urls = []
	reject(no_source,"Stat dexterity: reference_urls","Unsourced novel-stat research")
	var bad_id: Dictionary = definitions.duplicate(true)
	bad_id["Made Up ID"] = bad_id.attack.duplicate(true)
	reject(bad_id,"ID must be lowercase snake_case","Malformed canonical identifier")
	var bad_group: Dictionary = definitions.duplicate(true)
	bad_group.dexterity.aggregate_group = "damage"
	reject(bad_group,"aggregate_group","Unknown aggregate category")
	var bad_weight: Dictionary = definitions.duplicate(true)
	bad_weight.dexterity.aggregate_weight = NAN
	reject(bad_weight,"aggregate_weight","Nonfinite aggregate weight")
	var bad_combat_weight: Dictionary = definitions.duplicate(true)
	bad_combat_weight.attack.combat_index_weight = INF
	reject(bad_combat_weight,"combat_index_weight","Nonfinite direct combat aggregate weight")
	var hidden_estimate: Dictionary = definitions.duplicate(true)
	hidden_estimate.obsession.formula_note = "Focus effect."
	reject(hidden_estimate,"provisional mechanic","Undisclosed provisional qualitative mechanic")
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(definitions))
	check(Catalog.validate_entries(json_copy).is_empty(),"Numeric metadata survives JSON integer/float conversion")
	check(Catalog.validate_entries({}).size() > 0,"Empty catalog cannot silently disable all stats")
	print("STAT CATALOG: %d checks, %d failures. All102 declared stats have live consumers or informational indices; verified relationships and provisional qualitative/numerical interpretations are disclosed separately." % [checks,failures])
	quit(1 if failures else 0)
