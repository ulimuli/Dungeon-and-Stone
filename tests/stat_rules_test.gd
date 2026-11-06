extends SceneTree
const Rules = preload("res://game/stat_rules.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func registry() -> Dictionary:
	return {"power":{"default":10,"min":-1000,"max":1000,"rounding":"none","label":"Fixture only"}, "signed":{"default":-7,"min":-50,"max":50,"rounding":"none"}, "bounded":{"default":0,"min":0,"max":80,"rounding":"floor"}}

func modifier(id: String, source: String, stat: String, op: String, value: Variant) -> Dictionary:
	return {"id":id,"source":source,"stat":stat,"op":op,"value":value}

func reject(base: Dictionary, mods: Array, definitions: Dictionary, label: String) -> void:
	var base_before: String = var_to_str(base)
	var mods_before: String = var_to_str(mods)
	var registry_before: String = var_to_str(definitions)
	var result: Dictionary = Rules.evaluate(base,mods,definitions)
	check(not result.errors.is_empty() and result.values.is_empty() and result.breakdown.is_empty(),label + ": rejection is atomic")
	check(var_to_str(base) == base_before and var_to_str(mods) == mods_before and var_to_str(definitions) == registry_before,label + ": rejection is pure")

func _initialize() -> void:
	var definitions: Dictionary = registry()
	var base: Dictionary = {"power":10}
	var mods: Array = [modifier("flat_b","equipment","power","add",2),modifier("more_b","essence_b","power","multiply",2),modifier("increased_b","equipment","power","increase",0.5),modifier("flat_a","equipment","power","add",3),modifier("increased_a","essence_a","power","increase",0.25),modifier("more_a","essence_a","power","multiply",1.5)]
	var base_before: String = var_to_str(base)
	var mods_before: String = var_to_str(mods)
	var registry_before: String = var_to_str(definitions)
	var result: Dictionary = Rules.evaluate(base,mods,definitions)
	check(result.errors.is_empty() and result.values.power == 78.75,"Flat sums precede additive increases, then independent multiplier product")
	check(result.values.signed == -7 and result.values.bounded == 0,"Missing base stats receive registry defaults, including negative defaults")
	var detail: Dictionary = result.breakdown.power
	check(detail.base == 10 and detail.flat == 5 and detail.increased == 0.75 and detail.multiplier == 3 and detail.minimum == null and detail.unclamped == 78.75 and detail.final == 78.75,"Breakdown exposes every formula stage")
	check(detail.sources.size() == 6 and detail.sources[0].id == "flat_a" and detail.sources[1].id == "flat_b" and detail.sources[0].source == "equipment","Stable modifier IDs sort source details; same source can stack independently")
	check(var_to_str(base) == base_before and var_to_str(mods) == mods_before and var_to_str(definitions) == registry_before,"Successful evaluation never mutates inputs")
	var expected: String = var_to_str(result)
	for rotation: int in range(mods.size()):
		var permuted: Array = mods.duplicate(true)
		for shift: int in range(rotation): permuted.push_back(permuted.pop_front())
		permuted.reverse()
		check(var_to_str(Rules.evaluate(base,permuted,definitions)) == expected,"Permutation preserves exact values, breakdown and output order")
	result = Rules.evaluate({"signed":-10},[modifier("neg_add","source","signed","add",-5),modifier("neg_inc","other","signed","increase",0.5),modifier("negative_floor","source","signed","at_least",-30)],definitions)
	check(result.errors.is_empty() and result.values.signed == -22.5 and result.breakdown.signed.minimum == -30,"Signed stats and negative at_least do not acquire an implicit zero floor")
	result = Rules.evaluate({"signed":-10},[modifier("a","same","signed","at_least",-8),modifier("b","same","signed","at_least",-3)],definitions)
	check(result.values.signed == -3 and result.breakdown.signed.minimum == -3,"Strongest explicit at_least modifier wins")
	result = Rules.evaluate({"bounded":79},[modifier("add","source","bounded","add",10),modifier("floor","source","bounded","at_least",200)],definitions)
	check(result.values.bounded == 80 and result.breakdown.bounded.unclamped == 200,"Registry caps apply after explicit minimum")
	check(Rules.evaluate({"bounded":-10},[],definitions).values.bounded == 0,"Registry lower cap applies to negative input")
	var rounding: Dictionary = {}
	for mode: String in ["floor","ceil","nearest","none"]: rounding[mode] = {"default":-2.6,"min":-10,"max":10,"rounding":mode}
	result = Rules.evaluate({},[],rounding)
	check(result.values.floor == -3 and result.values.ceil == -2 and result.values.nearest == -3 and result.values.none == -2.6,"Rounding modes handle signed values explicitly")
	check(Rules.evaluate({},[],{}).errors.is_empty(),"Empty passed registry imposes no hardcoded stat requirements")
	var unstable: Array = [modifier("a","source","power","add",1.0e16),modifier("b","source","power","add",-1.0e16),modifier("c","source","power","add",1)]
	var reverse: Array = unstable.duplicate(true); reverse.reverse()
	check(var_to_str(Rules.evaluate({"power":0},unstable,definitions)) == var_to_str(Rules.evaluate({"power":0},reverse,definitions)),"Cancellation-sensitive floating point accumulation follows stable ID order")
	for malformed: Variant in [null,{},"modifiers",1,true]: check(not Rules.validate_modifiers(malformed,definitions).is_empty(),"Malformed modifier collection rejected")
	for bad: Variant in [null,[],"modifier",false]: reject(base,[bad],definitions,"Malformed modifier entry")
	for field: String in ["id","source","stat","op","value"]:
		var missing: Dictionary = modifier("fixture","source","power","add",1); missing.erase(field)
		reject(base,[missing],definitions,"Missing modifier field " + field)
	for field: String in ["id","source"]:
		var empty: Dictionary = modifier("fixture","source","power","add",1); empty[field] = "  "
		reject(base,[empty],definitions,"Empty identifier " + field)
	reject(base,[modifier("fixture","source","unknown","add",1)],definitions,"Unknown modifier stat")
	reject(base,[modifier("fixture","source","power","replace",1)],definitions,"Unknown modifier operation")
	for value: Variant in [NAN,INF,-INF,"1",true,null,{}]: reject(base,[modifier("fixture","source","power","add",value)],definitions,"Nonfinite or malformed modifier value")
	var duplicate: Array = [modifier("same","a","power","add",1),modifier("same","b","signed","multiply",2)]
	check(not Rules.validate_modifiers(duplicate,definitions).is_empty(),"Duplicate IDs across sources and stats are rejected")
	reject(base,duplicate,definitions,"Duplicate modifier IDs")
	for value: Variant in [NAN,INF,-INF,"10",true]: reject({"power":value},[],definitions,"Invalid base value")
	reject({"unknown":10},[],definitions,"Unknown base stat")
	for entry: Variant in [null,[],{"default":0,"min":10,"max":0,"rounding":"none"},{"default":INF,"min":0,"max":10,"rounding":"none"},{"default":0,"min":0,"max":10,"rounding":"invented"}]: reject({},[],{"power":entry},"Malformed registry definition")
	reject({},[],{1:{"default":0,"min":0,"max":10,"rounding":"none"}},"Nonstring registry ID")
	reject(base,[modifier("huge_a","a","power","multiply",1.0e308),modifier("huge_b","b","power","multiply",1.0e308)],definitions,"Finite operands causing arithmetic overflow")
	var pristine: Dictionary = Rules.evaluate(base,mods,definitions)
	pristine.breakdown.power.sources[0].source = "changed output"
	check(var_to_str(mods) == mods_before,"Returned provenance details cannot mutate input modifiers")
	print("STAT RULES: %d checks, %d failures. Generic fixture registry; stacking is an explicit implementation rule." % [checks,failures])
	quit(1 if failures else 0)
