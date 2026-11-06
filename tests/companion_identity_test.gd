extends SceneTree
## Assisted simulation integration; creates no player-save files.
const Simulation = preload("res://game/simulation.gd")
const RecruitmentData = preload("res://game/recruitment.gd")
const City = preload("res://game/city_life.gd")
const Content = preload("res://game/content.gd")
const Art = preload("res://game/character_art.gd")
const Validator = preload("res://game/save_validation.gd")
const RACES: Array[String] = ["barbarian","beastman","draconian","dwarf","fairy","human"]
const ATTRIBUTED_NAMES: Array[String] = ["Ainar Fenelin","Erwen Fornacci di Tersia","Hikurod Murad","Brown Rotmiller","Riol Warb Dwalkie","Missha Karlstein"]
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh(seed_value: int = 74119) -> GameSimulation:
	var sim: GameSimulation = Simulation.new()
	sim.new_campaign("Identity fixture","human","adventurer",seed_value)
	sim.state.gold = 10000
	return sim

func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var encoded: Dictionary = sim.snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(encoded))
	check(parsed is Dictionary,label + ": snapshot survives JSON")
	var restored: GameSimulation = Simulation.new()
	check(restored.restore(parsed),label + ": validated simulation restore succeeds")
	return restored

func _initialize() -> void:
	_test_campaign_pool_and_rng()
	_test_recruit_save_dismiss()
	_test_customized_identity()
	_test_permanent_death()
	_test_mage_absorption()
	_test_identity_migration()
	_test_benched_build_and_resources()
	_test_malformed_benched_units()
	_test_template_mage_save_restriction()
	for failure: String in failures: push_error(failure)
	print("COMPANION IDENTITY TEST: %d checks; %d failures. Generated campaign/city/recruit identities, JSON saves, death and mage restrictions; assisted fixtures, no player saves." % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_pool(sim: GameSimulation, expected: Dictionary, label: String) -> void:
	check(sim.companion_defs.size() == 12,label + ": twelve offers")
	check(sim.state.get("recruits",{}) is Dictionary,label + ": saved pool exists")
	check(same(sim.companion_defs,expected),label + ": offer view preserves full identity/template data")
	for id: String in expected:
		if not sim.companion_defs.has(id) or not sim.state.get("recruits",{}).has(id):
			check(false,label + ": missing persisted offer " + id)
			continue
		var actual: Dictionary = sim.companion_defs[id]
		check(actual.name == expected[id].name,label + ": name stable " + id)
		check(same(actual.appearance,expected[id].appearance),label + ": appearance stable " + id)
		check(sim.state.recruits[id].name == actual.name and same(sim.state.recruits[id].appearance,actual.appearance),label + ": saved identity matches offer " + id)

func _check_city(sim: GameSimulation, expected: Dictionary, label: String) -> void:
	var roster: Array[Dictionary] = City.roster(sim.state)
	var visible: Dictionary = {}
	for npc: Dictionary in roster:
		if npc.has("companion_id"): visible[str(npc.companion_id)] = npc
	var available: int = 0
	var saved: Dictionary = sim.state.city_life.npcs
	for id: String in expected:
		var blocked: bool = sim.state.get("roster",[]).has(id) or sim.state.get("fallen_ids",[]).has(id)
		if not blocked: available += 1
		check(visible.has(id) != blocked,label + ": map includes only available recruit " + id)
		var npc_id: String = "companion_" + id
		if not saved.has(npc_id):
			check(false,label + ": missing saved city identity " + id)
			continue
		var npc: Dictionary = saved[npc_id]
		check(npc.name == expected[id].name,label + ": city name matches offer " + id)
		check(npc.ancestry == expected[id].ancestry,label + ": city race matches offer " + id)
		check(same(npc.appearance,expected[id].appearance),label + ": city appearance matches offer " + id)
		var dialogue: Dictionary = City.dialogue(sim.state,str(npc.id))
		check(dialogue.name == npc.name and same(dialogue.appearance,npc.appearance),label + ": interactive city panel uses the same identity " + id)
	check(visible.size() == available,label + ": visible city recruit count matches availability")

func _test_campaign_pool_and_rng() -> void:
	for seed_value: int in [0,17,74119,-13]:
		var sim: GameSimulation = fresh(seed_value)
		var pool: Dictionary = sim.companion_defs.duplicate(true)
		check(pool.size() == 12,"Campaign has twelve offers")
		var names: Dictionary = {}
		var races: Dictionary = {}
		for id: String in pool:
			var offer: Dictionary = pool[id]
			check(not str(offer.name).strip_edges().is_empty(),"Generated personal name present " + id)
			check(not names.has(offer.name),"Generated personal names are unique within campaign " + id)
			check(not ATTRIBUTED_NAMES.has(str(offer.name)),"Offer uses an original generated identity " + id)
			check(str(offer.name) != str(Content.companions()[id].name),"Generated personal name replaces role label " + id)
			names[offer.name] = true
			races[offer.ancestry] = int(races.get(offer.ancestry,0)) + 1
		check(races.size() == 6,"Every race represented")
		for race: String in RACES: check(int(races.get(race,0)) == 2,"Exactly two generated recruits per race " + race)
		var untouched_rng: int = sim.rng.state
		sim.ensure_city_state()
		RecruitmentData.for_state(sim.state)
		_check_city(sim,pool,"Fresh city")
		check(sim.rng.state == untouched_rng,"Recruit/city identity work leaves simulation RNG unchanged")
		_check_pool(sim,pool,"Repeated query")
		var restored: GameSimulation = roundtrip(sim,"Pool")
		if restored.state.is_empty(): continue
		check(restored.rng.state == untouched_rng,"Restore keeps exact simulation RNG state")
		_check_pool(restored,pool,"Restored pool")
		_check_city(restored,pool,"Restored city")
		var twin: GameSimulation = fresh(seed_value)
		check(same(twin.companion_defs,pool),"Same seed produces same full recruit identities")
	check(not same(fresh(18).companion_defs,fresh(19).companion_defs),"Different campaign seeds vary generated identities")

func _test_recruit_save_dismiss() -> void:
	var sim: GameSimulation = fresh()
	var pool: Dictionary = sim.companion_defs.duplicate(true)
	for id: String in pool:
		var rng_before: int = sim.rng.state
		check(sim.recruit(id).is_empty(),"Generated recruit transaction succeeds " + id)
		var unit: Dictionary = sim.unit_by_id("comp_" + id)
		if unit.is_empty():
			check(false,"Recruited unit exists " + id)
			continue
		check(unit.name == pool[id].name and unit.ancestry == pool[id].ancestry,"Hired identity matches displayed offer " + id)
		check(same(unit.appearance,pool[id].appearance),"Hired appearance matches displayed offer " + id)
		check(sim.rng.state == rng_before,"Recruitment cosmetics do not consume combat RNG " + id)
		var restored: GameSimulation = roundtrip(sim,"Hired " + id)
		if restored.state.is_empty(): continue
		var saved_unit: Dictionary = restored.unit_by_id("comp_" + id)
		check(not saved_unit.is_empty() and saved_unit.get("name","") == unit.name,"Hired name persists through full restore " + id)
		check(same(saved_unit.get("appearance",{}),unit.appearance),"Hired appearance persists through full restore " + id)
		restored.dismiss("comp_" + id)
		check(restored.state.party.is_empty() and not restored.state.roster.has(id),"Dismissal frees party slot " + id)
		restored.ensure_city_state()
		check(restored.companion_defs[id].name == pool[id].name,"Dismissal cannot reroll a generated name " + id)
		check(restored.recruit(id).is_empty(),"Same living identity can rejoin " + id)
		var returned: Dictionary = restored.unit_by_id("comp_" + id)
		check(returned.get("name","") == unit.name and same(returned.get("appearance",{}),unit.appearance),"Rejoined identity is unchanged " + id)
		sim.dismiss("comp_" + id)
	_check_city(sim,pool,"All dismissal paths")

func _test_customized_identity() -> void:
	var sim: GameSimulation = fresh()
	var id: String = "fairy_archer"
	check(sim.recruit(id).is_empty(),"Cosmetic identity fixture recruits")
	var unit: Dictionary = sim.unit_by_id("comp_" + id)
	if unit.is_empty(): return
	var name_before: String = str(unit.name)
	var changed: Dictionary = unit.appearance.duplicate(true)
	changed.hair_color = "gold" if changed.hair_color != "gold" else "black"
	check(sim.customize(str(unit.id),changed).is_empty(),"Companion cosmetic edit succeeds")
	var expected: Dictionary = Art.normalize(changed,str(unit.ancestry))
	check(same(sim.state.recruits[id].appearance,expected),"Cosmetic edit updates persistent recruitment identity")
	_check_city(sim,sim.companion_defs,"Customized city")
	var restored: GameSimulation = roundtrip(sim,"Customized identity")
	if restored.state.is_empty(): return
	restored.dismiss("comp_" + id)
	check(restored.recruit(id).is_empty(),"Customized companion rejoins")
	var rejoined: Dictionary = restored.unit_by_id("comp_" + id)
	check(rejoined.get("name","") == name_before,"Customization never changes personal identity")
	check(same(rejoined.get("appearance",{}),expected),"Cosmetic edit survives save/dismiss/recruit")

func _test_permanent_death() -> void:
	var sim: GameSimulation = fresh()
	var id: String = "dwarf_guard"
	check(sim.recruit(id).is_empty(),"Death fixture recruits")
	var unit: Dictionary = sim.unit_by_id("comp_" + id)
	if unit.is_empty(): return
	var original: Dictionary = sim.companion_defs[id].duplicate(true)
	unit.hp = 0
	sim.on_death(unit,sim.hero())
	check(unit.dead and sim.state.fallen.has(original.name),"Generated companion death records identity")
	sim.dismiss(str(unit.id))
	check(not sim.recruit(id).is_empty(),"Dismissal cannot resurrect a dead generated recruit")
	check(sim.companion_defs[id].name == original.name and same(sim.companion_defs[id].appearance,original.appearance),"Death cannot reroll blocked identity")
	var restored: GameSimulation = roundtrip(sim,"Dead identity")
	if restored.state.is_empty(): return
	check(not restored.recruit(id).is_empty(),"Death blocks recruitment after full save restore")
	check(restored.companion_defs[id].name == original.name,"Dead personal name remains stable after restore")

func _test_mage_absorption() -> void:
	var sim: GameSimulation = fresh()
	var id: String = "human_mage"
	check(sim.recruit(id).is_empty(),"Mage fixture recruits")
	var mage: Dictionary = sim.unit_by_id("comp_" + id)
	if mage.is_empty(): return
	check(mage.get("profession","") == "mage" and not mage.get("can_absorb_essences",true),"Generated mage retains profession restriction")
	check(sim.essence_capacity(mage) == 0,"Wizard essence capacity is zero")
	check(mage.essences.is_empty() and mage.spells.has("ice_spear"),"Wizard uses a spell rather than an essence-granted spell")
	check(sim.enter_region(1),"Mage fixture enters actual dungeon")
	sim.state.units = []
	sim.state.combat = false
	mage.pos = sim.hero().pos
	var essence_id: String = "canon_goblin"
	sim.state.essence_drops = [{"id":essence_id,"pos":mage.pos,"region":int(sim.state.region),"expires_at":int(sim.state.time)+30}]
	sim.state.loot_essences = {essence_id:1}
	var failure: String = sim.absorb(essence_id,str(mage.id))
	check(not failure.is_empty(),"Mage absorption is rejected")
	check(mage.essences.is_empty() and sim.state.essence_drops.size() == 1 and int(sim.state.loot_essences.get(essence_id,0)) == 1,"Rejected mage absorption preserves loose essence and empty slots")
	check(sim.absorb(essence_id).is_empty(),"Same nearby drop is valid for a martial explorer")
	check(sim.hero().essences.has(essence_id),"Martial explorer acquires the real field essence")
	var restored: GameSimulation = roundtrip(sim,"Mage profession")
	if restored.state.is_empty(): return
	var saved_mage: Dictionary = restored.unit_by_id("comp_" + id)
	check(not saved_mage.is_empty() and restored.essence_capacity(saved_mage) == 0 and saved_mage.get("profession","") == "mage","Wizard restriction survives saved identity restore")

func _test_identity_migration() -> void:
	var sim: GameSimulation = fresh()
	if not sim.has_method("_migrate_companion_ids"):
		print("COMPANION IDENTITY: saved-ID migration not implemented; no migration coverage claimed")
		return
	check(sim.recruit("human_mage").is_empty(),"Saved-ID migration fixture recruits")
	var encoded: Dictionary = sim.snapshot()
	encoded.party[0].id = "comp_dwalkie"
	encoded.party[0].content_id = "dwalkie"
	encoded.roster = ["dwalkie"]
	encoded.selected = "comp_dwalkie"
	var restored: GameSimulation = Simulation.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(encoded))),"Prior companion ID restores through migration")
	if restored.state.is_empty(): return
	var mage: Dictionary = restored.unit_by_id("comp_human_mage")
	check(not mage.is_empty() and mage.get("content_id","") == "human_mage","Prior companion ID becomes neutral persistent ID")
	check(restored.state.roster == ["human_mage"] and restored.state.selected == "comp_human_mage","Migration updates roster and selected unit references")
	check(mage.get("name","") == restored.companion_defs.human_mage.name and not ATTRIBUTED_NAMES.has(str(mage.get("name",""))),"Migrated character receives its campaign-generated identity")

