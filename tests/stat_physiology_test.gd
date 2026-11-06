extends SceneTree
const Physiology = preload("res://game/stat_physiology.gd")
const Rules = preload("res://game/stat_rules.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func registry() -> Dictionary:
	return {"natural_recovery":{"default":1,"min":0,"max":1000,"rounding":"none"},"max_soul_power":{"default":12,"min":0,"max":1000000,"rounding":"none"},"soul_recovery":{"default":1,"min":0,"max":1000,"rounding":"none"},"max_health":{"default":24,"min":1,"max":1000000,"rounding":"floor"},"armor":{"default":0,"min":-1000000,"max":1000000,"rounding":"floor"},"attack_range":{"default":1,"min":1,"max":128,"rounding":"floor"},"healing_received_multiplier":{"default":1,"min":0,"max":100,"rounding":"none"},"height":{"default":180,"min":-1000000,"max":1000000,"rounding":"none"},"weight":{"default":0,"min":-1000000,"max":1000000,"rounding":"none"}}

func _initialize() -> void:
	var absent: Dictionary = {"unknown_stat":999,"leg_power":100,"appetite":100,"natural_energy":100}
	var snapshot: String = var_to_str(absent)
	check(Physiology.derived_modifiers({}).is_empty() and Physiology.derived_modifiers({"natural_regeneration":0,"soul_power":0,"soul_regeneration":0}).is_empty(),"Missing/zero raw stats preserve baseline and provenance")
	check(Physiology.derived_modifiers(absent).is_empty() and var_to_str(absent) == snapshot,"Context stats invent no unrelated generic modifiers and never mutate input")
	check(Physiology.morphology_modifiers({}).is_empty() and Physiology.morphology_modifiers({"bone_density":0}).is_empty(),"Missing and zero density preserve morphology exactly")
	var raw: Dictionary = {"natural_regeneration":50,"soul_power":20,"soul_regeneration":25}
	var before: String = var_to_str(raw)
	var rows: Array = Physiology.derived_modifiers(raw)
	check(rows.size() == 3 and Rules.validate_modifiers(rows,registry()).is_empty(),"Supported physiology emits valid generic modifier rows")
	var result: Dictionary = Rules.evaluate({},rows,registry())
	check(result.errors.is_empty() and result.values.natural_recovery == 1.5 and result.values.max_soul_power == 32 and result.values.soul_recovery == 1.25,"Raw points feed fractional recovery and additive resource capacity")
	var ids: Dictionary = {}
	for row: Dictionary in rows:
		check(str(row.id).begins_with("derived:physiology:") and str(row.source).begins_with("derived:physiology:"),"Stable source IDs distinguish derived physiology")
		ids[row.id] = true
	check(ids.size() == rows.size() and var_to_str(raw) == before,"Modifier IDs are unique and derivation is pure")
	var reduced: Dictionary = Rules.evaluate({},Physiology.derived_modifiers({"natural_regeneration":-50,"soul_power":-20,"soul_regeneration":-100}),registry())
	check(reduced.values.natural_recovery == 0.5 and reduced.values.max_soul_power == 0 and reduced.values.soul_recovery == 0,"Signed penalties reduce output without negative resource recovery")
	var physical: Dictionary = {"endurance":10,"bone_strength":20,"bone_density":40,"height":300,"absorption":100}
	var physical_snapshot: String = var_to_str(physical)
	var morphology: Array = Physiology.morphology_modifiers(physical)
	check(morphology.size() == 2 and Rules.validate_modifiers(morphology,registry()).is_empty(),"Morphology pass emits valid Weight and Height modifiers only")
	var shape: Dictionary = Rules.evaluate({"height":300},morphology,registry())
	check(shape.values.weight == 8 and shape.values.height == 292,"Density morphology changes body Weight and Height before downstream consumers")
	var resolved_physical: Dictionary = physical.duplicate(true)
	resolved_physical.weight = shape.values.weight
	resolved_physical.height = shape.values.height
	var physical_rows: Array = Physiology.derived_modifiers(resolved_physical)
	var physical_result: Dictionary = Rules.evaluate({},physical_rows,registry())
	check(physical_result.errors.is_empty() and physical_result.values.max_health == 34 and physical_result.values.armor == 2 and physical_result.values.healing_received_multiplier == 1.5,"Endurance, independent bone domains and Absorption feed canonical secondary stats")
	check(physical_result.values.attack_range == 1,"Morphology pass lowers Height below reach threshold before range is derived")
	check(Rules.evaluate({},Physiology.derived_modifiers({"height":300}),registry()).values.attack_range == 2,"Height reach threshold is applied to resolved absolute Height")
	check(Rules.evaluate({},Physiology.derived_modifiers({"height":299.99}),registry()).values.attack_range == 1 and Rules.evaluate({},Physiology.derived_modifiers({"height":420}),registry()).values.attack_range == 3,"Provisional Height reach uses floor at exact thresholds")
	check(Rules.evaluate({},Physiology.derived_modifiers({"bone_strength":20}),registry()).values.armor == 1 and Physiology.morphology_modifiers({"bone_strength":100}).is_empty(),"Bone Strength contributes armor without being conflated with Bone Density morphology")
	check(Rules.evaluate({},Physiology.derived_modifiers({"endurance":-100,"bone_strength":-20,"bone_density":-40}),registry()).values.max_health == 1 and Rules.evaluate({},Physiology.derived_modifiers({"bone_strength":-20,"bone_density":-40}),registry()).values.armor == -2,"Physical penalties retain sign and canonical health minimum")
	ids.clear()
	for row: Dictionary in morphology+physical_rows:
		check(not ids.has(row.id) and str(row.id).begins_with("derived:physiology:"),"Morphology and secondary pass provenance IDs are globally unique")
		ids[row.id] = true
	check(var_to_str(physical) == physical_snapshot,"Both physiology passes preserve raw input")
	for malformed: Variant in [null,"100",true,[],{},NAN,INF,-INF]:
		check(Physiology.derived_modifiers({"natural_regeneration":malformed,"soul_power":malformed,"soul_regeneration":malformed}).is_empty(),"Malformed raw values do not invent bonuses")
		check(Physiology.hearing_radius(malformed) == 0 and Physiology.blunt_damage_multiplier(malformed) == 1.0 and Physiology.knockback_reduction(malformed) == 0.0,"Malformed context points retain neutral baseline")
		check(Physiology.derived_modifiers({"endurance":malformed,"bone_strength":malformed,"bone_density":malformed,"height":malformed,"absorption":malformed}).is_empty() and Physiology.morphology_modifiers({"bone_density":malformed}).is_empty(),"Malformed physical points do not create derived or morphology bonuses")
		check(Physiology.jump_range(malformed,malformed) == 2 and Physiology.hunger_rate(malformed) == 1 and Physiology.healing_received_multiplier(malformed) == 1 and Physiology.breath_damage_multiplier(malformed) == 1 and Physiology.natural_energy_capacity(malformed) == 0,"Malformed provisional context values preserve baseline")
	check(Physiology.hearing_radius(0) == 0 and Physiology.hearing_radius(19) == 0 and Physiology.hearing_radius(20) == 1 and Physiology.hearing_radius(60) == 3,"Audible extra radius uses explicit estimated tile boundaries")
	check(Physiology.hearing_radius(-100) == 0 and Physiology.hearing_radius(1000000) == 8,"Hearing extra radius is bounded without negative vision")
	check(Physiology.blunt_damage_multiplier(0) == 1.0 and Physiology.knockback_reduction(0) == 0.0,"Zero Weight leaves damage and knockback unchanged")
	check(Physiology.blunt_damage_multiplier(100) == 1.5 and is_equal_approx(Physiology.knockback_reduction(100),1.0/3.0),"Heavier Weight strengthens blunt damage and resists some displacement")
	check(Physiology.blunt_damage_multiplier(-100) == 0.5 and Physiology.knockback_reduction(-100) == 0,"Negative Weight penalty grants no knockback resistance")
	check(Physiology.blunt_damage_multiplier(1000000) == 4 and Physiology.knockback_reduction(1000000) == 0.75,"Estimated Weight benefit stays bounded and never grants immunity")
	check(Physiology.jump_distance(0,2) == 2 and Physiology.jump_distance(100,2) == 4,"Jump helper scales a separately available action without changing zero baseline")
	check(Physiology.jump_distance(-100,2) == 0 and Physiology.jump_distance(10,-2) == 0,"Jump penalties and malformed baseline cannot produce negative distances")
	check(Physiology.jump_range(0) == 2 and Physiology.jump_range(49) == 2 and Physiology.jump_range(50) == 3 and Physiology.jump_range(0,50) == 3,"Generic Jump combines Jumping Power and Leg Power at explicit tile thresholds")
	check(Physiology.jump_range(-1000000,-1000000) == 1 and Physiology.jump_range(1000000,1000000) == 6,"Generic Jump stays within one to six tiles without granting Leap")
	check(Physiology.hunger_rate(0) == 1 and Physiology.hunger_rate(50) == 2 and Physiology.hunger_rate(-1000000) == 0.25 and Physiology.hunger_rate(1000000) == 20,"Appetite scales fractional food consumption with explicit lower and upper caps")
	check(Physiology.healing_received_multiplier(0) == 1 and Physiology.healing_received_multiplier(-1000000) == 0.25 and Physiology.healing_received_multiplier(1000000) == 4,"Absorption healing factor is bounded and preserves zero baseline")
	check(Physiology.breath_damage_multiplier(0) == 1 and Physiology.breath_damage_multiplier(100) == 0.5 and Physiology.breath_damage_multiplier(-100) == 2 and Physiology.breath_damage_multiplier(-1000000) == 4,"Explicit breathing hazards scale continuously and negative capacity increases damage")
	check(Physiology.breath_damage_multiplier(1000000) > 0 and Physiology.natural_energy_capacity(-100) == 0 and Physiology.natural_energy_capacity(50) == 50,"Large Lung Capacity never grants immunity and resource capacity remains nonnegative")
	check(Physiology.breath_duration(0,60) == 60 and Physiology.breath_duration(50,60) == 90,"Lung Capacity scales breath duration with an explicit estimate")
	check(Physiology.breath_duration(-100,60) == 0 and Physiology.breath_duration(100,NAN) == 0,"Breathing helper cannot produce negative or nonfinite durations")
	check(Physiology.soul_recovery_rate(12) == 1 and Physiology.soul_recovery_rate(24) == 2 and Physiology.soul_recovery_rate(24,12,1,50) == 3,"Optional recovery model is proportional to pool and scales Soul Regeneration once")
	check(Physiology.soul_recovery_rate(12,0) == 0 and Physiology.soul_recovery_rate(INF) == 0 and Physiology.soul_recovery_rate(-12) == 0,"Optional model guards invalid denominators and resource pools")
	check(Physiology.natural_energy_available(100) == 0 and Physiology.natural_energy_available(100,false) == 0,"Natural Energy never grants a first spirit contract or starter Fairy")
	check(Physiology.natural_energy_available(100,true) == 100 and Physiology.natural_energy_available(-1,true) == 0,"Existing contract may use a nonnegative estimated resource amount")
	seed(7703)
	var expected_rng: int = randi()
	seed(7703)
	Physiology.derived_modifiers(raw)
	Physiology.hearing_radius(100)
	Physiology.jump_distance(50)
	Physiology.knockback_reduction(50)
	Physiology.morphology_modifiers(physical)
	Physiology.jump_range(50,50)
	Physiology.hunger_rate(50)
	Physiology.healing_received_multiplier(50)
	Physiology.breath_damage_multiplier(50)
	Physiology.natural_energy_capacity(50)
	check(randi() == expected_rng,"All physiology queries leave production randomness untouched")
	var metadata: Dictionary = Physiology.support_metadata()
	check(metadata.size() == 15,"Research metadata covers fourteen original stats and Absorption")
	for stat: String in ["endurance","bone_strength","bone_density","height","leg_power","appetite","absorption","lung_capacity","jumping_power","natural_energy"]:
		check(metadata[stat].helper_available and metadata[stat].qualitative_estimate and metadata[stat].numerical_estimate and not str(metadata[stat].unknown_reason).is_empty() and not str(metadata[stat].estimated_formula).is_empty(),"User-authorized provisional qualitative effects retain uncertainty and estimated formulas: "+stat)
	for stat: String in ["jumping_power","lung_capacity","natural_energy"]:
		check(str(metadata[stat].integration_status).contains("context_helper_only"),"Context helper is not advertised as a live action/hazard: "+stat)
	for stat: String in metadata:
		check(not metadata[stat].reference_urls.is_empty(),"Named physiology stat retains source provenance: "+stat)
	metadata.weight.reference_urls.clear()
	check(not Physiology.support_metadata().weight.reference_urls.is_empty(),"Returned metadata cannot mutate future provenance")
	for value: int in range(0,301,10):
		check(Physiology.blunt_damage_multiplier(value+10) >= Physiology.blunt_damage_multiplier(value) and Physiology.knockback_reduction(value+10) >= Physiology.knockback_reduction(value),"Weight response is monotone within its estimated cap")
		check(Physiology.jump_range(value+10,50) >= Physiology.jump_range(value,50) and Physiology.hunger_rate(value+10) >= Physiology.hunger_rate(value) and Physiology.breath_damage_multiplier(value+10) <= Physiology.breath_damage_multiplier(value),"Jump, hunger and breathing mappings are monotone within provisional caps")
	print("STAT PHYSIOLOGY: %d checks, %d failures. Pure helpers; provisional qualitative effects and numerical coefficients are explicit; context helpers grant no spirit acquisition." % [checks,failures])
	quit(1 if failures else 0)
