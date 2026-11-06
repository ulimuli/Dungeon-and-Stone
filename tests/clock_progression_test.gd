extends SceneTree
## Minute-resolution simulation regression tests. Fixture placement/resources
## isolate clock rules; per-grid-action minutes remain implementation estimates.
const Simulation = preload("res://game/simulation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh(with_mage: bool = false) -> GameSimulation:
	var sim := Simulation.new()
	sim.new_campaign("Minute clock", "barbarian", "adventurer", 74119)
	sim.state.water=1000 # Isolate clock/food tests from independent water shortages.
	if with_mage:
		sim.state.gold = 4000 # Assisted supply budget; no income claim.
		check(sim.recruit("human_mage").is_empty(),"Clock fixture recruits generated mage")
		check(sim.buy("essence_test_tube").is_empty(),"Clock fixture buys physical tube")
	check(sim.enter_region(1),"Clock fixture enters actual expedition")
	sim.state.units = []; sim.state.combat = false
	if with_mage: sim.state.party[0].pos = sim.hero().pos + Vector2i.RIGHT
	return sim

func drop(sim: GameSimulation, id: String, area: int, deadline: int) -> void:
	sim.state.essence_drops.append({"id":id,"pos":sim.hero().pos,"region":area,"expires_at":deadline})
	sim._recount_essence_drops()

func _init() -> void:
	_test_actions_and_hours()
	_test_camp_and_food()
	_test_lifetimes_and_sealing()
	_test_portals_and_closure()
	_test_closure_overshoot()
	_test_legacy_clock_migration()
	print("CLOCK PROGRESSION: %d checks, %d failures. Actual action/camp/food/portal rules and schema2-to3 JSON migration; grid timing is estimated, no human balance claim." % [checks,failures])
	quit(1 if failures else 0)

func _test_actions_and_hours() -> void:
	var sim := fresh()
	check(int(sim.state.version) == 3,"Fresh campaigns use minute-clock schema3")
	check(sim.elapsed_hours() == 0.0,"New expedition starts at zero elapsed hours")
	var start: Vector2i = sim.hero().pos
	check(sim.move_unit(Vector2i.UP),"Actual exploration move succeeds")
	check(int(sim.state.time) == 1 and sim.hero().pos == start + Vector2i.UP,"One movement costs one minute rather than fifteen")
	check(sim.move_unit(Vector2i.DOWN),"Actual return movement succeeds")
	var target: Dictionary = sim.spawn_enemy("canon_goblin",start + Vector2i.UP)
	sim.update_visibility()
	sim.rng.seed = 11210 # Reproducible accuracy and natural rare drop, unchanged odds.
	check(sim.attack(sim.hero(),target),"Actual default melee attack resolves")
	check(int(sim.state.time) == 3,"Two moves plus one attack cost three minutes")
	check(not sim.state.combat and target.dead,"Lethal attack clears actual combat")
	sim.end_round()
	check(int(sim.state.time) == 4,"Waiting outside combat costs one minute")
	sim.advance_time(56)
	check(int(sim.state.time) == 60 and is_equal_approx(sim.elapsed_hours(),1.0),"Sixty accumulated minutes display as one hour")
	check(int(sim.state.food) == 10,"Ordinary minute actions do not consume a full day of food")

func _test_camp_and_food() -> void:
	var sim := fresh()
	var food_before: int = int(sim.state.food)
	for index: int in range(3):
		check(sim.camp(),"Actual safe eight-hour camp succeeds")
		check(int(sim.state.time) == (index+1)*480,"Camp advances exactly eight hours in minutes")
		check(is_equal_approx(sim.elapsed_hours(),float((index+1)*8)),"Camp elapsed-hours display matches real duration")
	check(int(sim.state.food) == food_before - 1,"Three camps consume exactly one day of shared food")
	var leap := fresh()
	leap.state.food = 10
	leap.advance_time(3*1440+12)
	check(int(leap.state.food) == 7 and int(leap.state.time) == 4332,"Multi-day advance charges every crossed day")
	leap.advance_time(1427)
	check(int(leap.state.food) == 7,"No ration charged one minute before next day")
	leap.advance_time(1)
	check(int(leap.state.food) == 6,"One minute across exact day boundary charges once")
	var starving := fresh()
	starving.state.food = 1
	var hp: int = int(starving.hero().hp)
	starving.advance_time(3*1440)
	check(int(starving.state.food) == 0 and int(starving.state.fatigue) == 2 and int(starving.hero().hp) < hp,"Every missed daily ration applies real hunger consequence")

func _test_lifetimes_and_sealing() -> void:
	var sim := fresh()
	drop(sim,"canon_goblin",1,30)
	drop(sim,"canon_gnome",2,30)
	sim.advance_time(29)
	check(sim.state.essence_drops.size() == 2,"Loose drops in both area tags survive twenty-nine minutes")
	sim.advance_time(1)
	check(sim.state.essence_drops.is_empty() and sim.state.loot_essences.is_empty(),"All loose drops expire exactly at thirty minutes")
	var sealing := fresh(true)
	drop(sealing,"canon_goblin",1,30)
	sealing.advance_time(15)
	var mana: int = int(sealing.state.party[0].mana)
	check(sealing.seal_essence("canon_goblin",sealing.state.party[0].id).is_empty(),"Fifteen-minute sealing can finish at loose deadline")
	check(int(sealing.state.time) == 30 and sealing.state.essence_drops.is_empty(),"Boundary seal advances clock to thirty minutes and removes loose drop")
	check(int(sealing.state.inventory.get("sealed_canon_goblin",0)) == 1 and int(sealing.state.party[0].mana) == mana,"Seal preserves actual item without invented mana cost")
	sealing.advance_time(60)
	check(int(sealing.state.inventory.get("sealed_canon_goblin",0)) == 1,"Filled tube survives an additional real hour")
	var short := fresh(true)
	drop(short,"canon_goblin",1,14)
	var before: String = var_to_str(short.state.inventory)
	check(not short.seal_essence("canon_goblin",short.state.party[0].id).is_empty(),"Fourteen minutes cannot support fifteen-minute sealing")
	check(int(short.state.time) == 0 and var_to_str(short.state.inventory) == before and short.state.essence_drops.size() == 1,"Insufficient-time rejection preserves clock, container and essence")

func _test_portals_and_closure() -> void:
	var cave := fresh()
	check(cave.portal_limit() == 10080,"Crystal Cave closes after seven days in minutes")
	cave.state.food = 100
	cave.add_item("mana_stone_rank_9",2,true)
	cave.advance_time(10079)
	check(cave.state.mode == "dungeon","Cave remains open one minute before seven-day closure")
	cave.advance_time(1)
	check(cave.state.mode == "city" and int(cave.state.time) == 10080 and is_equal_approx(cave.elapsed_hours(),168.0),"Exact seven-day boundary returns survivors through actual transition")
	check(int(cave.state.inventory.get("mana_stone_rank_9",0)) == 2 and int(cave.state.day) == 2,"Closure banks earned loot and advances city day once")
	for area: int in [2,3,4]:
		var deeper := fresh()
		deeper.hero().pos = EarlyFloorRules.return_anchor(deeper.state.map,int(area)) # Harness traversal placement only.
		check(deeper.travel_region(area),"Actual area portal accepts deeper destination")
		deeper.state.units = []; deeper.state.combat = false; deeper.state.food = 100
		check(int(deeper.state.time) == 1 and deeper.portal_limit() == 14400,"Crossing costs one minute and deeper deadline is ten days")
		deeper.hero().pos = deeper.state.map.entrance
		deeper.advance_time(10080-int(deeper.state.time))
		check(deeper.state.mode == "dungeon","Second floor survives past cave closure")
		check(not deeper.travel_region(1) and int(deeper.state.region) == area,"Seven-day cave return is blocked using minute clock")
		deeper.advance_time(14399-int(deeper.state.time))
		check(deeper.state.mode == "dungeon","Second floor remains open one minute before tenth day")
		deeper.advance_time(1)
		check(deeper.state.mode == "city" and int(deeper.state.time) == 14400 and is_equal_approx(deeper.elapsed_hours(),240.0),"Ten-day exact boundary returns survivor")

func _test_legacy_clock_migration() -> void:
	var source := fresh(true)
	source.hero().pos = EarlyFloorRules.return_anchor(source.state.map,int(2))
	check(source.travel_region(2),"Migration fixture creates actual area memory")
	source.state.units = []; source.state.combat = false
	source.hero().essences = ["canon_goblin"]
	source.hero().cooldowns = {"canon_goblin":2}
	source.hero().statuses = {"chilled":3}
	source.hero().status_power = {"chilled":1}
	source.state.party[0].cooldowns = {"ice_spear":4}
	source.rng.randi()
	var legacy: Dictionary = source.snapshot()
	legacy.version = 2
	legacy.time = 17 # Legacy quarter-hour beats, deliberately not minutes.
	legacy.essence_drops = [
		{"id":"canon_goblin","pos":legacy.hero.pos,"region":1,"expires_at":19},
		{"id":"canon_gnome","pos":legacy.hero.pos,"region":2,"expires_at":20}]
	legacy.loot_essences = {"canon_goblin":1,"canon_gnome":1}
	legacy.terrain_effects = [{"pos":legacy.hero.pos,"team":"ally","owner":"hero","radius":3,"damage":0,"type":"concealment","turns":5}]
	var raw: Dictionary = JSON.parse_string(JSON.stringify(legacy))
	var raw_before: String = JSON.stringify(raw)
	var rng_before: int = source.rng.state
	var migrated := Simulation.new()
	check(migrated.restore(raw),"Legacy JSON snapshot restores through real migration")
	check(JSON.stringify(raw) == raw_before,"Clock migration leaves supplied legacy JSON unchanged")
	if migrated.state.is_empty(): return
	check(int(migrated.state.version) == 3 and int(migrated.state.time) == 255,"Legacy seventeen quarter-hours become255minutes once")
	check(is_equal_approx(migrated.elapsed_hours(),4.25),"Legacy elapsed real hours are conserved")
	check(migrated.state.essence_drops.size() == 2,"Both area-tagged intact drops survive migration")
	if migrated.state.essence_drops.size() == 2:
		check(int(migrated.state.essence_drops[0].expires_at) == 285 and int(migrated.state.essence_drops[1].expires_at) == 300,"All region-tagged absolute expiry deadlines scale by15")
	check(int(migrated.hero().cooldowns.get("canon_goblin",-1)) == 2 and int(migrated.state.party[0].cooldowns.get("ice_spear",-1)) == 4,"Essence and spell cooldowns remain round counts")
	check(int(migrated.hero().statuses.get("chilled",-1)) == 3 and int(migrated.state.terrain_effects[0].turns) == 5,"Status and temporary-terrain durations are not multiplied")
	check(migrated.state.floor_memory.has("1") and int(migrated.state.floor_memory["1"].map.area) == 1,"Migration preserves actual prior-region geography")
	print("CLOCK RNG DIAGNOSTIC: campaign_seed=%d source_rng_seed=%d restored_rng_seed=%d saved_state=%d restored_state=%d" % [int(source.state.seed),source.rng.seed,migrated.rng.seed,rng_before,migrated.rng.state])
	check(migrated.rng.state == rng_before and int(migrated.state.seed) == int(source.state.seed),"Clock migration preserves saved campaign seed and exact RNG stream state")
	for index: int in range(6):
		check(source.rng.randi() == migrated.rng.randi(),"Original expedition and migrated save produce identical subsequent RNG output")
	var current: Dictionary = JSON.parse_string(JSON.stringify(migrated.snapshot()))
	var again := Simulation.new()
	check(again.restore(current),"Migrated schema3 snapshot restores again")
	check(int(again.state.time) == 255 and int(again.state.essence_drops[0].expires_at) == 285,"Current schema does not receive a second times15 conversion")
	for index: int in range(6):
		check(migrated.rng.randi() == again.rng.randi(),"Migrated and current snapshots produce identical subsequent RNG output")
	var state_before: String = var_to_str(again.state)
	var random_before: int = again.rng.state
	var invalid: Dictionary = raw.duplicate(true)
	invalid.time = "seventeen"
	check(not again.restore(invalid),"Malformed legacy clock is rejected before migration arithmetic")
	check(var_to_str(again.state) == state_before and again.rng.state == random_before,"Failed legacy migration leaves running state and RNG intact")

func _test_closure_overshoot() -> void:
	var near_close := fresh()
	near_close.state.food = 100
	near_close.advance_time(10070)
	var food: int = int(near_close.state.food)
	check(near_close.camp(),"Camp begun ten minutes before closure resolves through actual transition")
	check(near_close.state.mode == "city" and int(near_close.state.time) == 10080,"Camp stops at closure instead of overshooting by470minutes")
	check(int(near_close.state.food) == food - 1,"Closing camp charges only the crossed closing-day ration")
	var huge := fresh()
	huge.state.food = 7
	huge.advance_time(30*1440)
	check(huge.state.mode == "city" and int(huge.state.time) == 10080,"Month-sized leap is capped at seven-day portal deadline")
	check(int(huge.state.food) == 0 and int(huge.state.fatigue) == 0 and int(huge.hero().hp) > 0,"Huge advance cannot charge post-closure rations or kill returned survivor")
	var already_closed := fresh()
	already_closed.state.time = already_closed.portal_limit() # Legacy/assisted overdue-state guard.
	food = int(already_closed.state.food)
	already_closed.advance_time(1)
	check(already_closed.state.mode == "city" and int(already_closed.state.time) == 10080,"Already-closed dungeon returns immediately without another minute")
	check(int(already_closed.state.food) == food,"Already-closed guard does not charge another ration")
