extends SceneTree
## Synthetic stat fixtures verify live consumers; they are not obtainable content.
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fresh() -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Stat expansion fixture","human","adventurer",74119)
	sim.state.gold = 100000
	return sim

func mod(id: String, stat: String, value: float) -> Dictionary:
	return {"id":id,"source":"test_fixture","stat":stat,"op":"add","value":value}

func battlefield(sim: GameSimulation) -> Dictionary:
	check(sim.enter_region(1),"Expansion fixture enters actual expedition")
	sim.state.units = []; sim.state.combat = true; sim.resolving_round = true
	var unit: Dictionary = sim.hero()
	for y: int in range(-6,7):
		for x: int in range(-6,7):
			var tile: Vector2i = unit.pos+Vector2i(x,y)
			if tile.x>0 and tile.y>0 and tile.y<sim.state.map.tiles.size()-1 and tile.x<sim.state.map.tiles[tile.y].size()-1: sim.state.map.tiles[tile.y][tile.x] = DungeonWorld.FLOOR
	sim.state.map.traps = []
	unit.base_stats = {"accuracy":1000}; sim.recalculate(unit,false); unit.ap = 20; unit.attacked = false
	var target: Dictionary = sim.spawn_enemy("canon_ghoul",unit.pos+Vector2i.RIGHT)
	target.hp = 1000; target.max_hp = 1000; target.armor = 0; target.evasion = 0; target.resist = {}; target.essences = []; target.statuses = {"stunned":99}
	sim.update_visibility()
	return target

func seed_hit(sim: GameSimulation) -> void:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,10000):
		probe.seed = candidate
		if probe.randi_range(1,100)<=20: sim.rng.seed = candidate; return

func _initialize() -> void:
	_test_typed_resistance_and_sensitivity()
	_test_cutting_and_weight()
	_test_criticals_and_secondary()
	_test_rng_save_replay()
	_test_status_and_raw_recovery()
	_test_anonymous_senses()
	_test_noise_save_validation()
	_test_fractional_resources()
	print("STAT EXPANSION: %d checks, %d failures. Synthetic fixtures verify combat, resources and evidence-based awareness; coefficients remain estimates." % [checks,failures])
	quit(1 if failures else 0)

func _test_typed_resistance_and_sensitivity() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	for kind: String in ["ground","solar","lightning"]:
		target.base_stats = {kind+"_resistance":100}; sim.recalculate(target,false)
		check(sim.stat_value(target,kind+"_resistance") == 100 and sim.resistance(target,kind) == 50,"Raw matching resistance remains a separate category: "+kind)
		check(sim.hit(unit,target,20,kind,"Elemental fixture",false,true) == 10,"Actual matching elemental damage is resisted: "+kind)
		var unrelated: String = "fire" if kind!="fire" else "cold"
		check(sim.hit(unit,target,20,unrelated,"Unrelated element fixture",false,true) == 20,"Matching resistance does not spill into another category: "+kind)
		target.base_stats[kind+"_resistance"] = -100
		check(sim.resistance(target,kind) == -50 and sim.hit(unit,target,20,kind,"Vulnerability fixture",false,true) == 30,"Negative raw elemental resistance increases matching damage: "+kind)
	target.base_stats = {}; target.resist = {}
	unit.modifiers = [mod("cold_power","cold_sensitivity",50)]; sim.recalculate(unit,false)
	check(sim.hit(unit,target,20,"cold","Cold sensitivity fixture",false,true) == 30,"Cold Sensitivity increases actual outgoing cold damage")
	check(sim.hit(unit,target,20,"fire","Unrelated sensitivity fixture",false,true) == 20,"Cold Sensitivity does not increase fire damage")
	var sources: Array = sim.stat_breakdown(unit).breakdown.cold_sensitivity.sources
	check(sources.any(func(row: Dictionary) -> bool: return row.id=="cold_power" and row.source=="test_fixture"),"Sensitivity source survives live stat breakdown")

