extends Control

const INK: Color = Color("020304")
const PANEL: Color = Color("050708")
const EDGE: Color = Color("90999a")
const GOLD: Color = Color("e5e8e4")
const PALE: Color = Color("f0f1eb")
const MUTED: Color = Color("9ba6a4")
const TEAL: Color = Color("a8bf67")
const RED: Color = Color("e46155")
const MAP_RECT: Rect2 = Rect2(8, 8, 432, 256)
const TILE: int = 16
const UIStats = preload("res://game/stat_catalog.gd")
const EarlyArt = preload("res://game/early_floor_content.gd")
var homeland_view: HomelandMap
var homeland_dialog: Dictionary = {}
var stats_show_all: bool = false
var sim: GameSimulation = GameSimulation.new()
var audio: GameAudio
var ui: Control
var overlay: String = ""
var screen: String = "title"
var city_location: String = "inn"
var selected_npc: String = ""
var trading_npc: String = ""
var npc_line: String = ""
var new_appearance: Dictionary = {}
var appearance_draft: Dictionary = {}
var appearance_target: String = "creation"
var inventory_filter: String = ""
var inventory_kind: String = "all"
var inventory_selected: String = ""
var inventory_storage: bool = false
var journal_filter: String = ""
var selected_party: String = "hero"
var selected_region: int = 1
var save_slot: int = 1
var jump_targeting: bool = false
var selected_ability: int = -1
var inspect_id: String = ""
var map_zoom: int = 0
var map_pan: Vector2 = Vector2.ZERO
var hovered: Vector2i = Vector2i(-1, -1)
var camera_tile: Vector2i = Vector2i.ZERO
var clock_time: float = 0.0
var depth_visual_key: String = ""
var depth_visual_distances: Dictionary = {}
var depth_visual_boundary: int = 0
var hit_flash: float = 0.0
var visual_units: Dictionary = {}
var visual_area: int = -1
var notice: String = ""
var notice_time: float = 0.0
var pending_confirm: Callable
var confirm_text: String = ""
var new_name: String = "Adventurer"
var new_seed: String = "74119"
var ancestry_id: String = "barbarian"
var background_id: String = ""
var waiting_binding: String = ""
var developer_enabled: bool = false
var settings: Dictionary = {"master": 0.65, "music": 0.45, "sfx": 0.75, "muted": false, "text_scale": 1.0, "reduced_motion": false, "shake": false, "fullscreen": false, "bindings": {"north": KEY_W, "south": KEY_S, "west": KEY_A, "east": KEY_D, "interact": KEY_E, "wait": KEY_SPACE, "inventory": KEY_I, "journal": KEY_J, "party": KEY_P, "camp": KEY_C, "jump": KEY_V}}
var textures: Dictionary = {}
var font: Font
var mono_font: Font
var item_defs: Dictionary = GameContent.weapons()
var essence_defs: Dictionary = GameContent.essences()
var monster_defs: Dictionary = GameContent.monsters()
var region_defs: Dictionary = GameContent.regions()
var companion_defs: Dictionary = GameContent.companions()
var frame_capture: String = ""

func _ready() -> void:
	font = load("res://assets/pixelify_sans.ttf")
	mono_font = load("res://assets/vt323.ttf")
	var saved_settings: Dictionary = SaveStore.load_settings()
	settings = preload("res://game/settings_validation.gd").sanitize(saved_settings, settings)
	audio = GameAudio.new()
	add_child(audio)
	apply_settings()
	sim.cue.connect(func(name: String) -> void:
		audio.play(name)
		if name == "hit": hit_flash = 0.18)
	sim.message.connect(func(_text: String) -> void: pass)
	background_id = str(GameContent.backgrounds().keys()[0])
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var content_errors: Array[String] = GameContent.validate()
	if not content_errors.is_empty(): notice = "Content validation: " + str(content_errors[0]); push_error(notice)
	developer_enabled = OS.get_cmdline_user_args().has("--dev")
	audio.ambient("city")
	render()
	if OS.get_cmdline_user_args().has("--smoke"): smoke_run.call_deferred()

func apply_settings() -> void:
	if audio != null:
		audio.set_volumes(float(settings.master), float(settings.music), float(settings.sfx))
		audio.muted = bool(settings.muted)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _process(delta: float) -> void:
	clock_time += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	notice_time = maxf(0.0, notice_time - delta)
	update_visual_units(delta)
	queue_redraw()

func update_visual_units(delta: float) -> void:
	if screen != "game" or sim.state.get("mode", "") != "dungeon":
		visual_units.clear(); visual_area = -1; return
	var area_seed: int = int(sim.state.map.seed)
	if visual_area != area_seed: visual_units.clear(); visual_area = area_seed
	var present: Dictionary = {}
	for unit: Dictionary in sim.allies() + sim.enemies():
		present[unit.id] = true
		var target: Vector2 = Vector2(unit.pos) * TILE
		if not visual_units.has(unit.id): visual_units[unit.id] = {"from": target, "to": target, "point": target, "age": 1.0, "facing": int(unit.get("facing", 0))}
		var visual: Dictionary = visual_units[unit.id]
		if visual.to != target:
			var travel: Vector2 = target - visual.to
			visual.facing = 1 if travel.x < 0 else 2 if travel.x > 0 else 3 if travel.y < 0 else 0
			visual.from = visual.point if travel.length() <= TILE * 2 else target
			visual.to = target
			visual.age = 0.0
		visual.age = minf(1.0, float(visual.age) + delta / 0.16)
		visual.point = target if settings.reduced_motion else Vector2(visual.from).lerp(target, float(visual.age)).round()
	for id: String in visual_units.keys():
		if not present.has(id): visual_units.erase(id)

func tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path: String = "res://assets/" + id + ".png"
		textures[id] = water_skin_texture() if id == "water_skin" else numbered_texture(id) if id in ["frost_spirit_ring", "guardians_braces"] else stone_golem_texture() if id == "classic_monster_stone_golem" else (tube_texture(id) if id.begins_with("tube_") else (load(path) if ResourceLoader.exists(path) else null))
	return textures[id]

func numbered_texture(id: String) -> Texture2D:
	var img := Image.create(24,24,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	if id == "frost_spirit_ring":
		for y: int in range(7,21):
			for x: int in range(5,19):
				var d: float = Vector2(x-11.5,y-13.5).length()
				if d >= 4.4 and d <= 6.5: img.set_pixel(x,y,Color("adbac0") if x<12 else Color("53646c"))
		img.fill_rect(Rect2i(8,3,8,7),Color("28454f"));img.fill_rect(Rect2i(9,4,6,5),Color("70b5ce"));img.fill_rect(Rect2i(10,4,2,2),Color("d6eff3"))
	else:
		for x: int in [3,13]:
			img.fill_rect(Rect2i(x,5,8,15),Color("4d606b"));img.fill_rect(Rect2i(x,6,7,2),Color("bed2d1"));img.fill_rect(Rect2i(x+1,10,6,6),Color("758f98"));img.fill_rect(Rect2i(x+3,11,2,4),Color("75c6b5"));img.fill_rect(Rect2i(x,18,7,2),Color("b7c3c2"))
	return ImageTexture.create_from_image(img)

func tube_texture(id: String) -> Texture2D:
	var image: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(7, 3, 10, 3), Color("393e3d"))
	image.fill_rect(Rect2i(8, 5, 8, 15), Color("809f9f"))
	image.fill_rect(Rect2i(9, 6, 6, 13), Color("172d34"))
	image.fill_rect(Rect2i(9, 19, 6, 2), Color("809f9f"))
	image.fill_rect(Rect2i(7, 2, 10, 2), Color("bd9463"))
	if id != "tube_empty":
		var liquid: Color = Color("b1c96b") if id.contains("archer") else Color("87b3d4") if id.contains("gnome") else Color("d3b95c")
		image.fill_rect(Rect2i(9, 11, 6, 8), liquid.darkened(0.35))
		image.fill_rect(Rect2i(10, 11, 4, 2), liquid)
	image.fill_rect(Rect2i(9, 6, 1, 12), Color("cfdfdb"))
	image.set_pixel(10, 20, Color("cfdfdb"))
	return ImageTexture.create_from_image(image)

func stone_golem_texture() -> Texture2D:
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var blocks: Array[Rect2i] = [Rect2i(9,3,14,9),Rect2i(8,13,16,11),Rect2i(2,11,6,13),Rect2i(24,11,6,13),Rect2i(8,24,7,6),Rect2i(18,24,7,6)]
	for block: Rect2i in blocks:
		image.fill_rect(block,Color("20282c"))
		image.fill_rect(block.grow(-1),Color("64726d"))
		image.fill_rect(Rect2i(block.position+Vector2i.ONE,Vector2i(block.size.x-2,2)),Color("95a28c"))
		image.fill_rect(Rect2i(block.end-Vector2i(block.size.x-1,3),Vector2i(block.size.x-2,2)),Color("3e4b49"))
	image.fill_rect(Rect2i(11,7,3,2),Color("dac579")); image.fill_rect(Rect2i(18,7,3,2),Color("dac579"))
	image.fill_rect(Rect2i(15,17,2,5),Color("2e393a")); image.set_pixel(17,19,Color("dac579"))
	return ImageTexture.create_from_image(image)

func style(fill: Color = PANEL, edge: Color = EDGE, margin: int = 6) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	return box

func setup_theme() -> void:
	var t: Theme = Theme.new()
	t.default_font = mono_font if screen == "game" and mono_font != null else font
	t.default_font_size = int((14 if screen == "game" else 11) * float(settings.text_scale))
	t.set_color("font_color", "Label", PALE)
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("5a6875"))
	t.set_stylebox("normal", "Button", style(PANEL, EDGE, 4))
	t.set_stylebox("hover", "Button", style(Color("1b1e1e"), PALE, 4))
	t.set_stylebox("pressed", "Button", style(Color("313636"), PALE, 4))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD, 4))
	t.set_stylebox("disabled", "Button", style(Color("030405"), Color("454b4b"), 4))
	t.set_stylebox("normal", "LineEdit", style(INK, EDGE, 4))
	t.set_stylebox("focus", "LineEdit", style(INK, GOLD, 4))
	t.set_color("font_color", "LineEdit", PALE)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("panel", "PanelContainer", style())
	t.set_stylebox("panel", "TooltipPanel", style(INK, GOLD))
	t.set_color("font_color", "TooltipLabel", PALE)
	t.set_font_size("font_size", "TooltipLabel", 11)
	ui.theme = t

func clear_ui() -> void:
	for child: Node in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	setup_theme()

func at(control: Control, rectangle: Rect2, parent: Node = null) -> Control:
	(parent if parent != null else ui).add_child(control)
	control.position = rectangle.position
	control.size = rectangle.size
	return control

func label(text: String, parent: Node, size_value: int = 11, color: Color = PALE, wrap: bool = true) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int((size_value + (3 if screen == "game" else 0)) * float(settings.text_scale)))
	l.add_theme_color_override("font_color", color)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func text_at(text: String, rectangle: Rect2, size_value: int = 11, color: Color = PALE) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", int((size_value + (3 if screen == "game" else 0)) * float(settings.text_scale)))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	l.position = rectangle.position
	l.size = rectangle.size
	return l

