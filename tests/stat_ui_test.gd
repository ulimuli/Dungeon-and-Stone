extends SceneTree
## Parsed real UI over assisted generic modifiers, funds and a bound essence.
## Settings and isolated slot99 bytes have a durable backup and bounded cleanup.
const MAIN = preload("res://main.tscn")
const PATHS: Array[String] = ["user://settings.json","user://settings.json.tmp","user://saves/slot_99.json","user://saves/slot_99.json.bak","user://saves/slot_99.json.tmp"]
const BACKUP: String = "user://test_backups/stat-ui-preserved.json"
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

func label_exact(text: String) -> Label:
	for node: Node in game.ui.find_children("*","Label",true,false):
		if node.text == text: return node
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
	check(visible,label+" fits viewport and ancestor scroll clipping")

func hover(control: Control) -> void:
	if control == null: return
	await reveal(control)
	var point: Vector2 = control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await process_frame

func click(control: Control) -> void:
	check(control != null,"Actual mouse target exists")
	if control == null: return
	await reveal(control)
	visible_control(control,"Mouse target "+str(control.get("text")))
	await hover(control)
	var point: Vector2 = control.get_global_rect().get_center()
	var down := InputEventMouseButton.new(); down.position = point; down.global_position = point; down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.pressed = true
	Input.parse_input_event(down); await process_frame
	var up := InputEventMouseButton.new(); up.position = point; up.global_position = point; up.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(up); await settle()

func resources() -> String:
	var state: Dictionary = game.sim.state.duplicate(true)
	state.erase("log")
	return var_to_str([state,game.sim.rng.state])

func restore_files() -> void:
	for path: String in PATHS:
		if preserved[path] == null:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(preserved[path]); file.close()
		check((FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null) == preserved[path],"Original bytes restored: "+path)

func watchdog() -> void:
	check(false,"UI test exceeded90seconds; restoring original files")
	restore_files()
	quit(1)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.capture(filename)
	check(FileAccess.file_exists("res://screenshots/"+filename),"Captured "+filename)

func modifier(id: String, stat: String, op: String, value: float) -> Dictionary:
	return {"id":"fixture:"+id,"source":"fixture:stat_ui","stat":stat,"op":op,"value":value}

func _run() -> void:
	var durable: Dictionary = {}
	for path: String in PATHS:
		preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		durable[path] = Marshalls.raw_to_base64(preserved[path]) if preserved[path] != null else null
	DirAccess.make_dir_recursive_absolute("user://test_backups")
	var backup := FileAccess.open(BACKUP,FileAccess.WRITE)
	backup.store_string(JSON.stringify({"encoding":"base64","files":durable})); backup.close()
	create_timer(90).timeout.connect(watchdog)
	root.size = Vector2i(640,360); root.content_scale_size = Vector2i(640,360); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = MAIN.instantiate(); root.add_child(game); game.save_slot = 99
	game.settings.fullscreen = false; game.settings.muted = true; game.settings.reduced_motion = true; game.apply_settings()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	for scale: float in [1.0,1.2]:
		print("STAT UI: parsed controls at ",scale)
		await test_scale(scale)
	for player: Node in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
	game.queue_free(); await settle()
	restore_files()
	print("STAT SCENE UI: %d checks, %d failures. Actual STATS/toggle/hover/preview/equip controls at100/120%%; assisted modifier fixture; all registered stats have consumers, with provisional effects disclosed; settings/slot99 restored." % [checks,failures])
	quit(1 if failures else 0)

