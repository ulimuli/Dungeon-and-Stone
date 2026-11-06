extends SceneTree
const Validator = preload("res://game/save_validation.gd")
const Simulation = preload("res://game/simulation.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)

func expect_valid(state: Dictionary, label: String) -> void:
	var before: String = var_to_str(state)
	var errors: Array[String] = Validator.validate(state)
	check(errors.is_empty(), label + ": " + str(errors))
	check(var_to_str(state) == before, label + " leaves input unchanged")

func expect_invalid(state: Dictionary, label: String) -> void:
	var before: String = var_to_str(state)
	var errors: Array[String] = Validator.validate(state)
	check(not errors.is_empty(), label + " rejects malformed payload")
	check(var_to_str(state) == before, label + " leaves input unchanged")
	if not errors.is_empty(): check(errors[0].begins_with("$"), label + " reports actionable field path")

func _init() -> void:
	var sim = Simulation.new()
	sim.new_campaign("Save validation", "barbarian", "adventurer", 74119)
	var city: Dictionary = sim.snapshot()
	expect_valid(city, "Fresh encoded city")
	var json_city: Dictionary = JSON.parse_string(JSON.stringify(city))
	expect_valid(json_city, "JSON numeric floats")
	expect_valid(sim.decode(json_city), "Decoded city")
	check(sim.recruit("barbarian_warrior").is_empty(), "Recruit actual companion fixture")
	expect_valid(sim.snapshot(), "City with actual companion")
	check(sim.recruit("human_mage").is_empty(), "Recruit actual spellcaster fixture")
	var wizard: Dictionary = sim.state.party.back()
	wizard.cooldowns.ice_spear = 2
	expect_valid(sim.snapshot(), "Actual spellcaster, mana and spell cooldown")
	check(sim.enter_region(1), "Actual expedition fixture")
	var dungeon: Dictionary = sim.snapshot()
	expect_valid(dungeon, "Encoded dungeon")
	expect_valid(sim.decode(JSON.parse_string(JSON.stringify(dungeon))), "Decoded JSON dungeon")
	var transitioned: bool = false
	for unit: Dictionary in sim.state.units: unit.alert = false
	sim.state.combat = false
	sim.hero().pos = EarlyFloorRules.return_anchor(sim.state.map,2)
	transitioned = sim.travel_region(2)
	check(transitioned, "Actual second-area transition fixture")
	expect_valid(sim.snapshot(), "Dungeon with floor memory")
	sim.hero().hp = 0
	sim.on_death(sim.hero(), {})
	expect_valid(sim.snapshot(), "Permanent death state")

	expect_invalid({}, "Empty payload")
	for key: String in city:
		var broken: Dictionary = city.duplicate(true)
		broken.erase(key)
		if key in ["hero","party","inventory","version","gold","map","units","seen","log","time","player_traps","essence_drops","floor_memory","visited_regions","rng_state"]:
			expect_invalid(broken, "Missing " + key)
	for mutation: Array in [["gold",-1],["gold",1.5],["gold","12"],["food",-1],["level",0],["region",99],["version",1],["mode","victory"],["party",{}],["hero",[]],["units",[null]],["terrain_effects",[false]],["seen",{"garbage":true}],["flags",{"bad":[]}],["floor_memory",{"2":[] }],["rng_state",[]]]:
		var broken: Dictionary = city.duplicate(true)
		broken[mutation[0]] = mutation[1]
		expect_invalid(broken, "Bad root " + str(mutation[0]))
	for field: String in ["inventory","storage","loot_items"]:
		for value: Variant in [-1,1.5,"1",null]:
			var broken: Dictionary = city.duplicate(true)
			broken[field] = {"healing_potion":value}
			expect_invalid(broken, "Bad item count " + field)
	var unknown: Dictionary = city.duplicate(true)
	unknown.inventory.unknown_item = 1
	expect_invalid(unknown, "Unknown item ID")
	for mutation: Array in [["hp","bad"],["hp",-1],["max_hp",0],["pos",[]],["pos",{"@v":[4]}],["pos",{"@v":"4,20"}],["pos",{"@v":[4,20.5]}],["pos",{"@v":[4,20],"extra":0}],["equipment",{"weapon":"healing_potion","armor":"","charm":""}],["statuses",{"unknown":2}],["statuses",[]],["essences",["canon_goblin","canon_goblin"]],["essences",["unimplemented"]],["cooldowns",{"unknown":1}],["ancestry","unknown"],["background","unknown"],["mana",-1],["spells",{}],["spells",["unknown_spell"]],["mana",999],["intent",{"kind":"advance","pos":false,"radius":0}]]:
		var broken: Dictionary = city.duplicate(true)
		broken.hero[mutation[0]] = mutation[1]
		expect_invalid(broken, "Bad hero " + str(mutation[0]))
	var legacy_optional: Dictionary = city.duplicate(true)
	for field: String in ["mana","max_mana","spells"]: legacy_optional.hero.erase(field)
	expect_valid(legacy_optional, "Optional mana and spell fields absent")
	var optional: Dictionary = city.duplicate(true)
	optional.hero.mana = 8.0
	optional.hero.max_mana = 12.0
	optional.hero.spells = []
	expect_valid(optional, "Optional resource and spell fields")
	for mutation: Array in [["width","38"],["width",1000000],["tiles",{}],["tiles",[[]]],["entrance",false],["exit",{"@v":[999,999]}],["spawns",["4,4"]],["traps",[null]],["rooms",[{"@r":[1,1,2]}]]]:
		var broken: Dictionary = dungeon.duplicate(true)
		broken.map[mutation[0]] = mutation[1]
		expect_invalid(broken, "Bad map " + str(mutation[0]))
	for field: String in dungeon.map:
		for value: Variant in [null,false,2.5,"x",[],{}]:
			var broken: Dictionary = dungeon.duplicate(true)
			broken.map[field] = value
			check(Validator.validate(broken) is Array, "Map mixed-type fuzz returns diagnostics for " + field)
	var solid: Dictionary = dungeon.duplicate(true)
	var entrance: Array = solid.map.entrance["@v"]
	solid.map.tiles[int(entrance[1])][int(entrance[0])] = 1
	expect_invalid(solid, "Blocked entrance")
	var row: Dictionary = dungeon.duplicate(true)
	row.map.tiles[0] = false
	expect_invalid(row, "Nonarray map row")
	var tile: Dictionary = dungeon.duplicate(true)
	tile.map.tiles[0][0] = {}
	expect_invalid(tile, "Nonnumeric tile")
	var dead_end: Dictionary = dungeon.duplicate(true)
	dead_end.map.tiles[1][36] = 0
	expect_invalid(dead_end, "Disconnected floor")
	var drop: Dictionary = dungeon.duplicate(true)
	drop.essence_drops = [{"id":"unknown","pos":{"@v":[4,20]},"region":1,"expires_at":2}]
	expect_invalid(drop, "Unknown dropped essence")
	var duplicate: Dictionary = dungeon.duplicate(true)
	duplicate.units.append(duplicate.units[0].duplicate(true))
	expect_invalid(duplicate, "Duplicate entity IDs")
	for field: String in ["hero","units","party","terrain_effects","player_traps","essence_drops","floor_memory","map","last_hit"]:
		for value: Variant in [null,false,2.5,"x",[],{}]:
			var broken: Dictionary = dungeon.duplicate(true)
			broken[field] = value
			var errors: Array[String] = Validator.validate(broken)
			check(errors is Array, "Mixed-type fuzz returns diagnostics for " + field)
	for field: String in city.hero:
		for value: Variant in [null,false,2.5,"x",[],{}]:
			var broken: Dictionary = city.duplicate(true)
			broken.hero[field] = value
			var errors: Array[String] = Validator.validate(broken)
			check(errors is Array, "Unit mixed-type fuzz returns diagnostics for " + field)
	expect_invalid({"@v":[1,2]}, "Coordinate tag at payload root")
	var deep: Dictionary = city.duplicate(true)
	var cursor: Dictionary = deep
	for index in range(40):
		cursor.extra = {}
		cursor = cursor.extra
	expect_invalid(deep, "Excessive nesting")
	var nan_state: Dictionary = city.duplicate(true)
	nan_state.gold = NAN
	expect_invalid(nan_state, "Nonfinite currency")
	var object_state: Dictionary = city.duplicate(true)
	object_state.hero.pos = Vector2(4,20)
	expect_invalid(object_state, "Floating vector")
	print("SAVE VALIDATION: %d checks, %d failures; encoded/decoded real snapshots, malformed structure, IDs, maps, nested tags and nonmutation. No save files written." % [checks,failures])
	quit(0 if failures == 0 else 1)