func _test_benched_build_and_resources() -> void:
	for id: String in ["human_scout", "human_mage"]:
		var sim: GameSimulation = fresh()
		check(sim.recruit(id).is_empty(), "Bench fixture recruits " + id)
		var unit: Dictionary = sim.unit_by_id("comp_" + id)
		if unit.is_empty(): continue
		check(sim.buy("spear").is_empty(), "Bench fixture buys replacement weapon " + id)
		check(sim.equip("spear", str(unit.id)).is_empty(), "Bench fixture changes equipment through actual transaction " + id)
		check(sim.buy("leather_armor").is_empty(), "Bench fixture buys armor " + id)
		check(sim.equip("leather_armor", str(unit.id)).is_empty(), "Bench fixture equips armor " + id)
		if id == "human_scout":
			sim.add_item("sealed_canon_goblin", 1)
			check(sim.absorb_sealed("canon_goblin", str(unit.id)).is_empty(), "Bench fixture absorbs an actual sealed essence")
			unit.cooldowns.canon_goblin = 2
		else:
			unit.mana = 2
			unit.cooldowns.ice_spear = 2
		unit.injuries = 2
		unit.hp = 7
		unit.energy = 1
		unit.durability = 37
		unit.loyalty = 42
		unit.behavior = "guard"
		sim.status(unit, "poison", 3, 2)
		sim.recalculate(unit)
		var before: Dictionary = unit.duplicate(true)
		var bag_before: Dictionary = sim.state.inventory.duplicate(true)
		sim.dismiss(str(unit.id))
		check(sim.state.party.is_empty() and sim.state.benched.has(id), "Dismissal stores living full unit " + id)
		check(same(sim.state.benched.get(id, {}), before), "Bench preserves full unit before serialization " + id)
		var restored: GameSimulation = roundtrip(sim, "Benched build " + id)
		if restored.state.is_empty(): continue
		check(same(restored.encode(restored.state.benched.get(id, {})), sim.encode(before)), "Benched unit survives JSON roundtrip " + id)
		check(restored.recruit(id).is_empty(), "Benched character rejoins " + id)
		var returned: Dictionary = restored.unit_by_id(str(before.id))
		check(not restored.state.benched.has(id), "Rejoin consumes bench entry instead of cloning " + id)
		for field: String in ["equipment", "essences", "hp", "max_hp", "injuries", "energy", "mana", "cooldowns", "statuses", "status_power", "durability", "behavior", "loyalty", "spells", "profession", "can_absorb_essences"]:
			check(same(returned.get(field), before.get(field)), "Rejoin retains " + field + " without free recovery/removal " + id)
		check(same(restored.state.inventory, bag_before), "Rejoin neither duplicates nor discards equipment/items " + id)
		check(Validator.validate(restored.snapshot()).is_empty(), "Rejoined build remains saveable " + id)

