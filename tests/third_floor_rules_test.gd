extends SceneTree
## Isolated environmental fixtures verify rules independently of campaign integration.
const Rules = preload("res://game/third_floor_rules.gd")
var checks: int = 0
var failures: int = 0

class FixtureSim extends RefCounted:
	var state: Dictionary = {}
	var stat_cache: Dictionary = {"stale": true}
	var monster_defs: Dictionary = {"canon_carnivaro": {}}
	var messages: Array[String] = []
	func _init(kind: String = "witch_forest") -> void:
		var tiles: Array = []
		for y: int in range(24):
			var row: Array = []
			for x: int in range(24): row.append(1 if x==0 or y==0 or x==23 or y==23 else 0)
			tiles.append(row)
		state = {"mode":"dungeon", "region":8, "time":0, "combat":false, "hero":unit("hero",Vector2i(12,12)), "party":[], "units":[], "terrain":kind, "serial":0, "map":{"width":24,"height":24,"tiles":tiles,"entrance":Vector2i(2,2),"exit":Vector2i(21,21),"hut_sites":[Vector2i(5,5),Vector2i(18,18)],"shelter_mounds":[Vector2i(8,8)],"area_portals":[]}}
	func unit(id: String, pos: Vector2i, team: String = "ally") -> Dictionary:
		return {"id":id,"pos":pos,"hp":30,"team":team,"statuses":{},"status_power":{},"summon":false}
	func hero() -> Dictionary: return state.hero
	func allies() -> Array: return [hero()]+state.party
	func enemies() -> Array: return state.units.filter(func(u: Dictionary)->bool:return int(u.hp)>0)
	func region_data() -> Dictionary: return {"terrain":state.terrain,"name":"Fixture"}
	func unit_at(pos: Vector2i) -> Dictionary:
		for actor: Dictionary in allies()+enemies():
			if actor.hp>0 and actor.pos==pos: return actor
		return {}
	func spawn_enemy(id: String, pos: Vector2i, summoned: bool = false) -> Dictionary:
		state.serial+=1
		var actor: Dictionary = unit("enemy%d" % state.serial,pos,"enemy")
		actor["content_id"]=id; actor.summon=summoned; state.units.append(actor)
		return actor
	func say(message: String) -> void: messages.append(message)
	func clock(amount: int) -> void:
		var target: int = int(state.time)+amount
		var guard: int = 0
		while int(state.time)<target and guard<1000:
			var next: int = mini(target,Rules.next_deadline(self))
			var elapsed: int = next-int(state.time)
			state.time=next; Rules.advance(self,elapsed); guard+=1

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)

func _initialize() -> void:
	_fields(); _tides(); _eye(); _hut(); _determinism_and_blocked()
	print("THIRD FLOOR RULES: %d checks, %d failures. Pure fixture coverage; campaign/AI/UI integration is tested separately." % [checks,failures])
	quit(1 if failures else 0)

func _fields() -> void:
	var sim := FixtureSim.new()
	sim.hero().statuses={"poison":3,"ward":9,"transformed":4,"status_immunity":5,"stealth":3}
	sim.hero().status_power={"poison":7,"orphaned":12}
	var enemy: Dictionary=sim.spawn_enemy("canon_carnivaro",Vector2i(15,12))
	enemy.statuses={"burning":4,"ward":2}; enemy.status_power={"burning":9}
	Rules.apply_environment(sim)
	check(Rules.field_active(sim),"Witch field is active outside refuge")
	for actor: Dictionary in [sim.hero(),enemy]:
		check(actor.statuses.size()==3,"All ally and enemy non-field statuses are cleansed")
		check(actor.status_power.is_empty(),"Non-field potency entries, including orphaned entries, are removed")
		for id: String in Rules.FIELD_STATUSES:
			check(actor.statuses.get(id,0)==Rules.FIELD_DURATION,"Field status persists: "+id)
	check(sim.stat_cache.is_empty(),"Changing environmental statuses invalidates cached stats")
	for id: String in ["burning","ward","toppled","poison","concealed","status_immunity"]:
		check(Rules.blocks_status(sim,sim.hero(),id),"Field rejects non-field effect: "+id)
	for id: String in Rules.FIELD_STATUSES: check(not Rules.blocks_status(sim,enemy,id),"Field statuses are allowed")
	sim.state.terrain="ironrock_hills"; Rules.apply_environment(sim)
	for actor: Dictionary in [sim.hero(),enemy]: check(actor.statuses.is_empty(),"Leaving Witch forest removes environmental statuses")
	check(not Rules.blocks_status(sim,sim.hero(),"poison"),"Ordinary effects work after leaving Witch forest")
	sim.state.mode="city"; sim.state.terrain="witch_forest"
	check(not Rules.field_active(sim),"City cannot inherit a dungeon field")

