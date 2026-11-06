extends SceneTree

const Simulation = preload("res://game/simulation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> GameSimulation:
	var sim := Simulation.new()
	sim.new_campaign("Lifetime fixture", "barbarian", "adventurer", 74119)
	sim.enter_region(1)
	sim.state.units = []
	sim.state.combat = false
	return sim

func place(sim: GameSimulation, id: String, pos: Vector2i, region: int = -1, expiry: int = -1) -> void:
	sim.state.essence_drops.append({"id": id, "pos": pos, "region": int(sim.state.region) if region < 0 else region, "expires_at": int(sim.state.time) + 30 if expiry < 0 else expiry})
	sim.state.loot_essences[id] = int(sim.state.loot_essences.get(id, 0)) + 1

func _initialize() -> void:
	_test_real_drop()
	_test_expiry()
	_test_absorption()
	_test_region_and_travel()
	_test_persistence()
	_test_city_return()
	print("ESSENCE LIFETIME: %d checks, %d failures. Thirty-minute lifetimes on a minute-resolution simulation clock; fixtures isolate rules, not balance." % [checks, failures])
	quit(1 if failures else 0)

func _test_real_drop() -> void:
	var sim := fresh()
	check(is_equal_approx(float(sim.monster_defs.canon_goblin.essence_drop_chance), 0.0001), "Ordinary rank-nine essence baseline is 0.01 percent")
	# Find a favorable random state without changing the actual production odds.
	var fixture_rng := RandomNumberGenerator.new()
	fixture_rng.seed = 19
	var favorable_state: int = fixture_rng.state
	for index: int in range(1000000):
		favorable_state = fixture_rng.state
		if fixture_rng.randf() < 0.0001: break
	sim.rng.state = favorable_state
	var enemy: Dictionary = sim.spawn_enemy("canon_goblin", sim.hero().pos + Vector2i.RIGHT)
	sim.hit(sim.hero(), enemy, 99999, "physical", "Death/drop fixture", false, true)
	check(not sim.state.essence_drops.is_empty(), "Actual monster death produces a timestamped drop under a fixed RNG")
	if sim.state.essence_drops.is_empty(): return
	var drop: Dictionary = sim.state.essence_drops[0]
	check(drop.id == "canon_goblin" and drop.pos == sim.hero().pos + Vector2i.RIGHT, "Drop retains actual monster position and stable essence ID")
	check(drop.region == sim.state.region and drop.expires_at == sim.state.time + 30, "Drop is area-tagged and expires thirty minutes later")
	check(sim.state.loot_essences.canon_goblin == 1, "Drop appears once in the UI count")

func _test_expiry() -> void:
	var sim := fresh()
	place(sim, "canon_goblin", sim.hero().pos)
	place(sim, "canon_goblin_archer", sim.hero().pos)
	sim.advance_time(1)
	check(sim.state.essence_drops.size() == 2 and sim.state.loot_essences.size() == 2, "Drops survive the first minute")
	sim.advance_time(29)
	check(sim.state.essence_drops.is_empty() and sim.state.loot_essences.is_empty(), "Drops expire at the exact thirty-minute boundary")
	var notices: int = 0
	for line: String in sim.state.log:
		if line.contains("fade after thirty minutes"): notices += 1
	check(notices == 1, "Multiple simultaneous expirations produce one log message")
	sim.advance_time(1)
	var later_notices: int = 0
	for line: String in sim.state.log:
		if line.contains("fade after thirty minutes"): later_notices += 1
	check(later_notices == 1, "Expired drops never repeat their notification")
	place(sim, "canon_goblin", sim.hero().pos)
	sim.advance_time(60)
	check(sim.state.essence_drops.is_empty(), "Large time advances cannot skip expiration")

func _test_absorption() -> void:
	var sim := fresh()
	var origin: Vector2i = sim.hero().pos
	place(sim, "canon_goblin", origin + Vector2i(3, 0))
	check(not sim.absorb("canon_goblin").is_empty() and sim.hero().essences.is_empty(), "Remote loot count does not allow remote absorption")
	sim.hero().pos = origin + Vector2i(2, 0)
	check(sim.absorb("canon_goblin").is_empty(), "A living recipient within one tile can absorb the actual drop")
	check(sim.hero().essences == ["canon_goblin"] and sim.state.essence_drops.is_empty() and sim.state.loot_essences.is_empty(), "Absorption consumes one physical drop and its UI count")
	place(sim, "canon_goblin", sim.hero().pos)
	check(not sim.absorb("canon_goblin").is_empty() and sim.state.essence_drops.size() == 1, "Duplicate rejection leaves the physical drop available")
	var dead := fresh()
	place(dead, "canon_goblin", dead.hero().pos)
	dead.hero().hp = 0
	check(not dead.absorb("canon_goblin").is_empty() and dead.state.essence_drops.size() == 1, "Dead recipient cannot absorb")
	var phantom := fresh()
	phantom.state.loot_essences.canon_goblin = 1
	check(not phantom.absorb("canon_goblin").is_empty(), "Inventory-only fixture cannot bypass physical drop requirement")
	var stale := fresh()
	place(stale, "canon_goblin", stale.hero().pos, -1, int(stale.state.time))
	check(not stale.absorb("canon_goblin").is_empty() and stale.state.essence_drops.is_empty(), "Absorption validates expiry even before a later time update")
	var companion := fresh()
	companion.state.gold = 500
	# Recruitment is city-only, so construct a controlled party recipient here.
	var recipient: Dictionary = companion.make_unit("companion_fixture", "Recipient", "ally", "tank")
	recipient.content_id = "dwarf_guard"
	recipient.pos = companion.hero().pos + Vector2i(4, 0)
	companion.state.party.append(recipient)
	place(companion, "canon_goblin", companion.hero().pos)
	check(not companion.absorb("canon_goblin", recipient.id).is_empty(), "Hero proximity cannot substitute for the selected companion recipient's proximity")
	recipient.pos = companion.hero().pos + Vector2i.RIGHT
	check(companion.absorb("canon_goblin", recipient.id).is_empty() and recipient.essences.has("canon_goblin"), "A nearby living companion can absorb the drop instead of the hero")
	var multiple := fresh()
	place(multiple, "canon_goblin", multiple.hero().pos)
	place(multiple, "canon_goblin", multiple.hero().pos + Vector2i.RIGHT)
	check(multiple.absorb("canon_goblin").is_empty() and multiple.state.essence_drops.size() == 1 and multiple.state.loot_essences.canon_goblin == 1, "Absorption consumes exactly one of multiple identical drops")
	var portal := fresh()
	place(portal, "canon_goblin", portal.hero().pos)
	check(portal.interact() == "essence", "Nearby essence interaction takes priority over the arrival portal")
	portal.hero().pos = portal.state.map.exit
	place(portal, "canon_goblin_archer", portal.hero().pos)
	check(portal.interact() == "essence", "Nearby essence interaction takes priority over the onward portal")

func _test_region_and_travel() -> void:
	var sim := fresh()
	place(sim, "canon_goblin", sim.hero().pos, 2)
	check(not sim.absorb("canon_goblin").is_empty(), "Matching coordinates in another region cannot be absorbed")
	sim.advance_time(30)
	check(sim.state.essence_drops.is_empty(), "Drops in other regions still expire against the global clock")
	var travel := fresh()
	travel.hero().pos = EarlyFloorRules.return_anchor(travel.state.map,2)
	place(travel, "canon_goblin", travel.hero().pos)
	check(travel.travel_region(2), "Actual portal crossing succeeds with a dropped essence behind")
	check(travel.state.essence_drops.size() == 1 and travel.state.essence_drops[0].region == 1, "Crossing preserves the drop's original area rather than moving it with the party")
	check(not travel.absorb("canon_goblin").is_empty(), "The carried UI count cannot consume the abandoned area's drop")
	travel.advance_time(29)
	check(travel.state.essence_drops.is_empty() and travel.state.loot_essences.is_empty(), "Global deadline clears an abandoned drop after travel")

func _test_persistence() -> void:
	var sim := fresh()
	place(sim, "canon_goblin", sim.hero().pos)
	sim.advance_time(15)
	var snapshot: Dictionary = sim.snapshot()
	var restored := Simulation.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Save snapshot with physical drops restores")
	var saved_drop: Dictionary = restored.state.essence_drops[0]
	var original_drop: Dictionary = sim.state.essence_drops[0]
	check(saved_drop.id == original_drop.id and saved_drop.pos == original_drop.pos and int(saved_drop.region) == int(original_drop.region) and int(saved_drop.expires_at) == int(original_drop.expires_at) and int(restored.state.time) == int(sim.state.time), "Exact position, region, expiry and current clock persist")
	check(restored.absorb("canon_goblin").is_empty(), "Restored nearby drop remains usable before its deadline")
	var expiring := Simulation.new()
	expiring.restore(snapshot)
	expiring.advance_time(15)
	check(expiring.state.essence_drops.is_empty(), "Saving and loading does not refresh the lifetime")
func _test_city_return() -> void:
	var sim := fresh()
	place(sim, "canon_goblin", sim.hero().pos)
	check(sim.extract(true), "Closure return uses the actual extraction transition")
	check(sim.state.mode == "city" and sim.state.essence_drops.is_empty() and sim.state.loot_essences.is_empty(), "Uncontained essences are discarded instead of automatically banked")
	check(not sim.absorb("canon_goblin").is_empty(), "City cannot absorb a discarded uncontained essence")
	var direct := fresh()
	place(direct, "canon_goblin", direct.hero().pos)
	direct.return_city()
	check(direct.state.essence_drops.is_empty() and direct.state.loot_essences.is_empty(), "Direct city return also clears uncontained drops")
