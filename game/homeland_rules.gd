class_name HomelandRules
extends RefCounted
## Homeland visits remain part of the same city campaign, inventory and party.
## Universal visitor access, authored NPCs, map routes and activity bookkeeping
## are explicit reconstruction choices, not established novel entry rights.
## The catalog carries source-backed setting details. Existing campaign APIs
## retain authority over racial eligibility, price, materials and permanent rites.
## Interact describes charged/permanent actions; only perform commits them.
const Catalog = preload("res://game/homeland_catalog.gd")
const ACTIONS: Array[String] = ["coming_of_age","dragon_blessing","undying","skadia","spirit_lesson","spirit_stone","wind_guidance","magic_assess","magic_study","dragon_fear","rest","repair","training"]
const RACIAL_ACTIONS: Dictionary = {"coming_of_age":"barbarian","dragon_blessing":"draconian","undying":"barbarian","skadia":"beastman","spirit_lesson":"fairy","spirit_stone":"fairy","wind_guidance":"fairy","magic_assess":"human","magic_study":"human","dragon_fear":"draconian"}
const ALIASES: Dictionary = {"purchase_undying":"undying","learn_undying":"undying","awaken_skadia":"skadia","form_spirit_contract":"spirit_lesson","attempt_spirit_stone":"spirit_stone","toggle_wind_guidance":"wind_guidance","assess_magic":"magic_assess","study_magic":"magic_study","set_dragon_fear":"dragon_fear"}

static func ensure_state(sim: RefCounted) -> void:
	if str(sim.state.get("mode",""))!="city": return
	if not sim.state.has("homeland"):
		sim.state["homeland"] = {"location":"","selected":"hero","visited":[],"discoveries":[],"used":{}}
	elif sim.state.homeland is Dictionary:
		var unit: Dictionary = sim.unit_by_id(str(sim.state.homeland.get("selected","hero")))
		if not _living_ally(unit): sim.state.homeland["selected"] = "hero"

static func enter(sim: RefCounted, ancestry: String) -> String:
	if str(sim.state.get("mode",""))!="city": return "Visit a homeland from Rafdonia."
	if not Catalog.definitions().has(ancestry): return "Unknown homeland."
	ensure_state(sim)
	if not validate(sim.state).is_empty(): return "Invalid homeland visit state."
	sim.state.homeland.location = ancestry
	if not sim.state.homeland.visited.has(ancestry):
		sim.state.homeland.visited.append(ancestry)
		var entry: Dictionary = Catalog.definitions()[ancestry]
		sim.journal("Homeland: "+str(entry.name),str(entry.description)+" Visitor access and the present walking map are provisional reconstruction choices.")
	sim.say("Entered %s." % Catalog.definitions()[ancestry].name)
	return ""

static func leave(sim: RefCounted) -> String:
	if str(sim.state.get("mode",""))!="city": return "Return to Rafdonia first."
	if not sim.state.has("homeland"): return ""
	if not sim.state.homeland is Dictionary: return "Invalid homeland visit state."
	sim.state.homeland["location"] = ""
	sim.state.homeland["selected"] = "hero"
	return ""

static func select_actor(sim: RefCounted, unit_id: String) -> String:
	if str(sim.state.get("mode",""))!="city": return "Select a homeland visitor in the city."
	if not _living_ally(sim.unit_by_id(unit_id)): return "Choose a living active party member."
	ensure_state(sim)
	if not sim.state.homeland is Dictionary: return "Invalid homeland visit state."
	sim.state.homeland["selected"] = unit_id
	return ""

static func interact(sim: RefCounted, point_id: String, unit_id: String = "hero") -> Dictionary:
	var access: String = _access(sim,unit_id)
	if not access.is_empty(): return _result(false,access)
	var point: Dictionary = _point(str(sim.state.homeland.location),point_id)
	if point.is_empty(): return _result(false,"This point is not in the visited homeland.")
	var action: String = _action(str(point.get("action","lore")))
	var unit: Dictionary = sim.unit_by_id(unit_id)
	var line: String = str(point.get("message",point.get("line","")))
	if action=="return":
		return {"ok":true,"message":line,"open":"city","action":"return","confirm":false,"point_id":point_id,"unit_id":unit_id}
	if action in ["lore","artifact_blessing"]:
		if action=="artifact_blessing": line += " Dwarves extend Guardian’s Braces protection duration by1.5×. Its passive remains5%; ordinary gear gains no universal blessing. Repairs are a separate paid service."
		_discover(sim,point_id,point,line)
		return {"ok":true,"message":line,"open":"numbered" if action=="artifact_blessing" else "lore","point_id":point_id,"unit_id":unit_id,"reference_urls":point.get("reference_urls",[])}
	if action not in ACTIONS: return _result(false,"This activity is not available.")
	var racial: String = _race_access(action,unit)
	if not racial.is_empty(): return _result(false,line+" "+racial)
	if action in ["coming_of_age","dragon_blessing"]: return {"ok":true,"message":line,"open":"choices","action":action,"point_id":point_id,"unit_id":unit_id}
	var response: Dictionary = {"ok":true,"message":line+"\n\n"+_confirmation(sim,action,unit),"action":action,"confirm":true,"point_id":point_id,"unit_id":unit_id}
	return response

