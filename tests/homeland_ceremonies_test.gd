extends SceneTree
## Assisted funds/levels and battlefield setup; actual choices, absorption,
## combat effects and save validation. No player files or invented quest grants.
const Sim=preload("res://game/simulation.gd")
const Coming=preload("res://game/coming_of_age_rules.gd")
const Dragon=preload("res://game/dragon_blessing_rules.gd")
const Validator=preload("res://game/save_validation.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func valid_errors(payload: Dictionary) -> Array[String]:
	return Validator.validate(Sim.new().encode(payload))
func fresh(race: String="barbarian") -> GameSimulation:
	var sim:=Sim.new(); sim.new_campaign("Ceremony fixture",race,"adventurer",34117); sim.state.gold=10000
	return sim
func near(sim: GameSimulation, race: String, point_id: String) -> void:
	check(sim.enter_homeland(race).is_empty(),"Actual homeland entry succeeds")
	var layout: Dictionary=HomelandMap.layout_for(race)
	for point: Dictionary in layout.interactables:
		if point.id!=point_id: continue
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if sim.record_homeland_position(point.cell+direction): return
	check(false,"Ceremony point has a valid standing neighbor")
func roundtrip(sim: GameSimulation) -> GameSimulation:
	var restored:=Sim.new(); check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Actual JSON save roundtrip succeeds")
	return restored
func reject_choice(sim: GameSimulation, weapon: String, actor: String="hero") -> void:
	var before: String=var_to_str([sim.state,sim.rng.state])
	check(not Coming.choose(sim,actor,weapon).is_empty(),"Invalid weapon choice rejects")
	check(var_to_str([sim.state,sim.rng.state])==before,"Rejected choice preserves inventory, resources, flags and RNG")
func bless(sim: GameSimulation, id: String) -> void:
	sim.state.level=2; sim.recalculate(sim.hero(),false)
	near(sim,"draconian","draconian_language_guide")
	var before: String=var_to_str([sim.state,sim.rng.state])
	var response: Dictionary=sim.homeland_interact("draconian_language_guide")
	check(response.ok and response.open=="choices" and var_to_str([sim.state,sim.rng.state])==before,"Shaman offers a read-only blessing choice")
	check(sim.homeland_perform("dragon_blessing","hero","draconian_language_guide",id).ok,"Nearby shaman performs chosen real blessing")
func field(sim: GameSimulation, essence: String) -> Dictionary:
	sim.leave_homeland(); check(sim.enter_region(1),"Blessed actor enters actual expedition")
	sim.state.units=[]; sim.state.map.traps=[]; sim.resolving_round=true; sim.state.combat=true
	for y: int in range(2,18):
		for x: int in range(2,18): sim.state.map.tiles[y][x]=DungeonWorld.FLOOR
	sim.hero().pos=Vector2i(8,8)
	if not essence.is_empty():
		sim.state.essence_drops.append({"id":essence,"pos":sim.hero().pos,"region":1,"expires_at":100})
		sim._recount_essence_drops(); check(sim.absorb(essence).is_empty(),"Actual physical essence absorption remains compatible with blessing")
	sim.recalculate(sim.hero(),true); sim.hero().ap=20
	var enemy: Dictionary=sim.spawn_enemy("canon_ghoul",Vector2i(9,8)); enemy.hp=1000; enemy.max_hp=1000; enemy.armor=0; enemy.evasion=0; enemy.resist={}; enemy.statuses={}
	sim.update_visibility(); return enemy
func _initialize() -> void:
	for weapon: String in Coming.options():
		var sim:=fresh(); near(sim,"barbarian","barbarian_weapon_circle"); sim.hero().hp=7; sim.hero().energy=2
		var before: String=var_to_str([sim.state,sim.rng.state]); var review: Dictionary=sim.homeland_interact("barbarian_weapon_circle")
		check(review.ok and review.open=="choices" and var_to_str([sim.state,sim.rng.state])==before,"Coming-of-age options do not commit a choice")
		var inventory: Dictionary=sim.state.inventory.duplicate(true); var gold: int=sim.state.gold; var rng_before: int=sim.rng.state
		check(sim.homeland_perform("coming_of_age","hero","barbarian_weapon_circle",weapon).ok,"Every displayed weapon is actually selectable: "+weapon)
		check(sim.hero().equipment.weapon==weapon and sim.state.flags.coming_of_age_complete and sim.state.flags["coming_of_age_weapon:"+weapon],"Ceremony persists chosen equipment and stable one-time flags")
		check(sim.state.inventory==inventory and sim.state.gold==gold and sim.hero().hp==7 and sim.hero().energy==2 and sim.rng.state==rng_before,"Exchange creates no pack duplicate, payment, healing or random draws")
		var loaded:=roundtrip(sim); check(loaded.hero().equipment.weapon==weapon and loaded.state.flags.coming_of_age_complete,"Weapon choice survives restore")
		reject_choice(loaded,"club")
	var sim:=fresh(); reject_choice(sim,"bow"); reject_choice(sim,"club","missing")
	sim.state.level=2; reject_choice(sim,"spear")
	sim=fresh(); sim.state.visited_regions=[1]; reject_choice(sim,"spear")
	sim=fresh(); sim.hero().equipment.weapon="sword"; reject_choice(sim,"spear")
	sim=fresh(); sim.add_item("greatsword",100); reject_choice(sim,"greatsword")
	for race: String in ["human","fairy","dwarf","beastman","draconian"]: reject_choice(fresh(race),"club")
	var earth:=fresh("draconian"); bless(earth,"earth"); field(earth,"canon_goblin_archer")
	var baseline: Dictionary=earth.hero().duplicate(true); baseline.erase("dragon_blessing")
	var normal: Array=StatSources.modifiers(baseline,earth.item_defs,earth.essence_defs,earth.ancestry_defs)
	var enhanced: Array=StatSources.modifiers(earth.hero(),earth.item_defs,earth.essence_defs,earth.ancestry_defs)
	for row: Dictionary in normal:
		var found: Array=enhanced.filter(func(other: Dictionary)->bool:return other.id==row.id)
		check(found.size()==1,"Earth preserves unique modifier provenance")
		var scale: float=1.2 if str(row.source).begins_with("essence:") and row.op=="add" else 1.0
		check(is_equal_approx(float(found[0].value),float(row.value)*scale),"Earth scales only essence attributes; gear/race remain untouched: "+row.id)
	check(earth.skill_duration(earth.hero(),4)==4,"Earth does not boost skill duration")
	var sea:=fresh("draconian"); sea.state.level=2; sea.recalculate(sea.hero(),false)
	var maximum: int=sea.hero().max_energy; sea.hero().energy=2; sea.hero().hp=7
	bless(sea,"sea")
	check(sea.hero().max_energy==maximum+100 and sea.hero().energy==2 and sea.hero().hp==7,"Sea adds exactly100 raw Soul Power through capacity without free refill")
	var restored:=roundtrip(sea); check(restored.hero().dragon_blessing=="sea" and restored.hero().max_energy==sea.hero().max_energy,"Sea blessing and capacity survive actual save restore")
	for value: Variant in ["unknown",[],null,23]:
		var corrupted: Dictionary=sea.state.duplicate(true); corrupted.hero.dragon_blessing=value
		check(not valid_errors(corrupted).is_empty(),"Invalid persisted blessing fails validation")
	var forged: Dictionary=sea.state.duplicate(true); forged.hero.ancestry="human"
	check(not valid_errors(forged).is_empty(),"Foreign blessing rejects without the unimplemented story exception")
	var volcano:=fresh("draconian"); bless(volcano,"volcano"); var enemy: Dictionary=field(volcano,"canon_goblin")
	check(volcano.stat_value(volcano.hero(),"skill_power_multiplier")==1.3,"Volcano uses shared resolved multiplier")
	volcano.trigger(volcano.hero(),"on_hit",enemy,1,true)
	check(enemy.statuses.get("paralyzed",0)==3,"Volcano improves actual Goblin passive duration2→3")
	check(volcano.use_ability(0,volcano.hero().pos+Vector2i.DOWN),"Volcano trap skill executes with original targeting range and cost")
	check(volcano.state.player_traps.size()==1 and volcano.state.player_traps[0].status_duration==3,"Trap snapshots scaled strength for persistence")
	enemy.pos=volcano.state.player_traps[0].pos; enemy.statuses={}; volcano.step_hazards(enemy)
	check(enemy.statuses.get("paralyzed",0)==3,"Stepping on real trap applies scaled duration")
	var neutral: Dictionary=volcano.hero().duplicate(true); neutral.erase("dragon_blessing"); neutral.id="neutral"; neutral.essences=[]
	var own: Dictionary=volcano.hero().duplicate(true); own.essences=[]
	var a: int=volcano.hit(neutral,enemy,10,"physical","Attack",false,true,-1,{"attack_resolved":true,"category":"weapon"})
	var b: int=volcano.hit(own,enemy,10,"physical","Attack",false,true,-1,{"attack_resolved":true,"category":"weapon"})
	check(a==b,"Volcano never amplifies ordinary weapon hits")
	a=volcano.hit(neutral,enemy,10,"mana","Ice Spear",false,true,-1,{"attack_resolved":true,"category":"spell"})
	b=volcano.hit(own,enemy,10,"mana","Ice Spear",false,true,-1,{"attack_resolved":true,"category":"spell"})
	check(b>a,"Supported learned-spell damage consumes Volcano multiplier")
	for entry: Array in [["canon_goblin_archer","stealth",6],["canon_gnome","concealed",7],["canon_stone_golem","suppressed",3]]:
		var powered:=fresh("draconian"); bless(powered,"volcano"); var target: Dictionary=field(powered,entry[0])
		var ability: Dictionary=powered.techniques(powered.hero())[0].ability
		var target_pos: Vector2i=target.pos if entry[0]=="canon_stone_golem" else powered.hero().pos
		check(powered.use_ability(0,target_pos),"Supported Volcano essence executes: "+entry[0])
		var recipient: Dictionary=target if entry[0]=="canon_stone_golem" else powered.hero()
		check(recipient.statuses.get(entry[1],0)==entry[2],"Actual skill duration matches enhanced strength: "+entry[0])
		check(int(ability.get("effect_duration",ability.get("status_duration",0)))==int(entry[2]),"Targeting preview exposes same resolved duration")
	# Preserve each blessing on a real campaign snapshot before battlefield setup.
	for id: String in Dragon.IDS:
		var persistent:=fresh("draconian"); bless(persistent,id)
		var loaded:=roundtrip(persistent)
		check(loaded.hero().dragon_blessing==id and loaded.stat_value(loaded.hero(),"skill_power_multiplier")==persistent.stat_value(persistent.hero(),"skill_power_multiplier"),"Every blessing preserves shared effects across full campaign JSON")
	var party_sim:=fresh("human"); party_sim.state.level=2
	check(party_sim.recruit("draconian_warrior").is_empty(),"Real generated Draconian companion can join")
	var actor: String=party_sim.state.party[0].id
	near(party_sim,"draconian","draconian_language_guide")
	check(party_sim.homeland_perform("dragon_blessing",actor,"draconian_language_guide","sea").ok,"Selected generated companion receives its own blessing")
	party_sim.dismiss(actor)
	check(party_sim.state.benched.has("draconian_warrior") and party_sim.recruit("draconian_warrior").is_empty(),"Blessed companion can bench and rejoin through actual commands")
	check(party_sim.state.party[0].dragon_blessing=="sea" and not party_sim.hero().has("dragon_blessing"),"Blessing stays with its owner and is never copied to the hero")
	var party_load:=roundtrip(party_sim)
	check(party_load.state.party[0].dragon_blessing=="sea","Generated companion blessing survives campaign persistence")
	var snapshot_sim:=fresh("draconian"); bless(snapshot_sim,"volcano"); snapshot_sim.leave_homeland(); check(snapshot_sim.enter_region(1),"Snapshot fixture uses an untouched generated dungeon")
	snapshot_sim.snapshot()
	var snapshot_state: Dictionary=snapshot_sim.state.duplicate(true)
	snapshot_state.player_traps.append({"pos":snapshot_sim.hero().pos,"team":"ally","owner":"hero","status_duration":3})
	snapshot_state.terrain_effects.append({"pos":snapshot_sim.hero().pos,"team":"ally","owner":"hero","status_duration":3,"turns":7,"radius":3,"damage":0,"type":"concealment"})
	check(valid_errors(snapshot_state).is_empty(),"Snapshot strength is valid in an actual generated expedition: "+str(valid_errors(snapshot_state)))
	for malformed: Variant in [0,-1,1000001,"3",null,[],NAN]:
		for collection: String in ["player_traps","terrain_effects"]:
			var invalid: Dictionary=snapshot_state.duplicate(true); invalid[collection][0].status_duration=malformed
			check(not valid_errors(invalid).is_empty(),"Malformed saved skill potency is rejected before restoration")
	var fairy:=fresh("fairy"); check(fairy.form_spirit_contract().is_empty(),"First spirit lesson prepares actual recovery test")
	fairy.hero().natural_energy_current=1; fairy.hero().spirit.active=true
	check(fairy.city_service("rest").is_empty() and fairy.hero().natural_energy_current==20 and not fairy.hero().spirit.active,"Paid city recovery restores Nature Energy and dismisses spirit")
	print("HOMELAND CEREMONIES: %d checks, %d failures. Actual one-time weapon exchange, three blessing effects, combat and JSON persistence; access/grid estimates explicit." % [checks,failures])
	quit(1 if failures else 0)