func _test_malformed_benched_units() -> void:
	var sim: GameSimulation = fresh()
	check(sim.recruit("human_scout").is_empty(), "Bench validation fixture recruits")
	sim.dismiss("comp_human_scout")
	var valid: Dictionary = sim.snapshot()
	check(Validator.validate(valid).is_empty(), "Real benched state validates")
	var cases: Array[Dictionary] = []
	var bad_hp: Dictionary = valid.duplicate(true)
	bad_hp.benched.human_scout.hp = {"bad": true}
	cases.append(bad_hp)
	var unknown: Dictionary = valid.duplicate(true)
	unknown.benched.unknown_companion = unknown.benched.human_scout
	unknown.benched.erase("human_scout")
	cases.append(unknown)
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate.party.append(duplicate.benched.human_scout.duplicate(true))
	duplicate.roster.append("human_scout")
	cases.append(duplicate)
	for index: int in range(cases.size()):
		var payload: Dictionary = cases[index]
		var encoded_before: String = JSON.stringify(payload)
		check(not Validator.validate(payload).is_empty(), "Malformed bench rejects safely case %d" % index)
		check(JSON.stringify(payload) == encoded_before, "Malformed bench validation is pure case %d" % index)
		var target: GameSimulation = fresh(991)
		var target_before: Dictionary = target.snapshot()
		check(not target.restore(payload), "Malformed bench restore rejects case %d" % index)
		check(same(target.snapshot(), target_before), "Rejected bench cannot replace active campaign case %d" % index)

