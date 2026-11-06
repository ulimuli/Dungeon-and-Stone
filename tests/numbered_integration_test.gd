extends SceneTree
## Assisted funds/arenas; these checks make no claim about natural acquisition balance.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
const Numbered = preload("res://game/numbered_rules.gd")
const World = preload("res://game/world.gd")
const BRACES: String = "guardians_braces"
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(race: String = "human") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Numbered integration fixture",race,"adventurer",74119)
	sim.state.gold = 100000 # Explicit test grant, not normal starting income.
	return sim

func conserved(sim: GameSimulation) -> String:
	var data: Dictionary = sim.state.duplicate(true)
	data.erase("log")
	return var_to_str([data,sim.rng.state])

func equip_braces(sim: GameSimulation, unit_id: String = "hero") -> void:
	var gold: int = sim.state.gold
	var price: int = sim.market_price(BRACES,true)
	check(sim.buy(BRACES).is_empty(),"Actual market sells numbered artifact")
	check(int(sim.state.gold) == gold-price and int(sim.state.inventory.get(BRACES,0)) == 1,"Purchase pays displayed estimate and grants one artifact")
	check(sim.equip(BRACES,unit_id).is_empty(),"Owned artifact equips through actual command")

func arena(sim: GameSimulation) -> void:
	check(sim.enter_region(1),"Enter actual expedition")
	sim.state.units = []
	for y: int in range(1,int(sim.state.map.height)-1):
		for x: int in range(1,int(sim.state.map.width)-1): sim.state.map.tiles[y][x] = World.FLOOR
	sim.state.map.traps = []
	sim.hero().pos = Vector2i(6,6)
	sim.hero().ap = 2
	for index: int in range(sim.state.party.size()):
		sim.state.party[index].pos = Vector2i(7,6+index)
		sim.state.party[index].behavior = "manual"
		sim.state.party[index].ap = 2
	sim.state.combat = false
	sim.update_visibility()

func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var errors: Array[String] = Validator.validate(raw)
	check(errors.is_empty(),label+" snapshot validates: "+str(errors))
	var loaded := Sim.new()
	check(loaded.restore(raw),label+" JSON restore succeeds")
	return loaded

func reject_active(sim: GameSimulation, label: String, id: String = "hero") -> void:
	var before: String = conserved(sim)
	check(not sim.activate_guardians_braces(id).is_empty(),label+" rejects")
	check(conserved(sim) == before,label+" preserves resources, charge, clock and RNG")

func _initialize() -> void:
	_test_market_and_passive()
	_test_fractional_save_boundary()
	_test_active()
	_test_duration_and_guards()
	_test_transfer_and_persistence()
	_test_fear()
	_test_validation()
	print("NUMBERED / FEAR INTEGRATION: %d checks, %d failures. Assisted funds/arenas; actual market, gear, hits, protection, knockback, technique routing, transfer, JSON/bench persistence and innate fear. Numerical coefficients remain provisional." % [checks,failures])
	quit(1 if failures else 0)

func _test_market_and_passive() -> void:
	for race: String in ["human","dwarf"]:
		var sim := fresh(race)
		check(int(sim.item_defs[BRACES].price) == 50000 and int(sim.item_defs[BRACES].number) == 3112,"Numbered identity and compressed estimated price")
		equip_braces(sim)
		var before: String = conserved(sim)
		check(sim.state.flags.get("consignment_"+BRACES,false) and not sim.buy(BRACES).is_empty(),"Single consignment cannot be bought twice")
		check(conserved(sim) == before,"Duplicate purchase conserves currency and artifact")
		arena(sim)
		var target: Dictionary = sim.hero()
		target.hp = 1000; target.max_hp = 1000; target.armor = 5; target.resist = {"physical":50}
		var source: Dictionary = {"name":"Arithmetic fixture","team":"enemy","accuracy":100,"statuses":{}}
		#45 raw -> (45-5)*0.5=20 ->5% prevention=1.
		check(sim.hit(source,target,45,"physical","Passive arithmetic",false,true) == 19,"Actual hit applies5% AFTER armor/resistance for "+race)
		check(int(sim.braces_record().charge) == 1 and int(sim.braces_record().remainder) == 0,"Only actually prevented damage charges artifact")
		sim.braces_record().charge = 0; sim.braces_record().remainder = 0
		target.armor = 0; target.resist = {}
		var dealt: int = 0
		for index: int in range(100): dealt += sim.hit(source,target,1,"physical","Fractional fixture",false,true)
		check(dealt == 95 and int(sim.braces_record().charge) == 5 and int(sim.braces_record().remainder) == 0,"One hundred actual1HP hits preserve exact5% for "+race)
		var record: String = var_to_str(sim.braces_record())
		check(sim.hit(source,target,20,"physical","Fixed release cut",false,true,20) == 20 and var_to_str(sim.braces_record()) == record,"Fixed release-cut damage bypasses mitigation without charging")
		check(sim.unequip("charm").is_empty(),"Artifact can be removed outside combat")
		check(sim.hit(source,target,20,"physical","Unequipped",false,true) == 20 and var_to_str(sim.braces_record()) == record,"No implicit mitigation without artifact")

