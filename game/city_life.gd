class_name CityLife
extends RefCounted
## City service routing and generated adventurer records.
## Unnamed operators are interface representatives, not identified novel people.
## Their ancestry and appearance are provisional visual identities.
## The simulation owns service charges and recruitment transactions.

const Art = preload("res://game/character_art.gd")
const Content = preload("res://game/content.gd")
const SCHEMA_VERSION: int = 2
const NPC_ORDER: Array[String] = ["innkeeper", "guild_clerk", "smith", "appraiser", "herbalist", "tailor", "scout", "cook", "gate_guard", "veteran", "merchant", "scholar"]

static func _operator(role: String, location: String, ancestry: String, seed_value: int, services: Array, opens: Array) -> Dictionary:
	return {"name": role, "role": role, "location": location, "ancestry": ancestry, "seed": seed_value, "services": services, "opens": opens, "provisional_visual_identity": true, "reference_urls": []}

static func _profiles(state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"innkeeper": _operator("Innkeeper", "Inn", "human", 2101, ["rest", "rations", "relief"], []),
		"guild_clerk": _operator("Guild clerk", "Explorers Guild", "human", 2102, [], ["journal", "portal"]),
		"smith": _operator("Blacksmith", "Forge", "dwarf", 2103, ["repair"], ["inventory"]),
		"appraiser": _operator("Appraiser", "Market", "dwarf", 2104, [], ["market", "inventory"]),
		"herbalist": _operator("Apothecary", "Apothecary", "fairy", 2105, [], ["market"]),
		"tailor": _operator("Tailor", "Cloth Shop", "fairy", 2106, [], ["customize"]),
		"scout": _operator("Recruitment desk", "Recruitment", "beastman", 2107, [], ["companions"]),
		"cook": _operator("Food seller", "Food Stall", "beastman", 2108, ["rations"], []),
		"gate_guard": _operator("Portal attendant", "Dimensional Square", "barbarian", 2109, [], ["portal","homelands"]),
		"veteran": _operator("Party desk", "Recruitment", "barbarian", 2110, [], ["companions"]),
		"merchant": _operator("Merchant", "Market", "draconian", 2111, [], ["market", "inventory"]),
		"scholar": _operator("Records desk", "Records Room", "draconian", 2112, [], ["journal", "essences"])
	}
	var companions: Dictionary = Recruitment.for_state(state)
	for id: String in companions:
		var definition: Dictionary = companions[id]
		result["companion_" + id] = {"name": definition.name, "role": "Companion", "location": "Recruitment", "ancestry": definition.ancestry, "seed": 3100 + id.hash(), "services": [], "opens": ["companions"], "companion_id": id, "appearance": definition.get("appearance", {}), "reference_urls": definition.reference_urls.duplicate(), "provisional_visual_identity": true}
	return result

static func _appearance(profile: Dictionary) -> Dictionary:
	var appearance: Dictionary = Art.seeded(str(profile.ancestry), int(profile.seed))
	for key: String in profile.get("appearance", {}): appearance[key] = profile.appearance[key]
	return Art.normalize(appearance, str(profile.ancestry), int(profile.seed))

static func ensure_state(state: Dictionary) -> void:
	var previous: Dictionary = state.get("city_life", {}) if state.get("city_life", {}) is Dictionary else {}
	var saved_npcs: Dictionary = previous.get("npcs", {}) if previous.get("npcs", {}) is Dictionary else {}
	var profiles: Dictionary = _profiles(state)
	var npcs: Dictionary = {}
	for id: String in profiles:
		var profile: Dictionary = profiles[id]
		var npc: Dictionary = {"id": id}
		for key: String in ["name", "role", "location", "ancestry", "provisional_visual_identity", "reference_urls", "companion_id"]:
			if profile.has(key): npc[key] = profile[key]
		var saved: Dictionary = saved_npcs.get(id, {}) if saved_npcs.get(id, {}) is Dictionary else {}
		# Only cosmetic presentation is restored; service authorization comes from code.
		npc.appearance = _appearance(profile)
		if not profile.has("companion_id") and saved.get("appearance", {}) is Dictionary and not saved.get("appearance", {}).is_empty():
			var combined: Dictionary = npc.appearance.duplicate(true)
			for key: String in saved.appearance: combined[key] = saved.appearance[key]
			npc.appearance = Art.normalize(combined, str(profile.ancestry), int(profile.seed))
		npcs[id] = npc
	state.city_life = {"version": SCHEMA_VERSION, "npcs": npcs}

static func roster(state: Dictionary) -> Array[Dictionary]:
	ensure_state(state)
	var result: Array[Dictionary] = []
	for npc: Dictionary in state.city_life.npcs.values():
		var companion: String = str(npc.get("companion_id", ""))
		if not companion.is_empty() and (state.get("roster", []).has(companion) or state.get("fallen_ids", []).has(companion)): continue
		result.append(npc.duplicate(true))
	return result

static func tasks(state: Dictionary) -> Array[Dictionary]:
	ensure_state(state)
	return []

static func market_discount(_state: Dictionary, _npc_id: String) -> int:
	return 0

static func dialogue(state: Dictionary, npc_id: String) -> Dictionary:
	ensure_state(state)
	var profiles: Dictionary = _profiles(state)
	if not profiles.has(npc_id): return {"name": "Unavailable", "line": "", "choices": []}
	var profile: Dictionary = profiles[npc_id]
	var npc: Dictionary = state.city_life.npcs[npc_id]
	var choices: Array[Dictionary] = []
	for service: String in profile.services:
		choices.append({"id": "service:" + service, "label": {"rest": "Rest", "rations": "Buy food", "relief": "Relief work", "repair": "Repair equipment"}.get(service, service), "service": service})
	for open_id: String in profile.opens:
		choices.append({"id": "open:" + open_id, "label": {"market": "Browse goods", "companions": "View recruitment", "essences": "Inspect essences", "inventory": "Inspect equipment", "journal": "Open journal", "customize": "Change appearance", "portal": "Prepare for the Labyrinth", "homelands":"Visit the racial lands"}.get(open_id, open_id), "open": open_id})
	choices.append({"id": "leave", "label": "Close"})
	return {"name": npc.name, "line": "Recruitment" if profile.has("companion_id") else "Available services", "choices": choices, "location": npc.location, "appearance": npc.appearance.duplicate(true), "market_discount_percent": 0}

static func interact(state: Dictionary, npc_id: String, choice_id: String) -> Dictionary:
	if str(state.get("mode", "")) != "city": return {"ok": false, "message": "Return to Rafdonia first."}
	ensure_state(state)
	var profiles: Dictionary = _profiles(state)
	if not profiles.has(npc_id): return {"ok": false, "message": "Service unavailable."}
	var profile: Dictionary = profiles[npc_id]
	if choice_id == "leave": return {"ok": true, "message": ""}
	if choice_id.begins_with("service:"):
		var service: String = choice_id.trim_prefix("service:")
		if not profile.services.has(service): return {"ok": false, "message": "Service unavailable here."}
		return {"ok": true, "message": "", "service": service}
	if choice_id.begins_with("open:"):
		var open_id: String = choice_id.trim_prefix("open:")
		if not profile.opens.has(open_id): return {"ok": false, "message": "Service unavailable here."}
		var result: Dictionary = {"ok": true, "message": "", "open": open_id, "market_discount_percent": 0}
		if profile.has("companion_id"): result.companion_id = profile.companion_id
		return result
	return {"ok": false, "message": "Choice unavailable."}
