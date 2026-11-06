extends SceneTree

const Simulation = preload("res://game/simulation.gd")
const City = preload("res://game/city_life.gd")
const Art = preload("res://game/character_art.gd")
const Content = preload("res://game/content.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(ancestry: String = "") -> GameSimulation:
	var sim := Simulation.new()
	var race_id: String = str(Content.ancestries().keys()[0]) if ancestry.is_empty() else ancestry
	var background_id: String = str(Content.backgrounds().keys()[0])
	sim.new_campaign("City wrapper test", race_id, background_id, 74119)
	return sim

func recruit_id(sim: GameSimulation) -> String:
	for id: String in sim.companion_defs:
		if int(sim.companion_defs[id].get("unlock_region", 1)) <= int(sim.state.unlocked): return id
	return ""

func shop_item(sim: GameSimulation) -> String:
	var candidate: String = ""
	var best_price: int = -1
	for id: String in sim.item_defs:
		var item: Dictionary = sim.item_defs[id]
		var price: int = int(item.get("price", 0))
		if str(item.kind) == "material" or price > 80 + int(sim.state.unlocked) * 50: continue
		if float(item.get("weight", 0)) + sim.weight() > sim.capacity(): continue
		if price > best_price: best_price = price; candidate = id
	return candidate

func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func alternate(look: Dictionary) -> Dictionary:
	var changed: Dictionary = look.duplicate(true)
	changed.hair_color = "gold" if str(changed.hair_color) != "gold" else "black"
	return changed

func _initialize() -> void:
	_test_services()
	_test_market()
	_test_companion_routing()
	_test_customization()
	_test_restore_and_dungeon_boundaries()
	print("CITY SIMULATION: %d checks, %d failures. Actual wrappers/services, generated recruitment routing and cosmetic persistence. No player save slots used." % [checks, failures])
	quit(1 if failures else 0)

func _test_services() -> void:
	var sim := fresh()
	check(sim.state.city_life.npcs.size() == 12 + Content.companions().size() and sim.hero().has("appearance"), "New campaign initializes real city and hero appearance")
	sim.state.gold = 100
	sim.hero().hp = 1
	sim.hero().energy = 0
	var result: Dictionary = sim.interact_npc("innkeeper", "service:rest")
	check(result.ok and int(sim.state.gold) == 94, "NPC rest wrapper charges its six-stone fee exactly once")
	check(sim.hero().hp == sim.hero().max_hp and sim.hero().energy == sim.hero().max_energy, "NPC rest invokes real health/resource recovery")
	check(City.market_discount(sim.state, "innkeeper") == 0, "Service routing creates no price modifier")
	var food: int = int(sim.state.food)
	result = sim.interact_npc("innkeeper", "service:rations")
	check(result.ok and int(sim.state.gold) == 86 and int(sim.state.food) == food + 4, "NPC food service consumes eight stones and grants four food once")
	sim.hero().durability = 0
	sim.recalculate(sim.hero())
	var broken_power: int = int(sim.hero().power)
	result = sim.interact_npc("smith", "service:repair")
	check(result.ok and int(sim.state.gold) == 80 and int(sim.hero().durability) == 100, "NPC repair uses its actual six-stone fee and restores durability")
	check(int(sim.hero().power) > broken_power, "Repair restores the actual worn weapon's effective power")
	check(not sim.interact_npc("innkeeper", "service:repair").ok and int(sim.state.gold) == 80, "Wrong NPC cannot dispatch a forged service or charge")
	for service: String in ["rest", "rations", "repair"]:
		var poor := fresh()
		poor.state.gold = 0
		poor.hero().hp = 1
		poor.hero().energy = 0
		poor.hero().durability = 0
		var before_unit: Dictionary = poor.hero().duplicate(true)
		var before_food: int = int(poor.state.food)
		var before_city: Dictionary = poor.state.city_life.duplicate(true)
		var local: String = "smith" if service == "repair" else "innkeeper"
		var failed: Dictionary = poor.interact_npc(local, "service:" + service)
		check(not failed.ok and int(poor.state.gold) == 0, "Unaffordable NPC service rejects without charge: " + service)
		check(same(poor.hero(), before_unit) and int(poor.state.food) == before_food and same(poor.state.city_life, before_city), "Failed service grants no recovery, food, relation or reward: " + service)
	var group := fresh()
	group.state.gold = 500
	check(group.recruit(recruit_id(group)).is_empty(), "Party-size rest fixture recruits through actual command")
	var before_group_gold: int = int(group.state.gold)
	group.hero().hp = 1
	group.state.party[0].hp = 1
	check(group.interact_npc("innkeeper", "service:rest").ok and int(group.state.gold) == before_group_gold - 9, "NPC rest charges the correct actual party-size fee once")
	check(group.state.party[0].hp == group.state.party[0].max_hp, "Rest restores actual companion as well as hero")

func _test_market() -> void:
	var sim := fresh()
	sim.state.gold = 1000
	for faction: String in sim.state.rep: sim.state.rep[faction] = 18
	var item_id: String = shop_item(sim)
	check(not item_id.is_empty(), "Current catalog has eligible market stock for conservation test")
	var normal: int = sim.market_price(item_id, true)
	var discounted: int = sim.market_price(item_id, true, "merchant")
	var resale: int = sim.market_price(item_id, false)
	check(discounted == normal and discounted >= resale, "Actual NPC buying uses ordinary market terms without resale profit")
	check(sim.market_price(item_id, false, "merchant") == resale, "NPC discount never increases the actual resale price")
	var gold: int = int(sim.state.gold)
	var count: int = int(sim.state.inventory.get(item_id, 0))
	check(sim.buy(item_id, "merchant").is_empty(), "Actual buy accepts a valid trading NPC")
	check(int(sim.state.gold) == gold - discounted and int(sim.state.inventory.get(item_id, 0)) == count + 1, "Purchase conserves exact currency and item count")
	check(sim.sell(item_id).is_empty(), "Actual sale consumes the bought item")
	check(int(sim.state.gold) == gold - discounted + resale and int(sim.state.inventory.get(item_id, 0)) == count, "Buying/selling returns original inventory with no money gain")
	sim.state.rep[str(sim.state.rep.keys()[0])] = 10000
	check(sim.market_price(item_id, true, "merchant") == discounted, "Faction price modifier remains bounded at extreme values")
	check(sim.market_price(item_id, true, "innkeeper") == normal and sim.market_price(item_id, true, "unknown") == normal, "Nontraders and unknown NPC IDs cannot forge a discount")
	for id: String in sim.item_defs:
		check(sim.market_price(id, false, "merchant") <= sim.market_price(id, true, "merchant"), "No item permits maximal-discount retail/resale arbitrage: " + id)
	var before_buy: Dictionary = sim.state.inventory.duplicate(true)
	sim.state.gold = discounted - 1
	check(not sim.buy(item_id, "merchant").is_empty() and int(sim.state.gold) == discounted - 1 and same(sim.state.inventory, before_buy), "Insufficient discounted funds cannot create items or charge money")

func _test_companion_routing() -> void:
	var sim := fresh()
	var before_gold: int = int(sim.state.gold)
	var before_food: int = int(sim.state.food)
	var before_bag: Dictionary = sim.state.inventory.duplicate(true)
	check(City.tasks(sim.state).is_empty(), "No unsourced city tasks enter campaign progression")
	for id: String in Content.companions():
		var result: Dictionary = sim.interact_npc("companion_" + id, "open:companions")
		check(result.ok and result.open == "companions" and result.companion_id == id, "Generated adventurer opens real recruitment UI: " + id)
		check(int(sim.state.gold) == before_gold and int(sim.state.food) == before_food and same(sim.state.inventory, before_bag), "Opening companion record cannot charge or award resources")
	for choice: String in ["talk", "accept:unknown", "complete:unknown"]:
		check(not sim.interact_npc("merchant", choice).ok and int(sim.state.gold) == before_gold, "Unsupported conversation cannot create currency or progression")
	for id: String in sim.state.city_life.npcs:
		check(sim.market_price(shop_item(sim), true, id) == sim.market_price(shop_item(sim), true), "NPC identity has no unsourced price effect: " + id)

func _test_customization() -> void:
	for ancestry: String in Content.ancestries():
		var sim := fresh(ancestry)
		sim.state.gold = 20
		var look: Dictionary = alternate(sim.hero().appearance)
		var unchanged_stats: Dictionary = sim.hero().duplicate(true)
		unchanged_stats.erase("appearance")
		var rng_before: int = sim.rng.state
		check(sim.customize("hero", look).is_empty() and int(sim.state.gold) == 15, "Appearance changes cost exactly five stones for ancestry: " + ancestry)
		var after_stats: Dictionary = sim.hero().duplicate(true)
		after_stats.erase("appearance")
		check(same(after_stats, unchanged_stats) and sim.rng.state == rng_before, "Cosmetic edit changes no stats, equipment, resources or simulation RNG: " + ancestry)
		check(sim.hero().appearance == Art.normalize(look, sim.unit_ancestry(sim.hero())), "Actual edited appearance is normalized and saved: " + ancestry)
		check(sim.customize("hero", look) == "No changes." and int(sim.state.gold) == 15, "Unchanged appearance is not charged: " + ancestry)
		var equivalent: Dictionary = look.duplicate(true)
		equivalent.ignored_field = "not an appearance parameter"
		check(sim.customize("hero", equivalent) == "No changes." and int(sim.state.gold) == 15, "Ignored fields cannot trigger a spurious cosmetic charge: " + ancestry)
		var existing: Dictionary = sim.hero().appearance.duplicate(true)
		sim.state.gold = 4
		check(not sim.customize("hero", alternate(existing)).is_empty() and int(sim.state.gold) == 4 and sim.hero().appearance == existing, "Unaffordable appearance edit is atomic: " + ancestry)
	var companion := fresh()
	companion.state.gold = 500
	check(companion.recruit(recruit_id(companion)).is_empty(), "Companion cosmetic fixture uses actual recruitment")
	var unit: Dictionary = companion.state.party[0]
	var before_gold: int = int(companion.state.gold)
	check(companion.customize(unit.id, alternate(unit.appearance)).is_empty() and int(companion.state.gold) == before_gold - 5, "Living companion appearance uses the same real five-stone service")
	unit.dead = true
	check(not companion.customize(unit.id, alternate(unit.appearance)).is_empty() and int(companion.state.gold) == before_gold - 5, "Dead or missing companion cannot trigger a cosmetic charge")
	check(not companion.customize("missing", {}).is_empty() and int(companion.state.gold) == before_gold - 5, "Unknown recipient is rejected without charge")

func _test_restore_and_dungeon_boundaries() -> void:
	var sim := fresh()
	sim.state.gold = 500
	sim.recruit(recruit_id(sim))
	sim.customize("hero", alternate(sim.hero().appearance))
	sim.customize(sim.state.party[0].id, alternate(sim.state.party[0].appearance))
	sim.interact_npc("smith", "open:inventory")
	var before_city: Dictionary = sim.state.city_life.duplicate(true)
	var before_hero: Dictionary = sim.hero().appearance.duplicate(true)
	var before_companion: Dictionary = sim.state.party[0].appearance.duplicate(true)
	var rng_before: int = sim.rng.state
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored := Simulation.new()
	check(restored.restore(snapshot), "Actual snapshot/restore loads city state and appearances")
	check(same(restored.state.city_life, before_city), "Service identities and distinct appearances survive JSON round trip")
	check(same(restored.hero().appearance, before_hero) and same(restored.state.party[0].appearance, before_companion), "Hero and companion cosmetic changes survive JSON round trip")
	check(restored.rng.state == rng_before, "City restore preserves the exact simulation RNG stream")
	var restored_gold: int = int(restored.state.gold)
	check(not restored.interact_npc("smith", "complete:unknown").ok and int(restored.state.gold) == restored_gold, "Restored simulation refuses unsupported reward actions")
	var without_city: Dictionary = snapshot.duplicate(true)
	without_city.erase("city_life")
	var older := Simulation.new()
	check(older.restore(without_city), "Restore accepts snapshot missing optional city state: " + str(preload("res://game/save_validation.gd").validate(without_city)))
	if not older.state.is_empty(): check(City.roster(older.state).size() == 12 + Content.companions().size() - older.state.roster.size(), "Restored city shows service operators and available recruits, excluding active party")
	check(sim.enter_region(1), "Dungeon boundary fixture enters actual reconstruction expedition")
	var dungeon_gold: int = int(sim.state.gold)
	var dungeon_food: int = int(sim.state.food)
	var dungeon_city: Dictionary = sim.state.city_life.duplicate(true)
	var dungeon_look: Dictionary = sim.hero().appearance.duplicate(true)
	for choice: String in ["talk", "service:rest", "service:rations", "accept:unknown", "complete:unknown", "open:market"]:
		check(not sim.interact_npc("innkeeper", choice).ok, "Real wrapper blocks city interaction during expedition: " + choice)
	check(not sim.customize("hero", alternate(dungeon_look)).is_empty(), "Appearance service is unavailable during expedition")
	check(not sim.buy(shop_item(sim), "merchant").is_empty(), "NPC buying cannot bypass the city boundary")
	check(int(sim.state.gold) == dungeon_gold and int(sim.state.food) == dungeon_food and same(sim.state.city_life, dungeon_city) and sim.hero().appearance == dungeon_look, "Rejected dungeon actions conserve purse, food, operator records and appearance")
