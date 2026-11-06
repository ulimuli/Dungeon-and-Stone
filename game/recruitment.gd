class_name Recruitment
extends RefCounted
## One deterministic recruitment pool per campaign, saved in state.recruits.
## Presentation RNG is independent of the simulation random stream.
const Names = preload("res://game/adventurer_names.gd")
const Art = preload("res://game/character_art.gd")
const Content = preload("res://game/content.gd")
const IDENTITY_VERSION: int = 1

static func generate(campaign_seed: int) -> Dictionary:
	var result: Dictionary = {}
	var used: Dictionary = {}
	var templates: Dictionary = Content.companions()
	for id: String in templates:
		var offer: Dictionary = templates[id].duplicate(true)
		offer.id = id
		offer.template_id = id
		offer.identity_version = IDENTITY_VERSION
		offer.name = Names.generate(campaign_seed,id,used)
		used[offer.name] = true
		offer.appearance = Art.seeded(str(offer.ancestry),Names.stable_seed("adventurer-look-v1|%d|%s" % [campaign_seed,id]))
		result[id] = offer
	return result

static func for_state(state: Dictionary) -> Dictionary:
	var defaults: Dictionary = generate(int(state.get("seed",0)))
	var saved: Dictionary = state.get("recruits",{}) if state.get("recruits",{}) is Dictionary else {}
	var result: Dictionary = {}
	var used: Dictionary = {}
	# Reserve valid saved names before filling defaults, so repair cannot steal one.
	for id: String in defaults:
		var record: Variant = saved.get(id,{})
		if record is Dictionary and record.get("name") is String and not str(record.name).strip_edges().is_empty(): used[str(record.name)] = true
	var assigned: Dictionary = {}
	for id: String in defaults:
		var offer: Dictionary = defaults[id]
		var record: Dictionary = saved.get(id,{}) if saved.get(id,{}) is Dictionary else {}
		var saved_name: String = str(record.get("name","")) if record.get("name","") is String else ""
		if not saved_name.strip_edges().is_empty() and not assigned.has(saved_name): offer.name = saved_name
		elif used.has(str(offer.name)) or assigned.has(str(offer.name)):
			offer.name = Names.generate(int(state.get("seed",0)),id,used.merged(assigned))
		assigned[offer.name] = true
		if record.get("appearance") is Dictionary:
			var appearance: Dictionary = offer.appearance.duplicate(true)
			for key: String in record.appearance: appearance[key] = record.appearance[key]
			offer.appearance = Art.normalize(appearance,str(offer.ancestry))
		result[id] = offer
	state.recruits = result
	return result.duplicate(true)

static func neutral_id(id: String) -> String:
	return str({"ainar":"barbarian_warrior","erwen":"fairy_archer","hikurod":"dwarf_guard","rotmiller":"human_scout","dwalkie":"human_mage","missha":"beastman_swordsman"}.get(id,id))
