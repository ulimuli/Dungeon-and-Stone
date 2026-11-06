extends SceneTree
## Catalog capacity fixtures do not represent playable or researched items.
const Catalog = preload("res://game/numbered_catalog.gd")
const Rules = preload("res://game/numbered_rules.gd")
const Content = preload("res://game/content.gd")
const Sim = preload("res://game/simulation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func bad_row(key: String, value: Variant, label: String) -> void:
	var row: Dictionary = Catalog.definitions().snowfield_club.duplicate(true)
	row[key] = value
	check(not Catalog.validate_entries({"fixture":row}).is_empty(), label)

func fresh() -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Numbered catalog test", "human", "adventurer", 74119)
	sim.state.gold = 100000
	return sim

func expedition(sim: GameSimulation) -> Dictionary:
	check(sim.enter_region(1), "Actual expedition entry")
	sim.state.units = []; sim.state.combat = true; sim.resolving_round = true
	var source: Dictionary = sim.hero()
	source.essences = []; source.statuses = {}; source.ap = 10; source.accuracy = 1000
	var position: Vector2i = source.pos + Vector2i.RIGHT
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		if DungeonWorld.walkable(sim.state.map, source.pos + direction): position = source.pos + direction; break
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",position)
	target.hp = 1000; target.max_hp = 1000; target.evasion = 0; target.statuses = {}; target.armor = 0; target.resist = {}
	sim.update_visibility()
	return target

func seed_for(sim: GameSimulation, hit: bool) -> void:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,10000):
		probe.seed = candidate
		if (probe.randi_range(1,100) <= 98) == hit: sim.rng.seed = candidate; return
	check(false,"Deterministic hit/miss seed exists")

func _initialize() -> void:
	_test_registry()
	_test_validation()
	_test_purchase_and_attack()
	_test_proc_boundaries()
	_test_additional_damage_kill()
	print("NUMBERED CATALOG: %d checks, %d failures. %d bundled researched definitions; 1000 synthetic rows test validator capacity only." % [checks,failures,Catalog.definitions().size()])
	quit(1 if failures else 0)

func _test_registry() -> void:
	check(Catalog.validate().is_empty(), "Bundled catalog validates")
	var definitions: Dictionary = Catalog.definitions()
	for id: String in ["frost_spirit_ring","guardians_braces","snowfield_club"]:
		check(definitions.has(id), "Bundled Numbered definition: " + id)
		check(Content.weapons().has(id) and int(Content.weapons()[id].number) == int(definitions[id].number), "GameContent metadata derives from catalog: " + id)
	var equipment: Dictionary = {"equipment":{"weapon":"snowfield_club","armor":"club","charm":"guardians_braces"}}
	check(Rules.equipped_ids(equipment).has("snowfield_club") and Rules.equipped_ids(equipment).has("guardians_braces") and not Rules.equipped_ids(equipment).has("club"), "Shared resolver detects catalog entries and excludes ordinary gear")
	check(Rules.duration_for("guardians_braces",{"ancestry":"human"},20) == 4 and Rules.duration_for("guardians_braces",{"ancestry":"dwarf"},20) == 6,"Shared active duration uses catalog charge and Dwarf multiplier")
	check(Rules.duration_for("snowfield_club",{},0) == 0 and Rules.duration_for("unknown",{},0) == 0,"Passive or unknown item has no active duration")
	check(Rules.mitigate_for("guardians_braces",20,0) == {"damage":19,"prevented":1,"remainder":0},"Shared mitigation dispatches reduction operation")
	check(Rules.mitigate_for("snowfield_club",20,0) == {"damage":20,"prevented":0,"remainder":0},"Unrelated item does not gain Braces mitigation")
	var synthetic: Dictionary = {}
	for index: int in range(1000):
		var row: Dictionary = definitions.snowfield_club.duplicate(true)
		row.number = 1000 + index; row.name = "Validator fixture " + str(index)
		synthetic["validator_fixture_" + str(index)] = row
	check(Catalog.validate_entries(synthetic).is_empty(),"Validator accepts 1000 synthetic definitions without turning fixtures into playable content")
	check(not Catalog.definitions().has("validator_fixture_0"),"Capacity fixtures never modify live catalog")

func _test_validation() -> void:
	check(not Catalog.validate_entries({"fixture":null}).is_empty(),"Nonobject row rejected")
	var duplicate: Dictionary = Catalog.definitions().snowfield_club.duplicate(true)
	check(not Catalog.validate_entries({"fixture_a":duplicate,"fixture_b":duplicate.duplicate(true)}).is_empty(),"Duplicate canonical numbers rejected")
	for number: Variant in [0,10000,-1,1.5,"9712",true,null]: bad_row("number",number,"Invalid canonical number rejected: " + str(number))
	bad_row("name","","Missing display name rejected")
	bad_row("reference_urls",[],"Missing provenance rejected")
	bad_row("reference_urls",["not a source"],"Malformed provenance URL rejected")
	bad_row("slot","helmet","Unsupported equipment slot rejected")
	bad_row("price",-1,"Negative price rejected")
	bad_row("price","1800","Nonnumeric price rejected")
	bad_row("weight",-1,"Negative weight rejected")
	bad_row("passives",{},"Nonarray passive effects rejected")
	bad_row("passives",[{"op":"invented_effect"}],"Unsupported passive operation rejected")
	bad_row("passives",[{"op":"damage_reduction","percent":101}],"Reduction beyond one hundred percent rejected")
	bad_row("passives",[{"op":"extra_weapon_damage","amount":0,"damage_type":"cold"}],"Nonpositive additional damage rejected")
	bad_row("passives",[{"op":"extra_weapon_damage","amount":5,"damage_type":"invented"}],"Unsupported damage type rejected")
	for bad: Variant in [[],null,"stats",{"invented_stat":1},{"attack":"5"},{"attack":INF},{"attack":1000000001}]: bad_row("base_stats",bad,"Invalid intrinsic stat rejects safely")
	bad_row("weapon_style","invented","Unsupported weapon behavior rejects")
	bad_row("active",[],"Nonobject active definition rejected")
	var active: Dictionary = Catalog.definitions().guardians_braces.active.duplicate(true)
	active.effects = [{"op":"invented_effect","target":"allies","radius":3}]
	bad_row("active",active,"Unsupported active operation rejected")
	active.effects = [{"op":"status_immunity","target":"everyone","radius":3}]
	bad_row("active",active,"Unsupported target group rejected")
	active.effects = [{"op":"status_immunity","target":"allies","radius":-1}]
	bad_row("active",active,"Negative targeting radius rejected")
	active.effects = [{"op":"knockback","target":"enemies","radius":3,"distance":-1}]
	bad_row("active",active,"Negative displacement rejected")
	bad_row("passives",[],"Item without implemented passive, active or ritual rejected")