func _test_fractional_save_boundary() -> void:
	var sim := fresh()
	equip_braces(sim)
	# Use ordinary valid hero HP: nineteen1HP hits leave the hero alive.
	var source: Dictionary = {"name":"Carry boundary fixture","statuses":{}}
	sim.hero().armor = 0
	sim.hero().resist = {}
	for index: int in range(19): sim.hit(source,sim.hero(),1,"cold","Carry boundary",false,true)
	check(int(sim.braces_record().remainder) == 95 and int(sim.braces_record().charge) == 0,"Nineteen actual1HP hits build fractional carry without phantom charge")
	var loaded := roundtrip(sim,"Actual fractional mitigation boundary")
	var hp: int = loaded.hero().hp
	check(loaded.hit(source,loaded.hero(),1,"cold","Twentieth hit",false,true) == 0 and int(loaded.hero().hp) == hp,"Twentieth actual1HP hit is prevented across JSON restore")
	check(int(loaded.braces_record().charge) == 1 and int(loaded.braces_record().remainder) == 0,"Restored fractional boundary creates exactly one prevented-damage charge")

func _test_active() -> void:
	var sim := fresh()
	for template: String in ["human_scout","human_mage","dwarf_guard"]: check(sim.recruit(template).is_empty(),"Recruit actual companion: "+template)
	equip_braces(sim)
	arena(sim)
	var nearby: Dictionary = sim.state.party[0]
	var blocked: Dictionary = sim.state.party[1]
	var distant: Dictionary = sim.state.party[2]
	nearby.pos = Vector2i(7,6); blocked.pos = Vector2i(6,8); distant.pos = Vector2i(10,8)
	sim.state.map.tiles[7][6] = World.WALL
	for ally: Dictionary in [nearby,blocked,distant]:
		sim.status(ally,"poison",4,3)
		sim.status(ally,"marked",3,2)
	sim.status(sim.hero(),"weakened",4,3)
	sim.status(nearby,"ward",5,8)
	var foe: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(8,6))
	var unobstructed: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(4,6))
	var obstructed: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(6,9))
	var far_foe: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(13,6))
	sim.state.map.tiles[6][10] = World.WALL
	sim.update_visibility()
	sim.braces_record().charge = 20
	var energy: int = sim.hero().energy
	var mana: int = sim.hero().mana
	check(sim.state.combat,"Visible foe enables actual combat activation")
	check(sim.activate_guardians_braces().is_empty(),"Combat active executes")
	check(int(sim.hero().ap) == 0 and int(sim.hero().energy) == energy and int(sim.hero().mana) == mana,"Active spends2AP without invented SP/mana cost")
	check(int(sim.braces_record().charge) == 0 and int(sim.braces_record().cooldown) == Numbered.COOLDOWN+1,"Active consumes charge and starts global cooldown")
	check(not sim.hero().statuses.has("weakened") and not nearby.statuses.has("poison") and not nearby.statuses.has("marked"),"Active cleanses caster and nearby eligible ally")
	check(not nearby.status_power.has("poison") and not nearby.status_power.has("marked") and nearby.statuses.has("ward"),"Cleanse removes harmful potency and preserves benefits")
	check(int(sim.hero().statuses.status_immunity) == 5 and int(nearby.statuses.status_immunity) == 5,"Charge20 adds two estimated protection rounds plus tick allowance")
	check(blocked.statuses.has("poison") and not blocked.statuses.has("status_immunity"),"Wall blocks allied cleanse/protection")
	check(distant.statuses.has("poison") and not distant.statuses.has("status_immunity"),"Distant ally remains unprotected")
	check(foe.pos == Vector2i(9,6),"Knockback stops at wall after one tile")
	check(unobstructed.pos == Vector2i(2,6),"Unobstructed enemy is knocked back exactly two tiles")
	check(obstructed.pos == Vector2i(6,9) and far_foe.pos == Vector2i(13,6),"Knockback respects LOS/radius")
	for id: String in sim.HARMFUL_STATUSES:
		sim.status(nearby,id,4,2)
		check(not nearby.statuses.has(id),"Protection blocks harmful status: "+id)
	sim.status(nearby,"transformed",3,4)
	check(nearby.statuses.has("transformed"),"Protection still allows beneficial transformation")
	var hp: int = nearby.hp
	check(sim.hit({"name":"Damage fixture","statuses":{}},nearby,5,"cold","No damage immunity",false,true) == 5 and int(nearby.hp) == hp-5,"Status protection does not grant damage immunity")

