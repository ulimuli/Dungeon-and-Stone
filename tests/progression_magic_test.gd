extends SceneTree

const Simulation = preload("res://game/simulation.gd")
const Content = preload("res://game/content.gd")
const World = preload("res://game/world.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh() -> GameSimulation:
	var sim := Simulation.new()
	sim.new_campaign("Progression test", "barbarian", "adventurer", 74119)
	return sim

func arena(sim: GameSimulation) -> void:
	check(sim.enter_region(1), "Fixture enters actual expedition")
	sim.state.units = []
	# Controlled geography isolates spell/turn rules from procedural placement.
	for y: int in range(1, int(sim.state.map.height) - 1):
		for x: int in range(1, int(sim.state.map.width) - 1): sim.state.map.tiles[y][x] = World.FLOOR
	# Controlled spell arena uses ambient light; darkness has separate floor tests.
	sim.state.map.dark_outskirts_width=1
	sim.state.map.memorial_radius_estimate=1
	sim.state.map.traps = []
	sim.hero().pos = Vector2i(3, 4)
	sim.hero().ap = 2
	sim.state.combat = true
	sim.state.time = 0
	for index: int in range(sim.state.party.size()):
		sim.state.party[index].pos = Vector2i(4, 4 + index)
		sim.state.party[index].behavior = "manual"
		sim.state.party[index].ap = 2
	sim.update_visibility()

func caster_fixture() -> GameSimulation:
	var sim := fresh()
	sim.state.gold = 1000
	check(sim.recruit("human_mage").is_empty(), "Generated human mage recruits through actual command")
	arena(sim)
	sim.state.selected = str(sim.state.party[0].id)
	return sim

func target_fixture(sim: GameSimulation, pos: Vector2i = Vector2i(7, 4)) -> Dictionary:
	var target: Dictionary = sim.spawn_enemy("canon_ghoul", pos)
	target.hp = 1000
	target.max_hp = 1000
	target.alert = false
	sim.update_visibility()
	return target

func resources(unit: Dictionary) -> Array:
	return [unit.mana, unit.energy, unit.ap, unit.cooldowns.duplicate(true)]

func _initialize() -> void:
	_test_spell_recruitment_and_cast()
	_test_spell_rejections()
	_test_mana_persistence()
	_test_cumulative_progression()
	_test_first_hunts()
	_test_round_recursion_guard()
	_test_daily_food()
	print("PROGRESSION / MAGIC: %d checks, %d failures. Assisted arenas/XP boundaries; actual recruitment, kills, casts, rounds and JSON restore." % [checks, failures])
	quit(1 if failures else 0)

func _test_spell_recruitment_and_cast() -> void:
	var sim := caster_fixture()
	var caster: Dictionary = sim.selected()
	check(caster.content_id == "human_mage" and caster.spells == ["ice_spear"], "Recruited wizard receives sourced Ice Spear")
	check(int(caster.mana) == int(caster.max_mana) and int(caster.max_mana) > 0, "Recruited wizard starts with an independent mana pool")
	check(sim.hero().mana == 0 and sim.hero().max_mana == 0, "Noncaster has no mana pool")
	var techniques: Array[Dictionary] = sim.techniques(caster)
	check(techniques.size() == 1 and techniques[0].kind == "spell" and techniques[0].id == "ice_spear", "Manual technique list includes wizard spell")
	var spell: Dictionary = Content.spells().ice_spear
	var target: Dictionary = target_fixture(sim, caster.pos + Vector2i(int(spell.range), 0))
	var before_mana: int = int(caster.mana)
	var before_sp: int = int(caster.energy)
	var before_hp: int = int(target.hp)
	check(sim.use_technique(0, target.pos), "Manual spell casts at exact maximum range")
	check(int(caster.mana) == before_mana - int(spell.cost) and int(caster.energy) == before_sp, "Spell consumes mana and leaves Soul Power unchanged")
	check(int(caster.ap) == 0 and int(caster.cooldowns.ice_spear) == int(spell.cooldown) + 1, "Cast spends two AP and sets its actual cooldown")
	check(int(target.hp) < before_hp and int(sim.state.time) == 2, "Projectile resolves actual damage and time cost")
	var after: Array = resources(caster)
	caster.ap = 2
	check(not sim.use_technique(0, target.pos) and int(caster.mana) == int(after[0]), "Spell cooldown blocks a second cast without another mana charge")

func _test_spell_rejections() -> void:
	for condition: String in ["ally", "empty", "range", "wall", "hidden", "stunned", "paralyzed", "mana", "ap", "dead", "unknown_spell", "city"]:
		var sim := caster_fixture()
		var caster: Dictionary = sim.selected()
		var target: Dictionary = target_fixture(sim)
		var destination: Vector2i = target.pos
		match condition:
			"ally": destination = sim.hero().pos
			"empty": destination = Vector2i(6, 5)
			"range": target.pos = caster.pos + Vector2i(6, 0); destination = target.pos; sim.state.visible[sim.pos_key(destination)] = true
			"wall": sim.state.map.tiles[4][5] = World.WALL; sim.state.visible[sim.pos_key(destination)] = true
			"hidden": sim.state.visible = {}
			"stunned", "paralyzed": caster.statuses[condition] = 2
			"mana": caster.mana = 2
			"ap": caster.ap = 1
			"dead": caster.hp = 0
			"unknown_spell": caster.spells = []
			"city": sim.state.mode = "city"
		var before: Array = resources(caster)
		var hp: int = int(target.hp)
		check(not sim._cast_spell(caster, "ice_spear", destination), "Invalid cast rejects: " + condition)
		check(resources(caster) == before and int(target.hp) == hp and int(sim.state.time) == 0, "Rejected cast preserves resources, target and clock: " + condition)
	var slots := caster_fixture()
	check(not slots.use_technique(-1, Vector2i.ZERO) and not slots.use_technique(5, Vector2i.ZERO), "Technique index bounds reject safely")
	check(not slots._cast_spell(slots.selected(), "missing", Vector2i.ZERO), "Unknown spell ID rejects safely")

func _test_mana_persistence() -> void:
	var sim := caster_fixture()
	var caster: Dictionary = sim.selected()
	var target: Dictionary = target_fixture(sim)
	check(sim.use_technique(0, target.pos), "Persistence fixture uses actual spell")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var restored := Simulation.new()
	check(restored.restore(snapshot), "Wizard dungeon state restores from JSON snapshot")
	var loaded: Dictionary = restored.unit_by_id(str(caster.id))
	check(loaded.spells == caster.spells and int(loaded.mana) == int(caster.mana) and int(loaded.max_mana) == int(caster.max_mana), "Spell list and exact mana survive save roundtrip")
	check(int(loaded.energy) == int(caster.energy) and int(loaded.cooldowns.ice_spear) == int(caster.cooldowns.ice_spear), "Soul Power and spell cooldown persist independently")
	check(restored.rng.state == sim.rng.state and restored.rng.randi() == sim.rng.randi(), "Spell/save path preserves gameplay RNG stream")

func _test_cumulative_progression() -> void:
	var sim := fresh()
	var physical: Array = [sim.hero().str, sim.hero().agi, sim.hero().wit, sim.hero().vig, sim.hero().base_hp, sim.hero().max_hp]
	var initial_sp: int = int(sim.hero().max_energy)
	for boundary: Array in [[5,1,6],[6,2,30],[29,2,30],[30,3,150],[149,3,150],[150,4,-1],[1000000,4,-1]]:
		sim.state.xp = int(boundary[0])
		sim.check_level()
		check(int(sim.state.level) == int(boundary[1]) and int(sim.state.xp) == int(boundary[0]), "Cumulative threshold preserves total XP: %d" % int(boundary[0]))
		check(sim.next_level_xp() == int(boundary[2]) and sim.essence_capacity() == int(boundary[1]), "Next researched threshold and essence capacity are explicit")
		check([sim.hero().str, sim.hero().agi, sim.hero().wit, sim.hero().vig, sim.hero().base_hp, sim.hero().max_hp] == physical, "Level advancement adds no unsupported physical growth")
		check(int(sim.hero().max_energy) == initial_sp + (10 if int(boundary[1]) >= 2 else 0), "Only verified first level-up SP increase is applied")
	var jumped := fresh()
	jumped.state.xp = 150
	jumped.check_level()
	check(int(jumped.state.level) == 4 and int(jumped.state.xp) == 150, "Single cumulative XP update crosses all researched thresholds")

func _test_first_hunts() -> void:
	var sim := fresh()
	arena(sim)
	var species: Array[String] = ["canon_goblin", "canon_ghoul", "canon_gnome", "canon_blade_wolf", "canon_goblin_archer", "canon_goblin_swordsman"]
	for index: int in range(species.size()):
		var enemy: Dictionary = sim.spawn_enemy(species[index], Vector2i(8, 8))
		sim.hit(sim.hero(), enemy, 99999, "physical", "Assisted first-hunt fixture", false, true)
		check(int(sim.state.xp) == index + 1, "Actual first species defeat grants one knowledge XP: " + species[index])
		check(int(sim.state.level) == (2 if index == 5 else 1), "Actual six distinct first hunts reach level two")
	var before_xp: int = int(sim.state.xp)
	var repeat: Dictionary = sim.spawn_enemy(species[0], Vector2i(8, 8))
	sim.hit(sim.hero(), repeat, 99999, "physical", "Assisted repeat fixture", false, true)
	check(int(sim.state.xp) == before_xp and int(sim.state.killed[species[0]]) == 2, "Repeated species defeat records kill but grants zero XP")

func _test_round_recursion_guard() -> void:
	var sim := fresh()
	sim.state.gold = 1000
	check(sim.recruit("human_mage").is_empty() and sim.recruit("barbarian_warrior").is_empty(), "Actual wizard and melee companion recruit for round fixture")
	arena(sim)
	var caster: Dictionary = sim.state.party[0]
	var martial: Dictionary = sim.state.party[1]
	caster.behavior = "aggressive"
	martial.behavior = "aggressive"
	var target: Dictionary = target_fixture(sim, Vector2i(5, 5))
	sim.status(target, "paralyzed", 2)
	target.alert = true
	sim.hero().ap = 0
	var mana: int = int(caster.mana)
	var hp: int = int(target.hp)
	var durability: int = int(martial.durability)
	var starting_round: int = int(sim.state.round)
	sim.auto_end_if_spent()
	check(int(sim.state.round) == starting_round + 1 and not sim.resolving_round, "AI caster and martial actions resolve exactly one round without recursion")
	check(int(sim.state.time) == 5, "One spell, one melee attack and one round advance time exactly once")
	check(int(caster.mana) == mana - int(Content.spells().ice_spear.cost) + 1 and int(caster.cooldowns.ice_spear) == 3, "AI spell pays once and ticks mana/cooldown once")
	check(int(martial.durability) == durability - 1 and int(target.hp) < hp, "Martial ally attacks exactly once in the same round")
	check(int(target.statuses.paralyzed) == 1 and int(sim.hero().ap) == 2, "Enemy status and hero AP refresh happen exactly once")
	sim.auto_end_if_spent()
	check(int(sim.state.round) == starting_round + 1, "Refreshed manual hero AP prevents another automatic round")

func _test_daily_food() -> void:
	var sim := fresh()
	arena(sim)
	sim.state.food = 10
	sim.advance_time(3 * 1440 + 12)
	check(int(sim.state.food) == 7 and int(sim.state.time) == 4332, "Three-day leap charges each crossed daily food boundary")
	sim.advance_time(1427)
	check(int(sim.state.food) == 7, "Time before the next boundary does not charge another ration")
	sim.advance_time(1)
	check(int(sim.state.food) == 6, "Next exact daily boundary consumes one ration")
	var short := fresh()
	arena(short)
	short.state.food = 1
	var hp: int = int(short.hero().hp)
	short.advance_time(3 * 1440)
	check(int(short.state.food) == 0 and int(short.state.fatigue) == 2 and int(short.hero().hp) < hp, "Multi-day leap applies each missed food interval and its fatigue consequence")
