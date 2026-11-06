extends SceneTree
## Assisted integration fixtures; currency, level and placed drops are test grants.
## No claim that a fresh explorer naturally earns the ring's estimated price.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
const Rules = preload("res://game/racial_rules.gd")
const RING: String = "frost_spirit_ring"
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(race: String = "beastman") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Beastman integration fixture",race,"adventurer",74119)
	sim.state.gold = 20000 # Explicit fixture funding, not normal starting income.
	return sim

func conserved(sim: GameSimulation) -> String:
	# Exclude diagnostic messages; include all resources, world state and RNG.
	var data: Dictionary = sim.state.duplicate(true)
	data.erase("log")
	return var_to_str([data,sim.rng.state])

func safe_dungeon(sim: GameSimulation) -> void:
	check(sim.enter_region(1),"Enter actual expedition")
	sim.state.units = []
	sim.state.combat = false
	sim.update_visibility()

func absorb_drop(sim: GameSimulation, id: String, unit_id: String = "hero") -> void:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	sim.state.essence_drops = [{"id":id,"pos":unit.pos,"region":int(sim.state.region),"expires_at":int(sim.state.time)+30}]
	sim._recount_essence_drops()
	check(sim.absorb(id,unit_id).is_empty(),"Actual absorption consumes assisted field drop: "+id)
	check(sim.state.essence_drops.is_empty() and int(sim.state.loot_essences.get(id,0)) == 0,"Absorption removes loose essence")

func buy_ring(sim: GameSimulation) -> void:
	var gold: int = sim.state.gold
	var price: int = sim.market_price(RING,true)
	check(sim.buy(RING).is_empty(),"Actual city consignment sells numbered ring")
	check(int(sim.state.gold) == gold-price and int(sim.state.inventory.get(RING,0)) == 1,"Ring purchase pays displayed estimate and grants one ring")
	check(sim.state.flags.get("consignment_"+RING,false),"One-time consignment is recorded")

func ready(race: String = "beastman") -> GameSimulation:
	var sim := fresh(race)
	buy_ring(sim)
	check(sim.equip(RING).is_empty(),"Unengraved character equips owned ring without invented essence")
	return sim

func reject_ritual(sim: GameSimulation, label: String, unit_id: String = "hero") -> void:
	var before: String = conserved(sim)
	check(not sim.awaken_skadia(unit_id).is_empty(),label+" rejects")
	check(conserved(sim) == before,label+" preserves equipment, bags, stats, clock, currency and RNG")

func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var raw: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var errors: Array[String] = Validator.validate(raw)
	check(errors.is_empty(),label+" snapshot validates: "+str(errors))
	var loaded := Sim.new()
	check(loaded.restore(raw),label+" JSON restore succeeds")
	return loaded

func _initialize() -> void:
	_test_market_and_seal()
	_test_ritual_and_persistence()
	_test_rejections()
	_test_companion()
	_test_malformed_saves()
	_test_damage_types()
	print("BEASTMAN PROGRESSION: %d checks, %d failures. Actual purchase, absorption, sealing, destructive ritual, attacks and JSON/bench persistence; assisted funds/drops/level; numeric estimates remain provisional." % [checks,failures])
	quit(1 if failures else 0)