func _test_purchase_and_attack() -> void:
	var sim := fresh()
	var cost: int = sim.market_price("snowfield_club")
	var gold: int = sim.state.gold
	check(sim.buy("snowfield_club").is_empty(),"Actual market purchases the catalog weapon")
	check(int(sim.state.gold) == gold-cost and int(sim.state.inventory.get("snowfield_club",0)) == 1,"Actual quoted price charged once and weapon enters pack")
	gold = sim.state.gold
	check(not sim.buy("snowfield_club").is_empty() and int(sim.state.gold) == gold,"One consignment cannot be bought twice")
	check(sim.equip("snowfield_club").is_empty() and sim.hero().equipment.weapon == "snowfield_club","Actual equipment flow equips catalog weapon")
	var target: Dictionary = expedition(sim)
	var source: Dictionary = sim.hero()
	target.armor = 3; target.resist = {"physical":50,"cold":60}
	var expected_physical: int = sim.damage_amount(int(source.power),3,50,true)
	var expected_cold: int = sim.damage_amount(5,3,60,false)
	var hp: int = target.hp; var energy: int = source.energy; var mana: int = source.mana; var ap: int = source.ap
	seed_for(sim,true)
	check(sim.attack(source,target),"Actual normal weapon attack resolves")
	check(int(target.hp) == hp-expected_physical-expected_cold,"Physical armor/resistance and extra frost resistance resolve separately")
	check(int(source.energy) == energy and int(source.mana) == mana and int(source.ap) == ap-1,"Additional frost costs no Soul Power, mana or extra AP")
	check(sim.state.last_hit.kind == "cold" and int(sim.state.last_hit.amount) == expected_cold,"Additional damage retains cold damage type")
	check(not sim.activate_numbered("snowfield_club").is_empty(),"Passive club cannot invent an active technique")

func _test_proc_boundaries() -> void:
	var sim := fresh(); check(sim.buy("snowfield_club").is_empty() and sim.equip("snowfield_club").is_empty(),"Boundary fixture equips purchased club")
	var target: Dictionary = expedition(sim); var source: Dictionary = sim.hero()
	var hp: int = target.hp
	source.spells = ["ice_spear"]; source.mana = 30; source.max_mana = 30
	seed_for(sim,true)
	check(sim._cast_spell(source,"ice_spear",target.pos),"Actual spell casts while club is equipped")
	check(int(target.hp) == hp-int(source.power),"Spell receives no additional weapon frost")
	hp = target.hp
	check(sim.hit(source,target,7,"fire","Nonweapon fixture",true,true) == 7 and int(target.hp) == hp-7,"Nonweapon hit cannot proc additional frost")
	hp = target.hp; source.ap = 10; source.attacked = false
	seed_for(sim,false)
	check(sim.attack(source,target) and int(target.hp) == hp,"Missed actual weapon attack deals neither physical nor additional frost")
	sim.state.combat = false
	check(sim.equip("club").is_empty(),"Ordinary weapon can replace Numbered club")
	sim.state.combat = true; source.ap = 10; source.attacked = false; source.accuracy = 1000; hp = target.hp
	seed_for(sim,true)
	check(sim.attack(source,target) and int(target.hp) == hp-int(source.power),"Unequipped club grants no lingering additional damage")

func _test_additional_damage_kill() -> void:
	var sim := fresh(); check(sim.buy("snowfield_club").is_empty() and sim.equip("snowfield_club").is_empty(),"Lethal fixture equips purchased club")
	var target: Dictionary = expedition(sim); var source: Dictionary = sim.hero()
	target.hp = int(source.power)+1
	var xp: int = sim.state.xp
	var stones: int = sim.state.loot_items.get("mana_stone_rank_9",0)
	seed_for(sim,true)
	check(sim.attack(source,target) and target.hp == 0 and target.dead,"Additional frost kills target surviving physical hit")
	check(sim.state.last_hit.kind == "cold", "Lethal component is frost")
	check(int(sim.state.xp) == xp+int(sim.monster_defs.canon_ghoul.xp) and int(sim.state.killed.canon_ghoul) == 1,"Nested frost death grants first-kill XP exactly once")
	check(int(sim.state.loot_items.get("mana_stone_rank_9",0)) == stones+1,"Nested frost death grants exactly one mana stone")
	sim.on_death(target,source)
	check(sim.hit(source,target,100,"physical","Attack",true,true) == 0,"Dead target rejects repeated weapon damage")
	check(int(sim.state.xp) == xp+int(sim.monster_defs.canon_ghoul.xp) and int(sim.state.killed.canon_ghoul) == 1 and int(sim.state.loot_items.get("mana_stone_rank_9",0)) == stones+1,"Repeated death notification remains idempotent")
