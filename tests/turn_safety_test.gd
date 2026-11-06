extends SceneTree
const Sim = preload("res://game/simulation.gd")
const World = preload("res://game/world.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func arena() -> GameSimulation:
	var sim := Sim.new(); sim.new_campaign("Turn safety","human","adventurer",74119)
	check(sim.enter_region(1),"Actual expedition entry")
	sim.state.units = []; sim.state.combat = true; sim.state.round = 1
	for y: int in range(1,int(sim.state.map.height)-1):
		for x: int in range(1,int(sim.state.map.width)-1): sim.state.map.tiles[y][x] = World.FLOOR
	sim.state.map.traps = []; sim.hero().pos = Vector2i(6,6); sim.hero().ap = 2
	return sim
func _init() -> void:
	for status: String in ["","paralyzed","stunned","suppressed"]:
		var sim := arena()
		var enemy: Dictionary = sim.spawn_enemy("canon_goblin",Vector2i(7,6))
		enemy.alert = true; enemy.accuracy = 1000; sim.hero().evasion = 0
		if not status.is_empty(): sim.status(sim.hero(),status,3)
		var hp: int = sim.hero().hp
		var armor: int = int(sim.hero().armor)+(4 if status.is_empty() else 0)
		var expected: int = sim.damage_amount(int(enemy.power),armor,sim.resistance(sim.hero(),"physical"),true)
		sim.rng.seed = 11210
		sim.end_phase()
		check(int(sim.hero().hp) == hp-expected,"Guard protects only a conscious acting character: %s (expected %d damage, received %d; enemy position %s)" % [status,expected,hp-int(sim.hero().hp),enemy.pos])
		check(not sim.hero().guard,"Guard expires after its enemy phase")
	# A melee skirmisher must not spend its limited AP retreating out of reach.
	var melee := arena()
	var goblin: Dictionary = melee.spawn_enemy("canon_goblin",Vector2i(7,6))
	goblin.alert = true; goblin.accuracy = 1000; melee.hero().evasion = 0
	var melee_origin: Vector2i = goblin.pos
	var melee_hp: int = melee.hero().hp
	melee.rng.seed = 11210
	melee.enemy_turn(goblin)
	check(goblin.pos == melee_origin and int(melee.hero().hp)<melee_hp,"Adjacent melee skirmisher holds its attack square and actually strikes")
	check(int(goblin.ap) == int(melee.stat_value(goblin,"action_points"))-int(melee.stat_value(goblin,"attack_ap_cost")),"Melee strike spends exactly its resolved AP cost")
	for expensive_move: bool in [false,true]:
		var ranged := arena()
		var archer: Dictionary = ranged.spawn_enemy("canon_goblin_archer",Vector2i(7,6))
		archer.alert = true; archer.accuracy = 1000; ranged.hero().evasion = 0
		if expensive_move:
			archer.modifiers = [{"id":"fixture:movement","source":"test_fixture","stat":"movement_cost","op":"add","value":1}]
		var archer_origin: Vector2i = archer.pos
		var ranged_hp: int = ranged.hero().hp
		ranged.rng.seed = 11210
		ranged.enemy_turn(archer)
		check(int(ranged.hero().hp)<ranged_hp,"Ranged foe reserves enough AP to attack after its retreat decision")
		check((archer.pos == archer_origin) == expensive_move,"Ranged foe retreats only when movement plus attack are affordable")
		var spent: int = int(ranged.stat_value(archer,"attack_ap_cost"))+(0 if expensive_move else int(ranged.stat_value(archer,"movement_cost")))
		check(int(archer.ap) == int(ranged.stat_value(archer,"action_points"))-spent,"Ranged retreat/attack honors the resolved AP budget")
	var moving := arena()
	var gnome: Dictionary = moving.spawn_enemy("canon_gnome",Vector2i(8,6))
	gnome.alert = true; gnome.last_seen = moving.hero().pos
	moving.status(gnome,"concealed",3)
	var origin: Vector2i = gnome.pos
	moving.enemy_turn(gnome)
	check(gnome.pos != origin and not gnome.statuses.has("concealed"),"Moving enemy Gnome loses stationary concealment")
	var still := arena()
	gnome = still.spawn_enemy("canon_gnome",Vector2i(7,6)); gnome.alert = true; gnome.last_seen = still.hero().pos
	still.status(gnome,"concealed",3); still.enemy_turn(gnome)
	check(gnome.pos == Vector2i(7,6) and gnome.statuses.has("concealed"),"Stationary Gnome is not stripped of its legitimate field")
	var active := arena()
	active.snapshot() # Stamp RNG metadata before measuring restore nonmutation.
	var before: String = var_to_str(active.state); var stream: int = active.rng.state
	for mode: String in ["city","dungeon"]:
		var malformed: Dictionary = active.snapshot(); malformed.mode = mode; malformed.hero.hp = 0; malformed.hero.dead = false
		check(not Validator.validate(malformed).is_empty() and not active.restore(malformed),"Zero-health active hero rejected instead of creating a softlock")
		check(var_to_str(active.state) == before and active.rng.state == stream,"Rejected life-state keeps campaign and RNG unchanged")
	var bad_dead: Dictionary = active.snapshot(); bad_dead.mode = "dead"
	check(not Validator.validate(bad_dead).is_empty(),"Death screen cannot contain a living hero")
	active.hit({"name":"Defeat fixture","accuracy":100,"statuses":{}},active.hero(),100000,"physical","Defeat",false,true)
	check(active.state.mode == "dead" and Validator.validate(active.snapshot()).is_empty(),"Actual lethal damage produces a valid saveable death transition")
	var field := arena()
	field.state.combat = false
	field.update_visibility()
	field.state.essence_drops = [{"id":"canon_goblin","pos":field.hero().pos,"region":1,"expires_at":int(field.state.time)+30}]
	field._recount_essence_drops()
	check(field.absorb("canon_goblin").is_empty(),"Repeated-use fixture absorbs a real field essence")
	for direction: Vector2i in World.DIRECTIONS:
		check(field.use_technique(0,field.hero().pos+direction),"Ability can be reused outside combat after its actual cooldown")
		check(int(field.hero().ap) >= 0 and Validator.validate(field.snapshot()).is_empty(),"Out-of-combat ability never creates negative AP or an unsaveable state")
		for wait: int in range(4): field.end_round()
	field.advance_time(field.portal_limit()-int(field.state.time))
	check(field.state.mode == "city" and Validator.validate(field.snapshot()).is_empty(),"Repeated field techniques still complete a saveable expedition")
	print("TURN SAFETY: %d checks, %d failures. Guard/incapacitation, stationary enemy field and life-state save invariants; assisted arenas." % [checks,failures])
	quit(1 if failures else 0)
