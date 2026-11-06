extends SceneTree

const Art = preload("res://game/character_art.gd")
const Store = preload("res://game/persistence.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	seed(77761)
	var first_random: int = randi()
	var expected_random: int = randi()
	seed(77761)
	check(randi() == first_random, "Global random baseline reproducible")
	Art.seeded("human",921)
	Art.portrait({"id":"rng_guard", "ancestry":"human"})
	check(randi() == expected_random, "Cosmetic generation never consumes global RNG")
	var races: Array[String] = ["human", "fairy", "dwarf", "beastfolk", "barbarian", "draconian"]
	var choices: Dictionary = Art.options()
	check(choices.size() == 10, "Ten customization fields exposed")
	var original_choices: Dictionary = Art.options()
	choices.skin.clear()
	check(Art.options() == original_choices, "Public options cannot mutate global choices")
	choices = Art.options()
	var sheet: Image = Image.create(768, 512, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("090e18"))
	for n: int in range(races.size()):
		var race: String = races[n]
		var defaults: Dictionary = Art.seeded(race, 1827)
		check(defaults == Art.seeded(race, 1827), race + " seeded appearance is deterministic")
		check(defaults != Art.seeded(race, 1828), race + " different seed changes appearance")
		var malformed: Dictionary = {"skin":-900, "hair_color":999, "body":"invalid", "accessory":{"bad":true}, "version":900, "unknown":"no"}
		var normalized: Dictionary = Art.normalize(malformed,race,18)
		check(normalized.skin == choices.skin[0], race + " negative palette index bounded")
		check(normalized.hair_color == choices.hair_color[-1], race + " upper palette index bounded")
		check(normalized.version == 1 and normalized.size() == 11, race + " normalized schema excludes unknown fields")
		for field: String in choices:
			check(choices[field].has(normalized[field]), race + " invalid choice normalized: " + field)
		var appearances: Dictionary = {}
		var portraits: Dictionary = {}
		var sprites: Dictionary = {}
		for variation: int in range(12):
			var look: Dictionary = Art.seeded(race,1700+variation)
			var unit: Dictionary = {"id":"test_%d"%variation, "name":"Test", "ancestry":race, "appearance":look, "role":"civilian"}
			var texture: Texture2D = Art.portrait(unit)
			check(texture.get_width() == 64 and texture.get_height() == 64, "Portrait is native64")
			var image: Image = texture.get_image()
			var world_texture: Texture2D = Art.sprite(unit)
			var world_image: Image = world_texture.get_image()
			check(world_texture.get_width() == 32 and world_texture.get_height() == 32, "Sprite is native32")
			check(image.get_data() == Art.portrait(unit).get_image().get_data(), "Repeated portrait identical")
			check(world_image.get_data() == Art.sprite(unit).get_image().get_data(), "Repeated sprite identical")
			portraits[image.get_data().hex_encode().sha256_text()] = true
			sprites[world_image.get_data().hex_encode().sha256_text()] = true
			appearances[JSON.stringify(look)] = true
			if variation < 6:
				sheet.blit_rect(image,Rect2i(0,0,64,64),Vector2i(variation*128,n*80))
				var doubled: Image = world_image.duplicate()
				doubled.resize(64,64,Image.INTERPOLATE_NEAREST)
				sheet.blit_rect(doubled,Rect2i(0,0,64,64),Vector2i(variation*128+64,n*80))
		check(appearances.size() == 12 and portraits.size() == 12 and sprites.size() == 12, race + " twelve visibly distinct seeded NPCs")
		var unit: Dictionary = {"id":"walking", "ancestry":race, "appearance":defaults, "role":"ranged"}
		var down: Image = Art.sprite(unit,0,0).get_image()
		check(down.get_data() != Art.sprite(unit,3,0).get_image().get_data(), race + " back view differs")
		check(down.get_data() != Art.sprite(unit,0,1).get_image().get_data(), race + " stride differs")
		check(Art.sprite(unit,1,0).get_image().get_data() != Art.sprite(unit,2,0).get_image().get_data(), race + " side views differ")
		# Actual checksum-envelope persistence reader, isolated file; no player slot touched.
		var payload: String = JSON.stringify({"units":[unit], "mode":"city"})
		var path: String = "/tmp/dungeon_character_appearance_test.json"
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema":1,"payload":payload,"checksum":payload.sha256_text()}))
		file.close()
		var loaded: Dictionary = Store._read(path)
		check(loaded.ok, race + " actual save reader accepts appearance state")
		var restored: Dictionary = loaded.state.units[0]
		check(Art.normalize(restored.appearance,race) == defaults, race + " appearance survives JSON/checksum save")
		check(Art.portrait(restored).get_image().get_data() == Art.portrait(unit).get_image().get_data(), race + " persisted portrait identical")
		DirAccess.remove_absolute(path)
	# All fields must have visible effects on portraits; never display fake cosmetic controls.
	var baseline: Dictionary = Art.seeded("human",8)
	baseline.face_detail = "plain";baseline.accessory = "none";baseline.hair_style = "crop"
	for field: String in choices:
		var unique_images: Dictionary = {}
		for option: String in choices[field]:
			var changed: Dictionary = baseline.duplicate(true);changed[field] = option
			var image: Image = Art.portrait({"ancestry":"human","appearance":changed}).get_image()
			unique_images[image.get_data().hex_encode().sha256_text()] = true
		check(unique_images.size() == choices[field].size(), "Every " + field + " choice changes portrait pixels")
	var legacy: Dictionary = Art.normalize({"hair_style":"bald","gender":"female","skin":"#c99370","feature":"apron"},"barbarian",9)
	check(legacy.hair_style == "shaved" and legacy.presentation == "feminine" and legacy.accessory == "apron", "Legacy field aliases migrate")
	check(Art.seeded("beastman",42) == Art.seeded("beastfolk",42), "Race spelling aliases normalize")
	# This visual fixture is original module output, not gameplay content.
	DirAccess.make_dir_recursive_absolute("res://verification")
	var output: String = ProjectSettings.globalize_path("res://verification/character-art-contact-sheet.png")
	check(sheet.save_png(output) == OK, "Contact sheet written")
	for message: String in failures: push_error(message)
	print("CHARACTER_ART_TEST: %d checks; %d failures; contact sheet %s" % [checks,failures.size(),output])
	quit(0 if failures.is_empty() else 1)
