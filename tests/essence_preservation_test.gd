extends SceneTree
## Assisted in-memory rule fixtures. No normal saves or settings are written.
const Simulation = preload("res://game/simulation.gd")
const ESSENCE: String = "canon_goblin"
const FILLED: String = "sealed_" + ESSENCE
const EMPTY: String = "essence_test_tube"
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)

func fixture():
	var sim = Simulation.new()
	sim.new_campaign("Preservation fixture", "barbarian", "adventurer", 74119)
	sim.state.gold = 4000 # Explicit test grant, not normal income or a balance claim.
	check(sim.recruit("human_mage").is_empty(), "Recruit real generated human mage")
	check(sim.buy(EMPTY).is_empty(), "Actual shop sells empty preservation tube")
	check(sim.enter_region(1), "Enter actual expedition")
	sim.state.units = [] # Isolated safe arrival area.
	sim.state.combat = false
	var mage: Dictionary = sim.state.party[0]
	mage.pos = sim.hero().pos + Vector2i.RIGHT
	place_drop(sim, ESSENCE, 30)
	return sim

func place_drop(sim, id: String = ESSENCE, remaining: int = 30) -> void:
	sim.state.essence_drops = [{"id":id, "pos":sim.hero().pos, "region":int(sim.state.region), "expires_at":int(sim.state.time) + remaining}]
	sim._recount_essence_drops()

func resources(sim) -> String:
	var data: Dictionary = {"inventory":sim.state.inventory,"storage":sim.state.storage,"gold":sim.state.gold,"hero":sim.hero(),"party":sim.state.party,"time":sim.state.time,"drops":sim.state.essence_drops,"loose_counts":sim.state.loot_essences,"seed":sim.rng.seed,"rng":str(sim.rng.state)}
	return var_to_str(data)

func rejected_seal(sim, mage_id: String, label: String, essence_id: String = ESSENCE) -> void:
	var before: String = resources(sim)
	check(not sim.seal_essence(essence_id,mage_id).is_empty(), label + " rejected")
	check(resources(sim) == before, label + " preserves resources, drops, clock and RNG")

func rejected_absorption(sim, unit_id: String, label: String) -> void:
	var before: String = resources(sim)
	check(not sim.absorb_sealed(ESSENCE,unit_id).is_empty(), label + " rejected")
	check(resources(sim) == before, label + " preserves resources and RNG")