func test_scale(scale: float) -> void:
	game.sim.new_campaign("Stat UI assisted fixture","human","adventurer",74119)
	game.sim.state.gold = 100000; game.sim.state.flags.assisted = true
	var unit: Dictionary = game.sim.hero()
	var raw_strength: int = unit.str
	unit.base_stats = {"attack":10,"strength":10,"muscle_mass":20}
	unit.modifiers = [modifier("attack_increase","attack","increase",0.5),modifier("soul_cost","soul_cost_multiplier","multiply",0.5),modifier("mana_cost","mana_cost_multiplier","multiply",0.5),modifier("cooldown","cooldown_multiplier","multiply",0.5)]
	game.sim.item_defs.club.modifiers = [{"stat":"attack","op":"multiply","value":2},{"stat":"armor","op":"add","value":7},{"stat":"evasion","op":"increase","value":0.2},{"stat":"attack_range","op":"at_least","value":3}]
	game.sim.essence_defs.canon_goblin.modifiers = [{"stat":"attack","op":"add","value":5},{"stat":"mana_sensitivity","op":"add","value":2}]
	unit.essences = ["canon_goblin"] # Explicit fixture grant, not an obtained drop.
	game.sim.add_item("spear",1)
	game.sim.recalculate(unit,false)
	check(int(unit.str) == raw_strength and raw_strength != 12 and game.sim.stat_value(unit,"strength") == 12,"Resolved Strength12 preserves a distinct legacy base attribute")
	check(game.sim.stat_value(unit,"attack") == 45,"Live generic add/increase/multiply fixture resolves Attack45")
	game.settings.text_scale = scale; game.stats_show_all = false
	game.screen = "game"; game.selected_party = "hero"; game.overlay = "party"
	game.inventory_storage = false; game.inventory_filter = ""
	game.render(); await settle()
	check(label_containing("Strength 12") != null,"Character status displays resolved Strength rather than raw legacy field")
	visible_control(button("STATS"),"Compact Character Status STATS action")
	await click(button("STATS"))
	check(game.overlay == "stats","Real STATS action opens resolved registry")
	var attack: Label = label_exact("Attack")
	check(attack != null,"Resolved Attack row exists")
	if attack != null:
		var value: Label = attack.get_parent().get_child(1)
		check(value.text == "45","Stat row shows actual generic Attack45")
		check(attack.tooltip_text.contains("Club") and attack.tooltip_text.contains("Goblin") and attack.tooltip_text.contains("50%") and attack.tooltip_text.contains("×2"),"Provenance tooltip retains item/essence/increase/multiplier contributions")
		check(attack.tooltip_text.contains("(base + flat)") and attack.mouse_filter != Control.MOUSE_FILTER_IGNORE,"Stat formula tooltip is attached to a mouse-responsive row")
		await hover(attack)
		var hovered: Control = root.gui_get_hovered_control()
		check(hovered != null and hovered.tooltip_text.contains("Club"),"Parsed pointer reaches the actual provenance tooltip target")
	check(label_exact("Damage Taken Multiplier") == null,"Default neutral multiplier noise is hidden")
	check(label_exact("Mana Sensitivity") != null,"Provisional Mana Sensitivity has a working consumer and is shown")
	await capture("36-stats-%d.png" % int(scale*100))
	await click(button("SHOW ALL IMPLEMENTED"))
	check(label_exact("Damage Taken Multiplier") != null and label_exact("Mana Sensitivity") != null,"ShowAll reveals neutral implemented values and retains active provisional stats")
	await click(button("SHOW RELEVANT"))
	check(label_exact("Damage Taken Multiplier") == null,"Relevant filter restores neutral-noise suppression")
	await click(button("CHARACTER"))
	check(game.overlay == "party","Stats navigation returns to same character")
	var club_tooltip: String = game.item_tooltip("club")
	check(club_tooltip.contains("Attack ×2") and club_tooltip.contains("Armor +7") and club_tooltip.contains("+20% increased") and club_tooltip.contains("minimum 3"),"Item tooltip explains all four canonical modifier operations")
	var essence_tooltip: String = game.essence_tooltip("canon_goblin")
	check(essence_tooltip.contains("Attack +5") and essence_tooltip.contains("Mana Sensitivity +2") and not essence_tooltip.contains("catalog only"),"Essence tooltip shows provisional bonuses as working without obsolete research labels")
	check(essence_tooltip.contains("2 SP · 2 turn cooldown"),"Essence cost and cooldown are modified exactly once")
	var spell_tooltip: String = game.technique_tooltip({"id":"ice_spear","kind":"spell","ability":{"cost":999,"cooldown":999}})
	check(spell_tooltip.contains("2 Mana · 2 turn cooldown") and not spell_tooltip.contains("999"),"Spell tooltip uses canonical base costs and applies resource/cooldown modifiers once")
	game.overlay = "inventory"; game.inventory_selected = "spear"
	var before: String = resources()
	game.render(); await settle()
	check(resources() == before,"Rendering actual equipment preview never mutates campaign or RNG")
	var equip: Button = button("EQUIP")
	check(equip != null and equip.tooltip_text.contains("Attack -15 (45 → 30)") and equip.tooltip_text.contains("Armor -7"),"Equipment comparison uses complete resolved deltas instead of flat item power")
	check(label_containing("EQUIPMENT CHANGE") != null and label_containing("Attack -15") != null,"Resolved equipment changes are visible in inventory detail")
	await reveal(equip); visible_control(equip,"Inventory equip with generic preview")
	await capture("37-equipment-preview-%d.png" % int(scale*100))
	await click(equip)
	check(unit.equipment.weapon == "spear" and game.sim.stat_value(unit,"attack") == 30,"Actual equip matches the resolved preview's Attack30")