func button(text: String, action: Callable, parent: Node, hint: String = "", disabled: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size.y = 23
	b.tooltip_text = hint
	b.disabled = disabled
	b.pressed.connect(func() -> void: audio.play("ui"); action.call())
	parent.add_child(b)
	return b

func button_at(text: String, rectangle: Rect2, action: Callable, hint: String = "", disabled: bool = false) -> Button:
	var b: Button = button(text, action, ui, hint, disabled)
	b.position = rectangle.position
	b.size = rectangle.size
	return b

func column(rectangle: Rect2, panel: bool = true) -> VBoxContainer:
	var parent: Control = ui
	if panel:
		var p: PanelContainer = PanelContainer.new()
		at(p, rectangle)
		parent = p
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	if panel: parent.add_child(v)
	else: at(v, rectangle)
	return v

func scroll_column(rectangle: Rect2) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	at(p, rectangle)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	scroll.add_child(v)
	return v

func row(parent: Node) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	return h

func flash(text: String) -> void:
	if text.is_empty():
		notice = ""; notice_time = 0.0; return
	notice = text
	notice_time = 6.0
	if not sim.state.is_empty(): sim.say(text)

func action_result(result: String) -> void:
	flash(result)
	render()

func render() -> void:
	if not sim.state.is_empty():
		item_defs = sim.item_defs
		essence_defs = sim.essence_defs
		monster_defs = sim.monster_defs
		region_defs = sim.region_defs
		companion_defs = sim.companion_defs
	clear_ui()
	if screen == "title": render_title()
	elif screen == "create": render_creation()
	else:
		match str(sim.state.get("mode", "city")):
			"dungeon": render_dungeon()
			"city":
				if not str(sim.state.get("homeland",{}).get("location","")).is_empty(): render_homeland()
				else: render_city()
			"dead": render_defeat()
	if not overlay.is_empty(): render_overlay()
	if notice_time > 0.0 and not notice.is_empty():
		var note: PanelContainer = PanelContainer.new()
		note.add_theme_stylebox_override("panel", style(Color("111415"), GOLD, 4))
		at(note, Rect2(30, 318, 580, 36))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var note_label: Label = label(notice, note, 10, PALE)
		note_label.max_lines_visible = 2
	queue_redraw()
	if not overlay.is_empty():
		for control: Node in ui.find_children("*", "Button", true, false):
			if control.text == "CLOSE [Esc]": control.grab_focus(); break
	elif screen == "game" and sim.state.get("mode", "") == "city" and homeland_view!=null and is_instance_valid(homeland_view) and homeland_view.is_inside_tree():
		homeland_view.grab_focus()
	elif screen == "game" and sim.state.get("mode", "") == "city":
		for control: Node in ui.get_children():
			if control is CityMap: control.focus_location(city_location); break
	elif get_viewport().gui_get_focus_owner() == null:
		for control: Node in ui.find_children("*", "Button", true, false):
			if not control.disabled: control.grab_focus(); break

func render_title() -> void:
	text_at("DUNGEON\n& STONE", Rect2(40, 65, 400, 130), 48)
	button_at("NEW GAME", Rect2(46, 240, 170, 28), func() -> void: screen = "create"; render())
	button_at("CONTINUE", Rect2(46, 274, 170, 28), func() -> void: overlay = "load"; render())
	button_at("SETTINGS", Rect2(224, 274, 106, 28), func() -> void: overlay = "settings"; render())
	text_at("DEVELOPMENT BUILD " + str(ProjectSettings.get_setting("application/config/version", "")), Rect2(44, 328, 520, 16), 9, MUTED)

func render_creation() -> void:
	new_appearance = CharacterArt.normalize(new_appearance, ancestry_id, int(new_seed) if new_seed.is_valid_int() else 74119)
	text_at("CREATE YOUR EXPLORER", Rect2(18, 12, 570, 25), 21, GOLD)
	var left: VBoxContainer = scroll_column(Rect2(18, 44, 192, 268))
	label("RACE", left, 10, TEAL)
	for id: String in GameContent.ancestries():
		var a: Dictionary = GameContent.ancestries()[id]
		button(("> " if id == ancestry_id else "") + str(a.name), func() -> void: ancestry_id = id; render(), left)
	var right: VBoxContainer = scroll_column(Rect2(220, 44, 402, 268))
	var ancestry: Dictionary = GameContent.ancestries()[ancestry_id]
	var background: Dictionary = GameContent.backgrounds()[background_id]
	label(str(ancestry.name).to_upper(), right, 19, GOLD)
	var profile_row: HBoxContainer = row(right)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = portrait_texture({"id": "hero", "ancestry": ancestry_id, "appearance": new_appearance})
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_row.add_child(portrait)
	var profile: VBoxContainer = VBoxContainer.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_child(profile)
	label("STR %d   AGI %d   WIT %d   VIG %d" % [4 + int(ancestry.str), 4 + int(ancestry.agi), 4 + int(ancestry.wit), 4 + int(ancestry.vig)], profile, 11)
	label("Starting stats: unverified", profile, 10, MUTED).tooltip_text = str(ancestry.desc) + "\n" + str(ancestry.trait)
	button("CUSTOMIZE", func() -> void: begin_customization(), right)
	label(str(background.name), right, 11, MUTED).tooltip_text = str(background.desc)
	label("%d ST · F%d W%d · %d potions" % [background.gold,background.food,EarlyFloorRules.WATER_START,background.potions], right, 11, GOLD)
	var h: HBoxContainer = row(right)
	var name_field: LineEdit = LineEdit.new()
	name_field.placeholder_text = "Name"
	name_field.text = new_name
	name_field.max_length = 22
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.text_changed.connect(func(value: String) -> void: new_name = value)
	h.add_child(name_field)
	var seed_field: LineEdit = LineEdit.new()
	seed_field.placeholder_text = "Seed"
	seed_field.text = new_seed
	seed_field.custom_minimum_size.x = 95
	seed_field.max_length = 9
	seed_field.text_changed.connect(func(value: String) -> void: new_seed = value)
	h.add_child(seed_field)
	var slot_row: HBoxContainer = row(right)
	label("SAVE SLOT", slot_row, 11, GOLD, false)
	for slot: int in range(1, 4): button(("> " if slot == save_slot else "") + str(slot), func() -> void: save_slot = slot; render(), slot_row)
	label("Death is permanent.", right, 10, MUTED)
	button_at("BACK", Rect2(18, 321, 95, 26), func() -> void: screen = "title"; render())
	button_at("BEGIN GAME", Rect2(420, 321, 202, 26), func() -> void:
		var begin: Callable = func() -> void:
			sim.new_campaign(new_name, ancestry_id, background_id, int(new_seed) if new_seed.is_valid_int() else 74119, new_appearance)
			sim.enter_homeland(ancestry_id)
			screen = "game"; jump_targeting = false; selected_ability = -1; selected_region = 1; selected_party = "hero"; save_game(); render()
		var previous: Dictionary = SaveStore.load_campaign_slot(save_slot)
		if previous.ok:
			confirm_text = "Replace save slot %d? The current campaign in this slot will become its backup." % save_slot
			pending_confirm = begin; overlay = "confirm"; render()
		else: begin.call())

func top_bar(subtitle: String) -> void:
	var p: PanelContainer = PanelContainer.new()
	at(p, Rect2(8, 5, 624, 31))
	var h: HBoxContainer = HBoxContainer.new()
	p.add_child(h)
	var title: Label = label(subtitle, h, 13, GOLD, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	var supplies: Label=label("DAY %d  %d ST  F%d W%d" % [sim.state.day,sim.state.gold,sim.state.food,sim.state.get("water",EarlyFloorRules.WATER_START)],h,11,PALE,false)
	supplies.tooltip_text=supply_tooltip(); supplies.mouse_filter=Control.MOUSE_FILTER_PASS
	button("I", func() -> void: overlay = "inventory"; render(), h, "Pack [I]")
	button("P", func() -> void: overlay = "party"; render(), h, "Party [P]")
	button("J", func() -> void: overlay = "journal"; render(), h, "Journal [J]")
	if sim.state.get("mode", "") == "city": button("LANDS",func() -> void: overlay = "homelands"; render(),h,"Visit the racial lands.")
	if sim.state.get("mode", "") == "city": button("SAVE", func() -> void: save_game(); flash("Game saved."); render(), h, "Save [F5]")
	button("=", func() -> void: overlay = "pause"; render(), h, "Pause / settings [Esc]")



func render_city() -> void:
	audio.ambient("city")
	sim.ensure_city_state()
	top_bar("RAFDONIA · DISTRICT 7")
	var city: CityMap = CityMap.new()
	at(city, Rect2(8, 44, 624, 306))
	var locals: Array = []
	for npc: Dictionary in CityLife.roster(sim.state):
		if npc.has("companion_id"): continue
		npc.location_id = city_npc_location(str(npc.id))
		npc.location = npc.location_id
		locals.append(npc)
	city.configure({"npcs": locals, "reduced_motion": bool(settings.reduced_motion), "seed": int(sim.state.seed), "day": int(sim.state.day)}, sim.hero())
	city.location_selected.connect(open_city_location)
	city.npc_selected.connect(talk_to_npc)

func city_npc_location(npc_id: String) -> String:
	if npc_id.begins_with("companion_"): return "companions"
	return str({"innkeeper": "inn", "cook": "inn", "merchant": "market", "appraiser": "market", "tailor": "market", "smith": "workshop", "guild_clerk": "guild", "scholar": "guild", "scout": "companions", "veteran": "companions", "herbalist": "sanctum", "gate_guard": "portal"}.get(npc_id, "guild"))

func open_city_location(id: String) -> void:
	city_location = id
	trading_npc = "merchant" if id == "market" else ""
	if id == "storage":
		inventory_storage = true; inventory_selected = ""; overlay = "inventory"
	else: overlay = "city_location"
	render()

func talk_to_npc(id: String) -> void:
	selected_npc = id
	npc_line = ""
	overlay = "npc"
	render()

func city_npc_card(npc: Dictionary, parent: Node, with_dialogue: bool = false) -> void:
	var card: HBoxContainer = row(parent)
	var face: Button = button("", func() -> void: talk_to_npc(str(npc.id)), card, str(npc.name))
	face.custom_minimum_size = Vector2(64, 64)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = CharacterArt.portrait(npc)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at(portrait, Rect2(0, 0, 64, 64), face)
	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(details)
	label(str(npc.name), details, 14, GOLD)
	var dialogue: Dictionary = CityLife.dialogue(sim.state, str(npc.id))
	if with_dialogue: label(str(dialogue.line), details, 11, MUTED)
	else: button("TALK", func() -> void: talk_to_npc(str(npc.id)), details)
	var discount: int = CityLife.market_discount(sim.state, str(npc.id))
	if discount > 0: label("Prices −%d%%" % discount, details, 11, TEAL)

func render_city_location() -> void:
	var titles: Dictionary = {"inn": "INN", "market": "MARKET", "companions": "RECRUITMENT", "workshop": "BLACKSMITH", "sanctum": "APOTHECARY", "guild": "EXPLORERS GUILD", "portal": "DIMENSIONAL SQUARE"}
	var content: VBoxContainer = modal(str(titles.get(city_location, "CITY")))
	var host: String = str({"inn": "innkeeper", "market": trading_npc if not trading_npc.is_empty() else "merchant", "companions": "veteran", "workshop": "smith", "sanctum": "herbalist", "guild": "guild_clerk", "portal": "gate_guard"}.get(city_location, ""))
	if not host.is_empty(): city_npc_card(sim.state.city_life.npcs[host], content)
	match city_location:
		"inn":
			service_button("Rest / %d stones" % (6 + sim.state.party.size() * 3), "rest", content)
			service_button("4 rations / 8 stones", "rations", content)
			service_button("Relief work", "relief", content)
			if int(sim.state.day) != 1: button("Wait until next opening", func() -> void: sim.wait_for_opening(); save_game(); render(), content)
		"market", "sanctum":
			if city_location == "sanctum": trading_npc = "herbalist"
			service_button("4 rations / 8 stones", "rations", content)
			if city_location == "market": button("TAILOR / 5 stones", func() -> void: begin_customization("hero"), content)
			for id: String in item_defs:
				var item: Dictionary = item_defs[id]
				if item.kind == "material" or (int(item.price) > 130 and not item.get("market_unlocked", false)): continue
				if city_location == "sanctum" and item.kind != "consumable": continue
				button("%s / %d ST" % [item.name, sim.market_price(id, true, trading_npc)], func() -> void: action_result(sim.buy(id, trading_npc)); save_game(), content, item_tooltip(id))
			button("SELL / STORAGE", func() -> void: inventory_storage = false; overlay = "inventory"; render(), content)
		"workshop":
			service_button("Repair / %d stones" % (5 + int(sim.state.unlocked)), "repair", content)
			button("EQUIPMENT", func() -> void: overlay = "inventory"; render(), content)
		"companions":
			for id: String in companion_defs:
				var definition: Dictionary = companion_defs[id]
				if int(definition.get("unlock_region", 1)) > int(sim.state.unlocked): continue
				var preview: Dictionary = {"id": "comp_" + id, "name": definition.name, "role": definition.role}
				preview.ancestry = str(definition.ancestry)
				preview.appearance = CharacterArt.normalize(definition.get("appearance", {}), preview.ancestry, int(sim.state.seed) + str(preview.id).hash())
				var h: HBoxContainer = row(content)
				var face: TextureRect = TextureRect.new()
				face.texture = CharacterArt.portrait(preview)
				face.custom_minimum_size = Vector2(64, 64)
				face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				h.add_child(face)
				var detail: VBoxContainer = VBoxContainer.new()
				detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(detail)
				label(str(definition.name), detail, 13)
				label("%s · %s" % [GameContent.ancestries()[definition.ancestry].name, definition.role], detail, 11, MUTED)
				button("JOIN / %d ST" % maxi(0, int(definition.cost) - int(sim.state.unlocked) * 2), func() -> void: action_result(sim.recruit(id)); save_game(), detail, str(definition.desc), sim.state.roster.has(id) or sim.state.get("fallen_ids", []).has(id))
		"guild":
			for task: Dictionary in CityLife.tasks(sim.state):
				if task.claimed: continue
				var objective: String = ""
				for progress: Dictionary in task.progress:
					objective += (" · " if not objective.is_empty() else "") + "%d/%d" % [mini(int(progress.current), int(progress.target)), progress.target]
				button("%s  %s" % [task.name, objective], func() -> void: talk_to_npc(str(task.npc_id)), content, str(task.desc))
			button("JOURNAL", func() -> void: overlay = "journal"; render(), content)
		"portal":
			label("CRYSTAL CAVE", content, 19, TEAL)
			label("Floor 1 · 7 days", content, 12, MUTED)
			var party: HBoxContainer = row(content)
			for unit: Dictionary in sim.allies():
				var portrait: Button = button("", func() -> void: selected_party = unit.id; overlay = "party"; render(), party, unit_tooltip(unit))
				portrait.icon = CharacterArt.portrait(unit)
				portrait.expand_icon = true
				portrait.custom_minimum_size = Vector2(54, 54)
			label("F%d W%d · Pack %.1f/%d · Party %d/5" % [sim.state.food,sim.state.get("water",EarlyFloorRules.WATER_START),sim.weight(),sim.capacity(),sim.allies().size()],content,12)
			if int(sim.state.day) == 1:
				button("ENTER LABYRINTH", func() -> void:
					if sim.enter_region(1): selected_ability = -1; overlay = ""; save_game()
					render(), content)
			else:
				button("Wait until next opening", func() -> void: sim.wait_for_opening(); save_game(); render(), content)

func render_npc() -> void:
	var npc: Dictionary = sim.state.city_life.npcs.get(selected_npc, {})
	if npc.is_empty(): overlay = ""; return
	var dialogue: Dictionary = CityLife.dialogue(sim.state, selected_npc)
	var content: VBoxContainer = modal(str(npc.name).to_upper())
	city_npc_card(npc, content, true)
	if not npc_line.is_empty(): label(npc_line, content, 12, TEAL)
	for choice: Dictionary in dialogue.choices:
		var title: String = str(choice.label)
		if choice.has("service"):
			match str(choice.service):
				"rest": title = "Rest / %d ST" % (6 + sim.state.party.size() * 3)
				"rations": title = "4 rations / 8 ST"
				"repair": title = "Repair / %d ST" % (5 + int(sim.state.unlocked))
		if choice.get("open", "") == "customize": title = "Appearance / 5 ST"
		button(title, func() -> void:
			var result: Dictionary = sim.interact_npc(selected_npc, str(choice.id))
			npc_line = str(result.get("message", ""))
			if result.get("ok", false):
				if str(choice.id) == "leave": overlay = ""
				elif result.has("open"):
					var destination: String = str(result.open)
					if destination == "customize": begin_customization("hero"); save_game(); return
					elif destination in ["market", "companions", "portal"]:
						city_location = destination; trading_npc = selected_npc if destination == "market" else ""; overlay = "city_location"
					else: overlay = destination
				save_game()
			render(), content, str(choice.get("progress", "")))

func service_button(title: String, id: String, parent: Node) -> void:
	button(title, func() -> void: action_result(sim.city_service(id)); save_game(), parent)

func render_footer() -> void:
	var recent: String = str(sim.state.log[-1]) if not sim.state.log.is_empty() else ""
	text_at(recent, Rect2(12, 321, 616, 32), 10, MUTED)

func render_dungeon() -> void:
	var region: Dictionary = sim.region_data()
	audio.ambient("dungeon")
	var unit: Dictionary = sim.selected()
	var enlarged_hud: bool = float(settings.text_scale) > 1.05
	var stats: VBoxContainer = column(Rect2(448, 8, 184, 132 if enlarged_hud else 112))
	var actor_button: Button=button("[ %s ]" % str(unit.name),func() -> void: overlay="party"; render(),stats,unit_tooltip(unit))
	actor_button.clip_text=true; actor_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var race_name: String = str(GameContent.ancestries().get(unit.get("ancestry", ""), {}).get("name", unit.role))
	label("Mage   " + race_name if unit.get("profession", "") == "mage" else "Level: %d   %s" % [sim.state.level, race_name], stats, 10)
	resource_bar(stats, "HP", int(unit.hp), int(unit.max_hp), Color("91b34d"))
	resource_bar(stats, "MANA" if int(unit.get("max_mana", 0)) > 0 else "SP", int(unit.get("mana", 0)) if int(unit.get("max_mana", 0)) > 0 else int(unit.energy), int(unit.get("max_mana", 0)) if int(unit.get("max_mana", 0)) > 0 else int(unit.max_energy), Color("669eb9"))
	label("STR %d  AGI %d  WIT %d  VIG %d" % [sim.stat_value(unit,"strength"), sim.stat_value(unit,"agility"), sim.stat_value(unit,"wit"), sim.stat_value(unit,"vigor")], stats, 9)
	label("ATK %d   ARM %d   AP %d" % [sim.stat_value(unit,"attack"), sim.stat_value(unit,"armor"), maxi(0, int(unit.ap)) if sim.state.combat else int(sim.stat_value(unit,"action_points"))], stats, 10)
	var inventory: VBoxContainer = column(Rect2(448, 145 if enlarged_hud else 125, 184, 137 if enlarged_hud else 157))
	label("INVENTORY    %d stones" % sim.state.gold, inventory, 10)
	var bag_grid: GridContainer = GridContainer.new()
	bag_grid.columns = 5
	bag_grid.add_theme_constant_override("h_separation", 3)
	bag_grid.add_theme_constant_override("v_separation", 3)
	inventory.add_child(bag_grid)
	var ids: Array = sim.state.inventory.keys()
	for index: int in range(15 if enlarged_hud else 20):
		if index < ids.size():
			var id: String = str(ids[index])
			item_slot(id, int(sim.state.inventory[id]), 29, func() -> void:
				inventory_selected = id; overlay = "inventory"; render(), bag_grid)
		else: item_slot("", 0, 29, func() -> void: overlay = "inventory"; render(), bag_grid)
	var party_row: HBoxContainer = HBoxContainer.new()
	at(party_row, Rect2(454, 285, 173, 34))
	party_row.add_theme_constant_override("separation", 3)
	for ally: Dictionary in sim.allies():
		if ally.get("summon", false): continue
		var portrait: Button = button("", func() -> void: sim.state.selected = ally.id; selected_ability = -1; render(), party_row, unit_tooltip(ally))
		portrait.custom_minimum_size = Vector2(32, 32)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = portrait_texture(ally)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		at(sprite, Rect2(0, 0, 32, 32), portrait)
		if ally.id == sim.state.selected: portrait.add_theme_stylebox_override("normal", style(Color("252b23"), TEAL, 2))
	button_at("MAP", Rect2(448, 324, 56, 25), func() -> void: overlay = "map"; render())
	button_at("REST", Rect2(509, 324, 59, 25), func() -> void: sim.camp(); after_command(), "Rest eight hours outside combat.")
	button_at("MENU", Rect2(573, 324, 59, 25), func() -> void: overlay = "pause"; render())
	var commands: HBoxContainer = HBoxContainer.new()
	at(commands, Rect2(8, 268, 432, 26))
	commands.add_theme_constant_override("separation", 3)
	button("E / INTERACT", func() -> void: do_interact(), commands)
	button("SPACE / END", func() -> void: sim.end_phase(); after_command(), commands, "Spend remaining AP to guard, then end the party phase. Incapacitated allies cannot guard.")
	button("JUMP",func() -> void: jump_targeting = not jump_targeting; selected_ability = -1; render(),commands,"Jump to a visible tile [V]. Two movement actions; cannot cross walls. Provisional traversal rule.")
	var techniques: Array[Dictionary] = sim.techniques(unit)
	for i: int in range(mini(3, techniques.size())):
		var technique: Dictionary = techniques[i]
		var b: Button = button("%d %s" % [i + 1, technique.ability.name], func() -> void: selected_ability = i; render(), commands, technique_tooltip(technique))
		b.clip_text = true
		b.custom_minimum_size.x = 61
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var log_panel: VBoxContainer = column(Rect2(8, 296, 432, 56))
	var heading: HBoxContainer = row(log_panel)
	var location: String = "%s / %dh%02dm" % [region.name, int(sim.state.time)/60, int(sim.state.time)%60]
	var location_label: Label=label(location,heading,9,MUTED,false)
	location_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; location_label.clip_text=true
	var supplies: Label=label("F%d W%d" % [sim.state.food,sim.state.get("water",EarlyFloorRules.WATER_START)],heading,9,PALE,false)
	supplies.tooltip_text=supply_tooltip(); supplies.mouse_filter=Control.MOUSE_FILTER_PASS
	if sim.allies().any(func(a: Dictionary) -> bool: return a.statuses.has("suppressed")): button("FREE ALLY", func() -> void: overlay = "release"; render(), heading, "A free adjacent ally makes a controlled 1 HP cut; costs an attack and one AP.")
	var log_button: Button = button("LOG", func() -> void: overlay = "log"; render(), heading)
	log_button.add_theme_font_size_override("font_size", 11)
	log_button.add_theme_stylebox_override("normal", style(Color.BLACK, EDGE, 1))
	log_button.custom_minimum_size.y = 14
	var log_line: String = str(sim.state.log[-1]) if not sim.state.log.is_empty() else "Awaiting command."
	if jump_targeting: log_line = "JUMP: click a landing tile · Esc cancels"
	if selected_ability >= 0 and selected_ability < techniques.size(): log_line = "TARGET: %s. Click a tile; Escape cancels." % techniques[selected_ability].ability.name
	var log_label: Label = text_at(log_line, Rect2(14, 326, 416, 18), 10, TEAL if selected_ability >= 0 else PALE)
	log_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	log_label.size = Vector2(416, 18)
	log_label.clip_text = true
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func resource_bar(parent: Node, title: String, amount: int, maximum: int, color: Color) -> void:
	var h: HBoxContainer = row(parent)
	label(title, h, 9, PALE, false).custom_minimum_size.x = 17
	var progress: ProgressBar = ProgressBar.new()
	progress.max_value = maxi(1, maximum)
	progress.value = amount
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(70, 7)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_theme_stylebox_override("background", style(Color("0b0d0d"), Color("5f6865"), 0))
	progress.add_theme_stylebox_override("fill", style(color, color, 0))
	h.add_child(progress)
	label("%d/%d" % [amount, maximum], h, 9, PALE, false)

func portrait_texture(unit: Dictionary) -> Texture2D:
	return CharacterArt.portrait(unit)

func item_icon(id: String) -> String:
	var item: Dictionary = item_defs.get(id, {})
	if id in ["frost_spirit_ring","guardians_braces","water_skin"]: return id
	if id=="magic_torch": return "torch"
	if id.contains("mana_stone"): return "essence"
	if id == "essence_test_tube": return "tube_empty"
	if item.has("contained_essence"): return "tube_" + str(item.contained_essence)
	match str(item.get("kind", "")):
		"weapon": return "sword"
		"armor": return "shield"
		"accessory": return "essence"
		"material": return "material"
		"consumable": return "food" if str(item.get("effect", "")) == "food" else "healing_potion"
	return "coin"

func item_slot(id: String, amount: int, extent: int, callback: Callable, parent: Node) -> Button:
	var b: Button = button("", callback, parent, item_tooltip(id) if not id.is_empty() else "Empty slot")
	b.custom_minimum_size = Vector2(extent, extent)
	b.add_theme_stylebox_override("normal", style(Color.BLACK, Color("7b8582"), 1))
	if not id.is_empty():
		var icon: TextureRect = TextureRect.new()
		icon.texture = tex(item_icon(id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		at(icon, Rect2((extent - 24) / 2, 1, 24, 24), b)
		if amount > 1:
			var count: Label = label(str(amount), b, 8, Color.WHITE, false)
			count.position = Vector2(2, extent - 11)
			count.size = Vector2(extent - 4, 10)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return b

func after_command() -> void:
	if sim.state.get("mode", "") != "dungeon": selected_ability = -1; save_game()
	render()

func do_interact() -> void:
	var result: String = sim.interact()
	if result == "portal": overlay = "portal"
	if result == "essence": overlay = "essences"
	if result == "memorial": overlay = "memorial"
	if result == "hut":
		var failure: String=sim.enter_witch_hut()
		if failure.is_empty(): overlay="witch_hut"
		else: flash(failure)
	after_command()

func status_text(unit: Dictionary) -> String:
	var result: String = ""
	for id: String in unit.statuses:
		var short: String=str({"field_disoriented":"DISORIENTED","field_hallucinations":"HALLUCINATIONS","field_pain":"PAIN+","toppled":"TOPPLED","anchored":"ANCHOR","frenzy":"FRENZY"}.get(id,id.left(3).to_upper()))
		result+=short+(" " if id in ThirdFloorRules.FIELD_STATUSES or id=="toppled" else ":%d " % int(unit.statuses[id]))
	return result

func _number(value: float) -> String:
	if is_zero_approx(value): return "0"
	return ("%.2f" % value).rstrip("0").rstrip(".")

func _signed_number(value: float) -> String:
	return ("+" if value >= 0 else "") + _number(value)

func _stat_name(id: String) -> String:
	return str(UIStats.definitions().get(id, {}).get("name",id.replace("_"," ").capitalize()))

func _stat_display(id: String, value: float) -> String:
	var unit: String = str(UIStats.definitions().get(id, {}).get("unit",""))
	if unit == "percent": return _number(value) + "%"
	if unit == "points": return _number(value) + " pt"
	if id.ends_with("_multiplier") or id == "natural_recovery": return "×" + _number(value)
	return _number(value)

func _tooltip_unit() -> Dictionary:
	if sim.state.is_empty(): return {}
	if overlay in ["party","stats","inventory","essences","ring_seal"]:
		var chosen: Dictionary = sim.unit_by_id(selected_party)
		if not chosen.is_empty(): return chosen
	return sim.selected()

func _modifier_text(modifier: Dictionary) -> String:
	var id: String = str(modifier.get("stat",""))
	var amount: float = float(modifier.get("value",0))
	var operation: String = ""
	match str(modifier.get("op","")):
		"add": operation = _signed_number(amount)
		"increase": operation = _signed_number(amount*100) + "% increased"
		"multiply": operation = "×" + _number(amount)
		"at_least": operation = "minimum " + _number(amount)
		_: return ""
	var definition: Dictionary = UIStats.definitions().get(id,{})
	return "%s %s%s" % [_stat_name(id),operation," · catalog only" if not definition.get("implemented",false) else ""]

func _modifier_lines(modifiers: Array) -> Array[String]:
	var lines: Array[String] = []
	for entry: Variant in modifiers:
		if not entry is Dictionary: continue
		var text: String = _modifier_text(entry)
		if not text.is_empty(): lines.append(text)
	return lines

func _contributor_name(source: String) -> String:
	var key: String = source.replace("/",":").replace(".",":").get_slice(":",source.replace("/",":").replace(".",":").get_slice_count(":")-1)
	if item_defs.has(key): return str(item_defs[key].name)
	if essence_defs.has(key): return str(essence_defs[key].name)
	if GameContent.ancestries().has(key): return str(GameContent.ancestries()[key].name)
	return key.replace("_"," ").capitalize()

func item_tooltip(id: String) -> String:
	var item: Dictionary = item_defs.get(id,{})
	if item.is_empty(): return ""
	var lines: Array[String] = [str(item.name),str(item.desc)]
	lines.append_array(_modifier_lines(item.get("modifiers",[])))
	if int(item.get("str_req",0)) > 0 or int(item.get("agi_req",0)) > 0: lines.append("Requires STR %d / AGI %d" % [item.get("str_req",0),item.get("agi_req",0)])
	lines.append("Weight %.1f · Sell %d ST" % [item.get("weight",0),sim.market_price(id,false)])
	if item.get("experimental_balance",false): lines.append("Numerical values are provisional.")
	return "\n".join(lines)

func unit_tooltip(unit: Dictionary) -> String:
	return "%s / %s\nSTR %s AGI %s WIT %s VIG %s\nAttack %s / Armor %s / Range %s\nAccuracy %s − target Evasion; Evasion %s\n%s %s / injuries %d / gear %d%%\n%s" % [unit.name,unit.role,_number(sim.stat_value(unit,"strength")),_number(sim.stat_value(unit,"agility")),_number(sim.stat_value(unit,"wit")),_number(sim.stat_value(unit,"vigor")),_number(sim.stat_value(unit,"attack")),_number(sim.stat_value(unit,"armor")),_number(sim.stat_value(unit,"attack_range")),_number(sim.stat_value(unit,"accuracy")),_number(sim.stat_value(unit,"evasion")),"Mana" if sim.stat_value(unit,"max_mana") > 0 else "Soul Power",_number(sim.stat_value(unit,"max_mana") if sim.stat_value(unit,"max_mana") > 0 else sim.stat_value(unit,"max_soul_power")),unit.injuries,unit.durability,status_text(unit)]

func essence_summary(id: String, unit: Dictionary = {}) -> String:
	var e: Dictionary=essence_defs[id]
	var effect: String=str(e.desc)
	match id:
		"canon_goblin": effect="Melee hits: paralysis. Places a trap."
		"canon_goblin_archer": effect="Bow hits: poison. Thief Step conceals you."
		"canon_gnome": effect="Conceals nearby allies. Moving ends the field."
		"canon_stone_golem": effect="Immobilizes an area. Any damage breaks Suppression."
		"canon_death_fiend": effect="Physical Preservation: "+", ".join(_modifier_lines(e.get("passive_modifiers",[])))+" (estimate)."
	if str(e.get("ability",{}).get("effect","")).is_empty():
		return "Tracks nearby creatures by smell. Anonymous traces do not reveal terrain or identity." if e.get("passive","")=="scent_tracking" else effect
	if unit.is_empty(): unit=_tooltip_unit()
	var ability: Dictionary=e.ability if unit.is_empty() else sim.resolved_essence_ability(unit,id)
	var cost: int=int(e.ability.cost) if unit.is_empty() else sim.ability_cost(unit,int(e.ability.cost),"soul")
	var cooldown: int=int(e.ability.cooldown) if unit.is_empty() else sim.ability_cooldown(unit,int(e.ability.cooldown))
	return "%s\n%s · %d SP · %d turn cooldown" % [effect,ability.name,cost,cooldown]

func technique_tooltip(technique: Dictionary) -> String:
	var unit: Dictionary=sim.selected()
	# Costs/cooldowns start from catalog bases and are resolved exactly once.
	# Effect text and range come from the technique's actual display ability.
	if technique.kind=="essence": return essence_tooltip(str(technique.id),unit)
	var shown: Dictionary=technique.get("ability",{})
	if technique.kind=="numbered":
		var active: Dictionary=NumberedCatalog.definitions().get(str(technique.id),{}).get("active",{})
		return "%s\n%d turn cooldown" % [tooltip_wrap(str(shown.get("description",""))),sim.ability_cooldown(unit,int(active.get("cooldown",shown.get("cooldown",0))))]
	var spell: Dictionary=GameContent.spells().get(str(technique.id),shown)
	return "%s · Rank %d\n%d Mana · %d turn cooldown · Range %d\n%s" % [shown.get("name",spell.name),spell.rank,sim.ability_cost(unit,int(spell.cost),"mana"),sim.ability_cooldown(unit,int(spell.cooldown)),shown.get("range",spell.range),tooltip_wrap(str(shown.get("description",spell.description)))]

func essence_tooltip(id: String, unit: Dictionary = {}) -> String:
	var e: Dictionary=essence_defs[id]
	if unit.is_empty(): unit=_tooltip_unit()
	var ability: Dictionary=e.get("ability",{}) if unit.is_empty() else sim.resolved_essence_ability(unit,id)
	var lines: Array[String]=["%s · Rank %d" % [e.name,e.get("rank",e.get("tier",9))],essence_summary(id,unit)]
	lines.append_array(_modifier_lines(e.get("modifiers",[])))
	if e.get("modifiers",[]).is_empty(): lines.append("Attribute bonuses unverified.")
	var effect: String=str(ability.get("effect",""))
	if effect.is_empty(): lines.append("Passive component; full kit unverified.")
	elif effect=="call_dead":
		lines.append("%d Ghouls · Duration %d turns · Range %d" % [ability.get("summon_count",10),ability.get("summon_duration",0),ability.get("range",0)])
		lines.append("Player resource, duration and grid values are provisional.")
	else:
		var duration: int=int(ability.get("effect_duration",ability.get("status_duration",0)))
		lines.append("Range %d · Duration %d turns" % [ability.get("range",0),duration])
		var description: String=str(ability.get("description",""))
		if not description.is_empty(): lines.append(tooltip_wrap(description))
	if not unit.is_empty() and unit.get("essences",[]).has(id) and not sim.active_essences(unit).has(id): lines.append("Skills sealed by the Ring of the Frost Spirit.")
	return "\n".join(lines)

func tooltip_wrap(text: String) -> String:
	var lines: Array[String]=[]
	for paragraph: String in text.split("\n"):
		var line: String=""
		for word: String in paragraph.split(" ",false):
			if not line.is_empty() and line.length()+word.length()+1>64: lines.append(line); line=""
			line+=(" " if not line.is_empty() else "")+word
		lines.append(line)
	return "\n".join(lines)

func modal(title: String) -> VBoxContainer:
	var dim: ColorRect = ColorRect.new()
	dim.color = INK
	at(dim, Rect2(0, 0, 640, 360))
	var heading_label: Label = text_at(title, Rect2(22, 16, 486, 26), 18, GOLD)
	heading_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading_label.clip_text = true
	heading_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_label.tooltip_text = title
	button_at("CLOSE [Esc]", Rect2(522, 14, 96, 28), func() -> void: overlay = ""; selected_ability = -1; render())
	return scroll_column(Rect2(22, 48, 596, 297))

func render_overlay() -> void:
	match overlay:
		"city_location": render_city_location()
		"npc": render_npc()
		"appearance": render_customization()
		"portal":
			var choices: Array[int]=sim.portal_choices()
			var content: VBoxContainer=modal("REGION PATH" if sim.floor_number()==3 and choices.all(func(id: int)->bool:return int(sim.region_data(id).floor)==3) else "LABYRINTH PORTAL")
			if choices.is_empty(): label("No route within reach.",content,13)
			for index: int in choices:
				var destination: Dictionary=sim.region_data(index)
				button("Return to Crystal Cave" if index==1 else str(destination.name),func() -> void:
					if sim.travel_region(index): overlay=""
					after_command(),content)
				label("Floor%d · closes day%d" % [destination.floor,destination.portal_closes_after_days],content,11,MUTED)
		"witch_hut":
			var content: VBoxContainer=modal("WITCH’S CABIN")
			if ThirdFloorRules.in_refuge(sim):
				label("Safe refuge · %dh %dm left" % [(int(sim.state.hut_until)-int(sim.state.time))/60,(int(sim.state.hut_until)-int(sim.state.time))%60],content,14,TEAL)
				label("Forest effects are quiet here.",content,12,MUTED)
				button("REST",func()->void: sim.camp(); after_command(),content)
				button("LEAVE",func()->void: sim.leave_witch_hut(); overlay=""; sim.update_visibility(); after_command(),content)
			else:
				label("The cabin has faded.",content,14)
				button("RETURN TO FOREST",func()->void: overlay=""; after_command(),content)
		"memorial":
			var content: VBoxContainer=modal("GREAT SAGE MEMORIAL")
			label("The Great Sage’s monument stands in a dark clearing, apart from the four outer portal steles.",content,13)
			label("Its ritual rifts are not available yet.",content,11,MUTED)
		"homelands": render_homeland_travel()
		"homeland_dialog": render_homeland_dialog()
		"homeland_notes": render_homeland_notes()
		"homeland_choice": render_homeland_choice()
		"inventory": render_inventory()
		"party": render_party()
		"stats": render_stats()
		"essences": render_essences()
		"racial": render_racial_progression()
		"ring_seal": render_ring_seal()
		"profession": render_profession()
		"release": render_release_suppression()
		"journal": render_journal()
		"map": render_map()
		"log":
			var content: VBoxContainer = modal("COMBAT LOG")
			for line: String in sim.state.log: label(line, content, 11, PALE)
		"inspect":
			var content: VBoxContainer = modal("INSPECT")
			var target: Dictionary = sim.unit_by_id(inspect_id)
			if not target.is_empty():
				label(unit_tooltip(target), content, 13)
				label("Estimated Combat Index: %.1f" % sim.stat_value(target,"combat_index"),content,12,TEAL).tooltip_text = "Approximate summary of resolved stats. It does not grant additional damage or defenses."
				if target.team == "enemy":
					var definition: Dictionary = monster_defs[target.content_id]
					label(str(definition.desc), content, 12, MUTED)
					var intent: String=str(target.get("intent",{}).get("kind",""))
					var warning: String=str(definition.get("telegraph",""))
					if warning.is_empty(): warning="Advance and attack within reach."
					if intent=="call_dead": warning="Call of the Dead · nearby Ghoul summoning."
					if target.statuses.has("toppled"): warning="Toppled · unable to rise unaided."
					label("Intent: "+warning,content,12,RED)
					if target.content_id=="canon_death_fiend":
						button("TOPPLE",func() -> void: action_result(sim.topple_target(target.id)),content,"An adjacent free ally can knock it onto its back. Requires STR8,2AP and an unused attack; these grid thresholds are provisional. It cannot rise unaided.")
					var chance: int = clampi(int(sim.stat_value(sim.selected(),"accuracy")) - int(sim.stat_value(target,"evasion")), 20, 98)
					label("Your basic attack: %d%% chance, %d damage before temporary effects." % [chance, sim.damage_amount(int(sim.selected().power), int(target.armor), sim.resistance(target, "physical"), true)], content, 12, TEAL)
					label("Resistances: " + str(target.resist) + "\nStatus: " + status_text(target), content, 11)
		"settings": render_settings()
		"pause": render_pause()
		"save", "load": render_saves()
		"confirm":
			var content: VBoxContainer = modal("CONFIRM")
			label(confirm_text, content, 13)
			button("CONFIRM", func() -> void:
				var callback: Callable = pending_confirm
				overlay = ""; callback.call(); save_game(); render(), content)
			button("CANCEL", func() -> void: overlay = ""; render(), content)
		"developer": render_developer()

func render_inventory() -> void:
	modal("INVENTORY  %.1f/%d" % [sim.weight(), sim.capacity()])
	var search: LineEdit = LineEdit.new()
	search.placeholder_text = "Search inventory…"
	search.text = inventory_filter
	at(search, Rect2(29, 55, 339, 25))
	var recipient: OptionButton = OptionButton.new()
	at(recipient, Rect2(388, 55, 223, 25))
	var members: Array = sim.allies().filter(func(u: Dictionary) -> bool: return not u.get("summon", false))
	if not members.any(func(u: Dictionary) -> bool: return u.id == selected_party): selected_party = "hero"
	for i: int in range(members.size()):
		recipient.add_item(str(members[i].name))
		if members[i].id == selected_party: recipient.select(i)
	recipient.item_selected.connect(func(index: int) -> void: selected_party = members[index].id; render())
	var slots: VBoxContainer = scroll_column(Rect2(29, 88, 339, 248))
	var detail: VBoxContainer = scroll_column(Rect2(380, 88, 231, 248))
	var toolbar: HBoxContainer = row(slots)
	button("PACK", func() -> void: inventory_storage = false; inventory_selected = ""; render(), toolbar)
	if sim.state.mode == "city": button("STORAGE", func() -> void: inventory_storage = true; inventory_selected = ""; render(), toolbar)
	if sim.state.mode == "dungeon": button("ESSENCES", func() -> void: overlay = "essences"; render(), toolbar)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	slots.add_child(grid)
	var fill_grid: Callable = func() -> void:
		for child: Node in grid.get_children(): grid.remove_child(child); child.queue_free()
		var bag: Dictionary = sim.state.storage if inventory_storage and sim.state.mode == "city" else sim.state.inventory
		var ids: Array = bag.keys().filter(func(id: String) -> bool: return inventory_filter.is_empty() or str(item_defs[id].name).to_lower().contains(inventory_filter.to_lower()))
		ids.sort_custom(func(a: String, b: String) -> bool: return str(item_defs[a].name) < str(item_defs[b].name))
		for index: int in range(maxi(32, int(ceil(ids.size() / 8.0)) * 8)):
			var id: String = str(ids[index]) if index < ids.size() else ""
			var slot: Button = item_slot(id, int(bag.get(id, 0)), 38, func() -> void: inventory_selected = id; render(), grid)
			if id == inventory_selected and not id.is_empty(): slot.add_theme_stylebox_override("normal", style(Color("181d15"), TEAL, 1))
	fill_grid.call()
	search.text_changed.connect(func(value: String) -> void: inventory_filter = value; fill_grid.call())
	var chosen: Dictionary = item_defs.get(inventory_selected, {})
	if chosen.is_empty():
		label("ITEM INFORMATION", detail, 14)
		label("WORN EQUIPMENT", detail, 12, TEAL)
		var unit: Dictionary = sim.unit_by_id(selected_party)
		if unit.is_empty(): unit = sim.hero()
		for slot: String in unit.equipment: label("%s: %s" % [slot.capitalize(), item_defs.get(unit.equipment[slot], {}).get("name", "Empty")], detail, 11)
	else:
		label(str(chosen.name), detail, 16)
		label(str(chosen.desc), detail, 11, MUTED)
		label("Weight: %.1f" % chosen.get("weight", 0), detail, 11)
		if str(chosen.get("kind","")) in ["weapon","armor","accessory"]:
			var modifiers: Array[String] = _modifier_lines(chosen.get("modifiers",[]))
			if not modifiers.is_empty(): label("\n".join(modifiers),detail,11)
			if int(chosen.get("str_req",0)) > 0 or int(chosen.get("agi_req",0)) > 0: label("Requires STR %d / AGI %d" % [chosen.get("str_req",0),chosen.get("agi_req",0)],detail,11,MUTED)
			var preview: Dictionary = sim.preview_equipment(inventory_selected,selected_party)
			var changes: Array[String] = _preview_delta_lines(preview)
			if not changes.is_empty():
				label("EQUIPMENT CHANGE",detail,12,TEAL)
				label("\n".join(changes.slice(0,5))+("\nMore changes in the EQUIP tooltip." if changes.size()>5 else ""),detail,11,MUTED)
		if inventory_storage and sim.state.mode == "city": button("WITHDRAW", func() -> void: action_result(sim.store_item(inventory_selected, true)), detail)
		else:
			if not str(chosen.get("slot", "")).is_empty(): button("EQUIP", func() -> void: equip_from_inventory(inventory_selected, selected_party), detail, comparison(inventory_selected))
			if chosen.kind == "consumable": button("USE", func() -> void: action_result(sim.use_item(inventory_selected, selected_party)), detail)
			if chosen.has("contained_essence"): button("ABSORB", func() -> void: confirm_absorption(str(chosen.contained_essence), selected_party, -1, true), detail)
			if sim.state.mode == "city":
				button("SELL / %d stones" % sim.market_price(inventory_selected, false), func() -> void: action_result(sim.sell(inventory_selected)), detail)
				button("STORE", func() -> void: action_result(sim.store_item(inventory_selected)), detail)
	if sim.state.mode == "dungeon" and not sim.state.loot_items.is_empty():
		label("RECOVERED LOOT", detail, 12, TEAL)
		for id: String in sim.state.loot_items: label("%s ×%d" % [item_defs[id].name, sim.state.loot_items[id]], detail, 10)

func _preview_delta_lines(preview: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if not preview.get("errors",[]).is_empty():
		for error: Variant in preview.errors: lines.append(str(error))
		return lines
	var delta: Dictionary = preview.get("delta",{})
	for id: String in UIStats.definitions():
		if not UIStats.definitions()[id].implemented or not delta.has(id) or is_zero_approx(float(delta[id])): continue
		lines.append("%s %s (%s → %s)" % [_stat_name(id),_signed_number(float(delta[id])),_stat_display(id,float(preview.get("before",{}).get(id,0))),_stat_display(id,float(preview.get("after",{}).get(id,0)))])
	if lines.is_empty(): lines.append("No resolved stat change.")
	return lines

func comparison(id: String) -> String:
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): unit = sim.hero()
	var item: Dictionary = item_defs[id]
	var old_id: String = str(unit.equipment.get(str(item.get("slot","")),""))
	var old_name: String = str(item_defs.get(old_id,{}).get("name","empty"))
	return item_tooltip(id)+"\nCompared with "+old_name+":\n"+"\n".join(_preview_delta_lines(sim.preview_equipment(id,str(unit.id))))

func render_party() -> void:
	modal("CHARACTER STATUS")
	var party_select: OptionButton = OptionButton.new()
	at(party_select, Rect2(29,54,498,25))
	button_at("STATS",Rect2(535,54,76,25),func() -> void: overlay = "stats"; render(),"Resolved stats and the sources that change them.")
	var members: Array = sim.allies().filter(func(u: Dictionary) -> bool: return not u.get("summon", false))
	for index: int in range(members.size()):
		party_select.add_item(str(members[index].name))
		if members[index].id == selected_party: party_select.select(index)
	party_select.item_selected.connect(func(index: int) -> void: selected_party = members[index].id; render())
	var chosen: Dictionary = sim.unit_by_id(selected_party)
	if chosen.is_empty(): chosen = sim.hero(); selected_party = "hero"
	var portrait_panel: VBoxContainer = scroll_column(Rect2(29, 88, 162, 248))
	label(str(chosen.name), portrait_panel, 16)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = portrait_texture(chosen)
	portrait.custom_minimum_size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_panel.add_child(portrait)
	label(str(GameContent.ancestries().get(chosen.get("ancestry", ""), {}).get("name", chosen.role)), portrait_panel, 13, MUTED)
	label(("Level %d / XP %d%s\n" % [sim.state.level, sim.state.xp, "/%d" % sim.next_level_xp() if sim.next_level_xp() >= 0 else ""] if chosen.id == "hero" else str(chosen.get("profession", "explorer")).capitalize() + "\n") + status_text(chosen), portrait_panel, 11)
	var detail: VBoxContainer = scroll_column(Rect2(199, 88, 412, 248))
	resource_bar(detail, "HP", int(chosen.hp), int(chosen.max_hp), Color("91b34b"))
	if sim.essence_capacity(chosen) > 0: resource_bar(detail, "SP", int(chosen.energy), int(chosen.max_energy), Color("669eb9"))
	if int(chosen.get("max_mana", 0)) > 0: resource_bar(detail, "MANA", int(chosen.mana), int(chosen.max_mana), Color("929fce"))
	label("Strength %d    Agility %d\nWit %d           Vigor %d" % [sim.stat_value(chosen,"strength"),sim.stat_value(chosen,"agility"),sim.stat_value(chosen,"wit"),sim.stat_value(chosen,"vigor")], detail, 13)
	label("Attack %d / Armor %d / Range %d\nAccuracy %d / Evasion %d\nGear condition %d%%" % [sim.stat_value(chosen,"attack"),sim.stat_value(chosen,"armor"),sim.stat_value(chosen,"attack_range"),sim.stat_value(chosen,"accuracy"),sim.stat_value(chosen,"evasion"),chosen.durability], detail, 12, MUTED)
	label("EQUIPMENT", detail, 14)
	for slot: String in chosen.equipment:
		var id: String = str(chosen.equipment[slot])
		button("%s / %s" % [slot.capitalize(), item_defs.get(id, {}).get("name", "Empty")], func() -> void: selected_party = chosen.id; overlay = "inventory"; render(), detail, item_tooltip(id))
		if not id.is_empty(): button("REMOVE / " + str(slot).to_upper(),func() -> void: action_result(sim.unequip(slot,chosen.id)),detail)
	for spell: String in chosen.get("spells", []): label(str(GameContent.spells()[spell].name) + " / Mana", detail, 12).tooltip_text = str(GameContent.spells()[spell].description)
	label("ESSENCES / %d OF %d" % [chosen.essences.size(), sim.essence_capacity(chosen)], detail, 14)
	for id: String in chosen.essences: button(str(essence_defs[id].name), func() -> void: overlay = "essences"; render(), detail, essence_tooltip(id))
	button("Manage inventory", func() -> void: selected_party = chosen.id; overlay = "inventory"; render(), detail)
	button("Manage essences", func() -> void: selected_party = chosen.id; overlay = "essences"; render(), detail)
	if chosen.get("racial", {}).get("engraving_path", "") == "undying": label("Undying I · improved natural recovery", detail, 12, TEAL)
	if sim.state.mode == "city" and chosen.get("ancestry", "") == "barbarian": button("SOUL ENGRAVING", func() -> void: selected_party = chosen.id; overlay = "racial"; render(), detail)
	if chosen.equipment.get("charm", "") == "frost_spirit_ring":
		button("RING SEAL",func() -> void: selected_party = chosen.id; overlay = "ring_seal"; render(),detail,"Seal one essence’s skills; keep its attributes and occupied slot.")
	if chosen.get("ancestry", "") == "beastman":
		if sim.RacialProgression.has_skadia(chosen): label("Skadia · Strengthening · bare-handed cold",detail,12,TEAL).tooltip_text = "Initial contract. Physical bonus and damage conversion are estimated; weapons remain physical. Further awakenings are unfinished."
		elif chosen.equipment.get("charm", "") == "frost_spirit_ring": button("AWAKEN SKADIA",func() -> void: confirm_skadia(chosen.id),detail)
	if chosen.get("ancestry", "") == "draconian":
		button("SUPPRESS DRAGON FEAR" if chosen.get("dragon_fear_enabled",true) else "RELEASE DRAGON FEAR",func() -> void: action_result(sim.set_dragon_fear(not chosen.get("dragon_fear_enabled",true),chosen.id)),detail,"Innate intimidation: nearby opponents lose10 accuracy within3 tiles and line of sight. These numerical conversions are estimates. No stun or skipped turn.")
	if chosen.equipment.get("charm", "") == "guardians_braces":
		var record: Dictionary = sim.braces_record()
		label("Braces · absorbed %d · cooldown %d" % [record.charge,record.cooldown],detail,12,TEAL)
		if sim.state.mode == "dungeon": button("GUARDIAN’S PROTECTION",func() -> void: action_result(sim.activate_guardians_braces(chosen.id)),detail)
	if sim.state.mode == "city" and chosen.get("ancestry", "") == "human": button("MAGIC TRAINING",func() -> void: selected_party = chosen.id; overlay = "profession"; render(),detail)
	if chosen.get("ancestry","")=="fairy":
		if chosen.has("spirit"):
			label("Natural Energy %d/%d" % [chosen.natural_energy_current,sim.stat_value(chosen,"natural_energy")],detail,12,TEAL)
			button("DISMISS FIRE SPIRIT" if chosen.spirit.active else "SPIRIT LIGHT",func() -> void: flash(sim.toggle_spirit_light(chosen.id)); render(),detail,"Illumination uses Natural Energy independently of SP/mana. Drain and reach are estimates.")
			if chosen.get("wind_contract",false):
				button("DISMISS WIND GUIDANCE" if chosen.get("wind_guidance",false) else "WIND GUIDANCE",func() -> void: flash(sim.toggle_wind_guidance(chosen.id)); render(),detail,"Bow attacks gain10 Accuracy and spend1 Natural Energy per attempted shot. Bonus and cost are estimates.")
			elif sim.state.mode=="city":
				button("SPIRIT STONE / 10%",func() -> void:
					confirm_text = "Use one Spirit Stone for %s?10%% success. Consumed on success or failure. Additional affinity currently limited to Wind; the novel does not limit it to Wind. Natural Energy is shared. Stones in pack: %d." % [chosen.name,int(sim.state.inventory.get("spirit_stone",0))]
					pending_confirm = func() -> void: flash(sim.attempt_spirit_stone(chosen.id)); overlay = "party"
					overlay = "confirm"; render(),detail,"Purchase Spirit Stones at the market. Documented10% success; current Wind-only choice is provisional.")
			if sim.state.mode=="dungeon": button("REST SPIRIT / 2H",func() -> void: flash(sim.rest_spirit(chosen.id)); render(),detail)
		elif sim.state.mode=="city":
			button("SPIRIT LESSON / 120 ST",func() -> void:
				confirm_text = "Form a Fire Spirit contract for120 stones and3 city days? First-contract acquisition and costs are provisional. Uses a separate Natural Energy pool."
				pending_confirm = func() -> void: flash(sim.form_spirit_contract(chosen.id)); overlay = "party"
				overlay = "confirm"; render(),detail,"Provisional first-contract lesson; additional elemental Spirit Stones are a separate unfinished mechanic.")
	if chosen.id != "hero":
		label("Behavior", detail, 12, MUTED)
		var h: HBoxContainer = row(detail)
		for behavior: String in ["manual", "aggressive", "guard"]: button(behavior.to_upper(), func() -> void: chosen.behavior = behavior; render(), h)
		if sim.state.mode == "city": button("Leave in city", func() -> void: sim.dismiss(chosen.id); selected_party = "hero"; save_game(); render(), detail, "Keeps equipment, essences, health and injuries when rejoining.")

func _stat_has_changes(row: Dictionary) -> bool:
	for source: Dictionary in row.get("sources",[]):
		var op: String = str(source.get("op",""))
		var amount: float = float(source.get("value",0))
		if op == "multiply" and not is_equal_approx(amount,1): return true
		if op in ["add","increase"] and not is_zero_approx(amount): return true
		if op == "at_least" and amount > float(row.get("base",0)): return true
	return not is_equal_approx(float(row.get("final",0)),float(row.get("base",0)))

func _stat_breakdown_tooltip(id: String, row: Dictionary) -> String:
	var definition: Dictionary = UIStats.definitions()[id]
	var lines: Array[String] = [str(definition.name),str(definition.description)]
	lines.append("Base %s · flat %s · increased %s%% · multiplier ×%s" % [_number(float(row.get("base",0))),_signed_number(float(row.get("flat",0))),_signed_number(float(row.get("increased",0))*100),_number(float(row.get("multiplier",1)))])
	if row.get("minimum") != null: lines.append("Minimum "+_number(float(row.minimum)))
	lines.append("Final %s · rounding %s · bounds %s..%s" % [_stat_display(id,float(row.get("final",0))),str(definition.rounding),_number(float(definition.min)),_number(float(definition.max))])
	lines.append("(base + flat) × (1 + increased) × multipliers; apply minimum, round, then bounds.")
	for source: Dictionary in row.get("sources",[]):
		var modifier: Dictionary = source.duplicate()
		modifier.stat = id
		lines.append(_contributor_name(str(source.get("source","")))+": "+_modifier_text(modifier))
	lines.append(str(definition.formula_note))
	return "\n".join(lines)

func render_stats() -> void:
	var content: VBoxContainer = modal("STATS")
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): unit = sim.hero(); selected_party = "hero"
	label(str(unit.name),content,15,TEAL)
	var toolbar: HBoxContainer = row(content)
	button("CHARACTER",func() -> void: overlay = "party"; render(),toolbar)
	button("SHOW RELEVANT" if stats_show_all else "SHOW ALL IMPLEMENTED",func() -> void: stats_show_all = not stats_show_all; render(),toolbar,"Show neutral implemented values too. Catalog-only research has no gameplay effect and is excluded.")
	label("Hover a stat for its formula and contributions.",content,10,MUTED)
	var resolved: Dictionary = sim.stat_breakdown(unit)
	if not resolved.get("errors",[]).is_empty():
		for error: Variant in resolved.errors: label(str(error),content,11,RED)
		return
	var values: Dictionary = resolved.get("values",{})
	var details: Dictionary = resolved.get("breakdown",{})
	for id: String in UIStats.definitions():
		var definition: Dictionary = UIStats.definitions()[id]
		if not definition.implemented or not values.has(id): continue
		var value: float = float(values[id])
		var breakdown: Dictionary = details.get(id,{"base":value,"final":value,"sources":[]})
		var changed: bool = _stat_has_changes(breakdown)
		if not stats_show_all and not changed and (is_zero_approx(value) or (id.ends_with("_multiplier") and is_equal_approx(value,float(definition.default)))): continue
		var line: HBoxContainer = row(content)
		var hint: String = _stat_breakdown_tooltip(id,breakdown)
		line.tooltip_text = hint; line.mouse_filter = Control.MOUSE_FILTER_PASS
		var name_label: Label = label(str(definition.name),line,12,TEAL if changed else PALE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = hint; name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var value_label: Label = label(_stat_display(id,value),line,12,TEAL if changed else PALE,false)
		value_label.custom_minimum_size.x = 90
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.tooltip_text = hint; value_label.mouse_filter = Control.MOUSE_FILTER_PASS

func render_essences() -> void:
	var content: VBoxContainer = modal("ESSENCES")
	var members: Array = sim.allies().filter(func(u: Dictionary) -> bool: return not u.get("summon", false))
	var recipients: OptionButton = OptionButton.new()
	content.add_child(recipients)
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): selected_party = "hero"; unit = sim.hero()
	for index: int in range(members.size()):
		recipients.add_item(str(members[index].name))
		if members[index].id == selected_party: recipients.select(index)
	recipients.item_selected.connect(func(index: int) -> void: selected_party = members[index].id; render())
	if sim.essence_capacity(unit) == 0: label("Mage · cannot absorb essences", content, 14, TEAL)
	else: label("%d/%d slots" % [unit.essences.size(), sim.essence_capacity(unit)], content, 14, TEAL)
	for id: String in unit.essences:
		label(str(essence_defs[id].name), content, 13).tooltip_text = essence_tooltip(id)
	for id: String in essence_defs:
		var count: int = int(sim.state.inventory.get("sealed_" + id, 0))
		if count > 0:
			button("OPEN %s ×%d" % [essence_defs[id].name, count], func() -> void: confirm_absorption(id, unit.id, -1, true), content, essence_tooltip(id), sim.essence_capacity(unit) == 0)
	if sim.state.mode != "dungeon": return
	var available: Dictionary = {}
	for drop: Dictionary in sim.state.essence_drops:
		if int(drop.region) == int(sim.state.region) and int(drop.expires_at) > int(sim.state.time): available[str(drop.id)] = int(available.get(str(drop.id), 0)) + 1
	if available.is_empty(): return
	label("LOOSE ESSENCES", content, 14)
	for id: String in available:
		label("%s ×%d" % [essence_defs[id].name, available[id]], content, 13, TEAL).tooltip_text = essence_tooltip(id)
		var actions: HBoxContainer = row(content)
		button("ABSORB", func() -> void: confirm_absorption(id, unit.id), actions, "Touch to absorb. Requires a free slot. Expires after 30 minutes.", sim.essence_capacity(unit) == 0)
		for mage: Dictionary in members:
			if mage.get("profession", "") == "mage": button("SEAL / " + str(mage.name), func() -> void: confirm_sealing(id, mage.id), actions, "Requires a tube, adjacency and 15 uninterrupted minutes. Timing is provisional.")

func confirm_absorption(id: String, unit_id: String, _slot: int = -1, sealed: bool = false) -> void:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if unit.is_empty(): return
	confirm_text = "Absorb %s?\n%s\n\n%s\n\nConsumes one slot. Permanent.%s" % [essence_defs[id].name, unit.name, essence_summary(id), " The tube is destroyed." if sealed else ""]
	if unit.equipment.get("charm", "") == "frost_spirit_ring" and unit.essences.is_empty(): confirm_text += "\nThe equipped ring will seal this essence’s skills."
	pending_confirm = func() -> void: flash(sim.absorb_sealed(id, unit_id) if sealed else sim.absorb(id, unit_id)); overlay = "essences"; save_game()
	overlay = "confirm"
	render()

func confirm_sealing(id: String, mage_id: String) -> void:
	confirm_text = "Seal %s?\n\nConsumes one test tube.\n15 minutes · mage must be nearby.\nSealed essence survives extraction." % essence_defs[id].name
	pending_confirm = func() -> void: flash(sim.seal_essence(id, mage_id)); overlay = "essences"; save_game()
	overlay = "confirm"
	render()

func render_journal() -> void:
	var content: VBoxContainer = modal("JOURNAL")
	var search: LineEdit = LineEdit.new()
	search.placeholder_text = "Search"
	search.text = journal_filter
	content.add_child(search)
	var list: VBoxContainer = VBoxContainer.new()
	content.add_child(list)
	var refill: Callable = func() -> void:
		for child: Node in list.get_children(): list.remove_child(child); child.queue_free()
		for entry: Dictionary in sim.state.journal:
			if not journal_filter.is_empty() and not (str(entry.title) + str(entry.text)).to_lower().contains(journal_filter.to_lower()): continue
			label(str(entry.title), list, 14, TEAL)
			label(str(entry.text), list, 11)
		if journal_filter.is_empty():
			label("RULES", list, 14)
			label("First defeat of each species: XP. Essence slots: character level. Soul Power fuels essence abilities.\n\nCrystal Cave closes at 168 hours; second-floor areas at 240; the third floor at360. Survivors return automatically.\n\nMovement: 1 AP. Attack: 1 AP, once per round. Ability: 2 AP plus SP. Leaving melee reach may provoke an attack.\n\nPhysical damage subtracts armor before resistance. Poison and paralysis prevent resource recovery and actions respectively. Concealment breaks when its source moves. Suppression breaks on any damage; a free adjacent ally can make a controlled1HP cut. Natural recovery occurs every90minutes outside combat while fed. Grid-action minutes and recovery coefficients are provisional.", list, 11, MUTED)
	refill.call()
	search.text_changed.connect(func(value: String) -> void: journal_filter = value; refill.call())

func render_map() -> void:
	modal("LABYRINTH MAP")
	var canvas: Control = Control.new()
	at(canvas,Rect2(40,62,560,230))
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.clip_contents = true
	var fit: int = maxi(1,int(minf(560.0/float(sim.state.map.width),230.0/float(sim.state.map.height))))
	var scale: int = fit + map_zoom*2
	canvas.draw.connect(func() -> void:
		var extent: Vector2 = Vector2(sim.state.map.width,sim.state.map.height)*scale
		var origin: Vector2 = canvas.size/2-Vector2(sim.hero().pos)*scale+map_pan
		origin.x = clampf(origin.x,canvas.size.x-extent.x,0) if extent.x > canvas.size.x else (canvas.size.x-extent.x)/2
		origin.y = clampf(origin.y,canvas.size.y-extent.y,0) if extent.y > canvas.size.y else (canvas.size.y-extent.y)/2
		for key: String in sim.state.seen:
			var components: PackedStringArray = key.split(",")
			if components.size() != 2: continue
			var point := Vector2i(int(components[0]),int(components[1]))
			var rectangle := Rect2(origin+Vector2(point)*scale,Vector2(scale,scale))
			if not Rect2(Vector2.ZERO,canvas.size).intersects(rectangle): continue
			canvas.draw_rect(rectangle,Color("2e393e") if int(sim.state.map.tiles[point.y][point.x]) == 1 else Color("7b9894"))
		for marker: Dictionary in dungeon_markers()+[{"pos":sim.hero().pos,"color":Color.WHITE,"kind":"party"}]:
			if sim.state.seen.has(sim.pos_key(marker.pos)):
				canvas.draw_rect(Rect2(origin+Vector2(marker.pos)*scale,Vector2(scale,scale)),marker.color)
				if scale >= 5: canvas.draw_string(mono_font if mono_font != null else font,origin+Vector2(marker.pos)*scale+Vector2(0,scale),"@" if marker.get("kind","")=="party" else ">" if marker.get("kind","")=="portal" else "M" if marker.get("kind","")=="memorial" else "?" if marker.get("kind","")=="boundary" else "<",HORIZONTAL_ALIGNMENT_LEFT,-1,8,INK)
	)
	canvas.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			map_pan += event.relative; canvas.queue_redraw()
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			map_zoom = clampi(map_zoom+(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1),0,3); map_pan = Vector2.ZERO; render()
	)
	button_at("−",Rect2(40,306,35,25),func() -> void: map_zoom = maxi(0,map_zoom-1); map_pan = Vector2.ZERO; render())
	button_at("+",Rect2(79,306,35,25),func() -> void: map_zoom = mini(3,map_zoom+1); map_pan = Vector2.ZERO; render())
	button_at("FIT",Rect2(118,306,48,25),func() -> void: map_zoom = 0; map_pan = Vector2.ZERO; render())
	text_at("Drag to pan · white: party · gold: portal",Rect2(178,306,425,25),10,MUTED)

func render_racial_progression() -> void:
	var content: VBoxContainer = modal("SANCTUARY · SOUL ENGRAVING")
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): unit = sim.hero(); selected_party = "hero"
	label(str(unit.name),content,16,TEAL)
	if unit.get("racial",{}).get("engraving_path","") == "undying":
		label("Undying I",content,16)
		label("+1 HP per 90-minute natural recovery interval. Permanent path.",content,12)
		return
	label("Undying I",content,16)
	label("Improves natural recovery. Choosing this path is permanent.",content,12)
	button("ENGRAVE / %d ST" % sim.UNDYING_SERVICE_COST,func() -> void:
		confirm_text = "Engrave Undying I for %s?\n\n%d stones · permanent path\n+1 HP each 90 minutes outside combat.\n\nPrice and HP conversion are provisional." % [unit.name,sim.UNDYING_SERVICE_COST]
		pending_confirm = func() -> void: flash(sim.learn_undying(unit.id)); overlay = "racial"
		overlay = "confirm"; render(),content,"Novel normal quote800,000; the current compressed economy uses an estimated 800. HP recovery conversion is estimated.")

func render_release_suppression() -> void:
	var content: VBoxContainer = modal("RELEASE SUPPRESSION")
	label("A free adjacent ally makes a 1 HP cut. Costs an attack and 1 AP.",content,12)
	var free: Array = sim.allies().filter(func(u: Dictionary) -> bool: return u.hp > 0 and not sim.unable_to_act(u))
	if free.is_empty(): label("No ally can act. Damage or expiry will break Suppression.",content,12); return
	var choice := OptionButton.new(); content.add_child(choice)
	for index: int in range(free.size()):
		choice.add_item(str(free[index].name))
		if sim.state.selected == free[index].id: choice.select(index)
	if not free.any(func(u: Dictionary) -> bool: return u.id == sim.state.selected): sim.state.selected = free[0].id
	choice.item_selected.connect(func(index: int) -> void: sim.state.selected = free[index].id; render())
	for unit: Dictionary in sim.allies():
		if unit.statuses.has("suppressed"): button("FREE %s / 1 HP" % unit.name,func() -> void: flash(sim.release_suppression(unit.id)); overlay = ""; after_command(),content,"Refuses a lethal cut.",int(unit.hp)<=1)

func render_settings() -> void:
	var content: VBoxContainer = modal("SETTINGS")
	for category: String in ["master", "music", "sfx"]:
		var h: HBoxContainer = row(content)
		label(category.to_upper(), h, 12, TEAL).custom_minimum_size.x = 100
		var slider: HSlider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = float(settings[category])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void: settings[category] = value; apply_settings(); SaveStore.save_settings(settings))
	for toggle: String in ["muted", "reduced_motion", "shake", "fullscreen"]:
		var check: CheckButton = CheckButton.new()
		check.text = toggle.replace("_", " ").capitalize()
		check.button_pressed = bool(settings[toggle])
		content.add_child(check)
		check.toggled.connect(func(value: bool) -> void: settings[toggle] = value; apply_settings(); SaveStore.save_settings(settings))
	var h: HBoxContainer = row(content)
	label("TEXT SCALE", h, 12, TEAL, false)
	for value: float in [1.0, 1.1, 1.2]: button("%d%%" % int(value * 100), func() -> void: settings.text_scale = value; SaveStore.save_settings(settings); render(), h)
	label("KEY BINDINGS", content, 12, GOLD)
	if not waiting_binding.is_empty(): label("Waiting for " + waiting_binding + "… Escape cancels.", content, 12, TEAL)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	content.add_child(grid)
	for id: String in settings.bindings:
		button("%s: %s" % [id, OS.get_keycode_string(int(settings.bindings[id]))], func() -> void: waiting_binding = id; render(), grid)
	label("Controller: D-pad move · A interact · X wait · Y pack · shoulders select · Start pause", content, 11, MUTED)