func _test_duration_and_guards() -> void:
	for race: String in ["human","dwarf"]:
		var sim := fresh(race)
		equip_braces(sim)
		arena(sim)
		var entries: Array[Dictionary] = sim.techniques(sim.hero())
		var slot: int = -1
		for index: int in range(entries.size()):
			if entries[index].kind == "numbered" and entries[index].id == BRACES: slot = index
		check(slot >= 0,"Numbered active appears in actual techniques")
		check(sim.use_technique(slot,sim.hero().pos),"Actual dispatcher routes numbered technique")
		check(int(sim.hero().statuses.status_immunity) == (4 if race == "dwarf" else 3),"Only Dwarf extends active duration1.5x")
		check(sim.unequip("charm").is_empty(),"Remove braces after active")
		check(sim.techniques(sim.hero()).all(func(entry: Dictionary) -> bool: return entry.kind != "numbered"),"Unequipped active disappears")
	for reason: String in ["city","missing gear","stunned","paralyzed","suppressed","fallen","one AP","cooldown","unknown unit"]:
		var sim := fresh(); equip_braces(sim)
		if reason != "city": arena(sim)
		var id: String = "hero"
		match reason:
			"missing gear": sim.unequip("charm")
			"stunned", "paralyzed", "suppressed": sim.hero().statuses[reason] = 2
			"fallen": sim.hero().hp = 0
			"one AP": sim.state.combat = true; sim.hero().ap = 1
			"cooldown": sim.braces_record().cooldown = 1
			"unknown unit": id = "missing_unit"
		reject_active(sim,reason,id)

func _test_transfer_and_persistence() -> void:
	var sim := fresh()
	check(sim.recruit("dwarf_guard").is_empty(),"Recruit Dwarf carrier")
	equip_braces(sim)
	sim.braces_record().charge = 23; sim.braces_record().remainder = 95
	var city := roundtrip(sim,"City artifact charge")
	check(int(city.braces_record().charge) == 23 and int(city.braces_record().remainder) == 95,"Charge/fraction survive city JSON")
	arena(city)
	check(city.activate_guardians_braces().is_empty(),"First carrier activates artifact")
	var cooldown: int = city.braces_record().cooldown
	check(city.unequip("charm").is_empty(),"Move artifact into bag after activation")
	var companion: Dictionary = city.state.party[0]
	check(city.equip(BRACES,companion.id).is_empty(),"Transfer owned artifact to another carrier")
	reject_active(city,"Transfer cannot reset cooldown",companion.id)
	var loaded := roundtrip(city,"Dungeon transferred artifact")
	check(int(loaded.braces_record().cooldown) == cooldown and int(loaded.braces_record().remainder) == 95,"Dungeon JSON preserves global cooldown/fraction")
	reject_active(loaded,"Restored transferred cooldown",companion.id)
	loaded.return_city()
	loaded.dismiss(companion.id)
	var benched := roundtrip(loaded,"Benched numbered carrier")
	check(benched.recruit("dwarf_guard").is_empty(),"Numbered carrier rejoins actual roster")
	check(benched.state.party[0].equipment.charm == BRACES and int(benched.braces_record().cooldown) == cooldown,"Bench/rejoin preserves owned gear and artifact cooldown")
	var weight: float = benched.weight()
	check(benched.unequip("charm",benched.state.party[0].id).is_empty() and is_equal_approx(benched.weight(),weight),"Numbered unequip conserves total weight")
	check(not benched.buy(BRACES).is_empty(),"Save/rejoin cannot restock consignment")

