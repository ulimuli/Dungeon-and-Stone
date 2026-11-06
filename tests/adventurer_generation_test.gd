extends SceneTree

const RecruitmentData = preload("res://game/recruitment.gd")
const Names = preload("res://game/adventurer_names.gd")
const Content = preload("res://game/content.gd")
const Art = preload("res://game/character_art.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _initialize() -> void:
	_test_templates()
	_test_generation()
	_test_persistence()
	_test_repair_and_isolation()
	print("ADVENTURER GENERATION: %d checks, %d failures. Twelve persistent generated identities, two per race; cosmetic RNG only. No player saves used." % [checks,failures])
	quit(1 if failures else 0)

func _test_templates() -> void:
	var templates: Dictionary = Content.companions()
	check(templates.size() == 12,"Twelve neutral combat templates exist")
	var races: Dictionary = {}
	for id: String in templates:
		var offer: Dictionary = templates[id]
		check(Content.ancestries().has(offer.ancestry),"Template ancestry resolves: " + id)
		check(offer.generated_adventurer and offer.reference_urls.is_empty(),"Template has no attributed novel personal identity: " + id)
		check(str(offer.weapon).is_empty() or Content.weapons().has(offer.weapon),"Template weapon exists: " + id)
		check(int(offer.hp) > 0 and int(offer.power) > 0 and int(offer.cost) >= 0,"Template has usable bounded combat/recruitment values: " + id)
		for spell: String in offer.spells: check(Content.spells().has(spell),"Template spell exists: " + spell)
		if offer.profession == "mage":
			check(offer.ancestry == "human" and offer.spells == ["ice_spear"] and not offer.can_absorb_essences,"Only evidenced human mage profession carries wizard spell and essence restriction")
		else:
			check(offer.spells.is_empty() and offer.can_absorb_essences,"Other templates remain martial explorers without guessed spell profession")
		races[offer.ancestry] = int(races.get(offer.ancestry,0)) + 1
	check(races.size() == 6,"All six races have recruit templates")
	for count: Variant in races.values(): check(int(count) == 2,"Every race has exactly two offers")
	check(templates.has("draconian_warrior") and templates.has("draconian_spearman"),"Draconian recruitment has two functional martial options")
	check(RecruitmentData.neutral_id("dwalkie") == "human_mage" and RecruitmentData.neutral_id("hikurod") == "dwarf_guard","Save ID conversion maps to neutral roles")
	check(RecruitmentData.neutral_id("human_mage") == "human_mage","Neutral ID conversion is idempotent")

func _test_generation() -> void:
	var original: Dictionary = RecruitmentData.generate(74119)
	check(same(original,RecruitmentData.generate(74119)),"Fixed campaign seed produces identical names and appearances")
	check(not same(original,RecruitmentData.generate(74120)),"Different campaign seeds vary recruit identities")
	for seed_value: int in [-74119,0,1,2,74119,74120,1000000000]:
		var offers: Dictionary = RecruitmentData.generate(seed_value)
		var used: Dictionary = {}
		var looks: Dictionary = {}
		for id: String in offers:
			var offer: Dictionary = offers[id]
			check(not str(offer.name).is_empty() and not used.has(offer.name),"Generated names are present and unique within campaign")
			used[offer.name] = true
			check(offer.id == id and offer.template_id == id and int(offer.identity_version) == 1,"Saved identity uses stable neutral template IDs")
			check(offer.appearance == Art.normalize(offer.appearance,offer.ancestry),"Generated appearance is complete and normalized")
			looks[JSON.stringify(offer.appearance)] = true
			var template: Dictionary = Content.companions()[id]
			check(offer.role == template.role and offer.weapon == template.weapon and offer.spells == template.spells and int(offer.hp) == int(template.hp) and int(offer.power) == int(template.power),"Random identities do not randomize or corrupt gameplay template")
		check(used.size() == 12 and looks.size() == 12,"Every generated campaign has twelve distinct names and appearances")
	var used_names: Dictionary = {}
	for index: int in range(80):
		var generated: String = Names.generate(12,"same-key",used_names)
		check(not used_names.has(generated) and generated != "Unnamed Adventurer","Collision handling finds a distinct ordinary personal name")
		used_names[generated] = true

func _test_persistence() -> void:
	var state: Dictionary = {"seed":74119,"month":1,"day":1,"gold":60,"roster":[],"party":[],"rng_state":"123456789"}
	var first: Dictionary = RecruitmentData.for_state(state)
	check(state.has("recruits") and same(first,state.recruits),"First access saves full recruitment identities into campaign state")
	check(same(first,RecruitmentData.for_state(state)),"Repeated access cannot reroll recruits")
	state.month = 99; state.day = 12
	check(same(first,RecruitmentData.for_state(state)),"Passing months does not create a recruit reroll exploit")
	state.roster = ["human_mage"]
	check(same(first,RecruitmentData.for_state(state)),"Recruitment history does not regenerate remaining names or appearances")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	check(same(first,RecruitmentData.for_state(restored)),"JSON save roundtrip preserves every recruit identity")
	state.recruits.human_mage.name = "Player Chosen Name"
	state.recruits.human_mage.appearance.hair_color = "silver"
	var edited: Dictionary = RecruitmentData.for_state(state)
	check(edited.human_mage.name == "Player Chosen Name" and edited.human_mage.appearance.hair_color == "silver","Valid saved personal names and cosmetic edits are preserved")
	var saved_name: String = str(state.recruits.human_mage.name)
	edited.human_mage.name = "View Mutation"
	edited.human_mage.appearance.hair_color = "gold"
	check(state.recruits.human_mage.name == saved_name and state.recruits.human_mage.appearance.hair_color == "silver","Returned offer views cannot mutate persisted identity dictionaries")

func _test_repair_and_isolation() -> void:
	var state: Dictionary = {"seed":74119,"gold":27,"food":4,"month":3,"day":2,"rng_state":"987654321","inventory":{"healing_potion":1},"roster":["human_mage"]}
	var unchanged: Dictionary = state.duplicate(true)
	RecruitmentData.for_state(state)
	var compare: Dictionary = state.duplicate(true)
	compare.erase("recruits")
	check(same(compare,unchanged),"Identity initialization cannot consume currency/items or advance simulation RNG")
	state.recruits.human_mage.cost = -999
	state.recruits.human_mage.hp = 999999
	state.recruits.human_mage.spells = ["missing"]
	var repaired: Dictionary = RecruitmentData.for_state(state)
	check(int(repaired.human_mage.cost) == int(Content.companions().human_mage.cost) and repaired.human_mage.spells == ["ice_spear"] and int(repaired.human_mage.hp) == int(Content.companions().human_mage.hp),"Saved presentation cannot inject altered combat, spell or recruitment prices")
	state.recruits.barbarian_warrior.name = "Duplicate Name"
	state.recruits.fairy_archer.name = "Duplicate Name"
	state.recruits.human_scout.appearance = {"skin":"invalid","hair_style":7}
	state.recruits.erase("draconian_spearman")
	repaired = RecruitmentData.for_state(state)
	var names: Dictionary = {}
	for offer: Dictionary in repaired.values(): names[offer.name] = true
	check(names.size() == 12 and repaired.size() == 12,"Partial or duplicate saved identities repair to twelve unique offers")
	check(repaired.human_scout.appearance == Art.normalize(repaired.human_scout.appearance,"human"),"Malformed cosmetic values repair through shared normalizer")
	for invalid: Variant in [false,[],{"human_mage":false},{"human_mage":{"name":3}}]:
		var broken: Dictionary = {"seed":74119,"recruits":invalid}
		check(RecruitmentData.for_state(broken).size() == 12,"Malformed optional recruit data recovers without crashing")