func _test_cutting_and_weight() -> void:
	var sim := fresh()
	check(sim.buy("sword").is_empty() and sim.equip("sword").is_empty(),"Cutting fixture buys and equips an actual sword")
	var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.modifiers = [mod("cutting_fixture","cutting_force",50)]; sim.recalculate(unit,false)
	var base_power: int = unit.power; var hp: int = target.hp; seed_hit(sim)
	check(sim.attack(unit,target) and int(target.hp)==hp-floori(float(base_power)*1.5),"Cutting Force affects an actual slashing sword attack")
	check(sim.hit(unit,target,20,"cold","Cutting spell exclusion",false,true,-1,{"category":"spell"}) == 20,"Cutting Force does not amplify unrelated spell damage")
	sim.state.combat = false; sim.add_item("club",1)
	check(sim.equip("club").is_empty(),"Cutting fixture switches to actual blunt equipment")
	sim.state.combat = true; unit.ap = 20; unit.attacked = false
	hp = target.hp; base_power = unit.power; seed_hit(sim)
	check(sim.attack(unit,target) and int(target.hp)==hp-base_power,"Cutting Force grants no bonus to a blunt club")
	unit.modifiers = [mod("body_weight_fixture","weight",100)]; sim.recalculate(unit,false); unit.ap = 20; unit.attacked = false
	hp = target.hp; base_power = unit.power; seed_hit(sim)
	check(sim.attack(unit,target) and int(target.hp)==hp-floori(float(base_power)*1.5),"Body Weight modifies an actual blunt attack through its explicit estimated factor")
	sim.state.combat = false; sim.add_item("sword",1); check(sim.equip("sword").is_empty(),"Weight fixture can return to sword")
	sim.state.combat = true; unit.ap = 20; unit.attacked = false; hp = target.hp; base_power = unit.power; seed_hit(sim)
	check(sim.attack(unit,target) and int(target.hp)==hp-base_power,"Body Weight does not apply its blunt bonus to a sword")

func _test_criticals_and_secondary() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats["critical_chance"] = 100; unit.base_stats["critical_damage_multiplier"] = 2
	sim.recalculate(unit,false)
	check(sim.stat_breakdown(unit).errors.is_empty(),"Critical fixture resolves without source errors: "+str(sim.stat_breakdown(unit).errors))
	var power: int = unit.power; var hp: int = target.hp; seed_hit(sim)
	check(sim.attack(unit,target) and int(target.hp)==hp-power*2,"Actual normal weapon hit consumes guaranteed critical chance and factor (power=%s, crit=%s, factor=%s, damage=%s)" % [power,sim.stat_value(unit,"critical_chance"),sim.stat_value(unit,"critical_damage_multiplier"),hp-int(target.hp)])
	for context: Dictionary in [{"category":"spell"},{"category":"secondary","secondary":true},{"category":"weapon","dot":true}]:
		var rng_before: int = sim.rng.state
		check(sim.hit(unit,target,20,"physical","Excluded critical fixture",false,true,-1,context)==20,"Spell, secondary and DOT contexts do not receive critical damage: "+str(context))
		check(sim.rng.state==rng_before,"Excluded critical context consumes no critical RNG")
	var rng_before: int = sim.rng.state
	check(sim.hit(unit,target,20,"physical","Attack",false,true,7,{"category":"weapon"})==7 and sim.rng.state==rng_before,"Fixed damage bypasses critical damage and critical RNG")
	unit.base_stats["critical_chance"] = 0; sim.recalculate(unit,false); rng_before = sim.rng.state
	check(sim.hit(unit,target,20,"physical","Attack",false,true)==20 and sim.rng.state==rng_before,"Zero chance preserves baseline damage and RNG sequence")
	# The Numbered weapon adds a second cold component to a successful normal hit.
	var secondary_sim := fresh()
	check(secondary_sim.buy("snowfield_club").is_empty() and secondary_sim.equip("snowfield_club").is_empty(),"Secondary fixture equips actual Club of the Snowfield")
	var secondary_target: Dictionary = battlefield(secondary_sim); var attacker: Dictionary = secondary_sim.hero()
	attacker.base_stats["critical_chance"] = 100; attacker.base_stats["critical_damage_multiplier"] = 2
	secondary_sim.recalculate(attacker,false); hp = secondary_target.hp; power = attacker.power; seed_hit(secondary_sim)
	var probe := RandomNumberGenerator.new(); probe.state = secondary_sim.rng.state; probe.randi_range(1,100)
	check(secondary_sim.attack(attacker,secondary_target) and int(secondary_target.hp)==hp-power*2-5,"Weapon critical doubles only normal hit while additional frost remains a single uncritical proc (power=%s, damage=%s)" % [power,hp-int(secondary_target.hp)])
	check(secondary_sim.state.last_hit.kind=="cold" and int(secondary_sim.state.last_hit.amount)==5,"Actual secondary frost remains typed cold with its own magnitude")
	check(secondary_sim.rng.state==probe.state,"Guaranteed critical and guaranteed secondary proc add no hidden RNG draws")