func _tides() -> void:
	var sim := FixtureSim.new("dark_estuary")
	for minute: int in [0,1,359,1380,1439,1440]:
		sim.state.time=minute
		check(Rules.high_tide(sim),"High/rising tide recognized at minute "+str(minute))
		check(not Rules.can_camp(sim).is_empty(),"Wet estuary camp rejected during tide")
	for minute: int in [360,800,1379]:
		sim.state.time=minute
		check(not Rules.high_tide(sim) and Rules.can_camp(sim).is_empty(),"Ordinary estuary camp allowed outside tide")
	sim.state.time=0; sim.hero().pos=Vector2i(8,8)
	check(Rules.can_camp(sim).is_empty(),"Dry red mound is a tide refuge")
	var companion: Dictionary=sim.unit("companion",Vector2i(12,12)); sim.state.party.append(companion)
	check(not Rules.can_camp(sim).is_empty(),"Entire living party must gather on refuge")
	companion.pos=Vector2i(9,8)
	check(Rules.can_camp(sim).is_empty(),"Cardinal adjacent dry mound space admits companion")
	companion.pos=Vector2i(12,12); companion.summon=true
	check(Rules.can_camp(sim).is_empty(),"Summons do not consume refuge party capacity")
	sim.state.map.tiles[8][8]=DungeonWorld.WATER
	check(not Rules.can_camp(sim).is_empty(),"Water tile cannot pretend to be a dry refuge")
	sim.state.mode="city"
	check(not Rules.can_camp(sim).is_empty(),"Camping requires an expedition")

func _eye() -> void:
	var sim := FixtureSim.new()
	Rules.apply_environment(sim)
	check(not Rules.can_camp(sim).is_empty(),"Witch forest blocks ordinary eight-hour camp")
	check(Rules.next_deadline(sim)==60,"First-day stationary Eye deadline is60minutes")
	sim.clock(59)
	check(sim.enemies().is_empty(),"No early Eye encounter")
	sim.clock(1)
	check(sim.enemies().size()==1,"Threshold creates one ordinary Cannibalo")
	var enemy: Dictionary=sim.enemies()[0]
	var span: int=absi(enemy.pos.x-sim.hero().pos.x)+absi(enemy.pos.y-sim.hero().pos.y)
	check(span>=3 and span<=6,"Eye encounter appears within bounded visible ring")
	check(enemy.get("witch_eye",false) and not enemy.summon,"Eye pursuer is marked and not a summoned XP loophole")
	check(enemy.alert and enemy.last_seen==sim.hero().pos and sim.state.combat,"Eye pursuer knows the lingering position and initiates combat")
	check(DungeonWorld.line_of_sight(sim.state.map,sim.hero().pos,enemy.pos),"Eye encounter respects line of sight")
	sim.clock(300)
	check(sim.enemies().size()==1,"Existing living Eye pursuer prevents duplicate spawning during a large wait")
	sim.hero().pos+=Vector2i.RIGHT
	check(Rules.next_deadline(sim)>int(sim.state.time),"Movement resets stationary counter without a zero deadline")
	check(int(sim.state.map.witch_eye_stationary_minutes)==0,"Movement clears lingering position time")
	enemy.hp=0; sim.state.combat=false
	check(Rules.next_deadline(sim)==int(sim.state.time)+60,"New stationary interval follows movement and defeated pursuer")
	sim.clock(60)
	check(sim.enemies().size()==1 and sim.state.units.size()==2,"Defeated Eye pursuer can be replaced after a new stationary interval")
	var late := FixtureSim.new()
	Rules.apply_environment(late); late.state.map.witch_eye_exposure_minutes=Rules.EYE_LATE_EXPOSURE
	check(Rules.next_deadline(late)==10,"At84hours the documented short interval is10minutes")
	late.clock(9); check(late.enemies().is_empty(),"No early late-stage pursuit")
	late.clock(1); check(late.enemies().size()==1,"Late-stage pursuit occurs at10minutes")
	var edge := FixtureSim.new()
	Rules.apply_environment(edge); edge.state.map.witch_eye_exposure_minutes=Rules.EYE_LATE_EXPOSURE-1
	check(Rules.next_deadline(edge)==1,"Chronology stops at the84hour escalation boundary")
	edge.clock(10)
	check(edge.enemies().size()==1,"Large clock advance cannot skip escalation deadline")

