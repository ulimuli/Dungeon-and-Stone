extends SceneTree

const World = preload("res://game/world.gd")
const Saves = preload("res://game/persistence.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)

func _init() -> void:
	var seed_count: int = 3 if OS.get_cmdline_user_args().has("--quick") else 200
	for area in range(1, 5):
		for seed_value in range(seed_count):
			var map: Dictionary = World.generate(seed_value, area)
			var errors: Array[String] = World.validate(map)
			check(errors.is_empty(), "Area %d seed %d: %s" % [area, seed_value, errors])
			var reached: Dictionary = World.reachable(map, map.entrance)
			check(reached.has(map.exit) and int(reached.get(map.exit, 0)) >= 10, "Area %d seed %d portals are distinct, separated, and reachable" % [area, seed_value])
			check(int(map.area) == area and map.spawns.size() == 32 + area * 4, "Spawn layout uses only the selected researched area")
			check(map.traps.size() == (6 if area == 1 else (10 if area == 2 else 0)), "Trap placement follows the supported area subset")
			for portal: Vector2i in [map.entrance, map.exit]:
				var clear: bool = true
				for y in range(-1, 2):
					for x in range(-1, 2): clear = clear and World.walkable(map, portal + Vector2i(x, y))
				check(clear, "Area portal has safe arrival space for the party")
			if seed_value < 3: check(JSON.stringify(map) == JSON.stringify(World.generate(seed_value, area)), "Same seed and area reproduce identical geography and placements")
	var sight: Dictionary = {"width": 5, "height": 3, "tiles": [[1,1,1,1,1], [1,0,0,0,1], [1,1,1,1,1]]}
	check(World.line_of_sight(sight, Vector2i(1,1), Vector2i(3,1)), "Open ground preserves line of sight")
	sight.tiles[1][2] = World.WALL
	check(not World.line_of_sight(sight, Vector2i(1,1), Vector2i(3,1)), "Wall blocks sight beyond it")
	check(World.line_of_sight(sight, Vector2i(1,1), Vector2i(2,1)), "Target wall itself is visible")
	check(not World.walkable(sight, Vector2i(-1,1)), "Bounds guard")
	var corner: Dictionary = {"width": 2, "height": 2, "tiles": [[0,1], [1,0]]}
	check(not World.line_of_sight(corner, Vector2i.ZERO, Vector2i.ONE), "Solid diagonal corners block sight")
	var broken: Dictionary = World.generate(19, 1)
	broken.tiles[broken.exit.y][broken.exit.x] = World.WALL
	check(not World.validate(broken).is_empty(), "Validator rejects inaccessible area portal")
	var disconnected: Dictionary = World.generate(20, 2)
	disconnected.tiles[1][1] = World.FLOOR
	check(not World.validate(disconnected).is_empty(), "Validator rejects disconnected traversable ground")
	_test_saves()
	print("WORLD/SAVE TESTS: %d checks, %d failures; %d maps across Crystal Cave, Goblin Forest, Land of the Dead and Black Rock Mountain" % [checks, failures, seed_count * 4])
	quit(0 if failures == 0 else 1)

func _test_saves() -> void:
	var preserved: Dictionary = {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "user://saves/slot_99.json" + suffix
		if FileAccess.file_exists(path):
			preserved[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)
	var first: Dictionary = {"name": "Save roundtrip fixture", "seed": 123456, "area": 3, "inventory": [{"id": "test_material", "quantity": 7}], "flags": {"verified": true}, "hp": 23}
	check(Saves.save_slot(99, first).is_empty(), "First save commits")
	var loaded: Dictionary = Saves.load_slot(99)
	check(bool(loaded["ok"]), "Round trip loads")
	check(loaded["state"] == JSON.parse_string(JSON.stringify(first)), "Round trip retains nested values (JSON numeric equivalence)")
	var second: Dictionary = first.duplicate(true)
	second["hp"] = 11
	check(Saves.save_slot(99, second).is_empty(), "Second save commits")
	var file := FileAccess.open("user://saves/slot_99.json", FileAccess.WRITE)
	file.store_string("{corrupt!")
	file.close()
	loaded = Saves.load_slot(99)
	check(bool(loaded["ok"]) and int(loaded["state"].get("hp", 0)) == 23, "Corrupt primary recovers previous campaign")
	check(str(loaded["warning"]).contains("backup"), "Backup recovery is explained")
	check(Saves.save_slot(99, second).is_empty(), "Saving after corruption succeeds")
	# A corrupt primary must not overwrite the healthy existing backup.
	var backup_text := FileAccess.get_file_as_string("user://saves/slot_99.json.bak")
	check(backup_text.contains("Save roundtrip fixture"), "Healthy backup preserved")
	file = FileAccess.open("user://saves/slot_99.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 0, "state": first}))
	file.close()
	loaded = Saves.load_slot(99)
	check(bool(loaded["ok"]) and str(loaded["warning"]).contains("Legacy"), "Version zero migration")
	file = FileAccess.open("user://saves/slot_99.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "payload": JSON.stringify(second), "checksum": "tampered"}))
	file.close()
	DirAccess.remove_absolute("user://saves/slot_99.json.bak")
	check(not bool(Saves.load_slot(99)["ok"]), "Checksum rejects altered payload without backup")
	check(not Saves.save_slot(-1, first).is_empty(), "Invalid save slot rejected")
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "user://saves/slot_99.json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path in preserved:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(preserved[path])
		file.close()