func render_pause() -> void:
	var content: VBoxContainer = modal("PAUSED")
	button("Resume", func() -> void: overlay = ""; render(), content)
	button("Save game", func() -> void: overlay = "save"; render(), content)
	button("Load game", func() -> void: overlay = "load"; render(), content)
	button("Settings", func() -> void: overlay = "settings"; render(), content)
	button("Title screen", func() -> void: save_game(); overlay = ""; screen = "title"; render(), content)
	if developer_enabled: button("Developer console (test progression)", func() -> void: overlay = "developer"; render(), content)

func render_saves() -> void:
	var saving: bool = overlay == "save"
	var content: VBoxContainer = modal("SAVE GAME" if saving else "CONTINUE A GAME")
	for slot: int in range(1, 4):
		var info: Dictionary = SaveStore.load_campaign_slot(slot)
		var text: String = "Empty"
		if info.ok:
			var s: Dictionary = info.state
			text = "%s · day %d · level %d" % [s.get("hero", {}).get("name", "Unknown"), s.get("day", 1), s.get("level", 1)]
		elif FileAccess.file_exists("user://saves/slot_%02d.json" % slot): text = str(info.warning)
		button("SLOT %d / %s" % [slot, text], func() -> void:
			save_slot = slot
			if saving:
				if info.ok:
					confirm_text = "Replace slot %d (%s)? A backup of the last healthy save will be preserved." % [slot, text]
					pending_confirm = func() -> void: save_game(); overlay = ""
					overlay = "confirm"
				else: save_game(); overlay = ""
			else:
				if info.ok and sim.restore(info.state):
					screen = "game"; overlay = ""; selected_region = int(sim.state.region); selected_party = "hero"; selected_ability = -1; flash(str(info.warning))
				else: flash(str(info.warning) if not str(info.warning).is_empty() else "Incompatible save. Start a new game.")
			render(), content, str(info.get("warning", "")), not saving and not info.ok)