func _test_rng_save_replay() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats["critical_chance"] = 37; unit.base_stats["critical_damage_multiplier"] = 2; sim.recalculate(unit,false)
	sim.rng.seed = 672111
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	var dealt: int = sim.hit(unit,target,20,"physical","Attack",false,true)
	var rng_after: int = sim.rng.state
	var restored := Sim.new()
	check(restored.restore(saved),"New critical stats and enemy state survive actual JSON restore")
	var restored_target: Dictionary = restored.state.units[0]
	var replayed: int = restored.hit(restored.hero(),restored_target,20,"physical","Attack",false,true)
	check(replayed==dealt and restored.rng.state==rng_after,"Saved RNG exactly replays the next nontrivial critical outcome (damage=%s/%s, RNG=%s/%s)" % [dealt,replayed,rng_after,restored.rng.state])

func _test_status_and_raw_recovery() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	unit.modifiers = [mod("adaptability_fixture","adaptability",100),mod("control_fixture","control",100),mod("luck_fixture","luck",100)]
	sim.recalculate(unit,false)
	sim.status(unit,"poison",8); sim.status(unit,"frightened",8); sim.status(unit,"ward",8)
	check(int(unit.statuses.poison)==4 and int(unit.statuses.frightened)==2,"Adaptability reduces harmful duration and Control additionally reduces Fear")
	check(int(unit.statuses.ward)==8,"Mental duration conversion leaves beneficial effects unchanged")
	check(is_equal_approx(sim.stat_value(unit,"critical_chance"),5.0),"Luck feeds the shared critical chance through the explicit point estimate")
	check(sim.stat_breakdown(unit).breakdown.critical_chance.sources.any(func(row: Dictionary) -> bool: return row.source=="derived:luck"),"Luck-derived critical chance exposes provenance")
	unit.statuses = {}; unit.modifiers = [mod("maximum_adaptability","adaptability",1000000)]; sim.recalculate(unit,false)
	sim.status(unit,"paralyzed",8)
	check(int(unit.statuses.paralyzed)==1,"High Adaptability shortens a harmful status without granting immunity")
	unit.statuses = {}; var base_soul: int = unit.max_energy
	unit.modifiers = [mod("raw_regeneration","natural_regeneration",100),mod("raw_soul","soul_power",10),mod("raw_soul_regeneration","soul_regeneration",100)]
	sim.recalculate(unit,false); unit.hp = 7; unit.energy = 1
	check(int(unit.max_energy)==base_soul+10,"Raw Soul Power increases the actual essence resource pool")
	sim.natural_recovery_tick(unit)
	check(unit.hp==9,"Raw Natural Regeneration increases actual natural healing")
	sim.tick_unit(unit)
	check(unit.energy==3,"Raw Soul Regeneration increases actual Soul Power recovery")

func _test_anonymous_senses() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats["sight"] = 1; unit.base_stats["hearing"] = 100; unit.base_stats["sixth_sense"] = 60
	sim.recalculate(unit,false); target.pos = unit.pos+Vector2i.RIGHT*3; target.statuses.concealed = 99; sim.update_visibility()
	check(sim.stat_breakdown(unit).errors.is_empty(),"Senses fixture resolves without source errors: "+str(sim.stat_breakdown(unit).errors))
	check(not sim.unit_visible(target),"Senses fixture target is actually hidden")
	check(sim.audible_contacts().is_empty(),"Hearing grants no knowledge of a silent hidden enemy")
	check(sim.danger_warning(),"Sixth Sense supplies an anonymous nearby danger warning")
	sim.record_noise(target)
	var heard_pos: Vector2i = target.pos
	var visible_before: String = var_to_str(sim.state.visible); var seen_before: String = var_to_str(sim.state.seen); var rng_before: int = sim.rng.state
	var contacts: Array = sim.audible_contacts()
	check(contacts.size()==1 and contacts[0]=={"pos":heard_pos,"kind":"sound"},"Hearing reports only a recent sound position and anonymous kind")
	check(var_to_str(sim.state.visible)==visible_before and var_to_str(sim.state.seen)==seen_before and sim.rng.state==rng_before,"Awareness queries reveal no fog cells and consume no RNG")
	target.pos = unit.pos+Vector2i.RIGHT*5
	contacts = sim.audible_contacts()
	check(contacts.size()==1 and contacts[0].pos==heard_pos,"Hearing does not follow unrecorded enemy movement or reveal its current identity/location")
	sim.advance_time(3)
	check(sim.audible_contacts().size()==1,"Recent sound remains available at the estimated inclusive three-minute boundary")
	sim.advance_time(1)
	check(sim.audible_contacts().is_empty(),"Recorded sound expires after the three-minute evidence window")
	unit.base_stats["hearing"] = 0; sim.recalculate(unit,false); sim.record_noise(target)
	check(sim.audible_contacts().is_empty(),"Zero Hearing cannot produce hidden sound contacts")
	unit.base_stats["hearing"] = 100; sim.recalculate(unit,false)
	target.pos = unit.pos+Vector2i.RIGHT*3; sim.record_noise(target)
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var tile: Vector2i = target.pos+direction; sim.state.map.tiles[tile.y][tile.x] = DungeonWorld.WALL
	check(sim.audible_contacts().is_empty() and not sim.danger_warning(),"Disconnected stone blocks the estimated sound and nearby-danger propagation")
	unit.hp = 0
	check(sim.audible_contacts().is_empty() and not sim.danger_warning(),"A fallen observer receives no awareness reports")

