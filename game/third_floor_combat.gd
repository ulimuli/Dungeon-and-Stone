class_name ThirdFloorCombat
extends RefCounted
## Narrow adapters for documented third-floor defenses/support. All numerical
## grid durations, resistance baselines, ranges and cooldowns are estimates.
## The caller owns attack AP/payment, hit RNG, damage/procs and round advancement.
const World=preload("res://game/world.gd")
const FRENZY_COOLDOWN: String="frenzy"
const COUNTERWEIGHT_COOLDOWN: String="counterweight"
const ORCS: Array[String]=["canon_orc_warrior","canon_orc_archer","canon_orc_sorcerer","canon_mighty_orc_warrior"]

## Pre-RNG guard: a mobile Frogman completely avoids ordinary blunt strikes.
## Fixed scripted damage, spells, DOT and secondary elemental/proc effects bypass.
static func evades_weapon(sim: RefCounted, source: Dictionary, target: Dictionary, damage_type: String, fixed_damage: int, context: Dictionary) -> bool:
	if not _living(target) or damage_type!="physical" or fixed_damage>=0 or not _ordinary_weapon(context): return false
	var meta: Dictionary=_definition(sim,target).get("blunt_evasion",{})
	if meta.is_empty() or not meta.get("while_mobile",false): return false
	for status_id: String in meta.get("disabled_by",[]):
		if _has_status(target,status_id): return false
	var weapon: Dictionary=sim.item_defs.get(str(source.get("equipment",{}).get("weapon","")),{})
	var style: String=str(context.get("weapon_style",weapon.get("weapon_style",source.get("weapon_style",""))))
	return style=="blunt"

## Set the resolved physical damage to0 after ordinary hit resolution. Do not
## early-return: a connected weapon strike may still carry a cold/holy proc.
static func physical_immune(sim: RefCounted, target: Dictionary, damage_type: String, fixed_damage: int, context: Dictionary) -> bool:
	return _living(target) and damage_type=="physical" and fixed_damage<0 and not context.get("dot",false) and context.get("category","")!="spell" and bool(_definition(sim,target).get("physical_immunity",false))

## Called after positive damage, before normal hit triggers; non-DOT cold can
## stiffen mucus and open the next blunt strike. No nonexistent shaman skill is inferred.
static func on_damage(sim: RefCounted, target: Dictionary, damage_type: String, dealt: int, context: Dictionary) -> void:
	if dealt<=0 or damage_type!="cold" or context.get("dot",false) or not _living(target): return
	var meta: Dictionary=_definition(sim,target).get("cold_stiffening",{})
	if meta.is_empty(): return
	var status_id: String=str(meta.get("status","chilled")); var duration: int=maxi(1,int(meta.get("duration",2)))
	sim.status(target,status_id,duration)
	sim.say("Cold stiffens %s's mucus; blunt evasion is disabled while chilled." % str(target.get("name","Frogman")))

static func blocks_displacement(target: Dictionary) -> bool:
	return _living(target) and _has_status(target,"anchored")

## Carnivaro's Tracking Arrow affects its primary weapon attack only. Existing
## normal hit caps still apply; spells/traps/DOT/secondary effects get no bonus.
static func accuracy_bonus(sim: RefCounted, source: Dictionary, context: Dictionary) -> int:
	if not _living(source) or not _ordinary_weapon(context): return 0
	return maxi(0,int(_definition(sim,source).get("tracking_arrow",{}).get("accuracy_bonus",0)))

## Optional readable support intent. It never grants knowledge of hidden allies.
static func plan_intent(sim: RefCounted, enemy: Dictionary) -> void:
	if not _can_act(sim,enemy) or not _known_threat(sim,enemy): return
	var meta: Dictionary=_definition(sim,enemy).get("ally_buff",{})
	if not meta.is_empty() and int(enemy.get("cooldowns",{}).get(FRENZY_COOLDOWN,0))<=0:
		var target: Dictionary=_buff_target(sim,enemy,meta)
		if not target.is_empty(): enemy.intent={"kind":"frenzy","pos":target.pos,"radius":0,"target":str(target.id)}

