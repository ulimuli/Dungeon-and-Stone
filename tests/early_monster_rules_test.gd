extends SceneTree
## Pure command fixtures protect atomic placement, ownership, deterministic
## interaction and effect conditions. Actual simulation integration is separate.
const Rules=preload("res://game/early_monster_rules.gd")
const Content=preload("res://game/early_floor_content.gd")
const Base=preload("res://game/content_reference.gd")
var checks: int=0
var failures: int=0
class Fixture extends RefCounted:
	var state: Dictionary={"mode":"dungeon","combat":true,"units":[],"log":[],"gold":100,"time":0}
	var hero: Dictionary={}
	var monster_defs: Dictionary=Base.monsters()
	var rng:=RandomNumberGenerator.new()
	var recalculations: Array=[]
	var invisible: Dictionary={}
	func _init() -> void:
		rng.seed=81331; monster_defs.merge(Content.monsters())
		var tiles: Array=[]
		for y: int in range(24):
			var row: Array=[]
			for x: int in range(24): row.append(DungeonWorld.WALL if x==0 or y==0 or x==23 or y==23 else DungeonWorld.FLOOR)
			tiles.append(row)
		state.map={"width":24,"height":24,"tiles":tiles}
		hero=unit("hero","ally",Vector2i(8,8)); hero.essences=[Rules.FIEND]; hero.hp=12; hero.max_hp=30
	func unit(id: String,team: String,pos: Vector2i) -> Dictionary:
		return {"id":id,"name":id,"team":team,"pos":pos,"hp":20,"max_hp":20,"dead":false,"summon":false,"statuses":{},"status_power":{},"cooldowns":{},"essences":[],"spells":[],"str":4,"agi":4,"wit":4,"vig":4,"base_stats":{},"ap":3,"attacked":false,"energy":20,"max_energy":20,"mana":0,"max_mana":0,"content_id":"canon_ghoul","behavior":"manual","alert":true,"intent":{},"last_seen":Vector2i(8,8)}
	func allies() -> Array:
		var result: Array=[hero]
		for actor: Dictionary in state.units:
			if actor.team=="ally" and actor.hp>0: result.append(actor)
		return result
	func enemies() -> Array: return state.units.filter(func(actor: Dictionary)->bool:return actor.team=="enemy" and actor.hp>0)
	func unit_by_id(id: String) -> Dictionary:
		for actor: Dictionary in [hero]+state.units:
			if actor.id==id: return actor
		return {}
	func unit_at(pos: Vector2i) -> Dictionary:
		for actor: Dictionary in [hero]+state.units:
			if actor.hp>0 and actor.pos==pos: return actor
		return {}
	func selected() -> Dictionary: return hero
	func active_essences(actor: Dictionary) -> Array:
		return [] if actor.get("sealed",false) else actor.get("essences",[])
	func unable_to_act(actor: Dictionary) -> bool:
		for id: String in ["stunned","paralyzed","suppressed","toppled"]:
			if actor.get("statuses",{}).has(id): return true
		return false
	func stat_value(actor: Dictionary,id: String) -> float:
		return actor.get("test_stats",{}).get(id,actor.get("base_stats",{}).get(id,{"sight":12,"strength":10,"natural_recovery":3,"healing_received_multiplier":1}.get(id,1)))
	func heal(actor: Dictionary,amount: int) -> void:
		actor.hp=mini(actor.max_hp,actor.hp+ceili(amount*stat_value(actor,"healing_received_multiplier")))
	func say(message: String) -> void: state.log.append(message)
	func visible(pos: Vector2i) -> bool: return not invisible.has(pos) and DungeonWorld.walkable(state.map,pos)
	func unit_visible(actor: Dictionary) -> bool: return visible(actor.pos)
	func status(actor: Dictionary,id: String,duration: int) -> void: actor.statuses[id]=duration
	func ability_cooldown(_actor: Dictionary,base: int) -> int: return base
	func recalculate(actor: Dictionary,refill: bool=false) -> void:
		recalculations.append({"id":actor.id,"refill":refill})
		actor.max_hp=actor.base_stats.get("max_health",actor.max_hp); actor.power=actor.base_stats.get("attack",0); actor.armor=actor.base_stats.get("armor",0)
		if refill: actor.hp=actor.max_hp
	func spawn_enemy(id: String,pos: Vector2i,summoned: bool=false) -> Dictionary:
		var actor: Dictionary=unit("enemy_%d" % state.units.size(),"enemy",pos)
		actor.content_id=id; actor.summon=summoned; actor.base_stats={"action_points":2}
		actor.hp=monster_defs[id].hp; actor.max_hp=actor.hp
		state.units.append(actor); return actor
	func fiend(pos: Vector2i=Vector2i(11,8)) -> Dictionary:
		var actor: Dictionary=spawn_enemy(Rules.FIEND,pos); actor.spawn_origin=pos; return actor
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func ability() -> Dictionary: return Content.essences()[Rules.FIEND].ability.duplicate(true)
func reject_call(sim: Fixture,actor: Dictionary,row: Dictionary,center: Vector2i,label: String) -> void:
	var before: String=var_to_str([sim.state,sim.hero,sim.rng.state,sim.recalculations])
	check(not Rules.can_call(sim,actor,row,center).is_empty(),label+" preflight rejects")
	check(not Rules.call_dead(sim,actor,row,center).is_empty(),label+" command rejects")
	check(var_to_str([sim.state,sim.hero,sim.rng.state,sim.recalculations])==before,label+" failure is atomic and deterministic")