func _test_market_and_seal() -> void:
	var sim := fresh()
	check(int(sim.item_defs[RING].number) == 9425 and int(sim.item_defs[RING].price) == 1500,"Number9425 and compressed base price are explicit")
	buy_ring(sim)
	var before: String = conserved(sim)
	check(not sim.buy(RING).is_empty() and conserved(sim) == before,"Sold consignment cannot duplicate ring or spend more currency")
	safe_dungeon(sim)
	sim.state.level = 2 # Capacity fixture for two actual absorbed essences.
	absorb_drop(sim,"canon_goblin")
	absorb_drop(sim,"canon_gnome")
	var owned: Array = sim.hero().essences.duplicate()
	var stats: Array = [sim.hero().str,sim.hero().agi,sim.hero().wit,sim.hero().vig,sim.hero().max_hp,sim.hero().power,sim.essence_capacity(sim.hero())]
	before = conserved(sim)
	check(not sim.equip(RING).is_empty() and conserved(sim) == before,"Owned essences require explicit seal choice without resource loss")
	check(not sim.equip(RING,"hero","unknown").is_empty() and conserved(sim) == before,"Unowned seal cannot equip ring")
	check(sim.equip(RING,"hero","canon_goblin").is_empty(),"Explicit absorbed essence seal equips ring")
	check(sim.hero().essences == owned and sim.active_essences(sim.hero()) == ["canon_gnome"],"Sealing preserves ownership and filters only chosen essence")
	check([sim.hero().str,sim.hero().agi,sim.hero().wit,sim.hero().vig,sim.hero().max_hp,sim.hero().power,sim.essence_capacity(sim.hero())] == stats,"Sealing changes no attribute fields, derived power or capacity")
	var energy: int = sim.hero().energy
	var time: int = sim.state.time
	check(not sim.use_ability(0,sim.hero().pos),"Sealed essence active cannot execute")
	check(int(sim.hero().energy) == energy and int(sim.state.time) == time and sim.hero().cooldowns.is_empty(),"Blocked active spends no SP, cooldown or clock")
	check(sim.techniques(sim.hero()).all(func(entry: Dictionary) -> bool: return entry.id != "canon_goblin"),"Sealed active disappears from techniques")
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",sim.hero().pos+Vector2i.RIGHT)
	sim.trigger(sim.hero(),"on_hit",target,1,true)
	check(not target.statuses.has("paralyzed"),"Sealed Goblin passive cannot paralyze on weapon hit")
	check(sim.set_ring_seal("canon_gnome").is_empty(),"Seal can move to another owned essence outside combat")
	sim.trigger(sim.hero(),"on_hit",target,1,true)
	check(target.statuses.has("paralyzed"),"Moving seal restores Goblin passive")
	sim.state.units = []; sim.state.combat = false
	var loaded := roundtrip(sim,"Dungeon ring seal")
	check(loaded.hero().ring_sealed_essence == "canon_gnome" and loaded.active_essences(loaded.hero()) == ["canon_goblin"],"Saved ring retains selected skill seal")
	var weight: float = sim.weight()
	check(sim.unequip("charm").is_empty(),"Ring can be removed without ritual")
	check(is_equal_approx(sim.weight(),weight) and int(sim.state.inventory.get(RING,0)) == 1,"Unequip conserves total carried weight and one ring")
	check(not sim.hero().has("ring_sealed_essence") and sim.active_essences(sim.hero()) == owned,"Removing ring restores both essences and clears seal")
	# Every implemented essence, including the two expanded resolvers, must pass
	# through the shared skill filter; these are explicit bound-essence fixtures.
	for id: String in sim.essence_defs:
		var each := fresh()
		each.hero().essences = [id]
		each.add_item(RING,1)
		check(each.equip(RING,"hero",id).is_empty(),"Equip chosen seal for "+id)
		check(each.hero().essences == [id] and each.active_essences(each.hero()).is_empty() and each.techniques(each.hero()).is_empty(),"Sealed passive/active list excludes "+id)

func _test_ritual_and_persistence() -> void:
	for mode: String in ["city","dungeon"]:
		var sim := ready()
		check(sim.buy("leather_armor").is_empty() and sim.equip("leather_armor").is_empty(),"Actual market equips clothing to test destructive ritual")
		sim.add_item("cloth_armor",1) # Unworn reserve must survive.
		if mode == "dungeon": safe_dungeon(sim)
		var equipment: Dictionary = sim.hero().equipment.duplicate()
		var losses: Array[String] = sim.skadia_ritual_losses(sim.hero())
		for id: String in equipment.values():
			if not id.is_empty(): check(losses.has(str(sim.item_defs[id].name)),"Loss preview names worn "+id)
		var bag: Dictionary = sim.state.inventory.duplicate(true)
		var before_weight: float = sim.weight()
		var worn_weight: float = 0
		for id: String in equipment.values(): worn_weight += float(sim.item_defs.get(id,{}).get("weight",0))
		var gold: int = sim.state.gold
		var base_power: int = int(sim.hero().base_power)+int(sim.hero().str)
		var base_evasion: int = int(sim.hero().agi)*2
		check(sim.awaken_skadia().is_empty(),mode+" ritual succeeds with owned worn ring")
		check(sim.hero().racial == {"soul_beast":"skadia","awakening":0},"Initial permanent contract is saved without invented awakening stages")
		check(sim.hero().equipment.values().all(func(id: String) -> bool: return id.is_empty()),"Ritual destroys ALL worn gear")
		check(sim.state.inventory == bag and int(sim.state.gold) == gold,"Ritual preserves unworn inventory and adds no fee/refund")
		check(is_equal_approx(sim.weight(),before_weight-worn_weight),"Destroyed worn items leave carried weight without bag duplication")
		check(not sim.hero().has("ring_sealed_essence"),"Destroyed ring clears temporary essence seal")
		check(int(sim.hero().power) == base_power+2 and int(sim.hero().evasion) == base_evasion+2,"Supported strengthening applies explicit estimated physical bonuses once")
		reject_ritual(sim,"Repeat permanent ritual")
		var loaded := roundtrip(sim,mode+" Skadia contract")
		check(loaded.hero().racial.soul_beast == "skadia" and int(loaded.hero().racial.awakening) == 0 and loaded.hero().equipment == sim.hero().equipment,"JSON retains contract and destroyed equipment")
		check(int(loaded.hero().power) == int(sim.hero().power) and int(loaded.hero().evasion) == int(sim.hero().evasion),"Restore does not stack strengthening")
		reject_ritual(loaded,"Restored permanent contract")
		if mode == "city":
			check(loaded.buy(RING) != "","Destroyed consignment does not restock after save")