static func perform(sim: RefCounted, action_id: String, unit_id: String = "hero", point_id: String = "", choice_id: String = "") -> Dictionary:
	var access: String = _access(sim,unit_id)
	if not access.is_empty(): return _result(false,access)
	var action: String = _action(action_id)
	if not point_id.is_empty():
		var offered: Dictionary = _point(str(sim.state.homeland.location),point_id)
		if offered.is_empty() or _action(str(offered.get("action","")))!=action: return _result(false,"The confirmed point or activity is no longer available here.")
	if not _available(str(sim.state.homeland.location),action): return _result(false,"This action is not offered in the visited homeland.")
	if action=="return": return _result(leave(sim).is_empty(),"Returned to Rafdonia.")
	if action not in ACTIONS: return _result(false,"This point is an observation, not a rite.")
	var unit: Dictionary = sim.unit_by_id(unit_id)
	var racial: String = _race_access(action,unit)
	if not racial.is_empty(): return _result(false,racial)
	var failure: String = ""
	match action:
		"coming_of_age": failure = ComingOfAgeRules.choose(sim,unit_id,choice_id)
		"dragon_blessing": failure = DragonBlessingRules.inscribe(sim,unit_id,choice_id)
		"undying": failure = sim.learn_undying(unit_id)
		"skadia": failure = sim.awaken_skadia(unit_id)
		"spirit_lesson": failure = sim.form_spirit_contract(unit_id)
		"spirit_stone": failure = sim.attempt_spirit_stone(unit_id)
		"wind_guidance": failure = sim.toggle_wind_guidance(unit_id)
		"magic_assess": failure = sim.assess_magic(unit_id)
		"magic_study": failure = sim.study_magic(unit_id)
		"dragon_fear": failure = sim.set_dragon_fear(not bool(unit.get("dragon_fear_enabled",true)),unit_id)
		"rest","repair": failure = sim.city_service(action)
		"training": failure = sim.city_service("rest")
	if not failure.is_empty(): return _result(false,failure)
	var key: String = str(sim.state.homeland.location)+":"+action+":"+unit_id
	sim.state.homeland.used[key] = mini(1000000,int(sim.state.homeland.used.get(key,0))+1)
	return {"ok":true,"message":"%s completed for %s." % [action.replace("_"," "),unit.name],"action":action,"unit_id":unit_id}