func reject_topple(sim: Fixture,id: String,label: String) -> void:
	var before: String=var_to_str([sim.state,sim.hero,sim.rng.state])
	check(not Rules.topple(sim,id).is_empty(),label+" rejects")
	check(var_to_str([sim.state,sim.hero,sim.rng.state])==before,label+" preserves AP/attack/status/resources/RNG")
func _initialize() -> void:
	_test_placement_and_owned_summons()
	_test_regeneration()
	_test_telegraph_and_territory()
	_test_topple_and_assistance()
	print("EARLY MONSTER RULES: %d checks, %d failures. Atomic ten-Ghoul placement, owner cap, sealed/shared-stat healing, deterministic toppling and source-aware telegraphs/territory. Pure fixtures; actual Sim integration separate." % [checks,failures])
	quit(1 if failures else 0)
func _test_placement_and_owned_summons() -> void:
	var sim:=Fixture.new(); var row: Dictionary=ability(); var center: Vector2i=sim.hero.pos
	var before: String=var_to_str([sim.state,sim.hero,sim.rng.state]); var cells: Array[Vector2i]=Rules.summon_cells(sim,sim.hero,center,4,10)
	check(cells.size()==10 and cells==Rules.summon_cells(sim,sim.hero,center,4,10),"Preflight finds exactly ten deterministic squares")
	var unique: Dictionary={}
	for point: Vector2i in cells:
		check(not unique.has(point) and sim.unit_at(point).is_empty() and absi(point.x-center.x)+absi(point.y-center.y)<=4,"Each spawn is unique/free/in-radius")
		unique[point]=true
	check(var_to_str([sim.state,sim.hero,sim.rng.state])==before,"Placement preflight consumes no RNG or campaign data")
	check(Rules.can_call(sim,sim.hero,row,center).is_empty() and Rules.call_dead(sim,sim.hero,row,center).is_empty(),"Valid actual ten-creature command succeeds")
	check(sim.state.units.size()==10 and sim.recalculations.size()==10,"Ten friendly summons each pass the normal stat projection")
	var ids: Dictionary={}
	for actor: Dictionary in sim.state.units:
		check(actor.summon and actor.team=="ally" and actor.summoner=="hero" and actor.content_id=="canon_ghoul","Summoned faction and owner are explicit, not party recruits")
		check(actor.summon_expires_at==sim.state.time+24,"Temporary Ghouls also carry an absolute minute deadline")
		check(actor.lifetime==12 and actor.ap==0 and actor.attacked and actor.behavior=="aggressive","Summons have finite lifetime and no free immediate attack")
		check(actor.max_hp==sim.monster_defs.canon_ghoul.hp and actor.power==sim.monster_defs.canon_ghoul.power and actor.base_stats.carry_capacity==0 and actor.max_energy==0,"Friendly summon stats match monster rather than adventurer baselines")
		check(actor.essences.is_empty() and actor.spells.is_empty() and not ids.has(actor.id),"Summons cannot recursively inherit essence skills and have unique IDs"); ids[actor.id]=true
	check(sim.hero.energy==20 and sim.hero.ap==3 and sim.state.time==0,"Helper leaves cost/AP/clock/cooldown ownership to the technique command")
	reject_call(sim,sim.hero,row,center,"Existing owner cap")
	for actor: Dictionary in sim.state.units: actor.hp=0; actor.dead=true
	check(Rules.can_call(sim,sim.hero,row,center).is_empty(),"Expired/dead summons release ownership slots")
	var sealed:=Fixture.new(); sealed.hero.sealed=true; reject_call(sealed,sealed.hero,row,center,"Sealed essence")
	var recursive:=Fixture.new(); recursive.hero.summon=true; reject_call(recursive,recursive.hero,row,center,"Recursive summon caster")
	var incapacitated:=Fixture.new(); incapacitated.hero.statuses.stunned=2; reject_call(incapacitated,incapacitated.hero,row,center,"Incapacitated caster")
	var unknown:=Fixture.new(); var wrong: Dictionary=row.duplicate(true); wrong.summon_id="canon_goblin"; reject_call(unknown,unknown.hero,wrong,center,"Unsupported summoned species")
	var partial:=Fixture.new(); wrong=row.duplicate(true); wrong.summon_count=9; reject_call(partial,partial.hero,wrong,center,"Partial summon count")
	var hidden:=Fixture.new(); hidden.invisible[center]=true; reject_call(hidden,hidden.hero,row,center,"Unseen cast center")
	var far:=Fixture.new(); reject_call(far,far.hero,row,Vector2i(20,20),"Out-of-range center")
	var crowded:=Fixture.new()
	for point: Vector2i in Rules.summon_cells(crowded,crowded.hero,center,4,10): crowded.spawn_enemy("canon_ghoul",point)
	for y: int in range(4,13):
		for x: int in range(4,13):
			if Vector2i(x,y)!=center: crowded.state.map.tiles[y][x]=DungeonWorld.WALL
	reject_call(crowded,crowded.hero,row,center,"Insufficient connected free space")
	var native:=Fixture.new(); var fiend: Dictionary=native.fiend()
	var native_row: Dictionary={"summon_id":"canon_ghoul","summon_count":10,"summon_duration":12,"radius":3,"range":0}
	check(Rules.call_dead(native,fiend,native_row,fiend.pos).is_empty(),"Native fiend can summon independently of player essence ownership")
	check(native.state.units.filter(func(actor: Dictionary)->bool:return actor.get("summon",false) and actor.team=="enemy" and actor.summoner==fiend.id).size()==10,"Native summons remain opposing Ghouls with owner history")
