extends SceneTree
## Assisted funding and aptitude seeds; no claim of normal campaign affordability.
## Exercises only the supported basic Human magic entry path.
const Sim = preload("res://game/simulation.gd")
const Rules = preload("res://game/profession_rules.gd")
const Validator = preload("res://game/save_validation.gd")
const Content = preload("res://game/content.gd")
const World = preload("res://game/world.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func aptitude_seed(id: String = "hero", positive: bool = true) -> int:
	# Pure deterministic fixture selection, never production combat RNG rerolls.
	for value: int in range(1000):
		if (Rules.assessment({"id":id},value) == "limited") == positive: return value
	push_error("No aptitude fixture found")
	return 0

func fresh(race: String = "human", id: String = "hero", positive: bool = true) -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Human magic fixture",race,"adventurer",aptitude_seed(id,positive))
	sim.state.gold = 20000 # Explicit fixture grant.
	return sim

func clock_days(sim: GameSimulation) -> int:
	return (int(sim.state.get("month",1))-1)*30+int(sim.state.day)

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func conserved(sim: GameSimulation) -> String:
	var copy: Dictionary = sim.state.duplicate(true)
	copy.erase("log")
	return var_to_str([copy,sim.rng.state])

func reject(sim: GameSimulation, method: String, label: String, id: String = "hero") -> void:
	var before: String = conserved(sim)
	check(not str(sim.call(method,id)).is_empty(),label+" rejects")
	check(conserved(sim) == before,label+" preserves campaign, clock, currency and RNG")

func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	check(Validator.validate(raw).is_empty(),label+" snapshot validates")
	var loaded := Sim.new()
	check(loaded.restore(raw),label+" JSON restore succeeds")
	return loaded

func study(sim: GameSimulation, id: String = "hero") -> void:
	check(str(sim.call("assess_magic",id)).is_empty(),"Actual Human talent assessment succeeds: "+id)
	check(sim.unit_by_id(id).get("magic_assessment","") == "limited","Positive fixture records limited basic aptitude")
	check(str(sim.call("study_magic",id)).is_empty(),"Actual paid basic lessons succeed: "+id)

func _initialize() -> void:
	var probe := fresh()
	if not probe.has_method("assess_magic") or not probe.has_method("study_magic"):
		check(false,"Human magic APIs must exist before integration can pass")
	else:
		_test_transactions_and_clock()
		_test_rejections()
		_test_negative_persistence()
		_test_recruit_persistence()
		_test_spell_and_essence_restriction()
		_test_invalid_saves()
	print("PROFESSION INTEGRATION: %d checks, %d failures. Actual assessment, tuition, spell use and JSON/bench persistence; assisted funding/aptitude seeds; basic Human magic only." % [checks,failures])
	quit(1 if failures else 0)

func _test_transactions_and_clock() -> void:
	var sim := fresh()
	sim.state.day = 29
	sim.state.month = 2
	sim.hero().hp = 7
	sim.hero().energy = 2
	var gold: int = sim.state.gold
	var day: int = clock_days(sim)
	var rng_before: int = sim.rng.state
	var original: Dictionary = sim.hero().duplicate(true)
	check(str(sim.call("assess_magic","hero")).is_empty(),"Assessment succeeds at month boundary")
	check(int(sim.state.gold) == gold-Rules.ASSESSMENT_COST,"Assessment charges exactly advertised estimate")
	check(clock_days(sim) == day+Rules.ASSESSMENT_DAYS and int(sim.state.day) == 2 and int(sim.state.month) == 3,"Assessment advances three days and normalizes thirty-day month")
	check(sim.rng.state == rng_before,"Assessment does not consume combat RNG")
	check(sim.hero().magic_assessment == Rules.assessment(original,int(sim.state.seed)),"Assessment stores deterministic campaign/id result")
	check(int(sim.hero().hp) == 7 and int(sim.hero().energy) == 2 and sim.hero().spells.is_empty(),"Assessment grants no healing, SP or spells")
	reject(sim,"assess_magic","Repeated positive assessment")
	gold = sim.state.gold
	day = clock_days(sim)
	check(str(sim.call("study_magic","hero")).is_empty(),"Suitable Human buys basic lessons")
	check(int(sim.state.gold) == gold-Rules.TUITION_COST and clock_days(sim) == day+Rules.TUITION_DAYS,"Lessons charge exactly tuition and thirty elapsed days")
	check(int(sim.state.day) == 2 and int(sim.state.month) == 4 and sim.rng.state == rng_before,"Lessons normalize month and preserve combat RNG")
	var mage: Dictionary = sim.hero()
	check(mage.profession == "mage" and mage.get("magic_trained",false) and not mage.can_absorb_essences,"Training stores profession and permanent essence restriction")
	check(mage.spells == ["ice_spear"] and mage.essences.is_empty(),"Training grants only implemented basic spell")
	check(int(mage.mana) == int(mage.max_mana) and int(mage.max_mana) > 0,"Training fills independent mana pool")
	check(int(mage.hp) == 7 and int(mage.energy) == 2,"Tuition preserves injured HP and remaining SP")
	reject(sim,"study_magic","Training cannot be bought twice")
	var max_sp: int = mage.max_energy
	var physical: Array = [mage.str,mage.agi,mage.wit,mage.vig,mage.max_hp]
	sim.state.xp = 30 # Assisted cumulative progression boundary.
	sim.check_level()
	check(int(sim.state.level) == 3 and int(mage.max_energy) == max_sp and sim.essence_capacity(mage) == 0,"Trained mage receives no explorer SP level bonus or essence slots")
	check([mage.str,mage.agi,mage.wit,mage.vig,mage.max_hp] == physical,"Mage level growth grants no invented physical attributes")
	var loaded := roundtrip(sim,"Trained Human hero")
	if loaded.state.is_empty(): return
	check(loaded.hero().get("magic_trained",false) and loaded.hero().profession == "mage" and loaded.hero().magic_assessment == "limited","Hero training and assessment survive JSON")
	check(int(loaded.hero().hp) == int(mage.hp) and int(loaded.hero().mana) == int(mage.mana),"Hero resources survive restore without free recovery")

func _test_rejections() -> void:
	for race: String in ["barbarian","fairy","dwarf","beastman","draconian"]:
		var other := fresh(race)
		reject(other,"assess_magic","Wrong assessment race "+race)
		reject(other,"study_magic","Wrong lesson race "+race)
	for reason: String in ["missing","zero hp","dead","dungeon","assessment funds"]:
		var sim := fresh()
		var id: String = "hero"
		match reason:
			"missing": id = "missing_unit"
			"zero hp": sim.hero().hp = 0
			"dead": sim.hero().dead = true
			"dungeon": sim.state.mode = "dungeon"
			"assessment funds": sim.state.gold = Rules.ASSESSMENT_COST-1
		reject(sim,"assess_magic",reason,id)
	for reason: String in ["unassessed","negative","essence","mage","funds","zero hp","dead","dungeon","missing"]:
		var sim := fresh()
		check(str(sim.call("assess_magic","hero")).is_empty(),"Lesson rejection fixture assessed")
		var id: String = "hero"
		match reason:
			"unassessed": sim.hero().erase("magic_assessment")
			"negative": sim.hero().magic_assessment = "none"
			"essence": sim.hero().essences = ["canon_goblin"]
			"mage": sim.hero().profession = "mage"
			"funds": sim.state.gold = Rules.TUITION_COST-1
			"zero hp": sim.hero().hp = 0
			"dead": sim.hero().dead = true
			"dungeon": sim.state.mode = "dungeon"
			"missing": id = "missing_unit"
		reject(sim,"study_magic",reason,id)

func _test_negative_persistence() -> void:
	var id: String = "comp_human_scout"
	var sim := fresh("human",id,false)
	check(sim.recruit("human_scout").is_empty(),"Recruit negative aptitude Human fixture")
	check(str(sim.call("assess_magic",id)).is_empty(),"Negative assessment is a completed paid service")
	check(sim.unit_by_id(id).magic_assessment == "none","Negative aptitude stored permanently")
	sim.unit_by_id(id).name = "Renamed candidate"
	reject(sim,"assess_magic","Rename cannot reroll negative aptitude",id)
	reject(sim,"study_magic","Negative aptitude cannot purchase magic",id)
	sim.dismiss(id)
	var loaded := roundtrip(sim,"Benched negative Human assessment")
	if loaded.state.is_empty(): return
	check(loaded.recruit("human_scout").is_empty(),"Assessed Human rejoins after load")
	check(loaded.unit_by_id(id).magic_assessment == "none","Bench/rejoin retains negative result")
	reject(loaded,"assess_magic","Benched loaded result cannot reroll",id)
	reject(loaded,"study_magic","Benched loaded negative cannot buy training",id)

func _test_recruit_persistence() -> void:
	var id: String = "comp_human_scout"
	var sim := fresh("human",id)
	check(sim.recruit("human_scout").is_empty(),"Recruit prospective Human mage")
	study(sim,id)
	var unit: Dictionary = sim.unit_by_id(id)
	unit.hp = 9
	unit.mana = 2
	unit.cooldowns.ice_spear = 2
	var expected: Dictionary = unit.duplicate(true)
	sim.ensure_city_state()
	check(unit.profession == "mage" and not unit.can_absorb_essences,"City refresh cannot reset trained recruit from scout template")
	var loaded := roundtrip(sim,"Active newly trained recruit")
	if loaded.state.is_empty(): return
	check(loaded.unit_by_id(id).profession == "mage" and loaded.unit_by_id(id).get("magic_trained",false),"Active trained recruit survives restore")
	loaded.dismiss(id)
	loaded = roundtrip(loaded,"Benched newly trained recruit")
	if loaded.state.is_empty(): return
	check(loaded.recruit("human_scout").is_empty(),"Trained recruit rejoins from bench")
	var returned: Dictionary = loaded.unit_by_id(id)
	for field: String in ["id","profession","magic_trained","magic_assessment","can_absorb_essences","spells","essences","mana","hp","energy","cooldowns"]:
		check(same(returned.get(field),expected.get(field)),"Rejoined mage retains "+field)
	reject(loaded,"study_magic","Rejoined mage cannot repurchase lessons",id)
	check(Validator.validate(loaded.snapshot()).is_empty(),"Rejoined former scout mage remains saveable")

func _test_spell_and_essence_restriction() -> void:
	var sim := fresh()
	study(sim)
	sim.add_item("sealed_canon_goblin",1) # Explicit placed-item fixture.
	var before: String = conserved(sim)
	check(not sim.absorb_sealed("canon_goblin").is_empty(),"Trained hero rejects actual sealed essence absorption")
	check(conserved(sim) == before,"Rejected absorption preserves item, resources and clock")
	check(sim.recruit("human_scout").is_empty(),"Spell fixture recruits an idle ally to keep the round open")
	check(sim.wait_for_opening() and sim.enter_region(1),"Trained hero enters next actual expedition")
	sim.state.units = []
	for y: int in range(1,int(sim.state.map.height)-1):
		for x: int in range(1,int(sim.state.map.width)-1): sim.state.map.tiles[y][x] = World.FLOOR
	sim.state.map.traps = []
	# Controlled spell arena uses ambient light; darkness has separate floor tests.
	sim.state.map.dark_outskirts_width=1
	sim.state.map.memorial_radius_estimate=1
	sim.hero().pos = Vector2i(3,4)
	sim.hero().ap = 2
	for ally: Dictionary in sim.state.party:
		ally.pos = Vector2i(4,5)
		ally.ap = 2
		ally.behavior = "manual"
	sim.state.combat = true
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(7,4))
	target.hp = 1000
	target.max_hp = 1000
	target.alert = false
	sim.update_visibility()
	var mana: int = sim.hero().mana
	var sp: int = sim.hero().energy
	var hp: int = target.hp
	check(not sim.use_technique(0,Vector2i(5,4)),"Learned projectile rejects an empty target tile")
	check(int(sim.hero().mana) == mana and int(sim.hero().ap) == 2,"Rejected spell target spends no mana or AP")
	check(sim.use_technique(0,target.pos),"Newly learned Ice Spear uses real technique targeting")
	check(int(target.hp) < hp and int(sim.hero().mana) == mana-int(Content.spells().ice_spear.cost),"Learned spell resolves damage and actual mana cost")
	check(int(sim.hero().energy) == sp,"Learned magic spends mana independently of SP")

