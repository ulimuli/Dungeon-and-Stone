class_name StatCombatRules
extends RefCounted
## Pure combat-stat adapters. Novel evidence supports elemental sensitivity
## scaling matching elemental power, Cutting Force improving sword cutting,
## critical hits with target-dependent weak-point multipliers, and Pain
## Resistance changing felt pain. It does not establish these point curves.
## Estimates: sensitivity/cutting +1% per point, factors clamped0.1..5;
## critical chance points are percentage points clamped0..100; critical factor
## is supplied by the caller (usual provisional default1.5, bound1..10).
## No baseline critical roll occurs at zero chance. Only normal weapon hits
## qualify here. Fixed damage, DOT, secondary procs and spells never roll.
## Pain helpers change perceived pain only: never HP, armor, injury, AP,
## status duration, stun immunity or mental resistance directly.
## Mana Sensitivity spell amplification is an authorized reconstruction rule;
## the novel audit verifies the named attribute, not this qualitative effect.
## Its provisional curve matches sensitivity: signed +1% per point,0.1..5.

const DAMAGE_KINDS: Array[String] = ["physical","fire","cold","poison","dark","mana","ground","solar","lightning"]
const SENSITIVITY_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-279"
const CUTTING_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-279"
const CRITICAL_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/surviving-the-game-as-a-barbarian-episode-841/"
const PAIN_SOURCE: String = "https://bape-clothing.com/book/surviving-the-game-as-a-barbarian-2/chapter-35"
const POINT_FACTOR_ESTIMATE: float = 0.01
const MIN_POWER_FACTOR: float = 0.1
const MAX_POWER_FACTOR: float = 5.0
const DEFAULT_CRITICAL_FACTOR_ESTIMATE: float = 1.5

static func supports_damage_kind(kind: String) -> bool:
	return kind in DAMAGE_KINDS

static func sensitivity_multiplier(points: float) -> float:
	return clampf(1.0 + _finite_or(points,0.0)*POINT_FACTOR_ESTIMATE, MIN_POWER_FACTOR, MAX_POWER_FACTOR)

static func mana_sensitivity_multiplier(points: float) -> float:
	# Explicit reconstruction estimate for the canonical spell-damage modifier.
	return sensitivity_multiplier(points)

static func cutting_multiplier(points: float, context: Dictionary = {}) -> float:
	if _excluded_damage(context) or context.get("category","") != "weapon": return 1.0
	if context.get("weapon_style","") != "slashing" or context.get("damage_type","physical") != "physical": return 1.0
	return sensitivity_multiplier(points)

static func critical(chance_points: float, damage_multiplier: float, rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var chance: float = clampf(_finite_or(chance_points,0.0),0.0,100.0)
	var result: Dictionary = {"critical":false,"multiplier":1.0,"chance":chance,"roll":null}
	if _excluded_damage(context) or context.get("category","") != "weapon" or context.get("normal_attack",true) != true: return result
	if chance <= 0.0 or rng == null: return result
	var success: bool = true
	if chance < 100.0:
		var roll: float = rng.randf()*100.0
		result.roll = roll
		success = roll < chance
	result.critical = success
	if success: result.multiplier = clampf(_finite_or(damage_multiplier,1.0),1.0,10.0)
	return result

static func pain_multiplier(pain_resistance: float) -> float:
	# Estimated sensory curve:100 positive points halve perceived intensity;
	#100 negative points double it. This never mitigates health damage.
	var points: float = _finite_or(pain_resistance,0.0)
	var factor: float = 100.0/(100.0+points) if points >= 0.0 else 1.0-points/100.0
	return clampf(factor,MIN_POWER_FACTOR,MAX_POWER_FACTOR)

static func perceived_pain(intensity: float, pain_resistance: float) -> float:
	var raw: float = maxf(0.0,_finite_or(intensity,0.0))
	var result: float = raw*pain_multiplier(pain_resistance)
	return result if is_finite(result) else raw

static func _excluded_damage(context: Dictionary) -> bool:
	if context.get("fixed",false) == true or context.get("dot",false) == true or context.get("secondary",false) == true: return true
	var fixed: Variant = context.get("fixed_damage",-1)
	return (fixed is int or fixed is float) and is_finite(float(fixed)) and float(fixed) >= 0.0

static func _finite_or(value: float, fallback: float) -> float:
	return value if is_finite(value) else fallback