func _init() -> void:
	_test_attack_drop_boundary()
	var sim = fixture()
	var mage: Dictionary = sim.state.party[0]
	var mage_id: String = mage.id
	check(mage.get("profession","") == "mage", "Generated wizard has explicit mage profession")
	check(not bool(mage.get("can_absorb_essences",true)), "Generated wizard cannot absorb essences")
	check(sim.item_defs.has(FILLED), "Filled item has integrated content definition")
	var initial_gold: int = int(sim.state.gold)
	var initial_time: int = int(sim.state.time)
	var mana: int = int(mage.get("mana",0))
	var energy: int = int(mage.energy)
	check(sim.seal_essence(ESSENCE,mage_id).is_empty(), "Living adjacent mage seals actual unexpired drop")
	check(int(sim.state.inventory.get(EMPTY,0)) == 0 and int(sim.state.inventory.get(FILLED,0)) == 1, "Empty tube becomes exactly one filled tube")
	check(sim.state.essence_drops.is_empty() and int(sim.state.loot_essences.get(ESSENCE,0)) == 0, "Sealing removes physical drop and loose count")
	check(int(sim.state.time) == initial_time + 15, "Sealing advances exactly fifteen minutes")
	check(int(mage.get("mana",0)) == mana and int(mage.energy) == energy and int(sim.state.gold) == initial_gold, "Sealing adds no invented mana, SP or fee charge")
	rejected_absorption(sim,mage_id,"Wizard absorbing sealed essence")

	var encoded: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored = Simulation.new()
	check(restored.restore(encoded), "Filled tube snapshot passes actual save restore")
	check(int(restored.state.inventory.get(FILLED,0)) == 1, "Filled tube survives JSON save roundtrip")
	check(restored.state.party[0].get("profession","") == "mage", "Saved mage profession persists")
	restored.advance_time(31)
	check(int(restored.state.inventory.get(FILLED,0)) == 1, "Filled tube survives beyond original loose expiry")
	restored.state.food = 100 # Assisted stock isolates closure from starvation.
	restored.advance_time(restored.portal_limit() - int(restored.state.time))
	check(restored.state.mode == "city" and int(restored.state.inventory.get(FILLED,0)) == 1, "Actual timed extraction preserves filled essence")

	sim.state.mode = "city" # Assisted safe-city fixture; extraction rules tested separately.
	check(sim.store_item(FILLED).is_empty(), "Generic city storage accepts filled tube")
	check(int(sim.state.storage.get(FILLED,0)) == 1 and int(sim.state.inventory.get(FILLED,0)) == 0, "Deposit conserves filled item")
	rejected_absorption(sim,"hero","Absorption cannot bypass storage withdrawal")
	var stored = Simulation.new()
	check(stored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Stored filled essence passes save roundtrip")
	check(int(stored.state.storage.get(FILLED,0)) == 1 and int(stored.state.inventory.get(FILLED,0)) == 0, "Save preserves storage location without duplicating filled essence")
	check(sim.store_item(FILLED,true).is_empty(), "Generic storage withdraws filled tube")
	check(sim.absorb_sealed(ESSENCE).is_empty(), "Nonmage hero absorbs filled tube in city")
	check(sim.hero().essences.has(ESSENCE), "Sealed absorption grants real essence")
	check(int(sim.state.inventory.get(FILLED,0)) == 0 and int(sim.state.inventory.get(EMPTY,0)) == 0, "Absorption consumes filled tube without empty refund")
	rejected_absorption(sim,"hero","Already consumed tube")

	var dungeon_sim = fixture()
	check(dungeon_sim.seal_essence(ESSENCE,dungeon_sim.state.party[0].id).is_empty(), "Dungeon absorption fixture seals")
	check(dungeon_sim.absorb_sealed(ESSENCE).is_empty(), "Filled essence absorbs safely in dungeon")
	check(dungeon_sim.hero().essences.has(ESSENCE), "Dungeon absorption grants ability")
	# Explicit test-only second filled item verifies duplicate and full-slot refusal.
	dungeon_sim.add_item(FILLED,1)
	rejected_absorption(dungeon_sim,"hero","Duplicate essence")
	dungeon_sim.hero().essences = ["canon_gnome"]
	rejected_absorption(dungeon_sim,"hero","Occupied sole level-one slot")
	dungeon_sim.hero().essences = []
	dungeon_sim.state.combat = true
	rejected_absorption(dungeon_sim,"hero","Sealed absorption during combat")
	dungeon_sim.state.combat = false
	dungeon_sim.hero().hp = 0
	dungeon_sim.hero().dead = true
	rejected_absorption(dungeon_sim,"hero","Dead recipient")
	dungeon_sim.hero().hp = dungeon_sim.hero().max_hp
	dungeon_sim.hero().dead = false
	rejected_absorption(dungeon_sim,"missing_unit","Unknown recipient")
	# The existing direct field absorption must honor the same mage restriction.
	place_drop(dungeon_sim)
	check(not dungeon_sim.absorb(ESSENCE,dungeon_sim.state.party[0].id).is_empty(), "Mage also cannot absorb an unsealed field drop")

	for reason: String in ["unknown mage","nonmage","nonmage with spell","dead","zero health","distant","wrong area","missing tube","combat","insufficient lifetime","less than sealing duration","unknown essence","paralyzed","stunned","portal deadline","over capacity","city"]:
		var failure_sim = fixture()
		var caster: Dictionary = failure_sim.state.party[0]
		var caster_id: String = caster.id
		var target_id: String = ESSENCE
		match reason:
			"unknown mage": caster_id = "missing_unit"
			"nonmage": caster.profession = "explorer"; caster.spells = []
			"nonmage with spell": caster.profession = "explorer"
			"dead": caster.dead = true
			"zero health": caster.hp = 0
			"distant": caster.pos = failure_sim.state.map.exit
			"wrong area": failure_sim.state.essence_drops[0].region = 2
			"missing tube": failure_sim.state.inventory.erase(EMPTY)
			"combat": failure_sim.state.combat = true
			"insufficient lifetime": place_drop(failure_sim,ESSENCE,0)
			"less than sealing duration": place_drop(failure_sim,ESSENCE,14)
			"unknown essence": target_id = "unknown_essence"
			"paralyzed": caster.statuses.paralyzed = 1
			"stunned": caster.statuses.stunned = 1
			"portal deadline":
				failure_sim.state.time = failure_sim.portal_limit() - 15
				place_drop(failure_sim)
			"over capacity": failure_sim.add_item("club",1000)
			"city": failure_sim.state.mode = "city"
		rejected_seal(failure_sim,caster_id,reason,target_id)

	var trading = fixture()
	check(trading.seal_essence(ESSENCE,trading.state.party[0].id).is_empty(), "Trading fixture seals tube")
	trading.state.mode = "city"
	var sell_value: int = trading.market_price(FILLED,false)
	var gold_before: int = int(trading.state.gold)
	check(trading.sell(FILLED).is_empty(), "Filled tube can be sold using generic market")
	check(int(trading.state.gold) == gold_before + sell_value and int(trading.state.inventory.get(FILLED,0)) == 0, "Selling pays displayed value and removes filled tube")
	var after_sale: String = resources(trading)
	check(not trading.sell(FILLED).is_empty(), "Sold filled tube cannot be sold again")
	check(resources(trading) == after_sale, "Repeated sale cannot create currency")
	for id: String in [EMPTY,FILLED]:
		for day: int in [1,2,30]:
			trading.state.day = day
			check(trading.market_price(id,true) > trading.market_price(id,false), "%s day%d has no buy/sell arbitrage" % [id,day])
	var trade_before: String = resources(trading)
	check(not trading.buy(FILLED).is_empty(), "Filled essences must be obtained rather than bought from infinite stock")
	check(resources(trading) == trade_before, "Refused filled purchase preserves resources")
	print("ESSENCE PRESERVATION: %d checks, %d failures. Assisted rule fixtures, actual recruitment/shop/sealing/absorption/storage/selling/JSON restore; no normal save files written." % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_attack_drop_boundary() -> void:
	var sim = fixture()
	# Use the actual default hero and default Goblin statistics, without changing
	# drop probability. Only encounter placement and the favorable RNG seed are
	# assisted. This verifies a naturally rolled drop after a real lethal attack.
	sim.state.essence_drops = []
	sim._recount_essence_drops()
	var target: Dictionary = sim.spawn_enemy(ESSENCE,sim.hero().pos + Vector2i.UP)
	var mage: Dictionary = sim.state.party[0]
	mage.pos = target.pos + Vector2i.RIGHT
	sim.update_visibility()
	var probability: float = float(sim.monster_defs[ESSENCE].essence_drop_chance)
	check(is_equal_approx(probability,0.0001),"Real-attack regression retains ordinary 0.01 percent drop probability")
	var accuracy: int = clampi(int(sim.hero().accuracy) - int(target.evasion),20,98)
	var probe := RandomNumberGenerator.new()
	var favorable_seed: int = -1
	var expected_rng_state: int = 0
	for candidate: int in range(2000000):
		probe.seed = candidate
		if probe.randi_range(1,100) <= accuracy and probe.randf() < probability:
			favorable_seed = candidate
			expected_rng_state = probe.state
			break
	check(favorable_seed >= 0,"Find reproducible ordinary hit plus rare-drop RNG sequence")
	if favorable_seed < 0: return
	sim.rng.seed = favorable_seed
	check(sim.state.combat,"Visible actual Goblin starts combat before attack")
	check(sim.attack(sim.hero(),target),"Actual default hero attacks actual default Goblin")
	check(int(target.hp) == 0 and target.dead,"Actual attack kills default Goblin without stat overrides")
	check(not sim.state.combat,"Actual post-kill visibility clears combat")
	check(int(sim.state.time) == 1,"Actual lethal attack advances the expedition clock")
	check(sim.rng.state == expected_rng_state,"Actual attack consumes the searched accuracy and rare-drop RNG sequence")
	check(sim.state.essence_drops.size() == 1,"Actual monster death creates the naturally rolled rare essence")
	if sim.state.essence_drops.size() != 1: return
	var drop: Dictionary = sim.state.essence_drops[0]
	check(drop.id == ESSENCE and drop.pos == target.pos,"Natural essence has correct species and physical kill location")
	check(int(drop.expires_at) == int(sim.state.time) + 29,"Real kill leaves twenty-nine minutes after attack clock cost")
	var deadline: int = int(drop.expires_at)
	sim.advance_time(14)
	check(int(sim.state.time) == deadline - 15 and sim.state.essence_drops.size() == 1,"Drop remains available for a fifteen-minute boundary seal after fourteen minutes waiting")
	check(sim.seal_essence(ESSENCE,mage.id).is_empty(),"Adjacent mage seals real kill drop exactly at approximate expiry boundary")
	check(int(sim.state.time) == deadline,"Boundary sealing finishes at the original absolute expiry")
	check(int(sim.state.inventory.get(FILLED,0)) == 1 and int(sim.state.inventory.get(EMPTY,0)) == 0,"Boundary seal conserves one physical container")
	check(sim.state.essence_drops.is_empty() and int(sim.state.loot_essences.get(ESSENCE,0)) == 0,"Boundary seal removes drop before expiry cleanup")
	print("REAL ATTACK RARE-DROP BOUNDARY: seed %d, unchanged chance %.5f, sealed at minute %d." % [favorable_seed,probability,deadline])
