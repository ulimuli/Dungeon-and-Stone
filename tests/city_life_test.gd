extends SceneTree

const City = preload("res://game/city_life.gd")
const Content = preload("res://game/content.gd")
const RecruitmentData = preload("res://game/recruitment.gd")
const Art = preload("res://game/character_art.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh() -> Dictionary:
	return {"seed":74119, "mode":"city", "gold":60, "food":4, "inventory":{}, "flags":{}, "rep":{}, "journal":[]}

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _initialize() -> void:
	_test_roster()
	_test_routing()
	_test_persistence()
	print("CITY LIFE: %d checks, %d failures. Service routing, generated identities and deterministic provisional appearances." % [checks, failures])
	quit(1 if failures else 0)

func _test_roster() -> void:
	var a: Dictionary = fresh()
	var b: Dictionary = fresh()
	City.ensure_state(a)
	City.ensure_state(b)
	check(same(a.city_life,b.city_life), "City appearance generation is deterministic")
	check(City.roster(a).size() == 12 + Content.companions().size(), "Service operators and all generated recruits appear in roster")
	var races: Dictionary = {}
	var appearances: Dictionary = {}
	for npc: Dictionary in City.roster(a):
		check(npc.provisional_visual_identity, "Appearance interpretation is explicitly provisional: " + str(npc.id))
		check(Content.ancestries().has(npc.ancestry), "Roster ancestry resolves: " + str(npc.id))
		check(npc.appearance == Art.normalize(npc.appearance,npc.ancestry), "Saved appearance is normalized: " + str(npc.id))
		appearances[JSON.stringify(npc.appearance)] = true
		if npc.has("companion_id"):
			var offer: Dictionary = RecruitmentData.for_state(a)[npc.companion_id]
			check(npc.name == offer.name and npc.ancestry == offer.ancestry, "City recruit uses the campaign-persisted generated identity")
			check(npc.reference_urls.is_empty() and not npc.name.contains("Warrior") and not npc.name.contains("Mage"), "City recruit has a generated personal name without invented provenance")
		else:
			check(npc.name == npc.role and npc.reference_urls.is_empty(), "Unnamed service operator carries no invented canonical identity")
			races[npc.ancestry] = int(races.get(npc.ancestry,0)) + 1
	check(races.size() == 6, "Six races have equal service-operator visual representation")
	for count: Variant in races.values(): check(int(count) == 2,"Each race has two provisional operator appearances")
	check(appearances.size() == City.roster(a).size(),"Every roster entry has a distinct appearance")
	var copy: Array[Dictionary] = City.roster(a)
	copy[0].appearance.skin = "ebony" if copy[0].appearance.skin != "ebony" else "pale"
	check(not same(copy[0].appearance,a.city_life.npcs[copy[0].id].appearance),"Roster views are defensive copies")
	check(City.tasks(a).is_empty(),"No unsourced city tasks are offered")

func _test_routing() -> void:
	var state: Dictionary = fresh()
	for npc: Dictionary in City.roster(state):
		var dialogue: Dictionary = City.dialogue(state,npc.id)
		check(dialogue.name == npc.name and dialogue.choices.size() >= 2,"Roster entry opens functional choices: " + str(npc.id))
		check(dialogue.line in ["Available services","Recruitment"],"UI service labels do not invent attributed speech")
		for choice: Dictionary in dialogue.choices:
			var before: Dictionary = state.duplicate(true)
			var result: Dictionary = City.interact(state,npc.id,choice.id)
			check(result.ok,"Displayed choice dispatches: " + str(npc.id) + "/" + str(choice.id))
			check(same(state,before),"Routing leaves transactions to simulation: " + str(choice.id))
			if npc.has("companion_id") and choice.id != "leave":
				check(result.open == "companions" and result.companion_id == npc.companion_id,"Generated adventurer opens recruitment with stable identity")
		check(City.market_discount(state,npc.id) == 0,"NPC identity grants no unsourced price modifier")
	check(City.dialogue(state,"missing").choices.is_empty(),"Unknown operator has no offered actions")
	for pair: Array in [["missing","service:rest"],["innkeeper","service:repair"],["merchant","service:rest"],["tailor","open:market"],["merchant","talk"],["smith","accept:unknown"],["smith","complete:unknown"]]:
		var before: Dictionary = state.duplicate(true)
		check(not City.interact(state,pair[0],pair[1]).ok and same(state,before),"Forged or unsupported action cannot mutate city state")
	state.mode = "dungeon"
	var boundary: Dictionary = state.duplicate(true)
	for choice: String in ["service:rest","open:market","leave","talk"]:
		check(not City.interact(state,"innkeeper",choice).ok and same(state,boundary),"Remote city routing is blocked without mutation")

func _test_persistence() -> void:
	var state: Dictionary = fresh()
	City.ensure_state(state)
	state.city_life.npcs.innkeeper.appearance.hair_color = "gold"
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(state))
	City.ensure_state(snapshot)
	check(same(snapshot.city_life,state.city_life),"City roster and valid appearance edits survive JSON roundtrip")
	City.ensure_state(snapshot)
	check(same(snapshot.city_life,state.city_life),"Repeated initialization is idempotent")
	snapshot.city_life.npcs.merchant.name = "forged"
	snapshot.city_life.npcs.merchant.ancestry = "unknown"
	City.ensure_state(snapshot)
	check(snapshot.city_life.npcs.merchant.name == "Merchant" and snapshot.city_life.npcs.merchant.ancestry == "draconian","Saved data cannot override operator authorization identity")
	for malformed: Variant in [3,[],{"npcs":3},{"npcs":{"merchant":false}}]:
		var repaired: Dictionary = fresh()
		repaired.city_life = malformed
		City.ensure_state(repaired)
		check(City.roster(repaired).size() == 12 + Content.companions().size(),"Malformed optional city data receives safe deterministic defaults")
	check(City.market_discount({"city_life":{"npcs":{"merchant":{"relation":10000}}}},"merchant") == 0,"Saved arbitrary metadata cannot alter market terms")
