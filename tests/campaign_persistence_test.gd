extends SceneTree
## Uses only isolated internal slot 97, preserving every original byte.
const Saves = preload("res://game/persistence.gd")
const Simulation = preload("res://game/simulation.gd")
const SLOT: int = 97
const PATH: String = "user://saves/slot_97.json"
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)

func files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = PATH + suffix
		if FileAccess.file_exists(path): result[path] = FileAccess.get_file_as_bytes(path)
	return result

func clear_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = PATH + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func write_bytes(path: String, contents: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Can write isolated test fixture")
	if file == null: return
	file.store_buffer(contents)
	file.flush()
	file.close()

func envelope(path: String, state: Dictionary) -> void:
	var payload: String = JSON.stringify(state)
	write_bytes(path, JSON.stringify({"schema":1,"payload":payload,"checksum":payload.sha256_text(),"saved_at":"test fixture"}).to_utf8_buffer())

func rejected_restore(sim, payload: Dictionary, label: String) -> void:
	var state_before: String = var_to_str(sim.state)
	var rng_state_before: int = sim.rng.state
	var rng_seed_before: int = sim.rng.seed
	var payload_before: String = var_to_str(payload)
	check(not sim.restore(payload), label + " rejects restore")
	check(var_to_str(sim.state) == state_before, label + " preserves current simulation state")
	check(sim.rng.state == rng_state_before and sim.rng.seed == rng_seed_before, label + " preserves RNG seed and state")
	check(var_to_str(payload) == payload_before, label + " preserves input payload")

func _init() -> void:
	var preserved: Dictionary = files()
	clear_files()
	var sim = Simulation.new()
	sim.new_campaign("Campaign persistence", "barbarian", "adventurer", 74119)
	var first: Dictionary = sim.snapshot()
	check(Saves.save_campaign_slot(SLOT, first).is_empty(), "Validated campaign commits")
	var loaded: Dictionary = Saves.load_campaign_slot(SLOT)
	check(loaded.ok and loaded.warning.is_empty(), "Healthy campaign loads without warning")
	check(loaded.state == JSON.parse_string(JSON.stringify(first)), "Campaign JSON roundtrip preserves snapshot")
	var restored = Simulation.new()
	check(restored.restore(loaded.state), "Loaded campaign restores through real simulation validator")
	check(restored.hero().name == "Campaign persistence" and restored.rng.state == sim.rng.state, "Restore preserves hero and RNG")
	check(sim.city_service("rest").is_empty(), "Actual city command changes second snapshot")
	var second: Dictionary = sim.snapshot()
	check(Saves.save_campaign_slot(SLOT, second).is_empty(), "Second campaign save produces healthy backup")
	check(FileAccess.file_exists(PATH + ".bak"), "Campaign backup exists")
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(PATH + ".bak")
	var malformed_hero: Dictionary = second.duplicate(true)
	malformed_hero.hero = 42
	envelope(PATH, malformed_hero)
	check(Saves._read(PATH).ok, "Malformed hero fixture has a valid checksum envelope")
	loaded = Saves.load_campaign_slot(SLOT)
	check(loaded.ok and loaded.state == JSON.parse_string(JSON.stringify(first)), "Structurally invalid hero primary recovers healthy backup")
	check(str(loaded.warning).to_lower().contains("backup"), "Structural backup recovery is explained")
	rejected_restore(restored, malformed_hero, "Malformed hero")
	rejected_restore(restored, {"@v":[1]}, "Malformed encoded coordinate root")

	# Saving a healthy new state must not rotate a structurally invalid primary
	# over the healthy prior backup.
	check(Saves.save_campaign_slot(SLOT, second).is_empty(), "Healthy campaign can replace structurally invalid primary")
	check(FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Healthy backup survives structurally invalid primary replacement")
	check(Saves.load_campaign_slot(SLOT).ok, "Replacement primary is loadable")
	var before_invalid_write: Dictionary = files()
	check(not Saves.save_campaign_slot(SLOT, malformed_hero).is_empty(), "Invalid campaign payload is refused before writing")
	check(files() == before_invalid_write, "Refused campaign write leaves primary backup and temporary bytes unchanged")

	check(sim.enter_region(1), "Actual dungeon snapshot fixture")
	var dungeon: Dictionary = sim.snapshot()
	check(Saves.save_campaign_slot(SLOT, dungeon).is_empty(), "Valid dungeon campaign commits")
	loaded = Saves.load_campaign_slot(SLOT)
	check(loaded.ok and loaded.state.mode == "dungeon", "Valid dungeon campaign loads")
	var dungeon_sim = Simulation.new()
	check(dungeon_sim.restore(loaded.state), "Actual dungeon campaign restores")
	check(dungeon_sim.state.map.entrance == sim.state.map.entrance and dungeon_sim.state.units.size() == sim.state.units.size(), "Dungeon map and entities survive restore")
	var malformed_map: Dictionary = dungeon.duplicate(true)
	malformed_map.map.tiles[0] = false
	envelope(PATH, malformed_map)
	check(Saves._read(PATH).ok, "Malformed map fixture has valid checksum")
	loaded = Saves.load_campaign_slot(SLOT)
	check(loaded.ok and loaded.state.mode == "city" and str(loaded.warning).to_lower().contains("backup"), "Malformed map primary recovers valid city backup")
	rejected_restore(dungeon_sim, malformed_map, "Malformed map")
	var tagged_map: Dictionary = dungeon.duplicate(true)
	tagged_map.map.entrance = {"@v":[]}
	rejected_restore(dungeon_sim, tagged_map, "Malformed portal tag")
	var currency: Dictionary = second.duplicate(true)
	currency.gold = -1
	rejected_restore(restored, currency, "Negative currency")

	envelope(PATH + ".bak", malformed_hero)
	loaded = Saves.load_campaign_slot(SLOT)
	check(not loaded.ok and loaded.state.is_empty() and not str(loaded.warning).is_empty(), "Both structurally invalid copies fail safely with empty state")
	var invalid_pair: Dictionary = files()
	check(not Saves.save_campaign_slot(SLOT, malformed_map).is_empty(), "Invalid write refused when both prior copies are invalid")
	check(files() == invalid_pair, "Invalid write cannot worsen an invalid pair")
	for slot: int in [-1,100]:
		check(not Saves.load_campaign_slot(slot).ok, "Out-of-range campaign load refused")
		check(not Saves.save_campaign_slot(slot, first).is_empty(), "Out-of-range campaign save refused")
	check(files() == invalid_pair, "Out-of-range operations do not touch isolated files")

	clear_files()
	for path: String in preserved: write_bytes(path, preserved[path])
	check(files() == preserved, "Internal slot 97 restored byte for byte including temporary file")
	print("CAMPAIGN PERSISTENCE: %d checks, %d failures. Checksum-valid structural corruption, healthy backup preservation, atomic refusal and rejected-restore RNG conservation; slot 97 restored." % [checks,failures])
	quit(0 if failures == 0 else 1)