static func validate(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("homeland"): return errors
	if not state.homeland is Dictionary: errors.append("Homeland state must be an object."); return errors
	var home: Dictionary = state.homeland
	var definitions: Dictionary = Catalog.definitions()
	if not home.get("location") is String or (not str(home.get("location","")).is_empty() and not definitions.has(home.get("location"))): errors.append("Unknown homeland location.")
	if home.get("location") is String and not home.location.is_empty() and str(state.get("mode",""))!="city": errors.append("An active homeland visit requires city mode.")
	if not home.get("selected") is String or str(home.get("selected","")).is_empty() or str(home.get("selected","")).length()>128: errors.append("Invalid selected homeland actor.")
	elif home.get("location") is String and not home.location.is_empty():
		var selected: bool = false
		var active: Array = [state.get("hero",{})]
		if state.get("party") is Array: active.append_array(state.party)
		for unit: Variant in active:
			if unit is Dictionary and unit.get("id") is String and unit.id==home.selected and _living_ally(unit): selected = true
		if not selected: errors.append("Selected homeland actor must be a living active ally.")
	for field: String in ["visited","discoveries"]:
		if not home.get(field) is Array: errors.append("Homeland "+field+" must be an array."); continue
		var seen: Dictionary = {}
		if home[field].size()>(definitions.size() if field=="visited" else 512): errors.append("Too many homeland "+field+" entries.")
		for value: Variant in home[field]:
			if not value is String: errors.append("Invalid homeland "+field+" ID."); continue
			if seen.has(value): errors.append("Duplicate homeland "+field+" ID.")
			seen[value] = true
			if field=="visited" and not definitions.has(value): errors.append("Unknown visited homeland.")
			if field=="discoveries" and not _known_discovery(value): errors.append("Unknown homeland discovery.")
	if home.get("location") is String and not home.location.is_empty() and home.get("visited") is Array and not home.visited.has(home.location): errors.append("Active homeland must be recorded as visited.")
	if not home.get("used") is Dictionary: errors.append("Homeland usage must be an object.")
	else:
		if home.used.size()>4096: errors.append("Too many homeland usage entries.")
		for key: Variant in home.used:
			if not key is String or not _known_usage(key): errors.append("Unknown homeland action history.")
			var value: Variant = home.used[key]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or float(value)<0 or float(value)>1000000: errors.append("Invalid homeland usage count.")
	if home.has("positions"):
		if not home.positions is Dictionary: errors.append("Homeland positions must be an object.")
		else:
			for id: Variant in home.positions:
				var position: Variant = home.positions[id]
				if not definitions.has(id) or not position is Vector2i or position.x<0 or position.y<0 or position.x>=38 or position.y>=17: errors.append("Invalid homeland map position.")
	for key: Variant in home:
		if key not in ["location","selected","visited","discoveries","used","positions"]: errors.append("Unknown homeland state field.")
	return errors

static func _access(sim: RefCounted, unit_id: String) -> String:
	if str(sim.state.get("mode",""))!="city": return "Homeland activities require city access."
	if not sim.state.get("homeland") is Dictionary or str(sim.state.homeland.get("location","")).is_empty(): return "Enter a homeland first."
	if not validate(sim.state).is_empty(): return "Invalid homeland visit state."
	if not _living_ally(sim.unit_by_id(unit_id)): return "Choose a living active party member."
	return ""

static func _race_access(action: String, unit: Dictionary) -> String:
	if RACIAL_ACTIONS.has(action) and (not unit.get("ancestry") is String or unit.ancestry!=RACIAL_ACTIONS[action]): return "This rite requires a "+str(RACIAL_ACTIONS[action]).capitalize()+" participant."
	return ""

static func _confirmation(sim: RefCounted, action: String, unit: Dictionary) -> String:
	match action:
		"undying": return "Confirm permanent Undying I for %s: %d stones. Choosing this engraving path excludes other paths." % [unit.name,sim.UNDYING_SERVICE_COST]
		"skadia": return "Confirm Skadia for %s. The Ring of the Frost Spirit AND ALL WORN EQUIPMENT are destroyed permanently: %s. Initial cold affects bare-handed strikes." % [unit.name,", ".join(sim.skadia_ritual_losses(unit))]
		"spirit_lesson": return "Confirm first Fire Spirit instruction:120 stones and3 city days. Acquisition and costs are provisional. Natural Energy remains separate from mana and Soul Power."
		"spirit_stone": return "Confirm one Spirit Stone attempt: one stone is consumed on success OR failure;10% success. The currently enabled additional affinity is Wind."
		"magic_assess": return "Confirm aptitude assessment:10 stones and3 days. The recorded result cannot be rerolled. Costs and duration are provisional."
		"magic_study": return "Confirm basic magic lessons:600 stones and30 days. This Human becomes a mage, learns Ice Spear, and can no longer absorb essences."
		"dragon_fear": return "Confirm %s Dragon Fear for %s. Suppression affects the existing racial aura; this grants no Dragon Speech." % ["suppressing" if unit.get("dragon_fear_enabled",true) else "releasing",unit.name]
		"wind_guidance": return "Confirm toggling Wind Guidance. Bow shots spend1 shared Natural Energy even on a miss; current Accuracy bonus is an estimated+10."
		"rest": return "Confirm party recovery: %d stones. Restores HP, SP, mana and contracted spirits’ Natural Energy. Active spirits are dismissed." % [6+sim.state.party.size()*3]
		"training": return "Confirm a coached recovery and practice lesson: %d stones. This provisional service uses the existing party rest rules. It restores current resources; it grants no XP or permanent stat increase." % [6+sim.state.party.size()*3]
		"repair": return "Confirm party equipment repair: %d stones. Restores durability using the existing repair service; this does not bless ordinary equipment." % [5+int(sim.state.unlocked)]
	return "Confirm this activity."

static func _discover(sim: RefCounted, point_id: String, point: Dictionary, text: String) -> void:
	var id: String = str(sim.state.homeland.location)+":"+point_id
	if sim.state.homeland.discoveries.has(id): return
	sim.state.homeland.discoveries.append(id)
	sim.journal("Homeland discovery: "+str(point.get("name",point_id)),text)

static func _point(ancestry: String, point_id: String) -> Dictionary:
	for point: Dictionary in Catalog.points(ancestry):
		if point.get("id","")==point_id: return point
	return {}

static func _available(ancestry: String, action: String) -> bool:
	for point: Dictionary in Catalog.points(ancestry):
		if _action(str(point.get("action","")))==action: return true
	return false

static func _action(id: String) -> String:
	return str(ALIASES.get(id,id))

static func _known_discovery(id: String) -> bool:
	var split: PackedStringArray = id.split(":",true,1)
	return split.size()==2 and Catalog.definitions().has(split[0]) and not _point(split[0],split[1]).is_empty()

static func _known_usage(id: String) -> bool:
	var split: PackedStringArray = id.split(":",true,2)
	return split.size()==3 and Catalog.definitions().has(split[0]) and split[1] in ACTIONS and _available(split[0],split[1]) and not split[2].is_empty() and split[2].length()<=128

static func _living_ally(unit: Dictionary) -> bool:
	var health: Variant = unit.get("hp")
	return not unit.is_empty() and unit.get("team") is String and unit.team=="ally" and (health is int or health is float) and is_finite(float(health)) and float(health)>0 and unit.get("dead",false) is bool and not unit.get("dead",false) and unit.get("summon",false) is bool and not unit.get("summon",false)

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
