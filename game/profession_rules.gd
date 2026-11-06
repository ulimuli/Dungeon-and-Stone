class_name ProfessionRules
extends RefCounted
## Basic human magic entry only, not a complete human profession system.
## The novel supports uneven talent, assessment, teachers and paid basic lessons.
## "limited" qualifies for private basic lessons, not Magic Tower admission.
## All costs, elapsed days and the one-in-five aptitude distribution are numerical
## gameplay estimates. Simulation owns payment, elapsed time and applying results.
## A recorded negative assessment cannot be purchased again to reroll aptitude.

const TALENT_SOURCE: String = "https://hennoveltranslations.com/episodes/stgb-episode-52/"
const ASSESSMENT_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-292/"
const TRAINING_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-663/"
const ASSESSMENT_COST: int = 10
const ASSESSMENT_DAYS: int = 3
const TUITION_COST: int = 600
const TUITION_DAYS: int = 30

static func assessment(unit: Dictionary, seed: int) -> String:
	if str(unit.get("profession", "explorer")) == "mage": return "limited"
	# Stable identity only: no cosmetic names, global RNG or combat RNG state.
	var digest: String = ("%d:%s" % [seed, str(unit.get("id", ""))]).sha256_text()
	return "limited" if digest.substr(0, 8).hex_to_int() % 5 == 0 else "none"

static func can_assess(unit: Dictionary) -> String:
	if not _alive(unit): return "Choose a living character."
	if str(unit.get("ancestry", "")) != "human": return "Magic talent assessment requires a Human."
	if unit.has("magic_assessment"): return "Magic talent has already been assessed."
	return ""

static func can_study(unit: Dictionary) -> String:
	if not _alive(unit): return "Choose a living character."
	if str(unit.get("ancestry", "")) != "human": return "These basic magic lessons require a Human."
	if str(unit.get("profession", "explorer")) == "mage": return "This character is already a mage."
	if not unit.get("magic_assessment") is String or unit.magic_assessment != "limited":
		return "Basic magic lessons require a suitable talent assessment."
	var essences: Variant = unit.get("essences", [])
	if not essences is Array: return "Invalid essence record."
	if not essences.is_empty(): return "A character with absorbed essences cannot become a mage."
	return ""

static func validate(unit: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not unit.has("magic_assessment"): return errors
	var result: Variant = unit.magic_assessment
	if not result is String or result not in ["limited", "none"]:
		errors.append("invalid magic assessment")
	if str(unit.get("ancestry", "")) != "human": errors.append("magic assessment requires human ancestry")
	if str(unit.get("profession", "explorer")) == "mage" and result is String and result == "none":
		errors.append("mage cannot have a negative magic assessment")
	return errors

static func _alive(unit: Dictionary) -> bool:
	if not unit.get("dead", false) is bool or unit.get("dead", false): return false
	var health: Variant = unit.get("hp")
	return (health is int or health is float) and is_finite(float(health)) and float(health) > 0.0