func save_game() -> void:
	if sim.state.is_empty(): return
	var error: String = SaveStore.save_campaign_slot(save_slot, sim.snapshot())
	if not error.is_empty(): flash(error)

func render_defeat() -> void:
	top_bar("DEATH")
	var c: VBoxContainer = scroll_column(Rect2(50, 62, 540, 260))
	label("YOUR JOURNEY ENDS", c, 27, RED)
	label("Death is permanent.", c, 14)
	label(str(sim.state.log[-1]), c, 11, MUTED)
	button("Load game", func() -> void: overlay = "load"; render(), c)
	button("Title screen", func() -> void: screen = "title"; render(), c)

func render_developer() -> void:
	var c: VBoxContainer = modal("DEVELOPER TOOLS")
	label("Using these tools marks this save assisted.", c, 11, RED)
	button("Inspect state", func() -> void: print(JSON.stringify(sim.snapshot(), "  ")); flash("State written to log."), c)
	button("Grant supplies", func() -> void: sim.state.flags.assisted = true; sim.state.gold += 500; sim.state.food += 10; sim.add_item("healing_potion", 5); render(), c)
	if sim.state.mode == "dungeon":
		button("Drop implemented essences", func() -> void:
			sim.state.flags.assisted = true
			for id: String in essence_defs: sim.state.essence_drops.append({"id": id, "pos": sim.hero().pos, "region": sim.state.region, "expires_at": int(sim.state.time) + sim.UNCONTAINED_ESSENCE_LIFETIME_MINUTES})
			sim._recount_essence_drops(); render(), c)
		button("Spawn encounter", func() -> void:
			sim.state.flags.assisted = true; sim.spawn_enemy(str(sim.region_data().enemy_ids[0]), sim.nearest_free(sim.hero().pos + Vector2i(3, 0))); sim.update_visibility(); render(), c)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), INK)
	if screen == "title" or screen == "create":
		if tex("title_background") != null: draw_texture_rect(tex("title_background"), Rect2(0, 0, 640, 360), false, Color(0.75, 0.83, 0.85))
		draw_rect(Rect2(0, 0, 390, 360), Color(0.02, 0.04, 0.07, 0.35))
	elif not sim.state.is_empty() and sim.state.mode == "dungeon": draw_dungeon()
	if not overlay.is_empty(): return
	if hovered.x >= 0 and screen == "game" and sim.state.get("mode", "") == "dungeon": draw_hover()