## Returns true only when a support action consumed the native enemy's action.
## Native Iron Tusk gets an actual temporary Counterweight window, not permanent
## hidden immunity. A nearby active orc is required for Frenzy; lone sorcerers attack.
static func enemy_action(sim: RefCounted, enemy: Dictionary) -> bool:
	if not _can_act(sim,enemy) or not _known_threat(sim,enemy): return false
	var definition: Dictionary=_definition(sim,enemy)
	var anchor: Dictionary=definition.get("counterweight",{})
	if not anchor.is_empty() and not _has_status(enemy,"anchored") and int(enemy.get("cooldowns",{}).get(COUNTERWEIGHT_COOLDOWN,0))<=0:
		sim.status(enemy,"anchored",maxi(1,int(anchor.get("duration",4))))
		enemy.cooldowns[COUNTERWEIGHT_COOLDOWN]=sim.ability_cooldown(enemy,int(anchor.get("cooldown",6)))+1
		enemy.ap=0; enemy.attacked=true; enemy.intent={}
		sim.say("%s braces with Counterweight; displacement is blocked while anchored." % str(enemy.name))
		return true
	var meta: Dictionary=definition.get("ally_buff",{})
	if meta.is_empty() or int(enemy.get("cooldowns",{}).get(FRENZY_COOLDOWN,0))>0: return false
	var target: Dictionary=_buff_target(sim,enemy,meta)
	if target.is_empty(): return false
	sim.status(target,str(meta.get("status","frenzy")),maxi(1,int(meta.get("duration",2))))
	enemy.cooldowns[FRENZY_COOLDOWN]=sim.ability_cooldown(enemy,int(meta.get("cooldown",4)))+1
	enemy.ap=0; enemy.attacked=true; enemy.intent={}
	sim.say("%s uses Frenzy on %s: raw physical resistance ×3." % [str(enemy.name),str(target.name)])
	return true

static func _buff_target(sim: RefCounted, caster: Dictionary, meta: Dictionary) -> Dictionary:
	var chosen: Dictionary={}; var best: float=-1.0
	var radius: int=int(meta.get("radius",3)); var status_id: String=str(meta.get("status","frenzy"))
	for unit: Dictionary in sim.enemies():
		if not _living(unit) or unit.get("id","")==caster.get("id","") or unit.get("team","")!=caster.get("team","") or unit.get("content_id","") not in ORCS or unit.get("summon",false) or _has_status(unit,status_id): continue
		if _distance(caster.pos,unit.pos)>radius or not World.line_of_sight(sim.state.map,caster.pos,unit.pos): continue
		var score: float=sim.stat_value(unit,"attack")
		# Stable state order breaks ties; no random target selection or hidden tracking.
		if score>best: chosen=unit; best=score
	return chosen

static func _known_threat(sim: RefCounted, enemy: Dictionary) -> bool:
	var sight: int=maxi(0,int(sim.stat_value(enemy,"sight")))
	for ally: Dictionary in sim.allies():
		if not _living(ally): continue
		var distance: int=_distance(enemy.pos,ally.pos)
		if distance>sight or not World.line_of_sight(sim.state.map,enemy.pos,ally.pos): continue
		if distance>1 and (_has_status(ally,"stealth") or _has_status(ally,"concealed")): continue
		return true
	return false

static func _can_act(sim: RefCounted, enemy: Dictionary) -> bool:
	return _living(enemy) and enemy.get("team","")=="enemy" and not enemy.get("summon",false) and enemy.get("alert",false) and int(enemy.get("ap",0))>0 and not sim.unable_to_act(enemy)

static func _ordinary_weapon(context: Dictionary) -> bool:
	return context.get("category","")=="weapon" and not context.get("dot",false) and not context.get("secondary",false)

static func _has_status(unit: Dictionary, id: String) -> bool:
	return int(unit.get("statuses",{}).get(id,0))>0

static func _definition(sim: RefCounted, unit: Dictionary) -> Dictionary:
	return sim.monster_defs.get(str(unit.get("content_id","")),{})

static func _living(unit: Dictionary) -> bool:
	return not unit.is_empty() and float(unit.get("hp",0))>0 and not unit.get("dead",false)

static func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
