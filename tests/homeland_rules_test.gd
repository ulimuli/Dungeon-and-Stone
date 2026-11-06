extends SceneTree
## Test funds and selected seeds assist real campaign rites; no test rite grants.
const Sim = preload("res://game/simulation.gd")
const Rules = preload("res://game/homeland_rules.gd")
const Catalog = preload("res://game/homeland_catalog.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(ancestry: String = "human") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Homeland fixture",ancestry,"adventurer",34117)
	sim.state.gold=10000
	return sim
func point_for(ancestry: String, action: String) -> String:
	for point: Dictionary in Catalog.points(ancestry):
		if point.action==action: return point.id
	return ""
func unchanged_perform(sim: GameSimulation, action: String, id: String, point: String, label: String) -> void:
	var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	check(not Rules.perform(sim,action,id,point).ok,label+" rejects")
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,label+" preserves campaign and RNG")
func confirm(sim: GameSimulation, ancestry: String, action: String, id: String = "hero") -> Dictionary:
	var point: String=point_for(ancestry,action)
	var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	var response: Dictionary=Rules.interact(sim,point,id)
	check(response.get("ok",false) and response.get("confirm",false) and response.get("action")==action and response.get("point_id")==point and response.get("unit_id")==id,"NPC returns a concrete confirmation for "+action)
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,"Reviewing "+action+" commits no campaign mutation or RNG")
	return response
func commit(sim: GameSimulation, request: Dictionary) -> Dictionary:
	return Rules.perform(sim,request.action,request.unit_id,request.point_id)
func _initialize() -> void:
	_test_visits_and_discoveries()
	_test_barbarian_and_beastman_rites()
	_test_dwarf_services_and_training()
	_test_fairy_and_human_rites()
	_test_draconian_and_actor_guards()
	_test_validation_and_persistence()
	print("HOMELAND RULES: %d checks, %d failures. Six catalog lands share actual campaign inventory, rites, services, actors and saves; visitor access/layouts/operators are reconstruction choices." % [checks,failures])
	quit(1 if failures else 0)
func _test_visits_and_discoveries() -> void:
	var sim := fresh(); var rng_before: int=sim.rng.state; var gold: int=sim.state.gold
	Rules.ensure_state(sim)
	check(Rules.validate(sim.state).is_empty() and sim.state.homeland.location=="","City initializes optional homeland visit state")
	for ancestry: String in Catalog.ANCESTRIES:
		check(Rules.enter(sim,ancestry).is_empty(),"Visitor can enter authored "+ancestry+" location")
		check(sim.state.mode=="city" and sim.state.homeland.location==ancestry and sim.state.homeland.visited.has(ancestry),"Visit stays in the real city campaign and records the visited land")
		var point: String=point_for(ancestry,"lore")
		if not point.is_empty():
			var response: Dictionary=Rules.interact(sim,point)
			check(response.ok and response.open=="lore","Source observation opens readable homeland lore")
			var discoveries: int=sim.state.homeland.discoveries.size(); var journal: int=sim.state.journal.size(); var before: String=var_to_str(sim.state)
			check(Rules.interact(sim,point).ok and sim.state.homeland.discoveries.size()==discoveries and sim.state.journal.size()==journal and var_to_str(sim.state)==before,"Repeating an observation grants no extra record or farm reward")
	check(sim.state.homeland.visited.size()==6 and sim.state.gold==gold and sim.rng.state==rng_before,"Six visits and observations grant no money and consume no RNG")
	var visited: Array=sim.state.homeland.visited.duplicate(); var journal: int=sim.state.journal.size()
	check(Rules.enter(sim,"barbarian").is_empty() and sim.state.homeland.visited==visited and sim.state.journal.size()==journal,"Revisiting a land does not duplicate visit history")
	check(Rules.leave(sim).is_empty() and sim.state.homeland.location=="" and sim.state.homeland.selected=="hero","Leave returns to city while preserving discovery history")
	var before: String=var_to_str(sim.state)
	check(not Rules.enter(sim,"invented").is_empty() and var_to_str(sim.state)==before,"Unknown homeland rejects without mutation")
	check(not Rules.interact(sim,"barbarian_shaman").ok,"Interaction requires an active homeland visit")
	var outside := fresh(); check(outside.enter_region(1),"Dungeon access fixture enters expedition"); var outside_before: String=var_to_str(outside.state)
	Rules.ensure_state(outside)
	check(not Rules.enter(outside,"barbarian").is_empty() and var_to_str(outside.state)==outside_before,"Dungeon cannot create or enter a homeland overlay")
