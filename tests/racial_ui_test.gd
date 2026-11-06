extends SceneTree
## Real parsed mouse controls over assisted funds/essences. No natural-balance claim.
## Preserve settings and isolated slot99 primary/backup/temp byte for byte.
const MAIN = preload("res://main.tscn")
const Profession = preload("res://game/profession_rules.gd")
const BACKUP: String = "user://test_backups/racial-ui-preserved.json"
const PATHS: Array[String] = ["user://settings.json","user://settings.json.tmp","user://saves/slot_99.json","user://saves/slot_99.json.bak","user://saves/slot_99.json.tmp"]
var game: Control
var checks: int = 0
var failures: int = 0
var preserved: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: _run.call_deferred()

func settle() -> void:
	for frame: int in range(5): await process_frame

func button(text: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text == text: return node
	return null

func prefix_button(prefix: String) -> Button:
	for node: Node in game.ui.find_children("*","Button",true,false):
		if node.text.begins_with(prefix): return node
	return null

func label_containing(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text.contains(text): return node
	return null

func reveal(control: Control) -> void:
	if control == null: return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await settle()

func visible_control(control: Control, label: String) -> void:
	check(control != null,label+" exists")
	if control == null: return
	var visible: bool = control.is_visible_in_tree() and Rect2(0,0,640,360).encloses(control.get_global_rect())
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().encloses(control.get_global_rect()): visible = false
		ancestor = ancestor.get_parent()
	check(visible,label+" is fully visible within viewport and scroll clipping")

func click(control: Control) -> void:
	check(control != null,"Actual parsed mouse target exists")
	if control == null: return
	await reveal(control)
	visible_control(control,"Mouse target "+str(control.get("text")))
	var point: Vector2 = control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await process_frame
	var down := InputEventMouseButton.new()
	down.position = point; down.global_position = point; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true
	Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new()
	up.position = point; up.global_position = point; up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()

func resources() -> String:
	var state: Dictionary = game.sim.state.duplicate(true)
	state.erase("log")
	return var_to_str([state,game.sim.rng.state])

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.capture(filename)
	check(FileAccess.file_exists("res://screenshots/"+filename),"Captured "+filename)

func fresh(race: String, scale: float) -> void:
	game.sim.new_campaign("Racial UI assisted fixture",race,"adventurer",74119)
	game.sim.state.gold = 100000
	game.sim.state.flags.assisted = true
	game.settings.text_scale = scale
	game.screen = "game"; game.overlay = ""; game.selected_party = "hero"
	game.inventory_selected = ""; game.inventory_filter = ""; game.inventory_storage = false
	game.render(); await settle()

func open_party() -> void:
	if not game.overlay.is_empty(): await click(button("CLOSE [Esc]"))
	var party_button: Button = button("P")
	if party_button == null: party_button = prefix_button("[ ")
	await click(party_button)
	check(game.overlay == "party","Real party button opens character status")

func buy_ui(prefix: String) -> void:
	game.city_location = "market"; game.trading_npc = "merchant"; game.overlay = "city_location"
	game.render(); await settle()
	await click(prefix_button(prefix))

func restore_files() -> void:
	for path: String in PATHS:
		if preserved[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(preserved[path]); file.close()
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null) == preserved[path],"Restored original persisted bytes: "+path)

func watchdog() -> void:
	check(false,"Graphical suite exceeded90seconds; restored durable pretest files")
	restore_files()
	quit(1)

func _run() -> void:
	var durable: Dictionary = {}
	for path: String in PATHS:
		preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		durable[path] = Marshalls.raw_to_base64(preserved[path]) if preserved[path] != null else null
	DirAccess.make_dir_recursive_absolute("user://test_backups")
	var backup := FileAccess.open(BACKUP,FileAccess.WRITE)
	backup.store_string(JSON.stringify({"encoding":"base64","files":durable})); backup.close()
	create_timer(90).timeout.connect(watchdog)
	print("RACIAL UI: durable original-file backup written before scene launch")
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game); game.save_slot = 99
	game.settings.fullscreen = false; game.settings.muted = true; game.settings.reduced_motion = true
	game.apply_settings()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for id: String in ["frost_spirit_ring","guardians_braces"]:
		check(game.tex(id) != null and game.tex(id).get_size() == Vector2(24,24),"Native24px numbered icon: "+id)
	for scale: float in [1.0,1.2]:
		print("RACIAL UI: Skadia at ",scale)
		await test_skadia(scale)
	print("RACIAL UI: Dragon Fear")
	await test_dragon_fear()
	print("RACIAL UI: Guardian braces")
	await test_guardians_braces()
	for scale: float in [1.0,1.2]:
		print("RACIAL UI: Human instruction at ",scale)
		await test_human_magic(scale)
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle()
	restore_files()
	print("RACIAL SCENE UI: %d checks, %d failures. Parsed real market/equipment/seal/ritual/cancel/removal/fear/protection controls at100/120%%; assisted funding and bound essence; slot99/settings restored." % [checks,failures])
	quit(1 if failures else 0)

