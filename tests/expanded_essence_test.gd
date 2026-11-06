extends SceneTree

const Source = preload("res://game/content_reference.gd")
const Runtime = preload("res://game/reference_runtime.gd")
const Simulation = preload("res://game/simulation.gd")
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
	sim.new_campaign("Expanded essence fixture", "barbarian", "adventurer", 74119)
	sim.state.gold = 1000
	sim.recruit("barbarian_guard")
	sim.enter_region(1)
	sim.state.units = []
	for y: int in range(1,int(sim.state.map.height)-1):
		for x: int in range(1,int(sim.state.map.width)-1): sim.state.map.tiles[y][x] = World.FLOOR
	sim.state.map.traps = []
	sim.hero().pos = Vector2i(6,6)
	sim.hero().ap = 2
	sim.state.party[0].pos = Vector2i(5,6)
	sim.state.party[0].behavior = "manual"
	sim.state.party[0].ap = 2
	sim.state.time = 0
	sim.state.level = 2
	sim.recalculate(sim.hero(),true)
	sim.state.combat = true
	sim.update_visibility()
	return sim

func bind(sim: GameSimulation, id: String) -> void:
	sim.state.essence_drops.append({"id":id,"pos":sim.hero().pos,"region":int(sim.state.region),"expires_at":int(sim.state.time)+sim.UNCONTAINED_ESSENCE_LIFETIME_MINUTES})
	sim._recount_essence_drops()
	check(sim.absorb(id).is_empty(),"Actual physical-drop absorption accepts implemented component: " + id)

func target(sim: GameSimulation, pos: Vector2i) -> Dictionary:
	var unit: Dictionary = sim.spawn_enemy("canon_ghoul",pos)
	unit.hp = 1000; unit.max_hp = 1000
	return unit

func _initialize() -> void:
	_test_provenance_and_limits()
	var live: Dictionary = Runtime.essences()
	check(live.has("canon_blade_wolf") and live.has("canon_stone_golem"),"Only resolver-ready expanded components are advertised as obtainable")
	if live.has("canon_blade_wolf") and live.has("canon_stone_golem"):
		_test_scent_component()
		_test_suppression_component()
		_test_route_and_rewards()
		_test_release_and_telegraph()
		_test_actual_new_family_drops()
	print("EXPANDED ESSENCES: %d checks, %d failures. Partial sourced components; grid timings/range/drop estimate are not canonical coefficients. Assisted fixtures, no player saves." % [checks,failures])
	quit(1 if failures else 0)

func _test_provenance_and_limits() -> void:
	var research: Dictionary = Source.essences()
	for id: String in ["canon_blade_wolf","canon_stone_golem"]:
		var entry: Dictionary = research[id]
		check(entry.essence_transfer_verified and not entry.full_kit_verified,"Known transferable component does not imply verified complete essence kit")
		check(not entry.reference_urls.is_empty() and not entry.primary_text_evidence.is_empty(),"Component retains directly read source and claims")
		check(not entry.source_stats.size(),"Unknown stat bonuses are not invented")
	check(research.canon_blade_wolf.passive == "scent_tracking" and str(research.canon_blade_wolf.ability.effect).is_empty(),"Blade Wolf adds only documented tracking, with no invented active")
	check(str(research.canon_stone_golem.passive).is_empty() and research.canon_stone_golem.ability.breaks_on_damage,"Stone Golem adds only documented active and damage break")
	for id: String in ["canon_ghoul","canon_skeleton","canon_goblin_swordsman"]:
		check(not research.has(id) and str(Source.monsters()[id].essence).is_empty(),"Unverified existing monster kit remains absent: " + id)
	var golem: Dictionary = Runtime.monsters().canon_stone_golem
	check(golem.role == "controller" and golem.suppression.breaks_on_damage,"Stone Golem AI receives the documented control mechanic")
	check(not golem.essence_drop_chance_verified and str(golem.drop_rate_source).is_empty(),"Rank-eight drop estimate is not attributed to rank-nine probability evidence")
	var route: Dictionary = Runtime.regions().r04
	check(int(route.floor) == 2 and route.entry_direction == "south" and int(route.portal_closes_after_days) == 10,"Fourth area is the southern second-floor route with floor-two closure")
	check(route.enemy_ids == ["canon_gnome","canon_kobold_shield_soldier","canon_sandman","canon_stone_golem"],"Route uses researched implemented subset, not a fabricated boss")