func _test_fear() -> void:
	var sim := fresh("draconian")
	arena(sim)
	var foe: Dictionary = sim.spawn_enemy("canon_ghoul",Vector2i(8,6))
	sim.update_visibility()
	check(sim.dragon_fear_penalty(foe) == 10,"Living Draconian projects innate default fear without level gate")
	check(sim.dragon_fear_penalty(sim.hero()) == 0 and foe.statuses.is_empty(),"Pressure neither affects allies nor invents stun/turn loss")
	var energy: int = sim.hero().energy
	check(sim.set_dragon_fear(false).is_empty() and sim.dragon_fear_penalty(foe) == 0,"Suppressing innate fear removes pressure")
	check(int(sim.hero().energy) == energy,"Fear control has no invented SP price")
	var loaded := roundtrip(sim,"Suppressed innate fear")
	check(not loaded.hero().dragon_fear_enabled and loaded.dragon_fear_penalty(loaded.state.units[0]) == 0,"Suppression persists in dungeon JSON")
	check(sim.set_dragon_fear(true).is_empty(),"Innate fear can be restored")
	foe.pos = Vector2i(10,6)
	check(sim.dragon_fear_penalty(foe) == 0,"Out-of-radius foe receives no pressure")
	foe.pos = Vector2i(8,6); sim.state.map.tiles[6][7] = World.WALL
	check(sim.dragon_fear_penalty(foe) == 0,"Wall blocks fear")
	sim.state.map.tiles[6][7] = World.FLOOR
	foe.accuracy = 85
	var threshold: int = 85-int(sim.hero().evasion)
	var probe := RandomNumberGenerator.new()
	var selected_seed: int = -1
	for candidate: int in range(10000):
		probe.seed = candidate
		var roll: int = probe.randi_range(1,100)
		if roll > threshold-10 and roll <= threshold:
			selected_seed = candidate
			break
	check(selected_seed >= 0,"Find actual RNG boundary for fear accuracy")
	sim.rng.seed = selected_seed
	var hp: int = sim.hero().hp
	check(sim.hit(foe,sim.hero(),1,"cold","Fear accuracy",false) == 0 and int(sim.hero().hp) == hp,"Actual incoming hit applies fear accuracy reduction")
	sim.set_dragon_fear(false); sim.rng.seed = selected_seed
	check(sim.hit(foe,sim.hero(),1,"cold","Suppressed fear accuracy",false) == 1,"Identical hit succeeds after fear suppression")
	var wrong := fresh("human")
	var before: String = conserved(wrong)
	check(not wrong.set_dragon_fear(false).is_empty() and conserved(wrong) == before,"Wrong race cannot acquire/control fear")
	sim.hero().hp = 0
	check(sim.dragon_fear_penalty(foe) == 0 and not sim.set_dragon_fear(true).is_empty(),"Fallen Draconian cannot project/control fear")
	var bench := fresh("human")
	check(bench.recruit("draconian_warrior").is_empty(),"Recruit Draconian for persistent control")
	var carrier_id: String = bench.state.party[0].id
	check(bench.set_dragon_fear(false,carrier_id).is_empty(),"Control recruited Draconian fear")
	bench.dismiss(carrier_id)
	var restored := roundtrip(bench,"Benched Draconian fear")
	check(restored.recruit("draconian_warrior").is_empty() and not restored.state.party[0].dragon_fear_enabled,"Rejoining preserves suppressed innate fear")

func _test_validation() -> void:
	var sim := fresh("draconian")
	equip_braces(sim)
	sim.set_dragon_fear(false)
	sim.braces_record().charge = 2
	var loaded := roundtrip(sim,"Validation baseline")
	for record: Variant in [null,[],true,{"unknown":{}},{BRACES:null},{BRACES:{}},{BRACES:{"charge":-1,"remainder":0,"cooldown":0}},{BRACES:{"charge":0,"remainder":100,"cooldown":0}},{BRACES:{"charge":0,"remainder":0,"cooldown":999}},{BRACES:{"charge":0.5,"remainder":0,"cooldown":0}},{BRACES:{"charge":0,"remainder":0,"cooldown":0,"extra":1}}]:
		var raw: Dictionary = sim.snapshot()
		raw.numbered_state = record
		var before: String = conserved(loaded)
		check(not Validator.validate(raw).is_empty() and not loaded.restore(raw),"Malformed numbered state rejects: "+str(record))
		check(conserved(loaded) == before,"Malformed numbered state preserves campaign/RNG")
	for value: Variant in [null,0,"false",[],{}]:
		var raw: Dictionary = sim.snapshot()
		raw.hero.dragon_fear_enabled = value
		var before: String = conserved(loaded)
		check(not Validator.validate(raw).is_empty() and not loaded.restore(raw),"Malformed fear control rejects: "+str(value))
		check(conserved(loaded) == before,"Malformed fear control preserves campaign/RNG")
	var wrong := fresh("human")
	var wrong_raw: Dictionary = wrong.snapshot()
	wrong_raw.hero.dragon_fear_enabled = true
	var before: String = conserved(loaded)
	check(not Validator.validate(wrong_raw).is_empty() and not loaded.restore(wrong_raw) and conserved(loaded) == before,"Saved human cannot forge innate Draconian fear")
