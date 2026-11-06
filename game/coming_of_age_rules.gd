class_name ComingOfAgeRules
extends RefCounted
## A one-time opening equipment choice, not a repeatable gift service.
## The ceremony and weapon choice are sourced; item quality and this opening
## eligibility window are provisional reconstruction rules.
const SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-454/"
static func options() -> Array[String]:
	return ["club","shield","sword","spear","greatsword","battleaxe"]
static func can_choose(sim: RefCounted, unit_id: String, weapon: String) -> String:
	if weapon not in options(): return "Choose a weapon from the ceremony."
	if sim.state.get("mode","")!="city" or sim.state.get("combat",false): return "Return to the sanctuary before the ceremony."
	var unit: Dictionary=sim.unit_by_id(unit_id)
	if unit_id!="hero" or unit.is_empty() or unit.get("ancestry","")!="barbarian" or unit.get("dead",false) or float(unit.get("hp",0))<=0: return "The opening ceremony is for your young Barbarian."
	if sim.state.get("flags",{}).get("coming_of_age_complete",false): return "Your coming-of-age weapon has already been chosen."
	if int(sim.state.get("level",0))!=1 or not sim.state.get("visited_regions",[]).is_empty(): return "The opening ceremony must precede your first expedition."
	if unit.get("equipment",{}).get("weapon","")!="club": return "Wear your starting club to exchange it at the ceremony."
	if not sim.item_defs.has(weapon): return "This weapon is unavailable."
	var item: Dictionary=sim.item_defs[weapon]
	if sim.stat_value(unit,"strength")<int(item.get("str_req",0)) or sim.stat_value(unit,"agility")<int(item.get("agi_req",0)): return "Weapon requirements are not met."
	var projected: float=sim.weight()-float(sim.item_defs.club.weight)+float(item.weight)
	if projected>sim.capacity(): return "Make room for the chosen weapon first."
	return ""
static func choose(sim: RefCounted, unit_id: String, weapon: String) -> String:
	var failure: String=can_choose(sim,unit_id,weapon)
	if not failure.is_empty(): return failure
	var unit: Dictionary=sim.unit_by_id(unit_id)
	# Exchange directly: the original club never becomes saleable pack loot.
	unit.equipment.weapon=weapon
	sim.state.flags["coming_of_age_complete"]=true
	sim.state.flags["coming_of_age_weapon:"+weapon]=true
	sim.recalculate(unit,false)
	sim.journal("Coming of age","Chose %s before the first expedition. Weapon statistics and the opening exchange are provisional; the ceremony is described in chapter454." % sim.item_defs[weapon].name)
	sim.say("%s chooses %s." % [unit.name,sim.item_defs[weapon].name])
	return ""