func _test_regeneration() -> void:
	var sim:=Fixture.new(); var resources: Array=[sim.hero.energy,sim.hero.ap,sim.state.gold,sim.rng.state]
	Rules.tick(sim,sim.hero); check(sim.hero.hp==15,"Player combat regeneration consumes resolved natural_recovery3")
	check([sim.hero.energy,sim.hero.ap,sim.state.gold,sim.rng.state]==resources,"Passive recovery spends no SP/AP/currency/RNG")
	sim.hero.test_stats={"natural_recovery":5.1,"healing_received_multiplier":2.0}; Rules.tick(sim,sim.hero)
	check(sim.hero.hp==27,"Fractional shared skill strength rounds up then normal healing-received applies")
	sim.hero.sealed=true; Rules.tick(sim,sim.hero); check(sim.hero.hp==27,"Sealing disables passive combat healing")
	sim.hero.sealed=false; sim.state.combat=false; Rules.tick(sim,sim.hero); check(sim.hero.hp==27,"Outside combat uses existing natural recovery cadence, not extra per-round healing")
	sim.state.combat=true; sim.hero.hp=0; Rules.tick(sim,sim.hero); check(sim.hero.hp==0,"Passive never resurrects lethal injury")
	var enhanced:=Fixture.new(); enhanced.hero.test_stats={"natural_recovery":3,"skill_power_multiplier":1.3}; Rules.tick(enhanced,enhanced.hero)
	check(enhanced.hero.hp==16,"Volcano skill power scales the new passive through the two shared resolved stats")
	var enemy: Dictionary=sim.fiend(); enemy.hp=1; enemy.max_hp=72; Rules.tick(sim,enemy); check(enemy.hp==9,"Monster has its separately estimated eight-point rapid recovery")
	enemy.hp=70; Rules.tick(sim,enemy); check(enemy.hp==72,"Monster healing caps at maximum")
	enemy.hp=0; Rules.tick(sim,enemy); check(enemy.hp==0,"Native recovery also cannot resurrect")
