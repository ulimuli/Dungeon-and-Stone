class_name NumberedRules
extends RefCounted
## No. 3112 Guardian's Braces: the novel establishes 5% damage reduction,
## a stronger active after more damage is prevented, enemy knockback, and
## allied status cleansing/immunity. It does not establish damage immunity.
## Episode 58 demonstrates the Dwarf's 1.5x efficiency in active duration;
## this helper does not multiply the passive or ordinary equipment damage.
## Round durations, charge conversion/cap, charge reset, cooldown, radius and
## knockback distance are explicit numerical gameplay estimates. Simulation
## owns charge/reset, status handling, targets, cooldown and applying damage.
## Call mitigate AFTER ordinary armor/resistance. Persist its returned remainder
## so integer HP retains the exact 5% benefit across repeated small hits.

const ID: String = "guardians_braces"
const SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-58"
const ACQUISITION_SOURCE: String = "https://noveldex.io/series/novel/surviving-the-game-as-a-barbarian/chapter/48"
const BASE_DURATION: int = 2
const MAX_BASE_DURATION: int = 6
const DAMAGE_PER_EXTRA_ROUND: int = 10
const COOLDOWN: int = 6
const RADIUS: int = 3
const KNOCKBACK: int = 2

static func is_equipped(unit: Dictionary) -> bool:
	var equipment: Variant = unit.get("equipment", {})
	return equipment is Dictionary and equipment.values().has(ID)

static func duration(unit: Dictionary, absorbed_damage: int) -> int:
	return duration_for(ID,unit,absorbed_damage) if is_equipped(unit) else 0

static func mitigate(unit: Dictionary, incoming: int) -> Dictionary:
	var remainder: int = _remainder(unit)
	if not is_equipped(unit): return {"damage":maxi(0,incoming),"prevented":0,"remainder":remainder}
	return mitigate_for(ID,incoming,remainder)

static func _remainder(unit: Dictionary) -> int:
	var value: Variant = unit.get("braces_remainder", 0)
	if not (value is int or value is float): return 0
	if not is_finite(float(value)) or float(value) != floorf(float(value)): return 0
	if float(value) < 0.0 or float(value) >= 100.0: return 0
	return int(value)

# Shared resolver helpers: adding content that uses these operations requires
# data and source evidence, not another item-specific simulation branch.
static func equipped_ids(unit: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: String in unit.get("equipment", {}).values():
		if NumberedCatalog.definitions().has(id) and not result.has(id): result.append(id)
	return result

static func duration_for(id: String, unit: Dictionary, charge: int) -> int:
	var active: Dictionary = NumberedCatalog.definitions().get(id, {}).get("active", {})
	if active.is_empty(): return 0
	var rounds: int = int(active.base_duration)
	if int(active.charge_per_round) > 0: rounds += maxi(0,charge) / int(active.charge_per_round)
	rounds = mini(int(active.max_duration),rounds)
	if unit.get("ancestry", "") == "dwarf": rounds = ceili(float(rounds) * float(active.get("dwarf_duration_multiplier",1.0)))
	return rounds

static func mitigate_for(id: String, incoming: int, remainder: int) -> Dictionary:
	var percent: int = 0
	for effect: Dictionary in NumberedCatalog.definitions().get(id, {}).get("passives", []):
		if effect.op == "damage_reduction": percent = int(effect.percent)
	if incoming <= 0: return {"damage":0,"prevented":0,"remainder":clampi(remainder,0,99)}
	@warning_ignore("integer_division")
	var whole: int = incoming / 100
	var fraction: int = (incoming%100)*percent + clampi(remainder,0,99)
	@warning_ignore("integer_division")
	var prevented: int = whole*percent + fraction/100
	return {"damage":incoming-prevented,"prevented":prevented,"remainder":fraction%100}
