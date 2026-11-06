class_name SpiritStones
extends RefCounted
## Confirmed qualitative rules: a Spirit Stone attempts an additional spirit
## attribute with10% success; Wind can guide an arrow's trajectory and speed.
## The source quotes150,000 stones. PRICE=150 uses the game's compressed money
## scale. Wind-only availability is a provisional scope limit, not a novel rule.
## +10 bow Accuracy and1 Natural Energy per attempted shot are reconstruction
## choices. This helper alone adds no market item, UI, attack hook or content count.
const SOURCE: String = "https://martialrealm.com/novel/sgb/chapter-19-20-21/"
const PRICE: int = 150
const NOVEL_PRICE_QUOTE: int = 150000
const SUCCESS_PERCENT: int = 10
const ACCURACY_BONUS: int = 10
const ENERGY_COST: int = 1
const ITEM_ID: String = "spirit_stone"
const FireRules = preload("res://game/spirit_rules.gd")

static func attempt(sim: RefCounted, unit_id: String = "hero") -> String:
	if sim.state.get("mode","")!="city": return "Attempt an additional spirit contract in the city."
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_fairy(unit) or not _fire_contract(unit): return "Choose a living Fairy with a Fire Spirit contract."
	if not FireRules.validate_unit(unit).is_empty() or not validate_unit(unit).is_empty(): return "Invalid spirit contract state."
	if unit.get("wind_contract",false): return "This Fairy already has a Wind Spirit contract."
	var quantity: Variant = sim.state.get("inventory",{}).get(ITEM_ID,0)
	if not _integer(quantity) or float(quantity)<1: return "Need a Spirit Stone."
	# All preconditions precede both conserved mutations. Failed rolls consume
	# the stone as well; exactly one integer roll is drawn for each valid attempt.
	if not sim.take_item(ITEM_ID): return "Need a Spirit Stone."
	var success: bool = sim.rng.randi_range(1,100)<=SUCCESS_PERCENT
	if success:
		unit["wind_contract"] = true
		unit["wind_guidance"] = false
		sim.say("%s forms an additional Wind Spirit contract." % unit.name)
		sim.journal("Wind Spirit contract","A Spirit Stone formed an additional affinity. The documented success chance is10%; each attempt consumes a stone. Current Wind-only availability, +10 bow Accuracy and1 Natural Energy per shot are provisional conversions.")
	else: sim.say("%s’s Spirit Stone fails to form an additional contract." % unit.name)
	return ""

static func toggle(sim: RefCounted, unit_id: String = "hero") -> String:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_fairy(unit) or not _fire_contract(unit): return "Choose a living contracted Fairy."
	if not validate_unit(unit).is_empty() or not _has_wind(unit): return "A Wind Spirit contract is required."
	if sim.unable_to_act(unit): return "Cannot direct the spirit while unable to act."
	# Dismissal remains possible after changing equipment. Only activation
	# requires a currently equipped ranged bow and positive Natural Energy.
	if unit.wind_guidance:
		unit.wind_guidance = false
		sim.say("%s dismisses Wind Guidance." % unit.name)
		return ""
	if not _ranged(unit,sim.item_defs): return "Equip a bow to activate Wind Guidance."
	if not _positive_energy(unit): return "The spirit needs Natural Energy."
	unit.wind_guidance = true
	sim.say("%s guides bow shots with a Wind Spirit." % unit.name)
	return ""

static func attack_bonus(unit: Dictionary, items: Dictionary) -> int:
	return ACCURACY_BONUS if _eligible(unit,items) else 0

static func finish_attack(sim: RefCounted, unit: Dictionary) -> void:
	# Call once after a normal bow attack, including a miss; never for its
	# secondary procs, opportunities or spells. Eligibility is checked again.
	if not _eligible(unit,sim.item_defs): return
	unit["natural_energy_current"] = maxi(0,int(unit.natural_energy_current)-ENERGY_COST)
	if int(unit.natural_energy_current)==0:
		unit.wind_guidance = false
		unit.spirit.active = false
		sim.say("%s’s spirits stop as Natural Energy runs out." % unit.name)
		sim.update_visibility()

static func validate_unit(unit: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not unit.has("wind_contract") and not unit.has("wind_guidance"): return errors
	if not unit.get("wind_contract") is bool: errors.append("Wind contract flag must be boolean.")
	if not unit.get("wind_guidance") is bool: errors.append("Wind Guidance flag must be boolean.")
	if not unit.get("ancestry") is String or unit.ancestry!="fairy" or unit.get("summon",false): errors.append("Wind Spirit requires a Fairy.")
	if not _fire_contract(unit): errors.append("Wind Spirit requires an existing Fire Spirit contract.")
	else:
		for error: String in FireRules.validate_unit(unit): errors.append(error)
	if unit.get("wind_guidance") is bool and unit.wind_guidance:
		if not _has_wind(unit): errors.append("Wind Guidance requires a Wind Spirit contract.")
		if not _positive_energy(unit): errors.append("Active Wind Guidance requires Natural Energy.")
	# Equipment is deliberately not validated here: a saved contract remains
	# valid after swapping weapons, while attack_bonus rechecks eligibility.
	return errors

static func _eligible(unit: Dictionary, items: Dictionary) -> bool:
	return _living_fairy(unit) and _fire_contract(unit) and _has_wind(unit) and unit.get("wind_guidance") is bool and unit.wind_guidance and _positive_energy(unit) and _ranged(unit,items)

static func _has_wind(unit: Dictionary) -> bool:
	return unit.get("wind_contract") is bool and unit.wind_contract

static func _fire_contract(unit: Dictionary) -> bool:
	return unit.get("spirit") is Dictionary and unit.spirit.get("element") is String and unit.spirit.element=="fire" and unit.spirit.get("active") is bool

static func _living_fairy(unit: Dictionary) -> bool:
	return not unit.is_empty() and unit.get("ancestry") is String and unit.ancestry=="fairy" and unit.get("team","ally")=="ally" and unit.get("hp",0)>0 and not unit.get("dead",false) and not unit.get("summon",false)

static func _ranged(unit: Dictionary, items: Dictionary) -> bool:
	var equipment: Variant = unit.get("equipment",{})
	if not equipment is Dictionary: return false
	var weapon_id: Variant = equipment.get("weapon","")
	if not weapon_id is String: return false
	var weapon: Variant = items.get(weapon_id,{})
	return weapon is Dictionary and weapon.get("weapon_style") is String and weapon.weapon_style=="ranged"

static func _positive_energy(unit: Dictionary) -> bool:
	return _integer(unit.get("natural_energy_current")) and float(unit.natural_energy_current)>0 and float(unit.natural_energy_current)<=FireRules.MAX_ENERGY

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