func _test_barbarian_and_beastman_rites() -> void:
	var barb := fresh("barbarian"); check(Rules.enter(barb,"barbarian").is_empty(),"Barbarian visits Sanctuary")
	var request: Dictionary=confirm(barb,"barbarian","undying")
	check("permanent" in request.message.to_lower() and "800" in request.message,"Undying review states path permanence and actual cost")
	var gold: int=barb.state.gold
	check(commit(barb,request).ok and barb.hero().racial.engraving_path=="undying" and barb.state.gold==gold-800,"Shaman commits the existing paid permanent Undying API")
	check(barb.state.homeland.used.get("barbarian:undying:hero",0)==1,"Successful rite feeds persistent homeland action history")
	unchanged_perform(barb,"undying","hero",request.point_id,"Repeat permanent engraving")
	var beast := fresh("beastman")
	check(beast.buy("frost_spirit_ring").is_empty() and beast.equip("frost_spirit_ring").is_empty(),"Beastman prepares actual No9425 ritual catalyst")
	check(beast.buy("sword").is_empty() and beast.equip("sword").is_empty(),"Beastman prepares another actual worn item")
	check(Rules.enter(beast,"beastman").is_empty(),"Beastman visits council homeland")
	request=confirm(beast,"beastman","skadia")
	check("ALL WORN EQUIPMENT" in request.message and "Sword" in request.message and "Ring" in request.message,"Skadia review enumerates all destructive worn-equipment losses")
	gold=beast.state.gold
	check(commit(beast,request).ok and beast.hero().racial.soul_beast=="skadia","Soul keeper commits the actual Skadia awakening")
	check(beast.hero().equipment.values().all(func(id: String)->bool:return id.is_empty()) and beast.state.inventory.get("sword",0)==0 and beast.state.gold==gold,"Ritual destroys worn items without refund or invented fee")
	var stale := fresh("barbarian"); Rules.enter(stale,"barbarian"); request=confirm(stale,"barbarian","undying"); Rules.enter(stale,"dwarf")
	unchanged_perform(stale,request.action,"hero",request.point_id,"Confirmation from a different homeland")
func _test_dwarf_services_and_training() -> void:
	var sim := fresh("dwarf"); Rules.enter(sim,"dwarf")
	var before: Array=[sim.hero().power,sim.hero().armor,sim.hero().equipment.duplicate(true)]
	var response: Dictionary=Rules.interact(sim,point_for("dwarf","artifact_blessing"))
	check(response.ok and response.open=="numbered" and "1.5" in response.message and "5%" in response.message,"Dwarf bench explains the supported artifact interaction")
	check(before==[sim.hero().power,sim.hero().armor,sim.hero().equipment] and not response.get("confirm",false),"Artifact inspection grants no invented ordinary-item blessing")
	sim.hero().durability=20; var request: Dictionary=confirm(sim,"dwarf","repair"); var gold: int=sim.state.gold
	check(commit(sim,request).ok and sim.hero().durability==100 and sim.state.gold==gold-6,"Dwarf smith calls actual paid party equipment repair")
	sim.hero().hp=1; sim.hero().energy=0; request=confirm(sim,"dwarf","training"); gold=sim.state.gold
	var xp: int=sim.state.xp; var strength: int=sim.hero().str
	check(commit(sim,request).ok and sim.hero().hp==sim.hero().max_hp and sim.hero().energy==sim.hero().max_energy and sim.state.gold==gold-6,"Coached recovery has an actual paid resource effect through the existing rest service")
	check(sim.state.xp==xp and sim.hero().str==strength,"Repeatable training service grants no farmable XP or permanent statistics")
	unchanged_perform(sim,"repair","hero",point_for("dwarf","training"),"Forged point/action confirmation pair")
func _test_fairy_and_human_rites() -> void:
	var fairy := fresh("fairy"); Rules.enter(fairy,"fairy")
	var request: Dictionary=confirm(fairy,"fairy","spirit_lesson"); var gold: int=fairy.state.gold
	check(commit(fairy,request).ok and fairy.hero().natural_energy_current==20 and fairy.state.gold==gold-120 and fairy.state.day==4,"Homeland tutor applies actual Fire contract, Natural Energy, tuition and elapsed days")
	check(fairy.buy("spirit_stone").is_empty(),"Fairy purchases actual additional-spirit catalyst")
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,10000):
		probe.seed=candidate
		if probe.randi_range(1,100)==10: fairy.rng.seed=candidate; break
	request=confirm(fairy,"fairy","spirit_stone")
	check("failure" in request.message and "10%" in request.message,"Spirit Stone review explains consumption and chance")
	check(commit(fairy,request).ok and fairy.hero().wind_contract and not fairy.state.inventory.has("spirit_stone"),"Stone keeper applies actual seeded Wind contract and catalyst loss")
	check(fairy.buy("bow").is_empty() and fairy.equip("bow").is_empty(),"Fairy prepares actual Wind bow")
	request=confirm(fairy,"fairy","wind_guidance")
	check(commit(fairy,request).ok and fairy.hero().wind_guidance,"Wind guide toggles the existing live bow consumer")
	var human := fresh("human")
	for candidate: int in range(1,100):
		if ProfessionRules.assessment(human.hero(),candidate)=="limited": human.state.seed=candidate; break
	Rules.enter(human,"human"); request=confirm(human,"human","magic_assess"); gold=human.state.gold
	check(commit(human,request).ok and human.hero().magic_assessment=="limited" and human.state.gold==gold-10 and human.state.day==4,"Human assessor applies existing identity-based aptitude and assessment time/cost")
	request=confirm(human,"human","magic_study"); gold=human.state.gold
	check(commit(human,request).ok and human.hero().profession=="mage" and human.hero().spells.has("ice_spear") and not human.hero().can_absorb_essences,"Human tutor applies the actual mage transition, spell and essence restriction")
	check(human.state.gold==gold-600 and human.state.month==2 and human.state.day==4,"Magic study preserves real tuition and30-day city calendar")
