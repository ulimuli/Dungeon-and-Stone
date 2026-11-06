class_name StatRules
extends RefCounted
## Pure shared stat evaluation. Stacking is an explicit implementation rule,
## pending novel evidence; sharing a source does not make modifiers exclusive.
## Formula: max(at_least, (base + sum(add)) * (1 + sum(increase))
## * product(multiply)). Increase values are fractions, not whole percentages.
## The registry defines defaults, caps and rounding; no stat IDs are hardcoded.
## Rounding precedes registry caps, so the final value always obeys those caps.
## Modifier IDs are globally unique within one evaluation. Source IDs identify
## provenance and may repeat. ID ordering fixes floating-point accumulation.
## Validation and arithmetic failures return no partially computed values.

const OPERATIONS: Array[String] = ["add", "increase", "multiply", "at_least"]
const ROUNDING: Array[String] = ["floor", "ceil", "nearest", "none"]

static func validate_modifiers(mods: Variant, registry: Dictionary) -> Array[String]:
	var errors: Array[String] = _registry_errors(registry)
	if not mods is Array:
		errors.append("Modifiers must be an array.")
		errors.sort()
		return errors
	var seen: Dictionary = {}
	for index: int in range(mods.size()):
		var entry: Variant = mods[index]
		if not entry is Dictionary:
			errors.append("Modifier %d must be an object." % index)
			continue
		var modifier: Dictionary = entry
		var label: String = "Modifier " + str(modifier.get("id", index)) + ": "
		if not _identifier(modifier.get("id")):
			errors.append(label + "stable ID required.")
		elif seen.has(modifier.id): errors.append(label + "duplicate ID.")
		else: seen[modifier.id] = true
		if not _identifier(modifier.get("source")): errors.append(label + "stable source ID required.")
		if not _identifier(modifier.get("stat")) or not registry.has(modifier.get("stat")): errors.append(label + "unknown stat ID.")
		if not modifier.get("op") is String or modifier.get("op") not in OPERATIONS: errors.append(label + "unsupported operation.")
		if not _finite_number(modifier.get("value")): errors.append(label + "finite numeric value required.")
	errors.sort()
	return errors

static func evaluate(base: Dictionary, mods: Array, registry: Dictionary) -> Dictionary:
	var errors: Array[String] = validate_modifiers(mods, registry)
	for key: Variant in base:
		if not key is String or not registry.has(key): errors.append("Base contains unknown stat ID: " + str(key))
		elif not _finite_number(base[key]): errors.append("Base " + key + " requires a finite numeric value.")
	if not errors.is_empty(): return _failure(errors)
	var ordered: Array = mods.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	var values: Dictionary = {}
	var breakdown: Dictionary = {}
	var stat_ids: Array = registry.keys()
	stat_ids.sort()
	for stat_id: String in stat_ids:
		var definition: Dictionary = registry[stat_id]
		var initial: float = float(base.get(stat_id, definition.default))
		var flat: float = 0.0
		var increased: float = 0.0
		var multiplier: float = 1.0
		var minimum: Variant = null
		var sources: Array[Dictionary] = []
		for modifier: Dictionary in ordered:
			if modifier.stat != stat_id: continue
			var amount: float = float(modifier.value)
			match str(modifier.op):
				"add": flat += amount
				"increase": increased += amount
				"multiply": multiplier *= amount
				"at_least": minimum = amount if minimum == null else maxf(float(minimum), amount)
			sources.append({"id":str(modifier.id), "source":str(modifier.source), "op":str(modifier.op), "value":amount})
			if not is_finite(flat) or not is_finite(increased) or not is_finite(multiplier):
				errors.append("Stat " + stat_id + ": modifier accumulation is nonfinite.")
				break
		var raw: float = (initial + flat) * (1.0 + increased) * multiplier
		if not is_finite(raw): errors.append("Stat " + stat_id + ": evaluated value is nonfinite.")
		if minimum != null: raw = maxf(raw, float(minimum))
		var final: float = raw
		match str(definition.rounding):
			"floor": final = floorf(raw)
			"ceil": final = ceilf(raw)
			"nearest": final = roundf(raw)
		final = clampf(final, float(definition.min), float(definition.max))
		values[stat_id] = final
		breakdown[stat_id] = {"base":initial, "flat":flat, "increased":increased, "multiplier":multiplier, "minimum":minimum, "unclamped":raw, "final":final, "sources":sources}
	if not errors.is_empty(): return _failure(errors)
	return {"values":values, "breakdown":breakdown, "errors":errors}

static func _registry_errors(registry: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: Variant in registry:
		if not _identifier(key):
			errors.append("Registry requires nonempty string stat IDs.")
			continue
		var entry: Variant = registry[key]
		if not entry is Dictionary:
			errors.append("Stat " + str(key) + ": registry definition must be an object.")
			continue
		var definition: Dictionary = entry
		for field: String in ["default", "min", "max"]:
			if not _finite_number(definition.get(field)): errors.append("Stat " + str(key) + ": finite numeric " + field + " required.")
		if _finite_number(definition.get("min")) and _finite_number(definition.get("max")) and float(definition.min) > float(definition.max): errors.append("Stat " + str(key) + ": minimum exceeds maximum.")
		if not definition.get("rounding") is String or definition.get("rounding") not in ROUNDING: errors.append("Stat " + str(key) + ": unsupported rounding.")
	errors.sort()
	return errors

static func _failure(errors: Array[String]) -> Dictionary:
	errors.sort()
	return {"values":{}, "breakdown":{}, "errors":errors}

static func _identifier(value: Variant) -> bool:
	return value is String and not str(value).strip_edges().is_empty()

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
