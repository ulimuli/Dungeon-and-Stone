class_name EarlyMonsterRules
extends RefCounted
## Chapter23–24: Death Fiend regeneration, ten-Ghoul call, slow territorial
## pursuit and inability to rise after a takedown. Grid/AP/cooldown/lifetime,
## player summon resource values, strength threshold and assistance are estimates.
## Resource/cooldown/time payment belongs to Simulation's technique command.
const Content=preload("res://game/early_floor_content.gd")
const World=preload("res://game/world.gd")
const FIEND: String="canon_death_fiend"
const OWNER_CAP: int=10
const TOPPLE_STRENGTH: int=8
const TOPPLE_AP: int=2
const TOPPLE_DURATION: int=1000000
const ENEMY_SUMMON_LIFETIME: int=12
const DIRS: Array[Vector2i]=[Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]

static func tick(sim: RefCounted, unit: Dictionary) -> void:
	if sim.state.get("mode","")!="dungeon" or not _living(unit): return
	var amount: int=0
	if _native_fiend(unit):
		amount=int(_definition(sim,unit).get("regeneration",{}).get("amount",0))
	elif unit.get("team","")=="ally" and not unit.get("summon",false) and sim.state.get("combat",false) and sim.active_essences(unit).has(FIEND):
		amount=maxi(0,ceili(sim.stat_value(unit,"natural_recovery")*sim.stat_value(unit,"skill_power_multiplier")))
	if amount>0: sim.heal(unit,amount)