func draw_dungeon() -> void:
	var focus: Dictionary = sim.selected() if sim.state.combat else sim.hero()
	camera_tile = Vector2i(clampi(focus.pos.x - 13, 0, maxi(0, int(sim.state.map.width) - 27)), clampi(focus.pos.y - 8, 0, maxi(0, int(sim.state.map.height) - 16)))
	var tint: Color = Color(str(sim.region_data().color))
	for local_y: int in range(16):
		for local_x: int in range(27):
			var pos: Vector2i = camera_tile + Vector2i(local_x, local_y)
			var rect: Rect2 = Rect2(MAP_RECT.position + Vector2(local_x, local_y) * TILE, Vector2(TILE, TILE))
			if not sim.state.seen.has(sim.pos_key(pos)):
				draw_rect(rect, Color("000000")); continue
			var seen_now: bool = sim.visible(pos)
			var tile: int = int(sim.state.map.tiles[pos.y][pos.x])
			var tile_name: String = ("classic_wall" if tex("classic_wall") != null else "tile_wall") if tile in [1, 5] else ("tile_water" if tile == 2 else ("tile_hazard" if tile == 3 else ("classic_floor" if tex("classic_floor") != null else "tile_floor")))
			var shade: Color = Color.WHITE if seen_now else Color(0.22, 0.25, 0.29)
			var color: Color = shade.lerp(tint * shade, 0.20 if tile == 1 else 0.13)
			if tex(tile_name) != null: draw_texture_rect(tex(tile_name), rect, false, color)
			else: draw_rect(rect, EDGE if tile == 1 else PANEL)
			if sim.state.region==3: draw_dead_terrain(pos,rect,tile,shade)
			if sim.state.region==5: draw_canyon_terrain(pos,rect,tile,shade)
			if sim.floor_number()==3: draw_third_terrain(pos,rect,tile,shade)
			if seen_now and tile==0 and sim.floor_number()==1 and sim.state.map.get("crystal_lights",[]).has(pos):
				draw_rect(rect.grow(-1), Color(0.12, 0.33, 0.48, 0.13))
				draw_colored_polygon(PackedVector2Array([rect.position + Vector2(4, 10), rect.position + Vector2(6, 3), rect.position + Vector2(8, 7), rect.position + Vector2(7, 13)]), Color("5899b7"))
				draw_colored_polygon(PackedVector2Array([rect.position + Vector2(8, 12), rect.position + Vector2(11, 5), rect.position + Vector2(13, 9), rect.position + Vector2(12, 14)]), Color("86c4d8"))
			if seen_now and tile == 1 and int(sim.state.region) == 2:
				draw_rect(rect.grow(-1), Color("14291d"))
				draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(9, 10)), Color("25432d"))
				draw_rect(Rect2(rect.position + Vector2(2, 6), Vector2(12, 5)), Color("36523a"))
				draw_rect(Rect2(rect.position + Vector2(7, 11), Vector2(3, 5)), Color("4f4132"))
			if seen_now and tile == 1 and int(sim.state.region) == 4:
				draw_rect(rect.grow(-1),Color("333c42"))
				draw_line(rect.position+Vector2(2,6),rect.position+Vector2(13,4),Color("68736e"),1)
			if tile == 3:
				draw_rect(rect.grow(-2), Color(tint, 0.35), false)
			if tile == 5 and seen_now and sim.distance(pos, sim.hero().pos) <= 1: draw_string(mono_font if mono_font != null else font, rect.position + Vector2(6, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	for pos: Vector2i in sim.state.map.traps:
		if sim.visible(pos) and sim.distance(pos, sim.hero().pos) <= (3 if sim.stat_value(sim.hero(),"wit") >= 7 else 2) and not sim.state.disarmed.has(sim.pos_key(pos)): draw_icon("trap", pos, RED)
	for marker: Dictionary in dungeon_markers():
		if not sim.state.seen.has(sim.pos_key(marker.pos)): continue
		if marker.kind=="memorial": draw_memorial(marker.pos)
		elif marker.kind in ["boundary","path"]:
			if on_camera(marker.pos): draw_rect(Rect2(tile_point(marker.pos)+Vector2(3,5),Vector2(10,6)),MUTED,false)
		else: draw_icon("stairs",marker.pos,marker.color)
	var tree: Vector2i=ThirdFloorRules.active_hut_site(sim)
	if tree!=Vector2i(-1,-1) and sim.state.seen.has(sim.pos_key(tree)) and on_camera(tree):
		var point: Vector2=tile_point(tree)
		draw_rect(Rect2(point+Vector2(6,5),Vector2(4,12)),Color("665278"))
		draw_rect(Rect2(point+Vector2(1,-3),Vector2(14,11)),Color("a27dca"))
		draw_rect(Rect2(point+Vector2(5,-1),Vector2(6,5)),Color("e4c4f5"))
	for flower: Vector2i in sim.state.map.get("corpse_flowers",[]):
		if sim.state.seen.has(sim.pos_key(flower)): draw_corpse_flower(flower)
	for pit: Vector2i in sim.state.map.get("sewage_pits",[]):
		if pit_known(pit): draw_sewage_pit(pit)
	for drop: Dictionary in sim.state.get("essence_drops", []):
		if int(drop.get("region", -1)) == int(sim.state.region) and sim.visible(drop.pos): draw_icon("essence", drop.pos, Color("81bfe1"))
	for effect: Dictionary in sim.state.terrain_effects:
		for y: int in range(-int(effect.radius), int(effect.radius) + 1):
			for x: int in range(-int(effect.radius), int(effect.radius) + 1):
				var pos: Vector2i = effect.pos + Vector2i(x, y)
				if on_camera(pos) and sim.distance(pos, effect.pos) <= int(effect.radius): draw_rect(Rect2(tile_point(pos), Vector2(TILE, TILE)).grow(-1), Color(0.3, 0.8, 0.7, 0.25))
	for enemy: Dictionary in sim.enemies():
		if not sim.unit_visible(enemy): continue
		if enemy.intent.get("kind", "") in ["blast","suppression","call_dead"]:
			var radius: int=int(enemy.intent.get("radius",3))
			var center: Vector2i=enemy.intent.get("pos",enemy.pos)
			for y: int in range(-radius, radius + 1):
				for x: int in range(-radius, radius + 1):
					var pos: Vector2i = center + Vector2i(x, y)
					if on_camera(pos) and sim.distance(pos,center)<=radius:
						draw_rect(Rect2(tile_point(pos), Vector2(TILE, TILE)).grow(-1), Color(0.9, 0.25, 0.25, 0.3))
						draw_rect(Rect2(tile_point(pos), Vector2(TILE, TILE)).grow(-1), RED, false)
						draw_line(tile_point(pos) + Vector2(4, 4), tile_point(pos) + Vector2(11, 11), RED, 1)
	for contact: Dictionary in sim.audible_contacts():
		if on_camera(contact.pos):
			var center: Vector2 = tile_point(contact.pos)+Vector2(TILE,TILE)*0.5
			draw_arc(center,4,0,TAU,12,GOLD,1)
			draw_string(mono_font if mono_font != null else font,center+Vector2(-2,3),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	var breath_unit: Dictionary = sim.selected()
	if DungeonWorld.tile_at(sim.state.map,breath_unit.pos)==DungeonWorld.HAZARD:
		draw_string(mono_font if mono_font != null else font,Vector2(18,108),"BREATH %ds" % int(breath_unit.get("breath_remaining",sim.breath_capacity(breath_unit))),HORIZONTAL_ALIGNMENT_LEFT,-1,11,TEAL)
	if sim.danger_warning(): draw_string(mono_font if mono_font != null else font,Vector2(18,93),"! DANGER NEARBY",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOLD)
	for contact: Dictionary in sim.scent_contacts():
		if on_camera(contact.pos):
			var point: Vector2 = tile_point(contact.pos)
			draw_rect(Rect2(point+Vector2(3,3),Vector2(10,10)),TEAL,false)
			draw_string(mono_font if mono_font != null else font,point+Vector2(5,12),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEAL)
	var draw_units: Array = sim.allies() + sim.enemies()
	draw_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y or (a.pos.y == b.pos.y and a.pos.x < b.pos.x))
	for unit: Dictionary in draw_units:
		if unit.hp <= 0 or not on_camera(unit.pos) or not sim.unit_visible(unit): continue
		var sprite: String = "classic_monster_" + str(unit.get("content_id", "")).trim_prefix("canon_")
		var visual: Dictionary = visual_units.get(unit.id, {})
		var point: Vector2 = MAP_RECT.position + Vector2(visual.point) - Vector2(camera_tile) * TILE if visual.has("point") else tile_point(unit.pos)
		var bob: float = 0.0 if settings.reduced_motion else float(int(clock_time * 2 + unit.pos.x) % 2)
		draw_rect(Rect2(point + Vector2(3, 12), Vector2(11, 3)), Color(0, 0, 0, 0.35))
		if unit.team == "ally" and not unit.get("summon", false):
			var facing: int = int(visual.get("facing", unit.get("facing", 0)))
			var frame: int = int(float(visual.get("age", 1.0)) * 4) % 4 if not settings.reduced_motion and float(visual.get("age", 1.0)) < 1.0 else 0
			draw_map_texture(CharacterArt.sprite(unit, facing, frame), Rect2(point + Vector2(-8, -18 - bob), Vector2(32, 32)))
		elif tex(sprite) != null:
			var sprite_size: Vector2 = tex(sprite).get_size()
			draw_map_texture(tex(sprite), Rect2(point + Vector2(8 - sprite_size.x / 2, 14 - sprite_size.y - bob), sprite_size))
		else:
			var generated: Texture2D=ThirdFloorContent.sprite(str(unit.get("content_id","")),0 if settings.reduced_motion else int(clock_time*2)%2)
			if generated==null: generated=EarlyArt.sprite(str(unit.get("content_id","")),0 if settings.reduced_motion else int(clock_time*2)%2)
			if generated!=null: draw_map_texture(generated,Rect2(point+Vector2(-8,-18-bob),Vector2(32,32)))
			else: draw_rect(Rect2(point+Vector2(3,1),Vector2(10,13)),Color("d56b58") if unit.team=="enemy" else Color("91b34b"))
		if unit.get("summon",false) and unit.team=="ally": draw_rect(Rect2(point+Vector2(2,16),Vector2(12,1)),TEAL)
		if unit.id=="hero" and int(sim.state.get("torch_until",0))>int(sim.state.time): draw_magic_torch(point)
		if unit.id == sim.state.selected: draw_rect(Rect2(point + Vector2(2, 16), Vector2(12, 1)), TEAL)
		var hp_width: int = maxi(1, int(14.0 * float(unit.hp) / float(unit.max_hp)))
		draw_rect(Rect2(point + Vector2(1, 14), Vector2(14, 2)), INK)
		draw_rect(Rect2(point + Vector2(1, 14), Vector2(hp_width, 2)), Color("d56b58") if unit.team == "enemy" else Color("91b34b"))
		if not unit.statuses.is_empty(): draw_string(mono_font if mono_font != null else font, point + Vector2(0, -5), status_text(unit).left(3), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
	if jump_targeting:
		var jumper: Dictionary = sim.selected() if sim.state.combat else sim.hero()
		var reach: int = sim.jump_range(jumper)
		for dy: int in range(-reach,reach+1):
			for dx: int in range(-reach,reach+1):
				var target: Vector2i = jumper.pos+Vector2i(dx,dy)
				if on_camera(target) and sim.jump_error(target,jumper).is_empty(): draw_rect(Rect2(tile_point(target),Vector2(TILE,TILE)).grow(-1),TEAL,false)
	if selected_ability >= 0:
		var caster: Dictionary = sim.selected()
		var techniques: Array[Dictionary] = sim.techniques(caster)
		if selected_ability < techniques.size():
			var ability: Dictionary = techniques[selected_ability].ability
			for y: int in range(16):
				for x: int in range(27):
					var pos: Vector2i = camera_tile + Vector2i(x, y)
					if sim.visible(pos) and sim.distance(caster.pos, pos) <= int(ability.range) and DungeonWorld.line_of_sight(sim.state.map, caster.pos, pos): draw_rect(Rect2(tile_point(pos), Vector2(TILE, TILE)).grow(-1), Color(0.3, 0.9, 0.8, 0.25), false)
	if on_camera(hovered) and sim.visible(hovered): draw_rect(Rect2(tile_point(hovered), Vector2(TILE, TILE)), GOLD, false)
	if hit_flash > 0 and sim.state.has("last_hit") and on_camera(sim.state.last_hit.pos):
		var point: Vector2 = tile_point(sim.state.last_hit.pos)
		draw_rect(Rect2(point, Vector2(TILE, TILE)), Color(0.45, 0.8, 1.0, hit_flash * 2) if sim.state.last_hit.kind == "cold" else Color(1, 0.6, 0.5, hit_flash * 2))
		draw_string(mono_font if mono_font != null else font, point + Vector2(2, -2), "−%d" % sim.state.last_hit.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PALE)
	draw_rect(MAP_RECT, EDGE, false)

func draw_map_texture(texture: Texture2D, destination: Rect2) -> void:
	var clipped: Rect2 = destination.intersection(MAP_RECT)
	if not clipped.has_area(): return
	var ratio: Vector2 = texture.get_size() / destination.size
	var source: Rect2 = Rect2((clipped.position - destination.position) * ratio, clipped.size * ratio)
	draw_texture_rect_region(texture, clipped, source)

func on_camera(pos: Vector2i) -> bool:
	return pos.x >= camera_tile.x and pos.x < camera_tile.x + 27 and pos.y >= camera_tile.y and pos.y < camera_tile.y + 16

func tile_point(pos: Vector2i) -> Vector2:
	return MAP_RECT.position + Vector2(pos - camera_tile) * TILE

func draw_icon(id: String, pos: Vector2i, color: Color) -> void:
	if on_camera(pos) and tex(id) != null: draw_texture_rect(tex(id), Rect2(tile_point(pos), Vector2(TILE, TILE)), false, color)

func draw_hover() -> void:
	if not sim.visible(hovered): return
	var unit: Dictionary = sim.unit_at(hovered)
	var text: String=""
	if not unit.is_empty() and sim.unit_visible(unit): text="%s / HP %d/%d / armor %d / range %d" % [unit.name,unit.hp,unit.max_hp,unit.armor,unit.range]
	elif sim.state.map.get("corpse_flowers",[]).has(hovered):
		text="Corpse flower · water collected" if sim.state.map.get("harvested_flowers",[]).has(hovered) else "Corpse flower · E: collect water" if int(sim.state.time)>=sim.MINUTES_PER_DAY else "Corpse flower · blooms from expedition day2"
	elif sim.state.map.get("sewage_pits",[]).has(hovered) and pit_known(hovered): text="Sewage pit · marked safe" if sim.state.disarmed.has(sim.pos_key(hovered)) else "Hidden sewage pit · approach and press E to expose"
	elif sim.state.map.get("central_memorial")==hovered: text="Great Sage Memorial · E: inspect"
	elif sim.state.map.get("central_spire")==hovered: text="Central tower · fourth floor unavailable"
	elif hovered==ThirdFloorRules.active_hut_site(sim): text="Purple tree · E: Witch’s Cabin"
	elif hovered==sim.state.map.exit and int(sim.state.region) in [2,4]: text="Deeper route · destination not available yet"
	else:
		for gate: Dictionary in sim.state.map.get("area_portals",[]):
			if gate.pos==hovered: text=str(gate.direction).capitalize()+"ern stele · "+str(sim.region_data(int(gate.region)).name)
	if text.is_empty(): return
	draw_rect(Rect2(12, 245, 424, 16), Color(0.02, 0.04, 0.07, 0.96))
	draw_string(mono_font if mono_font != null else font, Vector2(16, 257), text, HORIZONTAL_ALIGNMENT_LEFT, 414, 10, PALE)

func _input(event: InputEvent) -> void:
	if not waiting_binding.is_empty() and event is InputEventKey and event.pressed:
		if event.keycode != KEY_ESCAPE:
			var collision: String = ""
			for id: String in settings.bindings:
				if id != waiting_binding and int(settings.bindings[id]) == event.keycode: collision = id
			if not collision.is_empty(): settings.bindings[collision] = settings.bindings[waiting_binding]
			settings.bindings[waiting_binding] = event.keycode
			SaveStore.save_settings(settings)
		waiting_binding = ""; render(); get_viewport().set_input_as_handled(); return
	if route_homeland_input(event):
		get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and overlay.is_empty() and screen == "game" and sim.state.get("mode", "") == "dungeon" and MAP_RECT.has_point(event.position):
		var inspect_pos: Vector2i = camera_tile + Vector2i((event.position - MAP_RECT.position) / TILE)
		var target: Dictionary = sim.unit_at(inspect_pos)
		if not target.is_empty() and sim.unit_visible(target): inspect_id = target.id; overlay = "inspect"; render(); get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion:
		var point: Vector2 = event.position
		hovered = camera_tile + Vector2i((point - MAP_RECT.position) / TILE) if MAP_RECT.has_point(point) else Vector2i(-1, -1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if jump_targeting: jump_targeting = false
		elif selected_ability >= 0: selected_ability = -1
		elif not overlay.is_empty(): overlay = ""
		elif screen == "game": overlay = "pause"
		elif screen == "create": screen = "title"
		render(); get_viewport().set_input_as_handled()

	if overlay.is_empty() and screen == "game" and not get_viewport().gui_get_focus_owner() is LineEdit:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
			var gameplay_keys: Array = [settings.bindings.inventory, settings.bindings.journal, settings.bindings.party, KEY_F5, KEY_F9]
			if sim.state.get("mode", "") == "dungeon": gameplay_keys += settings.bindings.values() + [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_1, KEY_2, KEY_3]
			if gameplay_keys.has(event.keycode):
				_unhandled_input(event)
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and sim.state.get("mode", "") == "dungeon":
			_unhandled_input(event)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not overlay.is_empty(): return
	if screen != "game": return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var bindings: Dictionary = settings.bindings
		if key == int(bindings.inventory): overlay = "inventory"; render(); return
		if key == int(bindings.journal): overlay = "journal"; render(); return
		if key == int(bindings.party): overlay = "party"; render(); return
		if key == KEY_F5: save_game(); flash("Game saved."); render(); return
		if key == KEY_F9 and developer_enabled: overlay = "developer"; render(); return
		if sim.state.mode != "dungeon": return
		if key == int(bindings.get("jump",KEY_V)): jump_targeting = not jump_targeting; selected_ability = -1; render(); return
		if key == KEY_TAB: cycle_party(); return
		if key in [KEY_1, KEY_2, KEY_3]:
			var slot: int = key - KEY_1
			if slot < sim.techniques(sim.selected()).size(): selected_ability = slot; jump_targeting = false; render()
			return
		if key == int(bindings.north) or key == KEY_UP: sim.move_unit(Vector2i.UP)
		elif key == int(bindings.south) or key == KEY_DOWN: sim.move_unit(Vector2i.DOWN)
		elif key == int(bindings.west) or key == KEY_LEFT: sim.move_unit(Vector2i.LEFT)
		elif key == int(bindings.east) or key == KEY_RIGHT: sim.move_unit(Vector2i.RIGHT)
		elif key == int(bindings.interact): do_interact(); return
		elif key == int(bindings.wait): sim.end_phase()
		elif key == int(bindings.camp): sim.camp()
		else: return
		after_command()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and sim.state.mode == "dungeon" and MAP_RECT.has_point(event.position):
		var pos: Vector2i = camera_tile + Vector2i((event.position - MAP_RECT.position) / TILE)
		if jump_targeting:
			if sim.jump(pos): jump_targeting = false
		elif selected_ability >= 0:
			if sim.use_technique(selected_ability, pos): selected_ability = -1
		else:
			var target: Dictionary = sim.unit_at(pos)
			if not target.is_empty() and target.team == "enemy": sim.attack(sim.selected(), target)
			elif not target.is_empty() and target.team == "ally": sim.state.selected = target.id
			elif sim.distance(sim.selected().pos if sim.state.combat else sim.hero().pos, pos) == 1: sim.move_unit(pos - (sim.selected().pos if sim.state.combat else sim.hero().pos))
		after_command()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START: overlay = "pause"; render(); return
		if sim.state.mode != "dungeon": return
		match event.button_index:
			JOY_BUTTON_DPAD_UP: sim.move_unit(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN: sim.move_unit(Vector2i.DOWN)
			JOY_BUTTON_DPAD_LEFT: sim.move_unit(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT: sim.move_unit(Vector2i.RIGHT)
			JOY_BUTTON_A: do_interact(); return
			JOY_BUTTON_X: sim.end_phase()
			JOY_BUTTON_Y: overlay = "inventory"
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: cycle_party(); return
		after_command()

func cycle_party() -> void:
	var group: Array = sim.allies().filter(func(u: Dictionary) -> bool: return u.hp > 0)
	var index: int = 0
	for i: int in range(group.size()):
		if group[i].id == sim.state.selected: index = i; break
	sim.state.selected = group[(index + 1) % group.size()].id
	selected_ability = -1
	render()

func capture(filename: String) -> void:
	# Force a frame even when macOS has occluded this verification window.
	# Waiting for frame_post_draw alone can suspend capture indefinitely.
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/" + filename)

func smoke_run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	await get_tree().create_timer(0.5).timeout
	await capture("01-title.png")
	screen = "create"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("02-create.png")
	sim.new_campaign("Adventurer", "barbarian", background_id, 74119)
	screen = "game"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("03-city.png")
	sim.enter_region(1); render()
	await get_tree().create_timer(0.2).timeout
	await capture("04-dungeon.png")
	overlay = "inventory"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("05-pack.png")
	overlay = "settings"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("06-settings.png")
	overlay = ""
	# A rendered tactical fixture tests layout/targeting only; not normal balance.
	sim.state.units = []
	var foe: Dictionary = sim.spawn_enemy("canon_goblin", sim.nearest_free(sim.hero().pos + Vector2i(3, 0)))
	sim.state.loot_essences.canon_goblin = 1
	sim.state.essence_drops = [{"id": "canon_goblin", "pos": sim.hero().pos, "region": sim.state.region, "expires_at": int(sim.state.time) + sim.UNCONTAINED_ESSENCE_LIFETIME_MINUTES}]
	sim.absorb("canon_goblin")
	sim.update_visibility()
	selected_ability = 0
	hovered = foe.pos
	render()
	await get_tree().create_timer(0.2).timeout
	await capture("07-combat-targeting.png")
	overlay = "essences"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("08-field-essence.png")
	overlay = "party"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("11-character-sheet.png")
	settings.text_scale = 1.2
	overlay = "inventory"; inventory_selected = "healing_potion"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("09-pack-120.png")
	overlay = "settings"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("10-settings-120.png")
	overlay = ""
	# Explicitly assisted visual fixture uses actual named recruitment commands.
	sim.state.mode = "city"; sim.state.gold = 1000; sim.state.flags.assisted = true
	for id: String in ["dwarf_guard", "fairy_archer", "human_mage", "beastman_swordsman"]: sim.recruit(id)
	sim.state.mode = "dungeon"
	for index: int in range(sim.state.party.size()):
		sim.state.party[index].pos = sim.nearest_free(sim.hero().pos + Vector2i(index % 2, index / 2 + 1))
	sim.update_visibility()
	render()
	await get_tree().create_timer(0.2).timeout
	await capture("12-party-hud-120.png")
	sim.state.mode = "city"
	render()
	await get_tree().create_timer(0.2).timeout
	await capture("13-city-party-120.png")
	settings.text_scale = 1.0
	selected_npc = "merchant"; npc_line = ""; overlay = "npc"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("15-city-npc.png")
	city_location = "guild"; overlay = "city_location"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("16-city-guild.png")
	begin_customization("hero")
	settings.text_scale = 1.2; render()
	await get_tree().create_timer(0.2).timeout
	await capture("17-customization-120.png")
	settings.text_scale = 1.0
	city_location = "portal"; overlay = "city_location"; render()
	await get_tree().create_timer(0.2).timeout
	await capture("18-portal-party.png")
	print("UI_SMOKE_OK: seventeen source-rendered screens captured; tactical fixtures use granted essence/companions")
	get_tree().quit()

func begin_customization(target: String = "creation") -> void:
	appearance_target = target
	var source: Dictionary = {"id": "hero", "ancestry": ancestry_id, "appearance": new_appearance}
	if target != "creation": source = sim.unit_by_id(target)
	if source.is_empty(): return
	appearance_draft = CharacterArt.normalize(source.get("appearance", {}), str(source.get("ancestry", "human")), int(new_seed) if target == "creation" else int(sim.state.seed))
	overlay = "appearance"
	render()

func appearance_preview_unit() -> Dictionary:
	if appearance_target == "creation": return {"id": "hero", "name": new_name, "ancestry": ancestry_id, "appearance": appearance_draft}
	var unit: Dictionary = sim.unit_by_id(appearance_target).duplicate(true)
	unit.appearance = appearance_draft
	return unit

func render_customization() -> void:
	modal("APPEARANCE")
	var unit: Dictionary = appearance_preview_unit()
	var side: VBoxContainer = column(Rect2(22, 50, 151, 260))
	if appearance_target != "creation":
		var members: Array = sim.allies().filter(func(u: Dictionary) -> bool: return not u.get("summon", false) and u.hp > 0)
		var select: OptionButton = OptionButton.new()
		for index: int in range(members.size()):
			select.add_item(str(members[index].name))
			if members[index].id == appearance_target: select.select(index)
		select.item_selected.connect(func(index: int) -> void: begin_customization(str(members[index].id)))
		side.add_child(select)
	else: label(str(GameContent.ancestries().get(ancestry_id, {}).get("name", "")), side, 13)
	var face: TextureRect = TextureRect.new()
	face.texture = CharacterArt.portrait(unit)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(128, 128)
	side.add_child(face)
	var figure: TextureRect = TextureRect.new()
	figure.texture = CharacterArt.sprite(unit)
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.custom_minimum_size = Vector2(64, 64)
	side.add_child(figure)
	var controls: VBoxContainer = column(Rect2(184, 50, 434, 260))
	controls.add_theme_constant_override("separation", 2)
	for field: String in CharacterArt.options():
		var choices: Array = CharacterArt.options()[field]
		var h: HBoxContainer = row(controls)
		var caption: Label = label(field.replace("_", " ").capitalize(), h, 10, PALE, false)
		caption.custom_minimum_size.x = 115
		var select: OptionButton = OptionButton.new()
		select.custom_minimum_size.y = 21
		select.add_theme_font_size_override("font_size", int(12 * float(settings.text_scale)))
		for state_name: String in ["normal", "hover", "pressed", "focus"]: select.add_theme_stylebox_override(state_name, style(PANEL, EDGE, 2))
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for index: int in range(choices.size()):
			select.add_item(str(choices[index]))
			if str(appearance_draft.get(field, "")) == str(choices[index]): select.select(index)
		select.item_selected.connect(func(index: int) -> void: appearance_draft[field] = choices[index]; render())
		h.add_child(select)
	button_at("RANDOMIZE", Rect2(22, 319, 151, 27), func() -> void:
		appearance_draft = CharacterArt.seeded(str(unit.get("ancestry", "human")), int(Time.get_ticks_usec() % 2147483647)); render())
	button_at("APPLY" if appearance_target == "creation" else "APPLY / 5 ST", Rect2(460, 319, 158, 27), func() -> void:
		if appearance_target == "creation": new_appearance = appearance_draft.duplicate(true)
		else:
			var result: String = sim.customize(appearance_target, appearance_draft)
			if not result.is_empty(): flash(result); render(); return
			save_game()
		overlay = ""; render())

func equip_from_inventory(id: String, unit_id: String) -> void:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if id == "frost_spirit_ring" and not unit.is_empty() and not unit.essences.is_empty():
		selected_party = unit_id
		overlay = "ring_seal"
		inventory_selected = id
		render()
		return
	action_result(sim.equip(id,unit_id))

func render_ring_seal() -> void:
	var content: VBoxContainer = modal("RING OF THE FROST SPIRIT")
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): label("Choose a character.",content,12); return
	var worn: bool = unit.equipment.get("charm", "") == "frost_spirit_ring"
	label("%s · seal one essence’s skills" % unit.name,content,14,TEAL)
	for id: String in unit.essences:
		button("SEAL / " + str(essence_defs[id].name),func() -> void:
			var result: String = sim.set_ring_seal(id,unit.id) if worn else sim.equip("frost_spirit_ring",unit.id,id)
			action_result(result),content,"Keeps attributes, essence ownership and occupied slot. Passive and active skills are unavailable while sealed.")
	if unit.essences.is_empty(): label("No absorbed essence to seal.",content,12)
	if worn and unit.get("ancestry", "") == "beastman" and not sim.RacialProgression.has_skadia(unit): button("AWAKEN SKADIA",func() -> void: confirm_skadia(unit.id),content)

func confirm_skadia(unit_id: String) -> void:
	var unit: Dictionary = sim.unit_by_id(unit_id)
	if unit.is_empty(): return
	confirm_text = "Awaken Skadia for %s?\n\nALL WORN EQUIPMENT IS DESTROYED:\n%s\n\nThe contract is permanent. Initial cold affects bare-handed strikes only.\nRemove other gear first to preserve it." % [unit.name,", ".join(sim.skadia_ritual_losses(unit))]
	pending_confirm = func() -> void: flash(sim.awaken_skadia(unit_id)); overlay = "party"
	overlay = "confirm"
	render()

func render_profession() -> void:
	var content: VBoxContainer = modal("MAGIC INSTRUCTION")
	var unit: Dictionary = sim.unit_by_id(selected_party)
	if unit.is_empty(): return
	label(str(unit.name),content,16,TEAL)
	if unit.get("profession", "") == "mage":
		label("Mage · Ice Spear",content,14)
		button("CHARACTER STATUS",func() -> void: overlay = "party"; render(),content)
		return
	if not unit.has("magic_assessment"):
		button("ASSESS / %d ST · %d DAYS" % [ProfessionRules.ASSESSMENT_COST,ProfessionRules.ASSESSMENT_DAYS],func() -> void:
			confirm_text = "Assess %s’s magical aptitude?\n\n%d stones · %d city days\nThe result is permanent and may be negative.\nFees, duration and talent frequency are estimates." % [unit.name,ProfessionRules.ASSESSMENT_COST,ProfessionRules.ASSESSMENT_DAYS]
			pending_confirm = func() -> void: flash(sim.assess_magic(unit.id)); overlay = "profession"
			overlay = "confirm"; render(),content,"Aptitude is stable for this character. Retesting, renaming and loading cannot reroll it. Time can pass the monthly entry opening.")
	elif unit.magic_assessment == "none": label("No aptitude for the basic instruction offered.",content,14)
	else:
		label("Limited aptitude · basic lessons available",content,14,TEAL)
		button("STUDY / %d ST · %d DAYS" % [ProfessionRules.TUITION_COST,ProfessionRules.TUITION_DAYS],func() -> void:
			confirm_text = "Teach Ice Spear to %s?\n\n%d stones · %d city days\nBecomes a mage and cannot absorb essences.\nRequires no absorbed essences.\nTuition and training duration are estimates." % [unit.name,ProfessionRules.TUITION_COST,ProfessionRules.TUITION_DAYS]
			pending_confirm = func() -> void: flash(sim.study_magic(unit.id)); overlay = "profession"
			overlay = "confirm"; render(),content,"Private basic instruction; no guaranteed Magic Tower admission. HP is preserved. Uses mana, not SP.")

func render_homeland_travel() -> void:
	var content: VBoxContainer = modal("RACIAL LANDS")
	var grid:=GridContainer.new(); grid.columns=2
	grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8)
	content.add_child(grid)
	for race: String in HomelandCatalog.ANCESTRIES:
		var entry: Dictionary = HomelandCatalog.definitions()[race]
		var target: Button = button(str(entry.name),func() -> void:
			var failure: String = sim.enter_homeland(race)
			if failure.is_empty(): overlay=""; save_game()
			else: flash(failure)
			render(),grid,str(entry.description))
		target.custom_minimum_size=Vector2(276,70); target.clip_text=true
		target.icon=CharacterArt.portrait({"id":"homeland_preview_"+race,"ancestry":race,"appearance":CharacterArt.seeded(race,3300+race.hash())})
		target.expand_icon=true; target.add_theme_constant_override("icon_max_width",36)
		target.tooltip_text += "\n"+"\n".join(entry.estimate_notes) if entry.get("provisional_location",false) else ""
	label("Rites require a participant of the appropriate race.",content,11,MUTED)

func render_homeland() -> void:
	var state: Dictionary = sim.state.homeland
	var location: String = str(state.location)
	var entry: Dictionary = HomelandCatalog.definitions()[location]
	var panel:=PanelContainer.new(); at(panel,Rect2(8,5,624,31))
	var header:=HBoxContainer.new(); header.add_theme_constant_override("separation",4); panel.add_child(header)
	button("RAFDONIA",func() -> void: leave_homeland_view(),header,"Return to the city.")
	var title: Label=label(str(entry.name),header,13,GOLD,false); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; title.clip_text=true
	var choice:=OptionButton.new(); choice.fit_to_longest_item=false; choice.clip_text=true; choice.custom_minimum_size=Vector2(130,24)
	choice.tooltip_text="Choose a party member for the local rites."
	header.add_child(choice)
	var visitors: Array = sim.allies().filter(func(u: Dictionary) -> bool: return u.hp>0 and not u.get("summon",false))
	for index: int in range(visitors.size()):
		choice.add_item(str(visitors[index].name))
		if visitors[index].id==state.selected: choice.select(index)
	choice.item_selected.connect(func(index: int) -> void:
		flash(sim.select_homeland_actor(visitors[index].id)); selected_party=visitors[index].id; render())
	button("?",func() -> void: overlay="homeland_notes"; render(),header,"About this place and its source details.")
	button("P",func() -> void: selected_party=str(state.selected); overlay="party"; render(),header,"Character Status")
	button("=",func() -> void: overlay="pause"; render(),header,"Pause [Esc]")
	homeland_view=HomelandMap.new(); at(homeland_view,Rect2(8,44,624,306))
	var visitor: Dictionary=sim.unit_by_id(str(state.selected))
	if visitor.is_empty(): visitor=sim.hero()
	homeland_view.configure(entry,visitor,sim.homeland_position())
	homeland_view.reduced_motion=bool(settings.reduced_motion); homeland_view.input_enabled=overlay.is_empty()
	homeland_view.position_changed.connect(func(position: Vector2i) -> void: sim.record_homeland_position(position))
	homeland_view.interaction_requested.connect(request_homeland_interaction)
	homeland_view.exit_requested.connect(leave_homeland_view)

func leave_homeland_view() -> void:
	flash(sim.leave_homeland()); overlay=""; save_game(); render()

func request_homeland_interaction(point_id: String) -> void:
	var location: String=str(sim.state.get("homeland",{}).get("location",""))
	var unit_id: String=str(sim.state.get("homeland",{}).get("selected","hero"))
	var result: Dictionary=sim.homeland_interact(point_id,unit_id)
	var point: Dictionary=HomelandCatalog.point(location,point_id)
	if result.get("open","")=="city": leave_homeland_view(); return
	if result.get("ok",false) and result.get("open","")=="choices":
		homeland_dialog=result.duplicate(true); homeland_dialog["location"]=location
		overlay="homeland_choice"
	elif result.get("ok",false) and result.get("confirm",false):
		confirm_text=str(point.get("name","Activity"))+"\n\n"+str(result.message)
		pending_confirm=func() -> void:
			if str(sim.state.get("homeland",{}).get("location",""))!=location: flash("Return to the reviewed activity first."); return
			var performed: Dictionary=sim.homeland_perform(str(result.action),unit_id,point_id)
			if not performed.ok: flash(str(performed.message))
			else: flash("")
		overlay="confirm"
	else:
		homeland_dialog={"title":str(point.get("name","Activity")),"message":str(result.get("message","Unavailable.")),"unit_id":unit_id,"equipment":result.get("open","")=="numbered"}
		overlay="homeland_dialog"
	render()

func render_homeland_dialog() -> void:
	var content: VBoxContainer=modal(str(homeland_dialog.get("title","Conversation")))
	label(str(homeland_dialog.get("message","")),content,13)
	if homeland_dialog.get("equipment",false): button("VIEW EQUIPMENT",func() -> void: selected_party=str(homeland_dialog.unit_id); overlay="inventory"; render(),content)

func render_homeland_notes() -> void:
	var location: String=str(sim.state.get("homeland",{}).get("location",""))
	var entry: Dictionary=HomelandCatalog.definitions().get(location,{})
	var content: VBoxContainer=modal("ABOUT "+str(entry.get("name","THE LAND")))
	label(str(entry.get("description","")),content,13)
	for note: String in entry.get("estimate_notes",[]): label(note,content,11,MUTED)
	label("These compact maps and visitor routes are reconstructions. Cultural references are recorded in the project’s source guide.",content,11,MUTED)

func route_homeland_input(event: InputEvent) -> bool:
	if screen!="game" or not overlay.is_empty() or sim.state.get("mode","")!="city" or str(sim.state.get("homeland",{}).get("location","")).is_empty(): return false
	if homeland_view==null or not is_instance_valid(homeland_view) or not homeland_view.is_inside_tree(): return false
	if event is InputEventKey and event.pressed:
		var key: int=event.keycode; var bindings: Dictionary=settings.bindings
		if key==int(bindings.north) or key==KEY_UP: homeland_view.move(Vector2i.UP)
		elif key==int(bindings.south) or key==KEY_DOWN: homeland_view.move(Vector2i.DOWN)
		elif key==int(bindings.west) or key==KEY_LEFT: homeland_view.move(Vector2i.LEFT)
		elif key==int(bindings.east) or key==KEY_RIGHT: homeland_view.move(Vector2i.RIGHT)
		elif key==int(bindings.interact) or key==KEY_SPACE: homeland_view.activate_nearby()
		else: return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: homeland_view.move(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN: homeland_view.move(Vector2i.DOWN)
			JOY_BUTTON_DPAD_LEFT: homeland_view.move(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT: homeland_view.move(Vector2i.RIGHT)
			JOY_BUTTON_A: homeland_view.activate_nearby()
			JOY_BUTTON_B: leave_homeland_view()
			_: return false
		return true
	return false

func render_homeland_choice() -> void:
	var coming: bool=homeland_dialog.get("action","")=="coming_of_age"
	var content: VBoxContainer=modal("COMING OF AGE" if coming else "DRAGON BLESSINGS")
	label(str(homeland_dialog.get("message","")),content,12)
	var unit_id: String=str(homeland_dialog.unit_id)
	var choices: Array=ComingOfAgeRules.options() if coming else DragonBlessingRules.IDS
	for id: String in choices:
		var row: Dictionary=item_defs[id] if coming else DragonBlessingRules.definitions()[id]
		var failure: String=ComingOfAgeRules.can_choose(sim,unit_id,id) if coming else DragonBlessingRules.can_inscribe(sim,unit_id,id)
		var description: String=item_tooltip(id)+"\nExchange your starting club once, before your first expedition." if coming else str(row.description)+"\n"+DragonBlessingRules.ACCESS_NOTE
		var target: Button=button(str(row.name),func() -> void: review_homeland_choice(id),content,description+("\n"+failure if not failure.is_empty() else ""))
		target.disabled=not failure.is_empty()
		if not coming: label(str(row.description),content,11,MUTED)
	if not coming: label("Level2 · 500 ST · one permanent blessing",content,11,GOLD)
	else: label("One weapon · starting club exchanged",content,11,GOLD)

func review_homeland_choice(choice_id: String) -> void:
	var review: Dictionary=homeland_dialog.duplicate(true)
	var coming: bool=review.action=="coming_of_age"
	var row: Dictionary=item_defs[choice_id] if coming else DragonBlessingRules.definitions()[choice_id]
	confirm_text="Choose %s?\n\n" % row.name
	confirm_text+=item_tooltip(choice_id)+"\n\nYour starting club is exchanged. This opening choice is permanent." if coming else str(row.description)+"\n\n500 stones. One permanent blessing; no replacement.\nLevel, fee, slot limit and grid conversions are provisional."
	pending_confirm=func() -> void:
		if str(sim.state.get("homeland",{}).get("location",""))!=str(review.location): flash("Return to the reviewed activity first."); return
		var performed: Dictionary=sim.homeland_perform(review.action,review.unit_id,review.point_id,choice_id)
		flash("" if performed.ok else str(performed.message))
	overlay="confirm"; render()

# Shared spatial markers keep the world view and overview consistent. The old
# exit remains a compatibility portal only on maps generated before version3.
func dungeon_markers() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if sim.floor_number()<3: result.append({"pos":sim.state.map.entrance,"color":TEAL,"kind":"arrival"})
	for gate: Dictionary in sim.state.map.get("area_portals",[])+sim.state.map.get("floor_portals",[]):
		result.append({"pos":gate.pos,"color":GOLD,"kind":"portal" if int(sim.region_data(int(gate.region)).floor)!=sim.floor_number() else "path"})
	if int(sim.state.map.get("generator_version",0))<3: result.append({"pos":sim.state.map.exit,"color":GOLD,"kind":"portal"})
	elif sim.floor_number()==2 and sim.state.map.get("floor_portals",[]).is_empty(): result.append({"pos":sim.state.map.exit,"color":MUTED,"kind":"boundary"})
	if sim.state.map.get("central_memorial") is Vector2i: result.append({"pos":sim.state.map.central_memorial,"color":MUTED,"kind":"memorial"})
	if sim.state.map.get("central_spire") is Vector2i: result.append({"pos":sim.state.map.central_spire,"color":MUTED,"kind":"boundary"})
	return result

func water_skin_texture() -> Texture2D:
	var image:=Image.create(24,24,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(9,2,6,4),Color("ae8d57")); image.fill_rect(Rect2i(8,6,8,2),Color("53412e"))
	image.fill_rect(Rect2i(5,9,14,11),Color("45392e")); image.fill_rect(Rect2i(6,8,12,13),Color("765e40"))
	image.fill_rect(Rect2i(7,10,10,9),Color("927a52")); image.fill_rect(Rect2i(9,12,6,5),Color("3c738a"))
	image.fill_rect(Rect2i(10,12,4,2),Color("97c4c2")); image.fill_rect(Rect2i(7,18,10,2),Color("514332"))
	return ImageTexture.create_from_image(image)

func draw_memorial(pos: Vector2i) -> void:
	if not on_camera(pos): return
	var point: Vector2=tile_point(pos)
	draw_rect(Rect2(point+Vector2(2,12),Vector2(12,3)),Color("4f575b"))
	draw_rect(Rect2(point+Vector2(5,2),Vector2(6,11)),Color("7b8588"))
	draw_rect(Rect2(point+Vector2(6,3),Vector2(4,2)),Color("a4afb0"))
	draw_line(point+Vector2(7,7),point+Vector2(8,10),Color("3c474c"),1)

func pit_known(pos: Vector2i) -> bool:
	if not sim.state.seen.has(sim.pos_key(pos)): return false
	return sim.state.disarmed.has(sim.pos_key(pos)) or (sim.visible(pos) and sim.distance(pos,sim.hero().pos)<=(3 if sim.stat_value(sim.hero(),"wit")>=7 else 2))

func draw_sewage_pit(pos: Vector2i) -> void:
	if not on_camera(pos): return
	var point: Vector2=tile_point(pos)
	var marked: bool=sim.state.disarmed.has(sim.pos_key(pos))
	draw_rect(Rect2(point+Vector2(2,5),Vector2(12,8)),Color("171a16"))
	draw_line(point+Vector2(2,5),point+Vector2(13,5),Color("706b4a"),1)
	if marked:
		draw_line(point+Vector2(4,7),point+Vector2(11,12),TEAL,1)
		draw_line(point+Vector2(11,7),point+Vector2(4,12),TEAL,1)
	else: draw_line(point+Vector2(4,10),point+Vector2(11,10),Color("48513a"),1)

func draw_corpse_flower(pos: Vector2i) -> void:
	if not on_camera(pos): return
	var point: Vector2=tile_point(pos)
	var harvested: bool=sim.state.map.get("harvested_flowers",[]).has(pos)
	var bloom: bool=int(sim.state.time)>=sim.MINUTES_PER_DAY
	var dim: Color=Color.WHITE if sim.visible(pos) else Color("50575b")
	draw_line(point+Vector2(2,13),point+Vector2(7,11),Color("536449")*dim,1)
	draw_line(point+Vector2(7,11),point+Vector2(12,14),Color("536449")*dim,1)
	draw_rect(Rect2(point+Vector2(3,8),Vector2(2,2)),Color("657044")*dim)
	if harvested: draw_rect(Rect2(point+Vector2(7,7),Vector2(3,4)),Color("544f47")*dim)
	elif not bloom: draw_rect(Rect2(point+Vector2(7,6),Vector2(3,6)),Color("776c74")*dim)
	else:
		for offset: Vector2i in [Vector2i(5,7),Vector2i(9,7),Vector2i(7,5),Vector2i(7,9)]: draw_rect(Rect2(point+Vector2(offset),Vector2(3,3)),Color("b5a7b1")*dim)
		draw_rect(Rect2(point+Vector2(8,8),Vector2(2,2)),Color("8cbac3")*dim)

func draw_dead_terrain(pos: Vector2i, rect: Rect2, tile: int, shade: Color) -> void:
	if tile==DungeonWorld.FLOOR:
		draw_rect(rect,Color("222322")*shade)
		if (pos.x*17+pos.y*7)%5==0: draw_rect(Rect2(rect.position+Vector2(3,9),Vector2(7,2)),Color("343731")*shade)
	elif tile==DungeonWorld.WALL:
		draw_rect(rect,Color("393a3d")*shade)
		draw_line(rect.position+Vector2(1,7),rect.position+Vector2(14,7),Color("55575a")*shade,1)
		draw_line(rect.position+Vector2(7,1),rect.position+Vector2(7,6),Color("262c29")*shade,1)
		if (pos.x+pos.y*3)%4==0:
			draw_line(rect.position+Vector2(2,1),rect.position+Vector2(5,14),Color("556149")*shade,1)
			draw_rect(Rect2(rect.position+Vector2(4,8),Vector2(3,2)),Color("6a7450")*shade)

func canyon_deep(pos: Vector2i) -> bool:
	var key: String=str(sim.state.map.seed)+":"+str(sim.state.region)
	if depth_visual_key!=key:
		depth_visual_key=key; depth_visual_distances=DungeonWorld.reachable(sim.state.map,sim.state.map.entrance)
		var values: Array=[]
		for spawn: Vector2i in sim.state.map.spawns: values.append(int(depth_visual_distances.get(spawn,0)))
		values.sort(); depth_visual_boundary=int(values[values.size()/2]) if not values.is_empty() else 50
		# Wall faces inherit depth from the nearest traversable canyon surface.
		# Flood once per map, avoiding a fresh path search for every drawn tile.
		var surface_queue: Array[Vector2i]=[]
		for cell: Vector2i in depth_visual_distances: surface_queue.append(cell)
		var cursor: int=0
		while cursor<surface_queue.size():
			var cell: Vector2i=surface_queue[cursor]; cursor+=1
			for direction: Vector2i in DungeonWorld.DIRECTIONS:
				var next: Vector2i=cell+direction
				if next.x<0 or next.y<0 or next.x>=int(sim.state.map.width) or next.y>=int(sim.state.map.height) or depth_visual_distances.has(next): continue
				depth_visual_distances[next]=depth_visual_distances[cell]; surface_queue.append(next)
	return int(depth_visual_distances.get(pos,depth_visual_boundary))>=depth_visual_boundary

func draw_canyon_terrain(pos: Vector2i, rect: Rect2, tile: int, shade: Color) -> void:
	var deep: bool=canyon_deep(pos)
	if tile==DungeonWorld.WALL:
		var rock: Color=Color("25252a") if deep else Color("67513d")
		draw_rect(rect,rock*shade)
		draw_line(rect.position+Vector2(1,3),rect.position+Vector2(14,2),rock.lightened(0.22)*shade,1)
		draw_line(rect.position+Vector2(2,8),rect.position+Vector2(13,7),rock.darkened(0.28)*shade,1)
		draw_line(rect.position+Vector2(5,10),rect.position+Vector2(7,14),rock.darkened(0.35)*shade,1)
		if DungeonWorld.walkable(sim.state.map,pos+Vector2i.DOWN): draw_rect(Rect2(rect.position+Vector2(0,13),Vector2(16,3)),rock.darkened(0.42)*shade)
	elif tile==DungeonWorld.FLOOR:
		draw_rect(rect,(Color("49423b") if deep else Color("8b7453"))*shade)
		if (pos.x*11+pos.y*3)%7==0: draw_rect(Rect2(rect.position+Vector2(4,10),Vector2(5,2)),Color("b19a6a")*shade)

func supply_tooltip() -> String:
	var text: String="Food / drinking water supplies"
	if sim.state.get("mode","")=="dungeon" and int(sim.state.get("torch_until",0))>int(sim.state.get("time",0)):
		var remaining: int=int(sim.state.torch_until)-int(sim.state.time)
		text+="\nMagic Torch: %dh%02dm remaining." % [remaining/60,remaining%60]
	return text

func draw_magic_torch(point: Vector2) -> void:
	var tip: Vector2=point+Vector2(7,-24)
	if not MAP_RECT.encloses(Rect2(tip,Vector2(5,10))): return
	var flicker: int=0 if settings.reduced_motion else int(clock_time*4)%2
	draw_rect(Rect2(tip+Vector2(2,5),Vector2(1,5)),Color("8d6e42"))
	draw_rect(Rect2(tip+Vector2(1,flicker),Vector2(3,6-flicker)),Color("cf783b"))
	draw_rect(Rect2(tip+Vector2(2,2),Vector2(1,3)),Color("ead38b"))

func draw_third_terrain(pos: Vector2i, rect: Rect2, tile: int, shade: Color) -> void:
	var terrain: String=str(sim.state.map.get("terrain",""))
	var seed_tone: int=(pos.x*7+pos.y*13)%5
	if terrain=="dark_estuary":
		draw_rect(rect,Color("253e45" if tile==2 else "34494a" if tile==0 else "182d32")*shade)
		if tile==2:
			draw_line(rect.position+Vector2(2,5+seed_tone),rect.position+Vector2(12,5+seed_tone),Color("57828a")*shade)
			if ThirdFloorRules.high_tide(sim): draw_rect(rect.grow(-1),Color(0.2,0.4,0.5,0.18))
		for mound: Rect2i in sim.state.map.get("dry_mounds",[]):
			if mound.has_point(pos): draw_rect(rect,Color("815a49")*shade); draw_rect(Rect2(rect.position+Vector2(3,6),Vector2(4,2)),Color("b18460")*shade); break
	elif terrain=="ironrock_hills":
		draw_rect(rect,Color("30383d" if tile==1 else "5c6058")*shade)
		draw_line(rect.position+Vector2(1,4+seed_tone),rect.position+Vector2(13,2+seed_tone),Color("4b5255" if tile==1 else "878a76")*shade)
		if tile==1: draw_rect(Rect2(rect.position+Vector2(2,12),Vector2(14,4)),Color("222b31")*shade)
	else:
		var witch: bool=terrain=="witch_forest"
		draw_rect(rect,Color("272637" if witch else "26382b")*shade)
		if tile==1:
			draw_rect(Rect2(rect.position+Vector2(6,9),Vector2(4,7)),Color("584657" if witch else "594b39")*shade)
			draw_rect(Rect2(rect.position+Vector2(1,1),Vector2(14,10)),Color("494056" if witch else "38543b")*shade)
			draw_rect(Rect2(rect.position+Vector2(3,2),Vector2(9,4)),Color("60516e" if witch else "4c6844")*shade)
		elif seed_tone<2: draw_line(rect.position+Vector2(2,11),rect.position+Vector2(11,4),Color("50405d" if witch else "42513a")*shade)