func _test_invalid_saves() -> void:
	var sim := fresh()
	study(sim)
	var valid: Dictionary = sim.snapshot()
	var receiver := fresh()
	var cases: Array[Dictionary] = []
	for value: Variant in [null,[],{},true,5,"", "tower"]:
		var raw: Dictionary = valid.duplicate(true)
		raw.hero.magic_assessment = value
		cases.append(raw)
	for value: Variant in [null,[],{},1,"true"]:
		var raw: Dictionary = valid.duplicate(true)
		raw.hero.magic_trained = value
		cases.append(raw)
	for field: String in ["negative","ancestry","profession","absorption","essence"]:
		var raw: Dictionary = valid.duplicate(true)
		match field:
			"negative": raw.hero.magic_assessment = "none"
			"ancestry": raw.hero.ancestry = "fairy"
			"profession": raw.hero.profession = "explorer"
			"absorption": raw.hero.can_absorb_essences = true
			"essence": raw.hero.essences = ["canon_goblin"]
		cases.append(raw)
	var recruit_sim := fresh("human","comp_human_scout")
	check(recruit_sim.recruit("human_scout").is_empty(),"Malformed bench fixture recruits prospective mage")
	study(recruit_sim,"comp_human_scout")
	recruit_sim.dismiss("comp_human_scout")
	var valid_bench: Dictionary = recruit_sim.snapshot()
	for field: String in ["assessment type","trained type","profession","negative"]:
		var raw: Dictionary = valid_bench.duplicate(true)
		var benched: Dictionary = raw.benched.human_scout
		match field:
			"assessment type": benched.magic_assessment = []
			"trained type": benched.magic_trained = "true"
			"profession": benched.profession = "explorer"
			"negative": benched.magic_assessment = "none"
		cases.append(raw)
	for index: int in range(cases.size()):
		var raw: Dictionary = cases[index]
		var original: String = var_to_str(raw)
		var before: String = conserved(receiver)
		check(not Validator.validate(raw).is_empty(),"Malformed magic save rejects case "+str(index))
		check(var_to_str(raw) == original,"Magic save validation leaves payload unchanged case "+str(index))
		check(not receiver.restore(raw),"Malformed magic restore rejects case "+str(index))
		check(conserved(receiver) == before,"Malformed magic restore preserves campaign and RNG case "+str(index))