static func summon_cells(sim: RefCounted, caster: Dictionary, center: Vector2i, radius: int, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if radius<0 or radius>16 or count<=0 or count>OWNER_CAP or not caster.get("pos") is Vector2i: return result
	var map: Dictionary=sim.state.get("map",{})
	if not World.walkable(map,center) or not World.line_of_sight(map,caster.pos,center): return result
	var queue: Array[Vector2i]=[center]
	var seen: Dictionary={center:true}; var cursor: int=0
	while cursor<queue.size():
		var point: Vector2i=queue[cursor]; cursor+=1
		if sim.unit_at(point).is_empty() and World.line_of_sight(map,center,point) and World.line_of_sight(map,caster.pos,point):
			result.append(point)
			if result.size()==count: return result
		for direction: Vector2i in DIRS:
			var next: Vector2i=point+direction
			if seen.has(next) or _distance(next,center)>radius or not World.walkable(map,next): continue
			seen[next]=true; queue.append(next)
	# Never return a partial cast: callers can preflight exact placement.
	return []

static func can_call(sim: RefCounted, caster: Dictionary, ability: Dictionary, center: Vector2i) -> String:
	if sim.state.get("mode","")!="dungeon": return "Call of the Dead requires a dungeon expedition."
	if not _living(caster) or caster.get("summon",false): return "Only a living original caster can call Ghouls."
	if caster.get("team","") not in ["ally","enemy"] or not caster.get("id") is String: return "Invalid summoner."
	if sim.unable_to_act(caster): return "Cannot call while unable to act."
	if caster.team=="ally":
		if not sim.active_essences(caster).has(FIEND): return "The Death Fiend's active is unavailable or sealed."
	elif not _native_fiend(caster): return "This enemy cannot call Ghouls."
	if not ability.get("summon_id","canon_ghoul") is String or ability.get("summon_id","canon_ghoul")!="canon_ghoul" or not sim.monster_defs.has("canon_ghoul"): return "The summoned creature is unavailable."
	if int(ability.get("summon_count",10))!=10: return "Call of the Dead requires all ten Ghouls."
	if int(ability.get("summon_duration",ENEMY_SUMMON_LIFETIME))<1 or int(ability.get("summon_duration",ENEMY_SUMMON_LIFETIME))>1000: return "Invalid summon lifetime."
	if not caster.get("pos") is Vector2i or _distance(caster.pos,center)>int(ability.get("range",0)): return "Choose a center within casting range."
	if caster.team=="ally" and not sim.visible(center): return "Choose visible ground for the call."
	var owned: int=0
	for unit: Dictionary in sim.state.get("units",[]):
		if _living(unit) and unit.get("summon",false) and unit.get("summoner","")==caster.id: owned+=1
	if owned+10>OWNER_CAP: return "Dismiss or lose your existing Ghouls before calling ten more."
	if summon_cells(sim,caster,center,int(ability.get("radius",0)),10).size()!=10: return "Need ten free connected squares in line of sight."
	return ""

static func call_dead(sim: RefCounted, caster: Dictionary, ability: Dictionary, center: Vector2i) -> String:
	var failure: String=can_call(sim,caster,ability,center)
	if not failure.is_empty(): return failure
	var places: Array[Vector2i]=summon_cells(sim,caster,center,int(ability.get("radius",0)),10)
	var definition: Dictionary=sim.monster_defs.canon_ghoul
	for point: Vector2i in places:
		var unit: Dictionary=sim.spawn_enemy("canon_ghoul",point,true)
		unit.team=caster.team; unit.summoner=caster.id
		unit.lifetime=int(ability.get("summon_duration",ENEMY_SUMMON_LIFETIME))
		# Absolute two-minute-per-round estimate prevents safe waiting from
		# preserving temporary Ghouls for hours outside combat.
		unit.summon_expires_at=int(sim.state.get("time",0))+int(unit.lifetime)*2
		unit.behavior="aggressive"; unit.ap=0; unit.attacked=true
		unit.alert=true; unit.last_seen=caster.pos; unit.essences=[]; unit.spells=[]
		unit.energy=0; unit.max_energy=0; unit.mana=0; unit.max_mana=0
		unit.spawn_origin=point
		# Friendly summons use the ally stat adapter, so explicitly project the
		# monster's baseline instead of adding ordinary adventurer Strength/HP.
		if unit.team=="ally":
			unit.base_hp=maxi(0,int(definition.hp)-int(unit.get("vig",4))*4)
			unit.base_power=maxi(0,int(definition.power)-int(unit.get("str",4)))
			unit.base_armor=int(definition.get("armor",0))
			unit.base_stats.merge({"max_health":int(definition.hp),"attack":int(definition.power),"armor":int(definition.get("armor",0)),"accuracy":int(definition.get("accuracy",80)),"evasion":int(definition.get("evasion",0)),"attack_range":int(definition.get("range",1)),"max_soul_power":0,"max_mana":0,"carry_capacity":0,"carry_bonus":0},true)
			sim.recalculate(unit,false)
	sim.say("%s calls ten Ghouls." % str(caster.get("name","Death Fiend")))
	return ""

static func plan_intent(sim: RefCounted, enemy: Dictionary) -> void:
	if not _native_fiend(enemy) or sim.unable_to_act(enemy) or not enemy.get("alert",false): return
	if int(enemy.get("cooldowns",{}).get(FIEND,0))>0: return
	var target: Dictionary=_known_target(sim,enemy)
	if target.is_empty() or not _in_territory(sim,enemy,target): return
	var ability: Dictionary=_enemy_ability(sim,enemy)
	if not can_call(sim,enemy,ability,enemy.pos).is_empty(): return
	enemy.intent={"kind":"call_dead","pos":enemy.pos,"radius":int(ability.radius),"summon_count":10}

static func enemy_action(sim: RefCounted, enemy: Dictionary, target: Dictionary) -> bool:
	if not _living(enemy) or enemy.get("team","")!="enemy" or sim.unable_to_act(enemy) or int(enemy.get("ap",0))<=0: return false
	# Assistance is an explicit provisional interaction, not autonomous recovery
	# by the fiend. An adjacent active enemy sacrifices its entire action.
	for fallen: Dictionary in sim.enemies():
		if fallen.get("statuses",{}).has("toppled") and _distance(enemy.pos,fallen.pos)==1 and World.line_of_sight(sim.state.map,enemy.pos,fallen.pos):
			fallen.statuses.erase("toppled"); fallen.status_power.erase("toppled")
			enemy.ap=0; enemy.attacked=true
			sim.say("%s helps %s stand; its action is spent." % [enemy.name,fallen.name])
			return true
	if not _native_fiend(enemy): return false
	var known: Dictionary=_known_target(sim,enemy)
	var pursuit: Dictionary=known if not known.is_empty() else target
	if pursuit.is_empty() and enemy.get("last_seen") is Vector2i and enemy.last_seen.x>=0: pursuit={"pos":enemy.last_seen}
	if not _in_territory(sim,enemy,pursuit):
		enemy.alert=false; enemy.intent={}; enemy.last_seen=enemy.get("spawn_origin",enemy.pos); enemy.ap=0
		sim.say("%s stops at the edge of its territory." % enemy.name)
		return true
	if int(enemy.get("cooldowns",{}).get(FIEND,0))>0: return false
	if known.is_empty(): return false
	var ability: Dictionary=_enemy_ability(sim,enemy)
	if enemy.get("intent",{}).get("kind","")=="call_dead":
		var failure: String=call_dead(sim,enemy,ability,enemy.pos)
		enemy.intent={}; enemy.ap=0
		if failure.is_empty(): enemy.cooldowns[FIEND]=sim.ability_cooldown(enemy,int(ability.cooldown))+1
		else: sim.say("Call of the Dead fails: "+failure)
		return true
	# On a newly awakened enemy, telegraph first rather than summon invisibly.
	if can_call(sim,enemy,ability,enemy.pos).is_empty():
		enemy.intent={"kind":"call_dead","pos":enemy.pos,"radius":int(ability.radius),"summon_count":10}; enemy.ap=0
		sim.say("The ground trembles around %s: ten Ghouls are coming." % enemy.name)
		return true
	return false

static func is_topple_vulnerable(target: Dictionary) -> bool:
	return _living(target) and target.get("content_id","")==FIEND

static func topple(sim: RefCounted, target_id: String) -> String:
	if sim.state.get("mode","")!="dungeon": return "Topple a Death Fiend in the dungeon."
	var actor: Dictionary=sim.selected(); var target: Dictionary=sim.unit_by_id(target_id)
	if not _living(actor) or actor.get("team","")!="ally" or actor.get("summon",false) or sim.unable_to_act(actor): return "Choose a free living party member."
	if not is_topple_vulnerable(target) or target.get("team","")!="enemy": return "Choose a living opposing Death Fiend."
	if target.get("statuses",{}).has("toppled"): return "This Death Fiend is already down."
	if not sim.unit_visible(target) or _distance(actor.pos,target.pos)!=1: return "Stand next to a visible Death Fiend."
	if sim.stat_value(actor,"strength")<TOPPLE_STRENGTH: return "Topple requires8 Strength (estimated)."
	if actor.get("attacked",false) or (sim.state.get("combat",false) and int(actor.get("ap",0))<TOPPLE_AP): return "Need2 AP and an unused attack."
	if sim.state.get("combat",false): actor.ap-=TOPPLE_AP
	actor.attacked=true
	sim.status(target,"toppled",TOPPLE_DURATION)
	target.ap=0; target.intent={}
	sim.say("%s topples %s. It cannot stand unaided." % [actor.name,target.name])
	return ""

static func _enemy_ability(sim: RefCounted, unit: Dictionary) -> Dictionary:
	var meta: Dictionary=_definition(sim,unit).get("summoning",{})
	return {"effect":"call_dead","summon_id":meta.get("monster","canon_ghoul"),"summon_count":meta.get("count",10),"radius":meta.get("radius",3),"range":0,"cooldown":meta.get("cooldown",6),"summon_duration":ENEMY_SUMMON_LIFETIME}

static func _definition(sim: RefCounted, unit: Dictionary) -> Dictionary:
	return sim.monster_defs.get(str(unit.get("content_id","")),{})

static func _native_fiend(unit: Dictionary) -> bool:
	return _living(unit) and unit.get("team","")=="enemy" and unit.get("content_id","")==FIEND and not unit.get("summon",false)

static func _known_target(sim: RefCounted, enemy: Dictionary) -> Dictionary:
	var vision: int=int(sim.stat_value(enemy,"sight"))
	var result: Dictionary={}; var best: int=1000000
	for ally: Dictionary in sim.allies():
		if not _living(ally): continue
		var distance: int=_distance(enemy.pos,ally.pos)
		if distance>vision or not World.line_of_sight(sim.state.map,enemy.pos,ally.pos): continue
		if distance>1 and (ally.get("statuses",{}).has("stealth") or ally.get("statuses",{}).has("concealed")): continue
		if distance<best: best=distance; result=ally
	return result

static func _in_territory(sim: RefCounted, enemy: Dictionary, target: Dictionary) -> bool:
	var radius: int=int(_definition(sim,enemy).get("territorial",{}).get("pursuit_radius",10))
	var origin: Vector2i=enemy.get("spawn_origin",enemy.pos)
	return not target.is_empty() and target.get("pos") is Vector2i and _distance(origin,target.pos)<=radius and _distance(origin,enemy.pos)<=radius

static func _living(unit: Dictionary) -> bool:
	var hp: Variant=unit.get("hp",0)
	return not unit.is_empty() and (hp is int or hp is float) and is_finite(float(hp)) and float(hp)>0 and not unit.get("dead",false)

static func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