func test_skadia(scale: float) -> void:
	await fresh("beastman",scale)
	game.sim.hero().essences = ["canon_goblin"] # Explicit assisted bound essence.
	game.render(); await settle()
	await buy_ui("Ring of the Frost Spirit / ")
	check(int(game.sim.state.inventory.get("frost_spirit_ring",0)) == 1,"Real market button purchases ring")
	game.overlay = "inventory"; game.inventory_selected = "frost_spirit_ring"; game.render(); await settle()
	var before: String = resources()
	await click(button("EQUIP"))
	check(game.overlay == "ring_seal" and resources() == before,"Equip requires explicit essence seal without mutating state")
	await click(prefix_button("SEAL / "))
	check(game.sim.hero().equipment.charm == "frost_spirit_ring" and game.sim.hero().ring_sealed_essence == "canon_goblin","Real seal choice equips ring and records owned essence")
	check(game.sim.active_essences(game.sim.hero()).is_empty() and game.sim.hero().essences == ["canon_goblin"],"Real ring UI seals skills without erasing ownership")
	await click(button("AWAKEN SKADIA"))
	check(game.overlay == "confirm" and game.confirm_text.contains("ALL WORN EQUIPMENT") and game.confirm_text.contains("Club"),"Destructive confirmation names all-worn loss and actual Club")
	await reveal(button("CONFIRM")); visible_control(button("CONFIRM"),"Destructive confirmation action")
	await capture("32-skadia-confirm-%d.png" % int(scale*100))
	before = resources()
	await click(button("CANCEL"))
	check(resources() == before and not game.sim.hero().has("racial"),"Actual cancel preserves gear, essence, currency and unset contract")
	await open_party()
	var weapon: String = game.sim.hero().equipment.weapon
	var armor: String = game.sim.hero().equipment.armor
	check(not weapon.is_empty() and not armor.is_empty(),"Starting worn weapon/clothes exist for preservation test")
	await click(button("REMOVE / WEAPON"))
	await click(button("REMOVE / ARMOR"))
	check(game.sim.hero().equipment.weapon.is_empty() and game.sim.hero().equipment.armor.is_empty(),"Real remove controls clear equipment slots")
	check(int(game.sim.state.inventory.get(weapon,0)) >= 1 and int(game.sim.state.inventory.get(armor,0)) >= 1,"Removed weapon/clothes enter carried bag")
	var bag: Dictionary = game.sim.state.inventory.duplicate(true)
	await click(button("AWAKEN SKADIA"))
	await click(button("CONFIRM"))
	check(game.overlay == "party" and game.sim.hero().racial.get("soul_beast","") == "skadia","Actual confirmed ritual creates permanent contract")
	check(game.sim.hero().equipment.charm.is_empty() and int(game.sim.state.inventory.get("frost_spirit_ring",0)) == 0,"Confirmed ritual destroys worn ring")
	check(game.sim.state.inventory == bag and game.sim.active_essences(game.sim.hero()) == ["canon_goblin"],"Removed bag gear survives and destroyed ring releases essence skills")
	var status: Label = label_containing("Skadia · Strengthening")
	check(status != null,"Character status displays supported Skadia contract")
	await reveal(status)
	await capture("33-skadia-status-%d.png" % int(scale*100))

