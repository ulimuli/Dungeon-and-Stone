extends SceneTree
## Assisted funds, level, rare-drop seed selection and empty test chambers.
## Commands, effects, spawning, ownership, loot and persistence are actual Sim.
## No player saves/settings; this is not unassisted balance or complete floors.
const Sim=preload("res://game/simulation.gd")
const Rules=preload("res://game/early_monster_rules.gd")
const Validator=preload("res://game/save_validation.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func fresh(race: String="barbarian") -> GameSimulation:
	var sim:=Sim.new(); sim.new_campaign("Early monster integration",race,"adventurer",34117)
	sim.state.gold=200000; sim.state.level=2; sim.recalculate(sim.hero(),true)
	return sim
func enter(sim: GameSimulation) -> void:
	check(sim.enter_region(1),"Actual expedition entry succeeds")
	sim.state.units=[]; sim.state.combat=false; sim.state.map.traps=[]
	sim.resolving_round=true; sim.hero().pos=sim.state.map.entrance; sim.hero().ap=20; sim.hero().attacked=false
	sim.update_visibility()
func bind(sim: GameSimulation) -> void:
	sim.state.essence_drops.append({"id":Rules.FIEND,"pos":sim.hero().pos,"region":sim.state.region,"expires_at":sim.state.time+30})
	sim._recount_essence_drops()
	check(sim.absorb(Rules.FIEND).is_empty(),"Actual nearby physical Death Fiend drop can be absorbed")
func built(race: String="barbarian") -> GameSimulation:
	var sim:=fresh(race); enter(sim); bind(sim); return sim
func sums(sim: GameSimulation,team: String="ally") -> Array:
	return sim.state.units.filter(func(actor: Dictionary)->bool:return actor.get("summon",false) and actor.team==team and actor.hp>0)
func conserved(sim: GameSimulation) -> String:
	var copy: Dictionary=sim.state.duplicate(true); copy.erase("log")
	return var_to_str([copy,sim.rng.state])
func rejected_cast(sim: GameSimulation,label: String) -> void:
	var before: String=conserved(sim)
	check(not sim.use_ability(0,sim.hero().pos),label+" rejects before casting")
	check(conserved(sim)==before,label+" preserves items, SP/AP, cooldowns, clock, ownership and RNG")
func roundtrip(sim: GameSimulation,label: String) -> GameSimulation:
	var restored:=Sim.new(); var payload: Dictionary=JSON.parse_string(JSON.stringify(sim.snapshot()))
	var errors: Array[String]=Validator.validate(payload)
	check(errors.is_empty(),label+" snapshot passes actual validator: "+str(errors))
	check(restored.restore(payload),label+" restores actual JSON snapshot")
	restored.resolving_round=true
	return restored
func seed_for_drop(chance: float) -> int:
	var probe:=RandomNumberGenerator.new()
	for candidate: int in range(1,200000):
		probe.seed=candidate
		if probe.randf()<chance: return candidate
	check(false,"Rare-drop fixture finds a reproducible favorable seed")
	return 1
func bless(sim: GameSimulation,id: String) -> void:
	check(sim.enter_homeland("draconian").is_empty(),"Draconian enters actual blessing location")
	for point: Dictionary in HomelandMap.layout_for("draconian").interactables:
		if point.id!="draconian_language_guide": continue
		for direction: Vector2i in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
			if sim.record_homeland_position(point.cell+direction): break
	check(sim.homeland_perform("dragon_blessing","hero","draconian_language_guide",id).ok,"Actual shaman commits selected blessing")
	check(sim.leave_homeland().is_empty(),"Blessed actor returns to the city")
func _initialize() -> void:
	_test_drop_and_regeneration()
	_test_sealing_and_blessing_interactions()
	_test_actual_summoning_and_limits()
	_test_enemy_patterns_and_toppling()
	_test_lifecycle_supplies_saves()
	print("EARLY MONSTER INTEGRATION: %d checks, %d failures. Actual rare-drop/absorb, shared healing and seal/blessing interactions, ten-Ghoul costs/ownership/rewards, enemy telegraphs/toppling, expiry and JSON. Assisted arenas/funds/level/seeds; no player files." % [checks,failures])
	quit(1 if failures else 0)
func _test_drop_and_regeneration() -> void:
	var sim:=fresh(); enter(sim)
	var target: Dictionary=sim.spawn_enemy(Rules.FIEND,sim.hero().pos+Vector2i.RIGHT)
	target.hp=1
	sim.rng.seed=seed_for_drop(float(sim.monster_defs[Rules.FIEND].essence_drop_chance))
	sim.hit(sim.hero(),target,1,"wound","Assisted lethal hit",false,true,1)
	check(sim.state.xp==2 and sim.state.loot_items.get("mana_stone_rank_8",0)==1,"Native Death Fiend grants actual first-speciesXP and rank-eight stone")
	check(sim.state.essence_drops.size()==1 and sim.state.essence_drops[0].id==Rules.FIEND and sim.state.essence_drops[0].expires_at==sim.state.time+30,"Actual rare on-death roll creates sourced physical essence with normal expiry")
	check(sim.absorb(Rules.FIEND).is_empty() and sim.state.essence_drops.is_empty(),"Actual kill drop is consumed by normal absorption")
	check(sim.stat_value(sim.hero(),"natural_recovery")==2,"Physical Preservation multiplies the shared recovery stat")
	sim.state.combat=true; sim.hero().hp=7; sim.tick_unit(sim.hero())
	check(sim.hero().hp==9,"Actual combat tick applies the new passive through central healing")
	sim.state.combat=false; sim.hero().hp=7; sim.advance_time(90)
	check(sim.hero().hp==9,"Safe ninety-minute recovery gains one shared passive tick without duplicate combat healing")
	var engraved:=fresh(); check(engraved.learn_undying().is_empty(),"Actual paid Undying engraving prepares synergy")
	enter(engraved); bind(engraved)
	check(engraved.stat_value(engraved.hero(),"natural_recovery")==4,"Undying additive recovery and preservation multiplier compose in the master calculator")
	engraved.state.combat=true; engraved.hero().hp=7; engraved.tick_unit(engraved.hero())
	check(engraved.hero().hp==11,"Actual combat recovery consumes the composed Undying build")
func _test_sealing_and_blessing_interactions() -> void:
	var sim:=fresh(); check(sim.buy("frost_spirit_ring").is_empty(),"Actual rare ring purchase prepares sealing")
	enter(sim); bind(sim)
	check(sim.equip("frost_spirit_ring","hero",Rules.FIEND).is_empty(),"Actual ring equip selects the absorbed Death Fiend skills")
	check(sim.stat_value(sim.hero(),"natural_recovery")==1 and sim.hero().essences.has(Rules.FIEND),"Sealing disables recovery skill while retaining essence and slot")
	sim.state.combat=true; sim.hero().ap=20; sim.hero().hp=7; sim.tick_unit(sim.hero())
	check(sim.hero().hp==7,"Sealed preservation cannot heal in actual combat tick")
	rejected_cast(sim,"Sealed Call of the Dead")
	check(sim.techniques(sim.hero()).is_empty(),"Sealed active disappears from actual technique list")
	var stale_before: String=conserved(sim)
	check(not sim.use_technique(0,sim.hero().pos) and conserved(sim)==stale_before,"A previously selected technique slot cannot execute after its essence is sealed")
	sim.state.combat=false; check(sim.unequip("charm").is_empty(),"Removing ring restores skill access without removing essence")
	check(sim.stat_value(sim.hero(),"natural_recovery")==2 and sim.techniques(sim.hero()).size()==1,"Shared passive and active recover after real unequip")
	var earth:=fresh("draconian"); bless(earth,"earth"); enter(earth); bind(earth)
	check(earth.stat_value(earth.hero(),"natural_recovery")==2,"Earth attribute enhancement never scales passive skill modifiers")
	var volcano:=fresh("draconian"); bless(volcano,"volcano"); enter(volcano); bind(volcano)
	check(volcano.stat_value(volcano.hero(),"natural_recovery")==2 and volcano.stat_value(volcano.hero(),"skill_power_multiplier")==1.3,"Volcano and preservation remain distinct shared stat factors")
	volcano.state.combat=true; volcano.hero().hp=7; volcano.tick_unit(volcano.hero())
	check(volcano.hero().hp==10,"Volcano boosts combat preservation strength through shared skill power")
	volcano.state.combat=false; volcano.hero().hp=7; volcano.advance_time(180)
	check(volcano.hero().hp==12 and is_equal_approx(volcano.hero().recovery_remainder,0.2),"Safe recovery retains fractional Volcano potency across intervals")
	volcano.state.combat=true; volcano.hero().ap=20; volcano.hero().energy=volcano.hero().max_energy
	check(volcano.techniques(volcano.hero())[0].ability.summon_duration==16,"Actual targeting entry exposes Volcano's resolved summon lifetime")
	check(volcano.use_ability(0,volcano.hero().pos) and sums(volcano).size()==10,"Enhanced summon technique executes through the normal command")
	check(sums(volcano)[0].lifetime==16 and sums(volcano)[0].summon_expires_at==volcano.state.time+30,"Resolved summon lifetime and absolute deadline agree after cast's two-minute action")
func _test_actual_summoning_and_limits() -> void:
	var sim:=built(); sim.state.combat=true; sim.hero().ap=20
	var energy: int=sim.hero().energy; var capacity: int=sim.capacity(); var before_rng: int=sim.rng.state; var time: int=sim.state.time
	check(sim.use_technique(0,sim.hero().pos),"Actual selectable Call of the Dead executes")
	check(sums(sim).size()==10 and sim.hero().energy==energy-12 and sim.hero().ap==18 and sim.hero().cooldowns[Rules.FIEND]==7 and sim.state.time==time+2,"Cast spends exactly12SP/twoAP/two minutes and starts cooldown once")
	check(sim.rng.state==before_rng and sim.capacity()==capacity and sim.state.party.is_empty(),"Summoning is deterministic and adds no carrying allowance or permanent party members")
	var seen: Dictionary={}
	for unit: Dictionary in sums(sim):
		check(unit.summoner=="hero" and unit.team=="ally" and unit.content_id=="canon_ghoul" and unit.lifetime==12 and not seen.has(unit.id),"Actual friendly Ghoul keeps faction/owner/lifetime and unique saved identity"); seen[unit.id]=true
		check(unit.max_hp==sim.monster_defs.canon_ghoul.hp and unit.power==sim.monster_defs.canon_ghoul.power and sim.stat_value(unit,"max_soul_power")==0,"Friendly Ghoul uses its actual monster combat/resource profile")
	sim.state.combat=true; sim.hero().cooldowns[Rules.FIEND]=0
	rejected_cast(sim,"Ten active owned Ghouls cap")
	var restored:=roundtrip(sim,"Living friendly summons")
	check(sums(restored).size()==10 and restored.state.entity_serial==sim.state.entity_serial,"Summoner ownership and monotonic spawn identity survive full campaign restoration")
	var xp: int=sim.state.xp; var loot: Dictionary=sim.state.loot_items.duplicate(true); var fallen: Array=sim.state.fallen_ids.duplicate(true)
	for unit: Dictionary in sums(sim): sim.hit(sim.hero(),unit,1000,"wound","Assisted summon death",false,true,1000)
	check(sim.state.xp==xp and sim.state.loot_items==loot and sim.state.fallen_ids==fallen,"Friendly summon deaths create no XP, mana stones or permanent companion losses")
	var blocked:=built(); blocked.state.combat=true; blocked.hero().ap=20
	for y: int in range(blocked.hero().pos.y-4,blocked.hero().pos.y+5):
		for x: int in range(blocked.hero().pos.x-4,blocked.hero().pos.x+5):
			if Vector2i(x,y)!=blocked.hero().pos: blocked.state.map.tiles[y][x]=DungeonWorld.WALL
	rejected_cast(blocked,"Insufficient ten-creature placement")
func _test_enemy_patterns_and_toppling() -> void:
	var sim:=fresh(); enter(sim); sim.state.combat=true
	var enemy: Dictionary=sim.spawn_enemy(Rules.FIEND,sim.hero().pos+Vector2i(3,0)); enemy.alert=true
	sim.update_visibility(); enemy.intent={}; enemy.hp=7
	sim.enemy_turn(enemy)
	check(enemy.intent.get("kind","")=="call_dead" and sums(sim,"enemy").is_empty(),"Actual enemy action first displays summon telegraph without instant Ghouls")
	sim.tick_unit(enemy); check(enemy.hp==15,"Native monster tick regenerates estimated eightHP")
	sim.enemy_turn(enemy)
	check(sums(sim,"enemy").size()==10 and enemy.cooldowns[Rules.FIEND]==7,"Following actual enemy action calls ten opposing Ghouls")
	var xp: int=sim.state.xp; var loot: Dictionary=sim.state.loot_items.duplicate(true); var drops: int=sim.state.essence_drops.size()
	for unit: Dictionary in sums(sim,"enemy"): sim.hit(sim.hero(),unit,1000,"wound","Assisted summon death",false,true,1000)
	check(sim.state.xp==xp and sim.state.loot_items==loot and sim.state.essence_drops.size()==drops,"Killing summoned enemy Ghouls grants no XP/materials/essences")
	var prone:=fresh(); enter(prone); prone.state.combat=true; prone.hero().ap=2
	enemy=prone.spawn_enemy(Rules.FIEND,prone.hero().pos+Vector2i.RIGHT); enemy.alert=true; enemy.intent={"kind":"call_dead"}
	prone.update_visibility(); var start: int=prone.state.time; var rng_before: int=prone.rng.state
	check(prone.topple_target(enemy.id).is_empty(),"Actual deterministic topple wrapper executes")
	check(prone.hero().ap==0 and prone.hero().attacked and prone.state.time==start+2 and prone.rng.state==rng_before,"Topple spends twoAP/unused attack/two minutes with no hit RNG")
	check(prone.unable_to_act(enemy) and prone.stat_value(enemy,"action_points")==0 and enemy.intent.is_empty(),"Topple disables actions and interrupts the fiend's pending call")
	prone.end_phase(); check(not prone.hero().guard,"Spent twoAP cannot turn into a free Guard")
	for index: int in range(3): prone.tick_unit(enemy); prone.enemy_turn(enemy)
	check(enemy.statuses.get("toppled",0)==Rules.TOPPLE_DURATION,"Actual round/status processing cannot let a fiend stand unaided")
	var loaded:=roundtrip(prone,"Toppled native fiend"); check(loaded.enemies()[0].statuses.has("toppled"),"Prone state survives actual JSON restoration")
	var helper: Dictionary=prone.spawn_enemy("canon_ghoul",enemy.pos+Vector2i.DOWN); helper.alert=true
	prone.enemy_turn(helper)
	check(not enemy.statuses.has("toppled") and helper.ap==0,"Actual adjacent enemy spends its turn helping the fiend stand")
	var braces:=fresh(); check(braces.buy("guardians_braces").is_empty() and braces.equip("guardians_braces").is_empty(),"Actual market supplies and equips the knockback artifact")
	enter(braces); braces.state.combat=true; braces.hero().ap=20
	enemy=braces.spawn_enemy(Rules.FIEND,braces.hero().pos+Vector2i.RIGHT); enemy.alert=true; braces.update_visibility()
	check(braces.activate_guardians_braces().is_empty() and enemy.statuses.has("toppled") and enemy.pos!=braces.hero().pos+Vector2i.RIGHT,"Guardian's actual repulsion also knocks a Death Fiend down")
	var unseen:=fresh(); enter(unseen); unseen.state.combat=true; unseen.hero().statuses.stealth=5
	enemy=unseen.spawn_enemy(Rules.FIEND,unseen.hero().pos+Vector2i(3,0)); enemy.alert=true; unseen.update_visibility(); enemy.intent={}; unseen.plan_intents()
	check(enemy.intent.get("kind","")!="call_dead","Actual intent planning cannot discover distant concealed targets")
	var blind:=fresh(); enter(blind); blind.state.combat=true
	enemy=blind.spawn_enemy(Rules.FIEND,blind.hero().pos+Vector2i(3,0)); enemy.alert=true
	for y: int in range(blind.hero().pos.y-3,blind.hero().pos.y+4): blind.state.map.tiles[y][blind.hero().pos.x+1]=DungeonWorld.WALL
	blind.update_visibility(); enemy.intent={}; blind.plan_intents(); blind.enemy_turn(enemy)
	check(enemy.intent.get("kind","")!="call_dead" and sums(blind,"enemy").is_empty(),"Actual wall occlusion prevents telegraphed or immediate hidden-target summoning")
	var territorial:=fresh(); enter(territorial); territorial.state.combat=true
	enemy=territorial.spawn_enemy(Rules.FIEND,territorial.hero().pos+Vector2i.RIGHT); enemy.alert=true; enemy.last_seen=territorial.hero().pos
	var origin: Vector2i=enemy.pos; var direction: Vector2i=Vector2i.RIGHT if origin.x<48 else Vector2i.LEFT
	# Straight controlled sight corridor isolates the territory rule; geography
	# is assisted test setup rather than a claimed novel floor layout.
	for step: int in range(12):
		for across: int in range(-1,2):
			var tile: Vector2i=origin+direction*step+Vector2i(0,across)
			territorial.state.map.tiles[tile.y][tile.x]=DungeonWorld.FLOOR
	territorial.hero().pos=origin+direction*11; enemy.base_stats.sight=20
	var hp_before: int=territorial.hero().hp; var random_before: int=territorial.rng.state
	territorial.enemy_turn(enemy); territorial.update_visibility()
	check(not enemy.alert and enemy.pos==origin and territorial.hero().hp==hp_before and territorial.rng.state==random_before,"Native fiend stops pursuit beyond its estimated territory without attack or random roll")
	check(not territorial.state.combat,"Actual visibility/combat update allows escape after territorial disengagement")

func _test_lifecycle_supplies_saves() -> void:
	var sim:=built(); sim.hero().ap=20
	check(sim.use_ability(0,sim.hero().pos),"Temporary lifetime fixture uses actual summon command")
	var deadline: int=sums(sim)[0].summon_expires_at
	sim.advance_time(deadline-sim.state.time-1)
	check(sums(sim).size()==10,"Absolute expiry preserves summons until the exact deadline")
	sim.advance_time(1); check(sums(sim).is_empty(),"Safe waiting expires all summons at the actual minute deadline")
	var loaded:=roundtrip(sim,"Expired summons"); check(sums(loaded).is_empty(),"Expired summons cannot resurrect after loading")
	var round_life:=built(); check(round_life.use_ability(0,round_life.hero().pos),"Round lifetime fixture summons actual Ghouls")
	var summon: Dictionary=sums(round_life)[0]
	for index: int in range(12): round_life.tick_unit(summon)
	check(summon.hp==0,"Combat lifetime expires at twelve actual round ticks independently of clock")
	var food:=built(); check(food.use_ability(0,food.hero().pos),"Food/water fixture summons real temporary units")
	for actor: Dictionary in sums(food): actor.base_stats.appetite=100; actor.summon_expires_at=food.state.time+2000
	food.state.combat=true; var rations: int=food.state.food; var water: int=food.state.water
	food.advance_time(1440-food.state.time)
	check(food.state.food==rations-1 and food.state.water==water-1,"Temporary summons add no food/water demand even with positive appetite stats")
	var saved:=built(); check(saved.use_ability(0,saved.hero().pos),"Corruption fixture summons real units")
	for field: String in ["summoner","lifetime","summon_expires_at"]:
		for value: Variant in [null,[],true,-1,1.5]:
			var bad: Dictionary=JSON.parse_string(JSON.stringify(saved.snapshot())); bad.units[0][field]=value
			check(not Validator.validate(bad).is_empty(),"Malformed saved summon field rejects: "+field+str(value))
	var crossing:=built(); check(crossing.use_ability(0,crossing.hero().pos),"Portal fixture creates actual owned summons")
	for gate: Dictionary in crossing.state.map.area_portals:
		if gate.region==2: crossing.hero().pos=gate.pos; break
	crossing.update_visibility()
	check(crossing.travel_region(2) and sums(crossing).is_empty(),"Crossing the actual directional portal dismisses temporary allies")
	check(not crossing.state.floor_memory["1"].units.any(func(actor: Dictionary)->bool:return actor.get("summon",false)),"Dismissed summons cannot reappear from prior-floor memory")
	var before: String=conserved(saved); var bad: Dictionary=JSON.parse_string(JSON.stringify(saved.snapshot())); bad.units[0].summoner=[]
	check(not saved.restore(bad) and conserved(saved)==before,"Rejected summon restoration preserves active campaign and RNG")