func _test_telegraph_and_territory() -> void:
	var sim:=Fixture.new(); var enemy: Dictionary=sim.fiend()
	check(Rules.enemy_action(sim,enemy,sim.hero) and enemy.intent.kind=="call_dead" and sim.state.units.size()==1,"Unprepared fiend telegraphs one action before spawning")
	check(enemy.ap==0,"Telegraph spends the monster action")
	enemy.ap=3
	check(Rules.enemy_action(sim,enemy,sim.hero) and sim.state.units.size()==11 and enemy.cooldowns.get(Rules.FIEND,0)==7,"Next action performs the ten-creature call and starts cooldown")
	enemy.intent={}; Rules.plan_intent(sim,enemy); check(enemy.intent.is_empty(),"Cooldown/cap prevent a second telegraph")
	var planned:=Fixture.new(); enemy=planned.fiend(); Rules.plan_intent(planned,enemy)
	check(enemy.intent.get("kind","")=="call_dead" and planned.state.units.size()==1,"Planning only warns, never grants units")
	var unseen:=Fixture.new(); enemy=unseen.fiend(); unseen.hero.statuses.stealth=2
	Rules.plan_intent(unseen,enemy); check(enemy.intent.is_empty(),"Concealed distant targets do not give omniscient summon intent")
	check(not Rules.enemy_action(unseen,enemy,unseen.hero) and unseen.state.units.size()==1,"An unknown target cannot cause a hidden summon")
	var border:=Fixture.new(); enemy=border.fiend(); border.hero.pos=Vector2i(22,8)
	check(Rules.enemy_action(border,enemy,border.hero) and not enemy.alert and enemy.ap==0 and enemy.intent.is_empty(),"Fiend abandons pursuit beyond source-inspired territorial boundary")
	var stunned:=Fixture.new(); enemy=stunned.fiend(); enemy.statuses.stunned=2
	Rules.plan_intent(stunned,enemy); check(enemy.intent.is_empty() and not Rules.enemy_action(stunned,enemy,stunned.hero),"Incapacitated fiend neither plans nor calls")
func _test_topple_and_assistance() -> void:
	var sim:=Fixture.new(); var enemy: Dictionary=sim.fiend(Vector2i(9,8)); enemy.intent={"kind":"call_dead"}
	var random_before: int=sim.rng.state
	check(Rules.topple(sim,enemy.id).is_empty(),"Adjacent sufficiently strong party member can make deterministic takedown")
	check(sim.hero.ap==1 and sim.hero.attacked and enemy.statuses.get("toppled",0)==Rules.TOPPLE_DURATION and enemy.ap==0 and enemy.intent.is_empty(),"Topple consumes attack/twoAP and interrupts fiend's pending cast")
	check(sim.rng.state==random_before and sim.state.time==0,"Helper takedown has no hit RNG or hidden clock ownership")
	reject_topple(sim,enemy.id,"Repeated toppling")
	var helper: Dictionary=sim.spawn_enemy("canon_ghoul",Vector2i(9,9))
	check(Rules.enemy_action(sim,helper,sim.hero) and helper.ap==0 and helper.attacked and not enemy.statuses.has("toppled"),"An adjacent free opposing creature can spend its whole action helping the fiend stand")
	var weak:=Fixture.new(); enemy=weak.fiend(Vector2i(9,8)); weak.hero.test_stats={"strength":7}; reject_topple(weak,enemy.id,"Insufficient Strength")
	var spent:=Fixture.new(); enemy=spent.fiend(Vector2i(9,8)); spent.hero.attacked=true; reject_topple(spent,enemy.id,"Used attack")
	var no_ap:=Fixture.new(); enemy=no_ap.fiend(Vector2i(9,8)); no_ap.hero.ap=1; reject_topple(no_ap,enemy.id,"Insufficient AP")
	var distant:=Fixture.new(); enemy=distant.fiend(Vector2i(10,8)); reject_topple(distant,enemy.id,"Distant target")
	var hidden:=Fixture.new(); enemy=hidden.fiend(Vector2i(9,8)); hidden.invisible[enemy.pos]=true; reject_topple(hidden,enemy.id,"Invisible target")
	var other:=Fixture.new(); enemy=other.spawn_enemy("canon_ghoul",Vector2i(9,8)); reject_topple(other,enemy.id,"Unsupported creature")
	var dead:=Fixture.new(); enemy=dead.fiend(Vector2i(9,8)); enemy.hp=0; reject_topple(dead,enemy.id,"Lethal target")
	var recursive:=Fixture.new(); enemy=recursive.fiend(Vector2i(9,8)); recursive.hero.summon=true; reject_topple(recursive,enemy.id,"Summoned takedown actor")
