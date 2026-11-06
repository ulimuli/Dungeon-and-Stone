class_name DragonBlessingRules
extends RefCounted
## Chapter202 establishes the three effects, not a public paid blessing shop.
## This native-Draconian rite uses explicitly provisional access: level2,500
## stones and one permanent slot at the currently implemented stage. Bjorn's
## exceptional foreigner bargain and its quest are not implemented here.
const SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-202"
const INSCRIPTION_COST: int = 500
const MIN_LEVEL: int = 2
const EARTH_SCALE: float = 1.2
const VOLCANO_SCALE: float = 1.3
const SEA_SOUL_POWER: int = 100
const IDS: Array[String] = ["earth","volcano","sea"]
const ACCESS_NOTE: String = "Level2,500 stones and a single slot are provisional gameplay access rules. The novel does not establish a public paid blessing market. The foreigner exception requires a story bargain that is not implemented."

static func definitions() -> Dictionary:
	return {
		"earth":{"id":"earth","name":"Blessing of the Earth Dragon","source":SOURCE,"reference_urls":[SOURCE],"description":"Additional attributes gained from essences increase by20%.","effect_scope":"essence_attributes_only","effect_value":EARTH_SCALE,"numerical_confidence":"exact_source_value","source_lines":"473–478","access_note":ACCESS_NOTE},
		"volcano":{"id":"volcano","name":"Blessing of the Volcano Dragon","source":SOURCE,"reference_urls":[SOURCE],"description":"Enhances the performance of all skills by about30%.","effect_scope":"skill_performance","effect_value":VOLCANO_SCALE,"numerical_confidence":"approximate_source_value","source_lines":"482–489","access_note":ACCESS_NOTE},
		"sea":{"id":"sea","name":"Blessing of the Sea Dragon","source":SOURCE,"reference_urls":[SOURCE],"description":"Adds100 Soul Power.","effect_scope":"soul_power","effect_value":SEA_SOUL_POWER,"numerical_confidence":"exact_source_value","source_lines":"491–497","access_note":ACCESS_NOTE}
	}

static func can_inscribe(sim: RefCounted, unit_id: String, blessing: String) -> String:
	if blessing not in IDS: return "Choose an Earth, Volcano or Sea Dragon blessing."
	if sim.state.get("mode","") != "city": return "Seek a Dragon blessing in the city."
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_native(unit): return "Choose a living Draconian party member."
	if unit.has("dragon_blessing"): return "This character already has a Dragon blessing."
	var level: Variant = sim.state.get("level",0)
	if not _number(level) or float(level)<MIN_LEVEL: return "A Dragon blessing requires level%d." % MIN_LEVEL
	var gold: Variant = sim.state.get("gold",0)
	if not _number(gold) or float(gold)<INSCRIPTION_COST: return "Need %d stones." % INSCRIPTION_COST
	return ""

static func inscribe(sim: RefCounted, unit_id: String, blessing: String) -> String:
	var error: String = can_inscribe(sim,unit_id,blessing)
	if not error.is_empty(): return error
	var unit: Dictionary = sim.unit_by_id(unit_id)
	# Preflight the full composed candidate before any payment or saved mutation.
	# The optional API also permits a minimal simulation fixture in pure tests.
	if sim.has_method("stat_breakdown"):
		var candidate: Dictionary = unit.duplicate(true)
		candidate["dragon_blessing"] = blessing
		var result: Dictionary = sim.stat_breakdown(candidate)
		if not result.get("errors",[]).is_empty(): return "Invalid blessing statistics."
	sim.state["gold"] -= INSCRIPTION_COST
	unit["dragon_blessing"] = blessing
	sim.recalculate(unit,false)
	var name: String = str(definitions()[blessing].name)
	sim.journal("Dragon blessing: "+unit_id,"%s receives %s. The effect follows chapter202; access at level2 for500 stones and the current single slot are provisional reconstruction choices." % [str(unit.get("name",unit_id)),name])
	sim.say("%s receives %s." % [str(unit.get("name",unit_id)),name])
	return ""

static func derived_modifiers(unit: Dictionary) -> Array:
	if not _valid_blessing(unit): return []
	match unit.dragon_blessing:
		"sea": return [{"id":"derived:dragon_blessing:sea:soul_power","source":"dragon_blessing:sea","stat":"soul_power","op":"add","value":SEA_SOUL_POWER}]
		"volcano": return [{"id":"derived:dragon_blessing:volcano:skill_power","source":"dragon_blessing:volcano","stat":"skill_power_multiplier","op":"multiply","value":VOLCANO_SCALE}]
	# Earth is scaled by the essence adapter only, never as an all-stat bonus.
	return []

static func essence_scale(unit: Dictionary) -> float:
	return EARTH_SCALE if _valid_blessing(unit) and unit.dragon_blessing == "earth" else 1.0

static func skill_scale(unit: Dictionary) -> float:
	return VOLCANO_SCALE if _valid_blessing(unit) and unit.dragon_blessing == "volcano" else 1.0

static func validate_unit(unit: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not unit.has("dragon_blessing"): return errors
	var blessing: Variant = unit.dragon_blessing
	if not blessing is String or blessing not in IDS: errors.append("invalid Dragon blessing")
	if unit.get("ancestry","") != "draconian": errors.append("Dragon blessing requires Draconian ancestry")
	if not unit.get("summon",false) is bool or unit.get("summon",false): errors.append("summons cannot hold a Dragon blessing")
	# Dead characters retain valid history. The campaign validator owns level.
	return errors

static func _valid_blessing(unit: Dictionary) -> bool:
	return unit.has("dragon_blessing") and validate_unit(unit).is_empty()

static func _living_native(unit: Dictionary) -> bool:
	if unit.is_empty() or unit.get("ancestry","") != "draconian": return false
	if unit.get("team","ally") != "ally": return false
	if not unit.get("dead",false) is bool or unit.get("dead",false): return false
	if not unit.get("summon",false) is bool or unit.get("summon",false): return false
	var health: Variant = unit.get("hp",0)
	return _number(health) and float(health)>0

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
