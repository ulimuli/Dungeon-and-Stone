extends SceneTree
## These are informational reconstruction indices, never combat multipliers.
const Indices = preload("res://game/stat_indices.gd")
const Catalog = preload("res://game/stat_catalog.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func registry() -> Dictionary:
	return {
		"strength":{"aggregate_group":"physical","aggregate_weight":1.0},
		"wit":{"aggregate_group":"mental","aggregate_weight":1.0},
		"dexterity":{"aggregate_group":"ability","aggregate_weight":0.5,"aggregate_weight_verified":true},
		"mana_resistance":{"aggregate_group":"ability","aggregate_weight":3.0,"aggregate_weight_verified":true},
		"distrust":{"aggregate_group":"mental","aggregate_weight":-0.6,"aggregate_weight_verified":true},
		"possessiveness":{"aggregate_group":"mental","aggregate_weight":0.0,"aggregate_weight_verified":true},
		"attack":{"combat_index_weight":1.0},"armor":{"combat_index_weight":2.0},"accuracy":{"combat_index_weight":0.25},"evasion":{"combat_index_weight":0.25},"attack_range":{"combat_index_weight":1.0}
	}

func reject(values: Dictionary, rows: Dictionary, diagnostic: String, label: String) -> void:
	var before_values: String = var_to_str(values)
	var before_rows: String = var_to_str(rows)
	var result: Dictionary = Indices.resolve(values,rows)
	check(result.values.is_empty() and result.breakdown.is_empty() and not result.errors.is_empty(),label+" fails atomically")
	check(result.errors.any(func(error: String) -> bool: return error.contains(diagnostic)),label+" has actionable diagnostic: "+str(result.errors))
	check(var_to_str(values) == before_values and var_to_str(rows) == before_rows,label+" does not mutate input or registry")

func _initialize() -> void:
	var rows: Dictionary = registry()
	var values: Dictionary = {"strength":10.0,"wit":5.0,"dexterity":8.0,"mana_resistance":2.0,"distrust":10.0,"possessiveness":500.0,"attack":20.0,"armor":3.0,"accuracy":80.0,"evasion":4.0,"attack_range":2.0}
	var before_values: Dictionary = values.duplicate(true)
	var before_rows: Dictionary = rows.duplicate(true)
	var result: Dictionary = Indices.resolve(values,rows)
	check(result.errors.is_empty() and result.values.size() == 4 and result.breakdown.size() == 4,"Resolver returns exactly four informational summaries")
	check(result.values.body_index == 10.0 and result.values.mind_index == -1.0 and result.values.ability_index == 10.0,"Verified signed/zero coefficients combine with estimated raw group inputs")
	check(result.values.combat_index == 68.0,"Combat estimate combines group indices and resolved combat terms exactly once")
	check(values == before_values and rows == before_rows,"Successful resolution preserves gameplay values and catalog metadata")
	for id: String in result.breakdown:
		var detail: Dictionary = result.breakdown[id]
		check(detail.informational_only and detail.estimated and detail.final == result.values[id],"Breakdown labels the informational estimate: "+id)
		var total: float = 0.0
		var seen: Dictionary = {}
		for source: Dictionary in detail.sources:
			total += float(source.value)
			check(not seen.has(source.id),"Contribution provenance IDs are unique: "+str(source.id))
			seen[source.id] = true
		check(is_equal_approx(total,float(detail.final)),"Visible contributions account for the entire informational result: "+id)
	var distrust: Dictionary = result.breakdown.mind_index.sources.filter(func(row: Dictionary) -> bool: return row.stat == "distrust")[0]
	check(distrust.weight == -0.6 and distrust.value == -6.0 and not distrust.estimated,"Known negative coefficient preserves input, sign and evidence status")
	var possession: Dictionary = result.breakdown.mind_index.sources.filter(func(row: Dictionary) -> bool: return row.stat == "possessiveness")[0]
	check(possession.value == 0.0 and possession.input == 500.0,"Known zero coefficient remains inspectable without changing totals")
	var modified: Dictionary = rows.duplicate(true)
	modified.strength.aggregate_weight = 2.5
	var changed: Dictionary = Indices.resolve(values,modified)
	check(changed.values.body_index == 25.0 and changed.values.combat_index == 83.0,"Changing registry data controls the group formula without hardcoded stat behavior")
	modified.strength.aggregate_group = "ability"
	changed = Indices.resolve(values,modified)
	check(changed.values.body_index == 0.0 and changed.values.ability_index == 35.0 and changed.values.combat_index == 83.0,"Registry group reassignment moves a contribution without duplicating it")
	var extended_rows: Dictionary = rows.duplicate(true)
	extended_rows["arbitrary_future_stat"] = {"default":4.0,"combat_index_weight":2.0}
	check(Indices.resolve(values,extended_rows).values.combat_index == 76.0,"A new registry combat contribution needs no calculator stat-name branch")
	var reverse_rows: Dictionary = {}
	var keys: Array = rows.keys()
	keys.reverse()
	for id: String in keys: reverse_rows[id] = rows[id]
	check(Indices.resolve(values,reverse_rows) == result,"Registry insertion order cannot change accumulation or provenance order")
	var defaults: Dictionary = {"strength":{"aggregate_group":"physical","aggregate_weight":1.5,"default":4.0},"attack":{"default":2.0,"combat_index_weight":1.0}}
	check(Indices.resolve({},defaults).values.combat_index == 8.0,"Missing resolved inputs use the supplied registry defaults")
	var empty: Dictionary = Indices.resolve({},{})
	check(empty.errors.is_empty() and empty.values.combat_index == 0.0,"Empty informational fixture has an explicit zero result")
	var catalog: Dictionary = Catalog.definitions()
	var integrated: Dictionary = Indices.resolve({},catalog)
	check(integrated.errors.is_empty() and integrated.values.size() == 4,"Actual catalog aggregate metadata resolves without a dependency cycle")
	for id: String in ["body_index","mind_index","ability_index","combat_index"]:
		check(catalog[id].aggregate_group == "none","Catalog aggregate outputs never recursively enter index groups: "+id)
	for invalid: Variant in [true,"4",null,NAN,INF,-INF,{},[]]:
		var bad: Dictionary = values.duplicate(true)
		bad.strength = invalid
		reject(bad,rows,"finite number","Invalid resolved input "+str(invalid))
		var bad_rows: Dictionary = rows.duplicate(true)
		bad_rows.strength.aggregate_weight = invalid
		reject(values,bad_rows,"aggregate_weight","Invalid aggregate coefficient "+str(invalid))
	var bad_group: Dictionary = rows.duplicate(true)
	bad_group.strength.aggregate_group = "combat_damage"
	reject(values,bad_group,"aggregate_group","Unknown group")
	var shadowed: Dictionary = rows.duplicate(true)
	shadowed["body_index"] = {"aggregate_group":"physical","aggregate_weight":1}
	reject(values,shadowed,"aggregate cannot contribute","Recursive aggregate contribution")
	var unknown: Dictionary = values.duplicate(true)
	unknown.unknown = 20
	reject(unknown,rows,"unknown stat ID","Unknown resolved stat")
	var overflow: Dictionary = values.duplicate(true)
	overflow.strength = 1.0e308
	var overflow_rows: Dictionary = rows.duplicate(true)
	overflow_rows.strength.aggregate_weight = 1.0e308
	reject(overflow,overflow_rows,"nonfinite contribution","Overflow in informational index")
	var bad_combat_weight: Dictionary = rows.duplicate(true)
	bad_combat_weight.attack.combat_index_weight = NAN
	reject(values,bad_combat_weight,"combat_index_weight","Nonfinite direct combat coefficient")
	var recursive_combat: Dictionary = rows.duplicate(true)
	recursive_combat["body_index"] = {"combat_index_weight":1.0}
	reject(values,recursive_combat,"aggregate cannot be counted","Direct aggregate recursion")
	var default_bad: Dictionary = {"strength":{"default":NAN}}
	reject({},default_bad,"default","Nonfinite fallback default")
	var no_group_weight: Dictionary = {"strength":{"aggregate_weight":1.0}}
	reject({},no_group_weight,"excluded weight","Weight on excluded group")
	print("STAT INDICES: %d checks, %d failures. Informational estimated summaries only; source-verified coefficients are labeled separately." % [checks,failures])
	quit(1 if failures else 0)
