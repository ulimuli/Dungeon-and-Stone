extends SceneTree

const Reference = preload("res://game/content_reference.gd")
const Simulation = preload("res://game/simulation.gd")
const Runtime = preload("res://game/reference_runtime.gd")
const Content = preload("res://game/content.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _init() -> void:
	_test_catalogue()
	_test_floor_and_knowledge()
	_test_portal_travel()
	_test_closure()
	_test_essence_effects()
	_test_paralysis_boundaries()
	_test_permanent_death_and_party()
	_test_combat_potion_restriction()
	print("REFERENCE RULES: %d checks, %d failures. Runtime coverage uses assisted fixtures; combat numbers and geography remain provisional." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_catalogue() -> void:
	var regions: Dictionary = Reference.regions()
	var monsters: Dictionary = Reference.monsters()
	var cave: Dictionary = regions["canon_crystal_cave"]
	var first_ids: Array = cave.enemy_ids.duplicate()
	first_ids.sort()
	var expected: Array[String] = ["canon_blade_wolf", "canon_ghoul", "canon_gnome", "canon_goblin"]
	expected.sort()
	check(first_ids == expected, "First-floor pool is the four researched regular species")
	check(not cave.enemy_ids.has("canon_goblin_archer") and not cave.enemy_ids.has("canon_skeleton") and not cave.enemy_ids.has("canon_slime"), "Second-floor/rift species excluded from ordinary cave spawns")
	check(int(cave.floor) == 1 and int(cave.portal_closes_after_days) == 7, "Cave metadata records first floor and seven-day closure")
	for id: String in cave.enemy_ids:
		check(monsters.has(id), "Every first-floor spawn ID resolves: " + id)
		check(int(monsters[id].rank) == 9, "First-floor species retain recorded rank9: " + id)
	for id: String in cave.exit_regions:
		check(regions.has(id) and int(regions[id].floor) == 2, "Referenced second-floor exit resolves: " + id)
		check(int(regions[id].portal_closes_after_days) == 10, "Second-floor closure metadata is ten days")
	check(not bool(regions["canon_green_iron_mine"].playable), "Unimplemented rift is not presented as playable")
	for id: String in monsters:
		var monster: Dictionary = monsters[id]
		check(not monster.reference_urls.is_empty(), "Species provenance present: " + id)
		check(monster.experimental_numeric_fields.has("hp") and monster.experimental_numeric_fields.has("power"), "Provisional combat numbers labeled: " + id)
	for id: String in Reference.essences():
		var essence: Dictionary = Reference.essences()[id]
		check(not essence.reference_urls.is_empty() and not essence.novel_chapters.is_empty(), "Essence provenance/chapter leads retained: " + id)
		check(not bool(essence.ability.numeric_parameters_verified), "Unknown essence numbers not mislabeled verified: " + id)
		check(not bool(essence.playable) and bool(essence.requires_implementation), "Unimplemented research essence not advertised as playable: " + id)

func fresh() -> GameSimulation:
	var sim := Simulation.new()
	sim.new_campaign("Reference test", "barbarian", "adventurer", 74119)
	sim.state.water=1000
	return sim

func drop_fixture(sim: GameSimulation, id: String) -> void:
	# Physical, area-tagged fixture with the real thirty-minute expiry boundary.
	sim.state.essence_drops.append({"id": id, "pos": sim.hero().pos, "region": int(sim.state.region), "expires_at": int(sim.state.time) + 30})
	sim._recount_essence_drops()

func _test_floor_and_knowledge() -> void:
	var sim := fresh()
	check(int(sim.state.version) == 3 and sim.state.mode == "city", "New campaign initializes current city save schema")
	check(sim.essence_defs.size() == 7 and sim.monster_defs.has("canon_goblin"), "Runtime activates only supported reference essences and species")
	check(not sim.enter_region(2), "Deeper areas cannot be entered directly from city")
	check(sim.enter_region(1), "Reference cave expedition enters")
	check(sim.floor_number() == 1 and sim.portal_limit() == 10080, "First-floor closure is 168 hours / 10080 minutes")
	for enemy: Dictionary in sim.enemies():
		check(enemy.content_id in ["canon_goblin", "canon_ghoul", "canon_gnome", "canon_blade_wolf"] , "Cave pool contains only researched regular species")
	for key: String in ["width", "height", "tiles", "entrance", "exit", "spawns", "traps", "rooms", "seed", "area"]:
		check(sim.state.map.has(key), "Generated cave contains required field: " + key)
	check(not sim.extract() and sim.state.mode == "dungeon", "Arrival portal is not an ordinary extraction stair")
	sim.state.units = []
	var first: Dictionary = sim.spawn_enemy("canon_goblin", sim.hero().pos + Vector2i.RIGHT)
	sim.hit(sim.hero(), first, 100000, "physical", "Assisted first-kill fixture", false, true)
	var xp: int = int(sim.state.xp)
	check(xp == int(sim.monster_defs.canon_goblin.xp), "First kill of species grants recorded knowledge XP")
	var second: Dictionary = sim.spawn_enemy("canon_goblin", sim.hero().pos + Vector2i.RIGHT)
	sim.hit(sim.hero(), second, 100000, "physical", "Assisted duplicate fixture", false, true)
	check(int(sim.state.xp) == xp and int(sim.state.killed.canon_goblin) == 2, "Second identical species gives zero XP")
	check(int(sim.state.loot_items.get("mana_stone_rank_9", 0)) == 2 and int(sim.state.loot_gold) == 0, "Each normal kill yields one rank-nine mana stone")
	for level in [1, 2, 4, 11]:
		sim.state.level = level
		check(sim.essence_capacity() == level, "Essence slot capacity equals level %d" % level)

func _test_portal_travel() -> void:
	var sim := fresh()
	check(sim.enter_region(1), "Portal fixture enters cave")
	sim.state.units = []
	sim.state.combat = false
	check(not sim.travel_region(2), "Area change requires portal proximity")
	# Harness teleports only to exercise portal transitions. Travel is a real command.
	sim.hero().pos = EarlyFloorRules.return_anchor(sim.state.map,int(2))
	check(sim.travel_region(2) and sim.state.region == 2 and sim.floor_number() == 2, "Cave portal reaches Goblin Forest")
	check(sim.portal_limit() == 14400, "Second floor uses ten-day / 240-hour closure")
	sim.state.units = []
	sim.state.combat = false
	sim.hero().pos = sim.state.map.entrance
	check(sim.travel_region(1) and sim.state.region == 1, "Forest entry portal returns to cave memory")
	check(sim.state.floor_memory.has("2") and sim.state.units.is_empty(), "Previously cleared area state retained between crossings")
	sim.hero().pos = EarlyFloorRules.return_anchor(sim.state.map,int(3))
	check(sim.travel_region(3) and sim.state.region == 3 and sim.floor_number() == 2, "Cave portal also reaches Land of the Dead")
	for enemy: Dictionary in sim.enemies(): check(sim.region_data().enemy_ids.has(enemy.content_id), "Undead area uses researched implemented subset")
	_test_save(sim)
	sim.state.units = []
	sim.state.combat = false
	sim.hero().pos = sim.state.map.entrance
	sim.advance_time(7 * 1440 - int(sim.state.time))
	check(sim.state.mode == "dungeon" and int(sim.state.region) == 3, "Second-floor explorer remains inside after first-floor seven-day closure")
	check(not sim.travel_region(1) and int(sim.state.region) == 3, "Closed first-floor portal cannot be used to return from second floor")

func _test_closure() -> void:
	var sim := fresh()
	check(sim.enter_region(1), "Closure fixture enters cave")
	sim.state.units = []
	sim.state.combat = false
	# Exact ordinary camp sequence: twenty-one eight-hour rests = seven days.
	var food: int = int(sim.state.food)
	sim.add_item("mana_stone_rank_9", 2, true)
	for index in range(21): check(sim.camp(), "Ordinary eight-hour camp %d" % (index + 1))
	check(sim.state.mode == "city" and int(sim.state.time) == 10080 and sim.elapsed_hours() == 168.0, "Automatic closure returns survivor after seven real expedition days")
	check(int(sim.state.food) == maxi(0, food - 7), "Seven days consume seven food through normal interval crossing")
	check(int(sim.state.inventory.get("mana_stone_rank_9", 0)) == 2 and sim.state.month == 1 and sim.state.day == 2, "Closure banks mana stones and returns within the same month")
	check(not sim.enter_region(1), "Mid-month return cannot immediately reenter the Labyrinth")
	check(sim.wait_for_opening() and int(sim.state.month) == 2 and int(sim.state.day) == 1, "Waiting advances to next monthly portal opening")
	check(not sim.wait_for_opening() and sim.enter_region(1), "Opening is available once and permits next expedition")
	var timed := fresh()
	check(timed.enter_region(1), "Accelerated clock fixture enters cave")
	timed.state.units = []
	timed.add_item("mana_stone_rank_9", 1, true)
	timed.advance_time(timed.portal_limit())
	check(timed.state.mode == "city" and int(timed.state.inventory.get("mana_stone_rank_9", 0)) == 1, "Direct deadline advance uses real closure/banking transition")

func _test_essence_effects() -> void:
	var sim := fresh()
	check(sim.enter_region(1), "Field binding fixture enters")
	sim.state.units = []
	sim.state.combat = false
	drop_fixture(sim, "canon_goblin")
	check(sim.absorb("canon_goblin").is_empty() and sim.hero().essences.has("canon_goblin"), "Intact expedition essence can be absorbed in the field")
	check(not sim.state.loot_essences.has("canon_goblin"), "Field absorption consumes unsecured essence once")
	drop_fixture(sim, "canon_goblin")
	check(not sim.absorb("canon_goblin").is_empty(), "Field duplicate binding rejected")
	check(not sim.remove_essence("hero", 0).is_empty(), "Unverified paid removal is unavailable")
	var enemy: Dictionary = sim.spawn_enemy("canon_ghoul", sim.hero().pos + Vector2i.RIGHT)
	enemy.hp = 1000
	enemy.max_hp = 1000
	sim.hit(sim.hero(), enemy, 1, "physical", "Attack", true, true)
	check(enemy.statuses.has("paralyzed"), "Goblin weapon poison paralyzes on melee weapon hit")
	enemy.statuses = {}
	sim.add_item("bow", 1)
	check(sim.equip("bow").is_empty(), "Conditional-poison fixture equips real ranged weapon")
	sim.hit(sim.hero(), enemy, 1, "physical", "Attack", true, true)
	check(not enemy.statuses.has("paralyzed"), "Melee-specific goblin poison does not apply through bow")
	sim.hero().equipment.weapon = ""
	sim.recalculate(sim.hero())
	sim.hit(sim.hero(), enemy, 1, "physical", "Attack", true, true)
	check(not enemy.statuses.has("paralyzed"), "Melee-weapon poison does not apply while unarmed")
	enemy.statuses = {}
	sim.hero().equipment.weapon = "club"
	sim.recalculate(sim.hero())
	sim.hit(sim.hero(), enemy, 1, "fire", "Non-weapon spell", true, true)
	check(not enemy.statuses.has("paralyzed"), "Weapon passive does not attach to an unrelated spell hit")
	sim.state.units = []
	sim.state.combat = false
	sim.update_visibility()
	var trap_position: Vector2i = sim.hero().pos + Vector2i.RIGHT
	check(sim.use_ability(0, trap_position) and sim.state.player_traps.size() == 1, "Goblin Create Trap places actual battlefield trap")
	var trapped: Dictionary = sim.spawn_enemy("canon_ghoul", trap_position)
	sim.step_hazards(trapped)
	check(trapped.statuses.has("paralyzed") and bool(sim.state.player_traps[0].get("spent", false)), "Enemy entering player trap is paralyzed and trap spent")
	trapped.statuses = {}
	sim.step_hazards(trapped)
	check(not trapped.statuses.has("paralyzed"), "Spent trap does not trigger a second time")
	sim.state.units = []
	sim.state.combat = false
	sim.hero().cooldowns = {}
	sim.status(sim.hero(), "paralyzed", 2)
	var energy: int = int(sim.hero().energy)
	check(not sim.use_ability(0, trap_position) and int(sim.hero().energy) == energy, "Paralyzed hero cannot cast an active ability")
	var archer := fresh()
	check(archer.enter_region(1), "Stealth fixture enters")
	archer.state.units = []
	archer.state.combat = false
	drop_fixture(archer, "canon_goblin_archer")
	check(archer.absorb("canon_goblin_archer").is_empty(), "Field bow essence binds")
	archer.update_visibility()
	check(archer.use_ability(0, archer.hero().pos) and archer.hero().statuses.has("stealth"), "Thief Step applies stealth")
	var concealed := fresh()
	concealed.state.gold = 1000 # Isolated area-effect fixture.
	check(concealed.recruit("dwarf_guard").is_empty(), "Area concealment fixture recruits nearby ally")
	check(concealed.enter_region(1), "Stationary concealment fixture enters")
	concealed.state.units = []
	concealed.state.combat = false
	drop_fixture(concealed, "canon_gnome")
	check(concealed.absorb("canon_gnome").is_empty(), "Field gnome essence binds")
	concealed.update_visibility()
	check(concealed.use_ability(0, concealed.hero().pos) and concealed.hero().statuses.has("concealed"), "Fairy Tale applies stationary concealment")
	check(concealed.state.party[0].statuses.has("concealed") and concealed.state.terrain_effects.size() == 1, "Stationary concealment covers a nearby ally through an owned area effect")
	check(concealed.move_unit(Vector2i.DOWN) and not concealed.hero().statuses.has("concealed"), "Moving breaks stationary concealment")
	check(concealed.state.terrain_effects.is_empty() and not concealed.state.party[0].statuses.has("concealed"), "Caster movement immediately cancels owned field and nearby ally concealment")

func _test_paralysis_boundaries() -> void:
	var sim := fresh()
	check(sim.enter_region(1), "Opportunity paralysis fixture enters")
	sim.state.units = []
	var enemy: Dictionary = sim.spawn_enemy("canon_goblin", sim.hero().pos + Vector2i.RIGHT)
	sim.status(enemy, "paralyzed", 2)
	enemy.alert = true
	sim.state.combat = true
	var hp: int = int(sim.hero().hp)
	check(sim.move_unit(Vector2i.DOWN) and int(sim.hero().hp) == hp and not enemy.get("reacted", false), "Paralyzed enemy cannot make opportunity attacks")
	var party := fresh()
	party.state.gold = 1000 # Isolated companion-AI fixture.
	check(party.recruit("dwarf_guard").is_empty() and party.enter_region(1), "Companion paralysis fixture enters")
	party.state.units = []
	var tank: Dictionary = party.state.party[0]
	tank.pos = Vector2i(6, 20)
	var target: Dictionary = party.spawn_enemy("canon_ghoul", Vector2i(2, 18))
	party.update_visibility()
	party.status(tank, "paralyzed", 2)
	var position: Vector2i = tank.pos
	var target_hp: int = int(target.hp)
	party.ally_ai(tank)
	check(tank.pos == position and int(target.hp) == target_hp, "Paralyzed companion cannot move or attack through autonomous AI")

func _test_permanent_death_and_party() -> void:
	var sim := fresh()
	sim.state.gold = 10000 # Test-only recruitment fixture, not campaign playthrough.
	sim.state.unlocked = 10
	for id: String in ["barbarian_warrior", "fairy_archer", "dwarf_guard", "human_scout"]: check(sim.recruit(id).is_empty(), "Party recruits companion " + id)
	check(sim.allies().size() == 5 and not sim.recruit("beastman_swordsman").is_empty(), "Party limit is five including hero")
	check(sim.enter_region(1), "Permanent death fixture enters")
	sim.hit({"name": "Lethal fixture", "statuses": {}}, sim.hero(), 100000, "physical", "Permanent death", false, true)
	check(sim.state.mode == "dead" and bool(sim.hero().dead), "Lethal hero damage ends the campaign")

func _test_combat_potion_restriction() -> void:
	var sim := fresh()
	check(sim.enter_region(1), "Potion restriction fixture enters")
	sim.state.units = []
	sim.state.combat = true
	sim.hero().hp = int(sim.hero().max_hp) - 25
	var count: int = int(sim.state.inventory.get("healing_potion", 0))
	var hp: int = int(sim.hero().hp)
	var ap: int = int(sim.hero().ap)
	check(not sim.use_item("healing_potion").is_empty(), "Healing potion is refused during combat")
	check(int(sim.state.inventory.get("healing_potion", 0)) == count and int(sim.hero().hp) == hp and int(sim.hero().ap) == ap, "Combat potion refusal preserves inventory, health, and action points")
	sim.state.combat = false
	check(sim.use_item("healing_potion").is_empty() and int(sim.state.inventory.get("healing_potion", 0)) == count - 1 and int(sim.hero().hp) == hp + 24, "Same potion can be consumed after breaking contact")

func _test_save(sim: GameSimulation) -> void:
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored := Simulation.new()
	check(restored.restore(snapshot), "Dungeon snapshot restores through JSON serialization")
	check(int(restored.state.version) == 3 and restored.monster_defs.size() == 35 and restored.essence_defs.size() == 7, "Restore initializes current source content caches")
	check(restored.state.region == sim.state.region and restored.state.floor_memory.size() == sim.state.floor_memory.size(), "Area and explored floor memories survive save roundtrip")
	check(restored.rng.state == sim.rng.state and restored.rng.randi() == sim.rng.randi(), "Save resumes exact gameplay RNG stream")
	check(Content.validate().is_empty(), "Available content references resolve after restore")