func _test_noise_save_validation() -> void:
	var sim := fresh(); var target: Dictionary = battlefield(sim); var unit: Dictionary = sim.hero()
	unit.base_stats["sight"] = 1; unit.base_stats["hearing"] = 100; sim.recalculate(unit,false)
	target.pos = unit.pos+Vector2i.RIGHT*3; target.statuses.concealed = 99; sim.update_visibility(); sim.record_noise(target)
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Actual sound evidence and Hearing survive validated JSON save/restore")
	check(restored.audible_contacts()==sim.audible_contacts(),"Restored auditory report uses the same recorded evidence")
	for noise: Variant in [null,[],{}, {"pos":Vector2i(-5,2),"time":0},{"pos":target.pos,"time":-1},{"pos":target.pos,"time":"0"},{"pos":target.pos,"time":INF}]:
		var raw: Dictionary = sim.snapshot(); raw.units[0].last_noise = noise
		var before: String = var_to_str(restored.state); var rng_before: int = restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Invalid sound record rejects before state assignment")
		check(var_to_str(restored.state)==before and restored.rng.state==rng_before,"Invalid sound restore preserves campaign and RNG")

func _test_fractional_resources() -> void:
	var sim := fresh(); var unit: Dictionary = sim.hero()
	unit.profession = "mage"; unit.can_absorb_essences = false; unit.spells = ["ice_spear"]
	unit.base_stats = {"soul_recovery":0.25,"mana_recovery":0.25}
	sim.recalculate(unit,false); unit.energy = 0; unit.mana = 0
	var stream: int = sim.rng.state
	for tick: int in range(3): sim.recover_resource(unit,"soul"); sim.recover_resource(unit,"mana")
	check(unit.energy==0 and unit.mana==0 and is_equal_approx(float(unit.soul_recovery_remainder),0.75) and is_equal_approx(float(unit.mana_recovery_remainder),0.75),"Subunit resource recovery accumulates without rounding into free resources")
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Fractional SP and mana recovery survive actual JSON restore")
	for resource: String in ["soul","mana"]:
		sim.recover_resource(unit,resource); restored.recover_resource(restored.hero(),resource)
	check(unit.energy==1 and unit.mana==1 and restored.hero().energy==1 and restored.hero().mana==1,"Fourth fractional tick restores one resource, identically across reload")
	check(sim.rng.state==stream,"Fractional recovery never consumes combat RNG")
	unit.energy = unit.max_energy; unit.soul_recovery_remainder = 0.75; sim.recover_resource(unit,"soul")
	check(not unit.has("soul_recovery_remainder"),"Full pools discard fraction to prevent banking future recovery")
	unit.energy-=1; sim.recover_resource(unit,"soul")
	check(unit.energy==unit.max_energy-1 and is_equal_approx(float(unit.soul_recovery_remainder),0.25),"Spending from full starts a fresh fractional recovery interval")
	for key: String in ["soul_recovery_remainder","mana_recovery_remainder"]:
		for bad: Variant in [-0.1,1,NAN,INF,null,"0.5"]:
			var raw: Dictionary = sim.snapshot(); raw.hero[key] = bad
			var before: String = var_to_str(restored.state); var saved_rng: int = restored.rng.state
			check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed resource recovery fraction rejects: "+key)
			check(var_to_str(restored.state)==before and restored.rng.state==saved_rng,"Rejected recovery fraction preserves state and RNG")