func _hut() -> void:
	var sim := FixtureSim.new()
	Rules.apply_environment(sim)
	check(Rules.active_hut_site(sim)==Vector2i(5,5),"First estimated site window is deterministic")
	var before: String=var_to_str(sim.state)
	check(not Rules.interact_hut(sim).is_empty(),"Remote refuge entry rejected")
	check(before==var_to_str(sim.state),"Remote entry has no side effects")
	sim.hero().pos=Vector2i(5,5); sim.state.time=120
	sim.state.combat=true
	check(not Rules.interact_hut(sim).is_empty(),"Refuge cannot bypass an active combat")
	sim.state.combat=false
	for index: int in range(5): sim.state.party.append(sim.unit("party%d" % index,Vector2i(5+index,6)))
	check(not Rules.interact_hut(sim).is_empty(),"Six living explorers exceed cabin capacity")
	sim.state.party[-1].summon=true
	check(Rules.interact_hut(sim).is_empty(),"Five explorers and a summon can use refuge")
	check(Rules.in_refuge(sim) and not Rules.field_active(sim),"Refuge suppresses Witch field")
	check(sim.state.hut_until==480,"Late entry receives remaining window rather than resetting eight hours")
	check(Rules.next_deadline(sim)==480,"Refuge expiry is a chronological deadline")
	check(Rules.can_camp(sim).is_empty(),"Cabin permits camp recovery")
	for actor: Dictionary in sim.allies(): check(actor.statuses.is_empty(),"Field statuses are absent inside refuge")
	check(not Rules.blocks_status(sim,sim.hero(),"ward"),"Ordinary statuses may exist inside refuge")
	sim.hero().statuses["ward"]=3
	sim.clock(120); Rules.interact_hut(sim)
	check(sim.state.hut_until==480,"Touching refuge again cannot refresh its deadline")
	sim.clock(239)
	check(Rules.in_refuge(sim) and sim.enemies().is_empty(),"Refuge remains protected until exact deadline")
	sim.clock(1)
	check(not Rules.in_refuge(sim) and Rules.field_active(sim),"Deadline ejects party and reapplies forest")
	check(sim.hero().statuses.size()==3 and not sim.hero().statuses.has("ward"),"Ejection cleanses non-field effects")
	check(Rules.active_hut_site(sim)==Vector2i(18,18),"Estimated placement changes to next site window")
	check(sim.enemies().is_empty(),"Resting in refuge does not count toward stationary pursuit")
	sim.clock(60)
	check(sim.enemies().size()==1,"Outside refuge Eye resumes after a full interval")

func _determinism_and_blocked() -> void:
	var first := FixtureSim.new(); var second := FixtureSim.new()
	Rules.apply_environment(first); Rules.apply_environment(second)
	first.clock(480); second.clock(480)
	check(var_to_str(first.state)==var_to_str(second.state),"Identical fixed clock and commands produce identical state")
	check(first.enemies().size()==1,"Long stationary advance cannot create a horde in one call")
	var blocked := FixtureSim.new()
	for y: int in range(1,23):
		for x: int in range(1,23): blocked.state.map.tiles[y][x]=DungeonWorld.WALL
	blocked.state.map.tiles[12][12]=DungeonWorld.FLOOR
	Rules.apply_environment(blocked); blocked.clock(61)
	check(blocked.enemies().is_empty(),"No illegal spawn in a sealed room")
	check(Rules.next_deadline(blocked)>int(blocked.state.time),"Failed placement never returns a recursive or zero deadline")
	blocked.state.terrain="orc_colony"; Rules.advance(blocked,100)
	check(blocked.enemies().is_empty(),"Non-Witch regions cannot inherit Eye pursuit")
