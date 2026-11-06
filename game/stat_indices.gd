class_name StatIndices
extends RefCounted
## Informational indices only. Group membership and weights come exclusively
## from the supplied registry, never a second catalog or hardcoded raw-stat list.
## Known coefficients coexist with explicitly estimated weights. Resolved values
## enter once; this helper never applies modifiers or buffs gameplay statistics.
const GROUPS: Dictionary = {"physical":"body_index", "mental":"mind_index", "ability":"ability_index"}

static func resolve(values: Dictionary, registry: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var sums: Dictionary = {"body_index":0.0,"mind_index":0.0,"ability_index":0.0,"combat_index":0.0}
	var sources: Dictionary = {"body_index":[],"mind_index":[],"ability_index":[],"combat_index":[]}
	var ids: Array = registry.keys()
	for id: Variant in values:
		if not id is String or not registry.has(id): errors.append("Index input has unknown stat ID: " + str(id))
		elif not _finite(values[id]): errors.append("Index input " + str(id) + " requires a finite number")
	for id: Variant in ids:
		if not id is String or not registry[id] is Dictionary:
			errors.append("Index registry requires named metadata rows: " + str(id)); continue
		var row: Dictionary = registry[id]
		var group: Variant = row.get("aggregate_group","none")
		var weight: Variant = row.get("aggregate_weight",0.0)
		if not group is String or (group != "none" and not GROUPS.has(group)): errors.append("Index registry " + id + ": unknown aggregate_group")
		if not _finite(row.get("combat_index_weight",0.0)): errors.append("Index registry " + id + ": combat_index_weight requires a finite number")
		if not _finite(weight): errors.append("Index registry " + id + ": aggregate_weight requires a finite number")
		elif group == "none" and float(weight) != 0.0: errors.append("Index registry " + id + ": excluded weight must be0")
		if not values.has(id) and not _finite(row.get("default",0.0)): errors.append("Index registry " + id + ": default requires a finite number")
	if not errors.is_empty(): return _failure(errors)
	ids.sort()
	for id: String in ids:
		var row: Dictionary = registry[id]
		var group: String = str(row.get("aggregate_group","none"))
		if group == "none": continue
		if id in ["body_index","mind_index","ability_index","combat_index"]:
			errors.append("Index registry " + id + ": an aggregate cannot contribute to itself or another group"); continue
		var target: String = GROUPS[group]
		var input: float = float(values.get(id,row.get("default",0.0)))
		var weight: float = float(row.get("aggregate_weight",0.0))
		var contribution: float = input * weight
		sums[target] += contribution
		if not is_finite(contribution) or not is_finite(float(sums[target])): errors.append("Index " + target + ": nonfinite contribution from " + id)
		if input != 0.0:
			sources[target].append({"id":"index:"+target+":"+id,"source":"aggregate:"+id,"stat":id,"op":"add","value":contribution,"input":input,"weight":weight,"estimated":not bool(row.get("aggregate_weight_verified",false))})
	for target: String in ["body_index","mind_index","ability_index"]:
		sums.combat_index += float(sums[target])
		sources.combat_index.append({"id":"index:combat_index:"+target,"source":"aggregate:"+target,"stat":target,"op":"add","value":sums[target],"input":sums[target],"weight":1.0,"estimated":true})
	for id: String in ids:
		var combat_weight: float = float(registry[id].get("combat_index_weight",0.0))
		if combat_weight == 0.0: continue
		if id in ["body_index","mind_index","ability_index","combat_index"]:
			errors.append("Index registry " + id + ": aggregate cannot be counted as a direct combat term"); continue
		var input: float = float(values.get(id,registry[id].get("default",0.0)))
		var contribution: float = input * combat_weight
		sums.combat_index += contribution
		sources.combat_index.append({"id":"index:combat_index:"+id,"source":"aggregate:"+id,"stat":id,"op":"add","value":contribution,"input":input,"weight":combat_weight,"estimated":true})
	if not is_finite(float(sums.combat_index)): errors.append("Index combat_index: nonfinite estimated total")
	if not errors.is_empty(): return _failure(errors)
	var breakdown: Dictionary = {}
	for target: String in sums:
		breakdown[target] = {"base":0.0,"flat":sums[target],"increased":0.0,"multiplier":1.0,"minimum":null,"unclamped":sums[target],"final":sums[target],"sources":sources[target],"estimated":true,"informational_only":true}
	return {"values":sums,"breakdown":breakdown,"errors":errors}

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _failure(errors: Array[String]) -> Dictionary:
	errors.sort()
	return {"values":{},"breakdown":{},"errors":errors}