func _test_rejections() -> void:
	for race: String in ["human","barbarian","fairy","dwarf","draconian"]:
		reject_ritual(ready(race),"Wrong race "+race)
	for reason: String in ["missing ring","combat","stunned","paralyzed","suppressed","zero health","dead","existing contract","malformed racial","unknown unit"]:
		var sim := ready()
		var unit_id: String = "hero"
		match reason:
			"missing ring": sim.unequip("charm")
			"combat": sim.state.combat = true
			"stunned", "paralyzed", "suppressed": sim.hero().statuses[reason] = 1
			"zero health": sim.hero().hp = 0
			"dead": sim.hero().dead = true
			"existing contract": sim.hero().racial = {"soul_beast":"skadia","awakening":0}
			"malformed racial": sim.hero().racial = []
			"unknown unit": unit_id = "missing_unit"
		reject_ritual(sim,reason,unit_id)

func _test_companion() -> void:
	var sim := fresh("human")
	check(sim.recruit("beastman_swordsman").is_empty(),"Recruit generated Beastman")
	var unit: Dictionary = sim.state.party[0]
	var id: String = unit.id
	buy_ring(sim)
	check(sim.equip(RING,id).is_empty() and sim.awaken_skadia(id).is_empty(),"Owned ring ritual applies to recruited Beastman")
	var power: int = unit.power
	sim.dismiss(id)
	var loaded := roundtrip(sim,"Benched Beastman contract")
	check(loaded.recruit("beastman_swordsman").is_empty(),"Same generated Beastman rejoins")
	check(loaded.state.party[0].id == id and loaded.state.party[0].racial.soul_beast == "skadia" and int(loaded.state.party[0].power) == power,"Rejoining preserves identity and contract without stacking bonuses")
	reject_ritual(loaded,"Rejoined permanent contract",id)

func _test_malformed_saves() -> void:
	var sim := ready()
	check(sim.awaken_skadia().is_empty(),"Validation fixture has legitimate permanent contract")
	var loaded := roundtrip(sim,"Validation baseline")
	for racial: Variant in [null,[],true,"skadia",{"soul_beast":"other","awakening":0},{"soul_beast":"skadia","awakening":1},{"soul_beast":"skadia","awakening":0.5},{"soul_beast":"skadia","awakening":0,"unknown":true}]:
		var raw: Dictionary = sim.snapshot()
		raw.hero.racial = racial
		var before: String = conserved(loaded)
		check(not Validator.validate(raw).is_empty() and not loaded.restore(raw),"Malformed Soul Beast record rejects: "+str(racial))
		check(conserved(loaded) == before,"Rejected racial record preserves active campaign and RNG")
	var ring_sim := ready()
	for seal: Variant in [null,42,[],true,"unknown","canon_goblin"]:
		var raw: Dictionary = ring_sim.snapshot()
		raw.hero.ring_sealed_essence = seal
		var before: String = conserved(loaded)
		check(not Validator.validate(raw).is_empty() and not loaded.restore(raw),"Malformed/unowned ring seal rejects: "+str(seal))
		check(conserved(loaded) == before,"Rejected ring seal preserves active campaign and RNG")

	# A valid equipped ring with owned essences needs a saved explicit selection.
	ring_sim.hero().essences = ["canon_goblin"]
	ring_sim.hero().ring_sealed_essence = "canon_goblin"
	for corruption: String in ["missing seal","empty owned seal","seal without ring"]:
		var raw: Dictionary = ring_sim.snapshot()
		match corruption:
			"missing seal": raw.hero.erase("ring_sealed_essence")
			"empty owned seal": raw.hero.ring_sealed_essence = ""
			"seal without ring": raw.hero.equipment.charm = ""
		var before: String = conserved(loaded)
		check(not Validator.validate(raw).is_empty() and not loaded.restore(raw),corruption+" rejects malformed save")
		check(conserved(loaded) == before,corruption+" preserves active campaign and RNG")

func _test_damage_types() -> void:
	var sim := ready()
	sim.add_item("club",1) # Explicit unworn reserve survives destruction of worn club.
	check(sim.awaken_skadia().is_empty(),"Attack fixture contracts Skadia")
	safe_dungeon(sim)
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",sim.hero().pos+Vector2i.RIGHT)
	target.hp = 1000; target.max_hp = 1000; target.armor = 3
	target.resist = {"cold":50,"physical":0}
	sim.update_visibility()
	for armed: bool in [false,true]:
		if armed:
			sim.state.combat = false
			check(sim.equip("club").is_empty(),"Equip preserved reserve weapon after ritual")
			sim.update_visibility()
		var kind: String = "physical" if armed else "cold"
		check(Rules.weapon_damage_type(sim.hero()) == kind,"Initial Skadia damage type: "+kind)
		sim.hero().ap = 2; sim.hero().attacked = false
		var expected: int = sim.damage_amount(int(sim.hero().power),int(target.armor),sim.resistance(target,kind),armed)
		var probe := RandomNumberGenerator.new()
		var chance: int = clampi(int(sim.hero().accuracy)-int(target.evasion),20,98)
		for candidate: int in range(10000):
			probe.seed = candidate
			if probe.randi_range(1,100) <= chance:
				sim.rng.seed = candidate
				break
		var hp: int = target.hp
		check(sim.attack(sim.hero(),target),"Actual "+kind+" attack executes")
		check(hp-int(target.hp) == expected,"Actual "+kind+" attack uses its resistance and appropriate armor rule")