func _test_template_mage_save_restriction() -> void:
	for benched: bool in [false, true]:
		for prior_id: bool in [false, true]:
			for missing_metadata: bool in [false, true]:
				var sim: GameSimulation = fresh()
				check(sim.recruit("human_mage").is_empty(), "Template restriction fixture recruits mage")
				if benched: sim.dismiss("comp_human_mage")
				var payload: Dictionary = sim.snapshot()
				var unit: Dictionary = payload.benched.human_mage if benched else payload.party[0]
				unit.essences = ["canon_goblin"]
				if missing_metadata:
					unit.erase("profession")
					unit.erase("can_absorb_essences")
				else:
					unit.profession = "explorer"
					unit.can_absorb_essences = true
				if prior_id:
					unit.id = "comp_dwalkie"
					unit.content_id = "dwalkie"
					if benched:
						payload.benched.dwalkie = payload.benched.human_mage
						payload.benched.erase("human_mage")
					else:
						payload.roster = ["dwalkie"]
						payload.selected = "comp_dwalkie"
				var label: String = "Mage template bench=%s legacy=%s absent=%s" % [benched, prior_id, missing_metadata]
				check(not Validator.validate(payload).is_empty(), label + ": template forbids existing essence independently of optional metadata")
				var target: GameSimulation = fresh(3291)
				var before: Dictionary = target.snapshot()
				var before_rng: int = target.rng.state
				check(not target.restore(JSON.parse_string(JSON.stringify(payload))), label + ": restore rejects instead of creating unsaveable state")
				check(same(target.snapshot(), before) and target.rng.state == before_rng, label + ": rejection preserves active state and RNG")