func _test_draconian_and_actor_guards() -> void:
	var dragon := fresh("draconian"); Rules.enter(dragon,"draconian")
	var request: Dictionary=confirm(dragon,"draconian","dragon_fear")
	check(commit(dragon,request).ok and not dragon.hero().dragon_fear_enabled,"Temple mentor suppresses actual innate Dragon Fear")
	request=confirm(dragon,"draconian","dragon_fear")
	check(commit(dragon,request).ok and dragon.hero().dragon_fear_enabled,"Temple mentor can restore existing Dragon Fear")
	var human := fresh(); Rules.enter(human,"barbarian")
	var before: String=var_to_str(human.state)
	check(not Rules.interact(human,point_for("barbarian","undying")).ok and var_to_str(human.state)==before,"Visitors cannot perform another race's rite")
	unchanged_perform(human,"undying","hero",point_for("barbarian","undying"),"Direct wrong-race rite")
	check(human.recruit("barbarian_warrior").is_empty(),"Visitor recruits a real Barbarian actor")
	var actor: Dictionary=human.state.party[0]
	check(Rules.select_actor(human,actor.id).is_empty() and human.state.homeland.selected==actor.id,"Homeland actor selection supports living active companions")
	request=confirm(human,"barbarian","undying",actor.id)
	check(commit(human,request).ok and actor.racial.engraving_path=="undying" and not human.hero().has("racial"),"NPC rite affects selected eligible companion rather than the hero")
	actor.hp=0
	unchanged_perform(human,"undying",actor.id,request.point_id,"Fallen selected actor")
	Rules.ensure_state(human)
	check(human.state.homeland.selected=="hero","City state repairs a homeland actor selection after the actor becomes unavailable")
func _test_validation_and_persistence() -> void:
	check(Rules.validate({}).is_empty(),"Legacy saves need no homeland field")
	var sim := fresh(); Rules.enter(sim,"human"); Rules.interact(sim,point_for("human","lore"))
	sim.state.homeland["positions"]={"human":Vector2i(1,1)}
	var restored := Sim.new()
	check(Rules.validate(sim.state).is_empty() and restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Optional homeland visits, discoveries and positions survive actual city JSON save")
	check(Rules.validate(restored.state).is_empty() and restored.state.homeland.location=="human" and restored.state.homeland.positions.human==Vector2i(1,1),"Restored homeland state preserves active map identity and position")
	for changes: Dictionary in [{"location":"invented"},{"location":1},{"selected":[]},{"selected":"missing"},{"visited":["human","human"]},{"visited":["invented"]},{"discoveries":["human:missing"]},{"used":[]},{"used":{"human:magic_assess:hero":-1}},{"used":{"human:magic_assess:hero":INF}},{"positions":{"human":Vector2i(38,1)}},{"positions":{"human":Vector2i(1,17)}},{"extra":1}]:
		var state: Dictionary=sim.state.duplicate(true); state.homeland.merge(changes,true)
		var before: String=var_to_str(state)
		check(not Rules.validate(state).is_empty() and var_to_str(state)==before,"Malformed homeland payload rejects without mutation: "+str(changes))
	for changes: Dictionary in [{"id":1},{"team":1},{"dead":1},{"summon":1},{"hp":NAN}]:
		var state: Dictionary=sim.state.duplicate(true); state.hero.merge(changes,true)
		var before: String=var_to_str(state)
		check(not Rules.validate(state).is_empty() and var_to_str(state)==before,"Malformed selected actor rejects without a type-comparison exception")
	var bad: Dictionary=sim.state.duplicate(true); bad.mode="dungeon"
	check(not Rules.validate(bad).is_empty(),"Active homeland location cannot leak into dungeon mode")
	var raw: Dictionary=sim.state.duplicate(true); raw.homeland=null
	check(not Rules.validate(raw).is_empty(),"Non-object homeland payload rejects safely")