func test_dragon_fear() -> void:
	await fresh("draconian",1.2)
	await open_party()
	await click(button("SUPPRESS DRAGON FEAR"))
	check(not game.sim.hero().get("dragon_fear_enabled",true),"Real suppression control disables innate fear")
	await click(button("RELEASE DRAGON FEAR"))
	check(game.sim.hero().get("dragon_fear_enabled",false),"Real release control restores innate fear")

func test_guardians_braces() -> void:
	await fresh("dwarf",1.0)
	await buy_ui("Guardian’s Braces / ")
	check(int(game.sim.state.inventory.get("guardians_braces",0)) == 1,"Real market button purchases Guardian's Braces")
	game.overlay = "inventory"; game.inventory_selected = "guardians_braces"; game.render(); await settle()
	await click(button("EQUIP"))
	check(game.sim.hero().equipment.charm == "guardians_braces","Actual inventory command equips numbered protection")
	check(game.sim.enter_region(1),"Actual scene expedition starts")
	game.sim.state.units = []; game.sim.state.combat = false
	game.sim.status(game.sim.hero(),"poison",4,3)
	game.overlay = ""; game.render(); await settle()
	await open_party()
	await click(button("GUARDIAN’S PROTECTION"))
	check(not game.sim.hero().statuses.has("poison") and game.sim.hero().statuses.has("status_immunity"),"Real party active cleanses poison and grants status protection")
	check(int(game.sim.hero().statuses.get("status_immunity",0)) == 4,"Dwarf's1.5x active duration reaches actual UI state")
	await reveal(label_containing("Braces · absorbed"))
	await capture("34-guardians-braces-status.png")

func test_human_magic(scale: float) -> void:
	await fresh("human",scale)
	var seed_value: int = -1
	for candidate: int in range(1000):
		if Profession.assessment(game.sim.hero(),candidate) == "limited":
			seed_value = candidate
			break
	check(seed_value >= 0,"Find stable suitable aptitude seed for assisted Human UI fixture")
	game.sim.new_campaign("Racial UI assisted fixture","human","adventurer",seed_value)
	game.sim.state.gold = 100000; game.sim.state.flags.assisted = true
	game.overlay = ""; game.render(); await settle()
	await open_party()
	await click(button("MAGIC TRAINING"))
	check(game.overlay == "profession","Actual Human training button opens instruction")
	var before: String = resources()
	await click(prefix_button("ASSESS / 10 ST"))
	check(game.overlay == "confirm" and game.confirm_text.contains("3 city days"),"Assessment discloses elapsed days before purchase")
	await click(button("CANCEL"))
	check(resources() == before and not game.sim.hero().has("magic_assessment"),"Cancel assessment preserves funds/day and unset aptitude")
	await open_party(); await click(button("MAGIC TRAINING"))
	await click(prefix_button("ASSESS / 10 ST")); await click(button("CONFIRM"))
	check(game.sim.hero().get("magic_assessment","") == "limited" and int(game.sim.state.gold) == 99990 and int(game.sim.state.day) == 4,"Confirmed assessment applies stable aptitude, exact fee and3days")
	before = resources()
	await click(prefix_button("STUDY / 600 ST"))
	check(game.overlay == "confirm" and game.confirm_text.contains("cannot absorb essences"),"Lessons disclose mage/essence commitment before purchase")
	await click(button("CANCEL"))
	check(resources() == before and game.sim.hero().profession != "mage","Cancel lessons preserves resources, date and profession")
	await open_party(); await click(button("MAGIC TRAINING"))
	await click(prefix_button("STUDY / 600 ST")); await click(button("CONFIRM"))
	var hero: Dictionary = game.sim.hero()
	check(hero.profession == "mage" and hero.spells.has("ice_spear") and int(hero.mana) > 0 and hero.essences.is_empty(),"Actual paid instruction teaches Ice Spear with mana and no essences")
	check(int(game.sim.state.gold) == 99390 and int(game.sim.state.get("month",1)) == 2 and int(game.sim.state.day) == 4,"Thirty days of instruction cross month correctly and charge600stones")
	check(label_containing("Mage · Ice Spear") != null,"Instruction UI displays learned magic")
	await capture("35-human-magic-%d.png" % int(scale*100))