func _test_scent_component() -> void:
	var sim := fresh()
	bind(sim,"canon_blade_wolf")
	check(sim.techniques(sim.hero()).is_empty(),"Passive-only component creates no empty active command")
	check(sim.has_method("scent_contacts"),"Simulation exposes anonymous scent contacts separately from sight")
	if not sim.has_method("scent_contacts"): return
	var hidden: Dictionary = target(sim,Vector2i(9,6))
	sim.state.map.tiles[6][8] = World.WALL
	sim.state.seen = {}; sim.state.visible = {}
	sim.update_visibility()
	check(not sim.unit_visible(hidden),"Fixture enemy is outside actual visual line of sight")
	var seen: Dictionary = sim.state.seen.duplicate(true)
	var visible: Dictionary = sim.state.visible.duplicate(true)
	var contacts: Array = sim.call("scent_contacts")
	check(not contacts.is_empty(),"Scent component reports a nearby unseen contact")
	for contact: Variant in contacts:
		if contact is Dictionary:
			check(not contact.has("name") and not contact.has("hp") and not contact.has("content_id") and not contact.has("id"),"Scent information does not expose species, HP or entity identity")
	check(sim.state.seen == seen and sim.state.visible == visible and not sim.unit_visible(hidden),"Scent does not reveal terrain or alter attack visibility")
	check(not sim.attack(sim.hero(),hidden),"Anonymous scent cannot enable attacks through a wall")
	var cloned := Simulation.new()
	check(cloned.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Scent-bound expedition saves through ordinary JSON roundtrip")
	if cloned.has_method("scent_contacts"): check(not cloned.call("scent_contacts").is_empty(),"Bound tracking persists after reload")

func _test_suppression_component() -> void:
	var sim := fresh()
	bind(sim,"canon_blade_wolf")
	bind(sim,"canon_stone_golem")
	check(sim.techniques(sim.hero()).size() == 1 and int(sim.techniques(sim.hero())[0].essence_slot) == 1,"Active command maps past an earlier passive-only essence slot")
	var one: Dictionary = target(sim,Vector2i(8,6))
	var two: Dictionary = target(sim,Vector2i(8,7))
	sim.update_visibility()
	var sp: int = int(sim.hero().energy)
	check(sim.use_technique(0,one.pos),"Suppression casts through actual essence resolver")
	check(one.statuses.has("suppressed") and two.statuses.has("suppressed"),"Suppression locks both targets in its provisional area")
	check(int(one.hp) == 1000 and int(two.hp) == 1000 and int(sim.hero().energy) == sp-3,"Control ability spends SP without dealing invented damage")
	var ally_hp: int = int(sim.hero().hp)
	sim.enemy_turn(one)
	check(int(sim.hero().hp) == ally_hp,"Suppressed enemy cannot take a normal offensive turn")
	sim.status(one,"paralyzed",2)
	sim.hit(sim.hero(),one,1,"physical","Damage-break fixture",false,true)
	check(not one.statuses.has("suppressed") and one.statuses.has("paralyzed"),"One positive damage breaks only Suppression, preserving separate paralysis")
	check(two.statuses.has("suppressed"),"Injury to one target does not free another suppressed target")
	var cloned := Simulation.new()
	check(cloned.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Suppression status and essence survive validated save roundtrip")
	if not cloned.state.is_empty(): check(cloned.enemies()[1].statuses.has("suppressed"),"Undamaged target remains suppressed after reload")
	sim.status(sim.hero(),"suppressed",2)
	var ap: int = int(sim.hero().ap)
	var energy: int = int(sim.hero().energy)
	check(not sim.move_unit(Vector2i.UP) and not sim.attack(sim.hero(),one),"Suppression blocks player movement and weapon attacks")
	sim.hero().cooldowns = {}
	check(not sim.use_technique(0,two.pos) and int(sim.hero().ap) == ap and int(sim.hero().energy) == energy,"Suppressed ability rejection preserves AP and SP")
	sim.hit({"name":"Minor wound","statuses":{}},sim.hero(),1,"physical","Release fixture",false,true)
	check(not sim.hero().statuses.has("suppressed"),"Positive damage also frees a suppressed player")

func _test_route_and_rewards() -> void:
	var sim := Simulation.new()
	sim.new_campaign("Route fixture","barbarian","adventurer",74119)
	check(sim.enter_region(1),"Actual first expedition starts")
	sim.state.units = []; sim.state.combat = false
	sim.hero().pos = EarlyFloorRules.return_anchor(sim.state.map,int(4))
	check(sim.travel_region(4),"Actual cave portal reaches researched Black Rock Mountain")
	if int(sim.state.region) != 4: return
	check(sim.floor_number() == 2 and sim.portal_limit() == 10*24*60,"Fourth area's closure remains second-floor ten days")
	check(World.validate(sim.state.map).is_empty(),"Fourth-area layout meets normal reachability/placement validator")
	for foe: Dictionary in sim.enemies(): check(route_enemy_ids(sim).has(foe.content_id),"Fourth-area encounter pool contains supported species only")
	sim.state.units = []; sim.state.combat = false
	var golem: Dictionary = sim.spawn_enemy("canon_stone_golem",sim.hero().pos+Vector2i.RIGHT)
	sim.hit(sim.hero(),golem,100000,"physical","Assisted rank-eight kill",false,true)
	check(int(sim.state.loot_items.get("mana_stone_rank_8",0)) == 1 and int(sim.state.xp) == 2,"Actual rank-eight death awards its rank-eight stone and first-species XP")

func _test_release_and_telegraph() -> void:
	var sim := fresh()
	# An actual visible enemy keeps the fixture in combat after visibility refresh.
	target(sim,Vector2i(8,6))
	sim.update_visibility()
	check(sim.state.combat,"Release-cost fixture is in actual combat")
	var companion: Dictionary = sim.state.party[0]
	sim.status(companion,"suppressed",2)
	var hp: int = int(companion.hp)
	var ap: int = int(sim.hero().ap)
	check(sim.release_suppression(str(companion.id)).is_empty(),"Adjacent free ally can use the source-supported release cut")
	check(int(companion.hp) == hp-1 and int(sim.hero().ap) == ap-1 and sim.hero().attacked and not companion.statuses.has("suppressed"),"Release cut costs exactly one actual HP and one AP/attack, then breaks Suppression")
	sim.status(companion,"suppressed",2)
	companion.hp = 1
	sim.hero().ap = 2; sim.hero().attacked = false
	check(not sim.release_suppression(str(companion.id)).is_empty() and int(companion.hp) == 1 and int(sim.hero().ap) == 2,"Release refuses a lethal cut without consuming HP or AP")
	companion.hp = hp
	companion.pos = sim.hero().pos + Vector2i(3,0)
	check(not sim.release_suppression(str(companion.id)).is_empty() and int(companion.hp) == hp,"Release requires actual adjacency")
	sim.state.units = []
	sim.update_visibility()
	companion.pos = sim.hero().pos + Vector2i.LEFT
	sim.hero().ap = 2; sim.hero().attacked = false
	check(not sim.state.combat and sim.release_suppression(str(companion.id)).is_empty(),"Release also works during exploration")
	check(int(companion.hp) == hp-1 and int(sim.hero().ap) == 2 and not sim.hero().attacked,"Exploration release spends health without consuming combat AP or attack")
	var danger := fresh()
	var golem: Dictionary = danger.spawn_enemy("canon_stone_golem",Vector2i(8,6))
	danger.update_visibility()
	danger.plan_intents()
	check(golem.intent.get("kind","") == "suppression" and golem.intent.pos == danger.hero().pos,"Stone Golem telegraphs its actual target tile before casting")
	var old_center: Vector2i = golem.intent.pos
	check(danger.move_unit(Vector2i.UP) and danger.move_unit(Vector2i.UP),"Player can move beyond the advertised area before resolution")
	danger.enemy_turn(golem)
	check(not danger.hero().statuses.has("suppressed") and danger.state.party[0].statuses.has("suppressed"),"Telegraphed Suppression resolves the old area: moved hero escapes while stationary ally is affected")
	check(int(golem.cooldowns.get("suppression",0)) > 0 and danger.distance(danger.hero().pos,old_center) > 1,"Resolved control cast enters cooldown and respects its dodgeable area")

func _test_actual_new_family_drops() -> void:
	for id: String in ["canon_blade_wolf","canon_stone_golem"]:
		var sim := fresh()
		var chance: float = float(sim.monster_defs[id].essence_drop_chance)
		var sampler: RandomNumberGenerator = RandomNumberGenerator.new()
		sampler.seed = 8877
		var favorable_state: int = -1
		# Assisted RNG selection exercises the real rare-drop transaction without
		# altering probabilities or pretending this is a natural frequency test.
		for roll: int in range(200000):
			var before: int = sampler.state
			if sampler.randf() < chance: favorable_state = before; break
		check(favorable_state != -1,"Fixed RNG stream includes a real configured rare-drop roll")
		if favorable_state == -1: continue
		var monster: Dictionary = sim.spawn_enemy(id,sim.hero().pos+Vector2i.RIGHT)
		sim.rng.state = favorable_state
		sim.hit(sim.hero(),monster,100000,"physical","Assisted rare-drop fixture",false,true)
		check(sim.state.essence_drops.size() == 1 and sim.state.essence_drops[0].id == id,"Actual monster death produces its own newly implemented essence family")
		if sim.state.essence_drops.is_empty(): continue
		check(sim.state.essence_drops[0].pos == monster.pos and int(sim.state.essence_drops[0].expires_at) == int(sim.state.time)+30,"Actual new-family drop has physical position and thirty-minute deadline")
		check(sim.absorb(id).is_empty() and sim.hero().essences.has(id) and sim.state.essence_drops.is_empty(),"Actual rare drop is obtainable and consumed through ordinary field absorption")
		check(float(sim.monster_defs[id].essence_drop_chance) == chance,"Rare-drop fixture never changes configured probability")

func route_enemy_ids(sim: GameSimulation) -> Array:
	return sim.region_data().enemy_ids
