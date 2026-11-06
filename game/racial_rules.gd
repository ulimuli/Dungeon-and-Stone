class_name RacialRules
extends RefCounted
## Purchased Undying stage 1 only. This is not a complete racial progression tree.
## The novel establishes greatly increased natural regeneration and an irreversible
## path choice. It does not establish a conversion to this game's HP clock.
## +1 HP per 90-minute noncombat recovery interval is a playable approximation.
## Simulation owns currency, sanctuary access, timing, healing and save validation.

const UNDYING_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-19-20-21/"
const RECOVERY_INTERVAL_MINUTES: int = 90
const UNDYING_HEAL_APPROXIMATION: int = 1

static func can_unlock_undying(unit: Dictionary) -> String:
	if not _alive(unit): return "Choose a living character."
	if str(unit.get("ancestry", "")) != "barbarian": return "Soul Engraving requires a Barbarian."
	if unit.has("racial") and not unit.racial is Dictionary: return "Invalid racial progression record."
	var racial: Dictionary = unit.get("racial", {})
	if not racial.get("engraving_path", "") is String: return "Invalid engraving path."
	var path: String = str(racial.get("engraving_path", ""))
	if path == "undying": return "Undying has already been engraved."
	if not path.is_empty(): return "Your engraving path is permanent. Another path cannot be chosen."
	if not _whole_number(racial.get("engraving_level", 0)) or int(racial.get("engraving_level", 0)) != 0: return "Invalid engraving level."
	return ""

static func unlock_undying(unit: Dictionary) -> String:
	var failure: String = can_unlock_undying(unit)
	if not failure.is_empty(): return failure
	var racial: Dictionary = unit.get("racial", {}).duplicate(true)
	racial.engraving_path = "undying"
	racial.engraving_level = 1
	unit.racial = racial
	return ""

static func natural_heal_bonus(unit: Dictionary) -> int:
	if not _alive(unit) or str(unit.get("ancestry", "")) != "barbarian": return 0
	if not unit.get("racial") is Dictionary: return 0
	var racial: Dictionary = unit.racial
	if not racial.get("engraving_path", "") is String or str(racial.get("engraving_path", "")) != "undying": return 0
	if not _whole_number(racial.get("engraving_level")) or int(racial.engraving_level) != 1: return 0
	return UNDYING_HEAL_APPROXIMATION

static func _alive(unit: Dictionary) -> bool:
	if not unit.get("dead", false) is bool or unit.get("dead", false): return false
	var health: Variant = unit.get("hp")
	return (health is int or health is float) and is_finite(float(health)) and float(health) > 0.0

static func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

# Chapter60: ring destruction forces a previously uncontracted Beastman's
# Strengthening contract. Initial cold applies to bare hands, not weapons.
const SKADIA_SOURCE: String = "https://noveldex.io/series/novel/surviving-the-game-as-a-barbarian/chapter/60"
const FROST_RING: String = "frost_spirit_ring"
const STRENGTHENING_POWER_ESTIMATE: int = 2
const STRENGTHENING_EVASION_ESTIMATE: int = 2

static func has_skadia(unit: Dictionary) -> bool:
	return unit.get("ancestry", "") == "beastman" and unit.get("racial", {}) is Dictionary and unit.get("racial", {}).get("soul_beast", "") == "skadia"

static func can_awaken_skadia(unit: Dictionary) -> String:
	if not _alive(unit): return "Choose a living character."
	if unit.get("ancestry", "") != "beastman": return "Only a Beastman can accept this Soul Beast contract."
	if unit.get("equipment", {}).get("charm", "") != FROST_RING: return "Wear the Ring of the Frost Spirit first."
	if not unit.get("racial", {}) is Dictionary: return "Invalid racial progression record."
	if not unit.get("racial", {}).is_empty(): return "This character already has a racial contract."
	return ""

static func validate_state(unit: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not unit.has("racial"): return errors
	if not unit.racial is Dictionary: errors.append("expected dictionary"); return errors
	var racial: Dictionary = unit.racial
	if racial.is_empty(): return errors
	match str(unit.get("ancestry", "")):
		"barbarian":
			if not racial.get("engraving_path") is String or str(racial.get("engraving_path")) != "undying" or not _whole_number(racial.get("engraving_level")) or racial.get("engraving_level") != 1: errors.append("invalid supported engraving")
			for key: String in racial:
				if key not in ["engraving_path","engraving_level"]: errors.append("unknown engraving field")
		"beastman":
			if not racial.get("soul_beast") is String or str(racial.get("soul_beast")) != "skadia" or not _whole_number(racial.get("awakening")) or racial.get("awakening") != 0: errors.append("invalid supported Soul Beast contract")
			for key: String in racial:
				if key not in ["soul_beast","awakening"]: errors.append("unknown Soul Beast field")
		_: errors.append("unsupported racial progression")
	return errors

static func weapon_damage_type(unit: Dictionary) -> String:
	return "cold" if has_skadia(unit) and str(unit.get("equipment", {}).get("weapon", "")).is_empty() else "physical"
