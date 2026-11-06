class_name SpiritRules
extends RefCounted
## First Fire Spirit contract, a deliberately provisional acquisition route.
## Early novel chapters10–12 establish sustained illumination around ten hours
## and roughly two hours of spirit rest. The lesson,120-stone price,3 days,
##20-point capacity,+3 sight within6 tiles and30-minute drain are reconstruction
## choices authorized for unspecified mechanics, not verified novel rules.
## Natural Energy stays separate from Soul Power, mana, essences and Light.
const INTERVAL: int = 30
const LESSON_COST: int = 120
const LESSON_DAYS: int = 3
const INITIAL_CAPACITY: int = 20
const REST_MINUTES: int = 120
const LIGHT_BONUS: int = 3
const LIGHT_DISTANCE: int = 6
const MAX_ENERGY: int = 1000000

static func form_contract(sim: RefCounted, unit_id: String = "hero") -> String:
	if sim.state.get("mode","")!="city": return "Seek spirit instruction in the city."
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_fairy(unit): return "Choose a living Fairy."
	if unit.has("spirit"): return "This Fairy already has a spirit contract."
	if int(sim.state.get("gold",0))<LESSON_COST: return "Need %d stones." % LESSON_COST
	if not unit.get("base_stats",{}) is Dictionary: return "Invalid base statistics."
	var candidate: Dictionary = unit.duplicate(true)
	candidate["base_stats"] = unit.get("base_stats",{}).duplicate(true)
	candidate.base_stats["natural_energy"] = INITIAL_CAPACITY
	var resolved: Dictionary = sim.stat_breakdown(candidate)
	if not resolved.errors.is_empty(): return "Invalid spirit statistics."
	var capacity: int = clampi(floori(float(resolved.values.get("natural_energy",0))),0,MAX_ENERGY)
	sim.state.gold -= LESSON_COST
	unit["base_stats"] = candidate.base_stats
	unit["spirit"] = {"element":"fire","active":false}
	unit["natural_energy_current"] = capacity
	sim.recalculate(unit,false)
	sim.advance_city_days(LESSON_DAYS)
	sim.journal("First Fire Spirit contract", "%s completes a provisional spirit lesson. Acquisition,120 stones,3 days,20 Natural Energy and the light/drain conversion are reconstruction choices; no Spirit Stone or essence is granted." % unit.name)
	sim.say("%s forms a Fire Spirit contract." % unit.name)
	return ""

static func toggle(sim: RefCounted, unit_id: String = "hero") -> String:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_fairy(unit) or not _contract(unit): return "Choose a living Fairy with a Fire Spirit contract."
	if sim.unable_to_act(unit): return "Cannot direct the spirit while unable to act."
	if bool(unit.spirit.active):
		unit.spirit.active = false
		sim.say("%s rests the Fire Spirit." % unit.name)
	else:
		if float(unit.get("natural_energy_current",0))<=0: return "The spirit needs rest to restore Natural Energy."
		unit.spirit.active = true
		sim.say("%s calls on the Fire Spirit’s light." % unit.name)
	if sim.state.get("mode","")=="dungeon": sim.update_visibility()
	return ""

static func visibility_bonus(sim: RefCounted, observer: Dictionary) -> int:
	if sim.state.get("mode","")!="dungeon" or observer.get("hp",0)<=0: return 0
	for unit: Dictionary in sim.allies():
		if not _living_fairy(unit) or not _contract(unit) or not bool(unit.spirit.active) or float(unit.get("natural_energy_current",0))<=0: continue
		if sim.distance(observer.pos,unit.pos)<=LIGHT_DISTANCE: return LIGHT_BONUS
	return 0

static func advance_tick(sim: RefCounted) -> void:
	# Called exactly once by the simulation for each30-minute world deadline.
	if sim.state.get("mode","")!="dungeon": return
	var changed: bool = false
	for unit: Dictionary in sim.allies():
		if not _contract(unit) or not bool(unit.spirit.active): continue
		if not _living_fairy(unit):
			unit.spirit.active = false
			if unit.has("wind_guidance"): unit.wind_guidance = false
			changed = true
			continue
		unit["natural_energy_current"] = maxi(0,int(unit.get("natural_energy_current",0))-1)
		if int(unit.natural_energy_current)==0:
			unit.spirit.active = false
			if unit.has("wind_guidance"): unit.wind_guidance = false
			changed = true
			sim.say("%s’s Fire Spirit runs out of Natural Energy and rests." % unit.name)
	if changed: sim.update_visibility()

static func rest(sim: RefCounted, unit_id: String = "hero") -> String:
	if sim.state.get("mode","")!="dungeon" or sim.state.get("combat",false): return "Rest the spirit outside combat in the Labyrinth."
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if not _living_fairy(unit) or not _contract(unit): return "Choose a living Fairy with a Fire Spirit contract."
	if sim.unable_to_act(unit): return "Cannot begin spirit rest while unable to act."
	unit.spirit.active = false
	if unit.has("wind_guidance"): unit.wind_guidance = false
	sim.update_visibility()
	sim.advance_time(REST_MINUTES)
	# Portal closure, defeat and time hazards happen before restoration.
	if sim.state.get("mode","")!="dungeon": return "The expedition ended before the spirit finished resting."
	unit = sim.unit_by_id(unit_id)
	if not _living_fairy(unit) or not _contract(unit): return "The Fairy could not complete spirit rest."
	unit["natural_energy_current"] = clampi(floori(float(sim.stat_value(unit,"natural_energy"))),0,MAX_ENERGY)
	sim.say("%s’s Fire Spirit rests two hours and restores Natural Energy." % unit.name)
	return ""

static func validate_unit(unit: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not unit.has("spirit"):
		if unit.has("natural_energy_current"): errors.append("Natural Energy resource requires a spirit contract.")
		return errors
	if not unit.get("ancestry") is String or unit.ancestry!="fairy" or unit.get("summon",false): errors.append("Only a Fairy can own this spirit contract.")
	var spirit: Variant = unit.spirit
	if not spirit is Dictionary: errors.append("Spirit contract must be an object.")
	else:
		if not spirit.get("element") is String or spirit.element!="fire": errors.append("Unsupported spirit element.")
		if not spirit.get("active") is bool: errors.append("Spirit active flag must be boolean.")
		for key: Variant in spirit:
			if key not in ["element","active"]: errors.append("Unknown spirit contract field.")
	var energy: Variant = unit.get("natural_energy_current")
	if not (energy is int or energy is float) or not is_finite(float(energy)) or float(energy)!=floorf(float(energy)) or float(energy)<0 or float(energy)>MAX_ENERGY: errors.append("Invalid current Natural Energy.")
	elif spirit is Dictionary and spirit.get("active") is bool and spirit.active and float(energy)<=0: errors.append("An exhausted spirit cannot remain active.")
	return errors

static func _contract(unit: Dictionary) -> bool:
	return unit.get("spirit") is Dictionary and unit.spirit.get("element") is String and unit.spirit.element=="fire" and unit.spirit.get("active") is bool

static func _living_fairy(unit: Dictionary) -> bool:
	return not unit.is_empty() and unit.get("ancestry","")=="fairy" and unit.get("team","ally")=="ally" and unit.get("hp",0)>0 and not unit.get("dead",false) and not unit.get("summon",false)
