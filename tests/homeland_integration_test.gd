extends SceneTree
## Funds and seed selection are explicit test assistance. All actor routes,
## visitor permissions, service coefficients and compact maps are provisional.
## Tests use actual Sim commands, dynamic map geometry and campaign saves.
const Sim = preload("res://game/simulation.gd")
const Catalog = preload("res://game/homeland_catalog.gd")
const Map = preload("res://game/homeland_map.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func fresh(ancestry: String = "human") -> GameSimulation:
	var sim := Sim.new()
	sim.new_campaign("Homeland integration",ancestry,"adventurer",34117)
	sim.state.gold=10000
	return sim
func point_for(land: String, action: String) -> Dictionary:
	for point: Dictionary in Map.layout_for(land).interactables:
		if point.action==action: return point
	return {}
func legal(layout: Dictionary, position: Vector2i) -> bool:
	if not layout.walkable.has(position) or position==layout.exit: return false
	for point: Dictionary in layout.interactables:
		if point.cell==position: return false
	return true
func approach(sim: GameSimulation, point_id: String) -> bool:
	var layout: Dictionary=Map.layout_for(sim.state.homeland.location)
	var point: Dictionary={}
	for row: Dictionary in layout.interactables:
		if row.id==point_id: point=row
	if point.is_empty(): check(false,"Requested real map point exists"); return false
	var origin: Vector2i=sim.homeland_position()
	var queue: Array[Vector2i]=[origin]; var previous: Dictionary={origin:origin}; var cursor: int=0; var destination: Vector2i=Vector2i(-1,-1)
	while cursor<queue.size():
		var current: Vector2i=queue[cursor]; cursor+=1
		if absi(current.x-point.cell.x)+absi(current.y-point.cell.y)<=1: destination=current; break
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var candidate: Vector2i=current+direction
			if legal(layout,candidate) and not previous.has(candidate): previous[candidate]=current; queue.append(candidate)
	if destination.x<0: check(false,"A legal route reaches actual map point "+point_id); return false
	var route: Array[Vector2i]=[]; var current: Vector2i=destination
	while current!=origin: route.push_front(current); current=previous[current]
	var moved: bool=true
	for position: Vector2i in route:
		if not sim.record_homeland_position(position): moved=false; break
	check(moved and sim.homeland_position()==destination,"Actual recorded neighbor route reaches "+point_id)
	return moved
func request(sim: GameSimulation, action: String, actor: String = "hero") -> Dictionary:
	var point: Dictionary=point_for(sim.state.homeland.location,action)
	if point.is_empty(): check(false,"Real homeland offers "+action); return {}
	if not approach(sim,point.id): return {}
	var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	var response: Dictionary=sim.homeland_interact(point.id,actor)
	check(response.get("ok",false) and response.get("confirm",false),"Nearby real NPC offers reviewable "+action)
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,"Reviewing actual rite commits no action, payment or RNG")
	return response
func commit(sim: GameSimulation, response: Dictionary) -> Dictionary:
	if response.is_empty(): return {"ok":false}
	return sim.homeland_perform(response.action,response.unit_id,response.point_id)
func rejected_commit(sim: GameSimulation, response: Dictionary, label: String) -> void:
	var before: String=var_to_str(sim.state); var rng_before: int=sim.rng.state
	check(not commit(sim,response).ok,label+" rejects")
	check(var_to_str(sim.state)==before and sim.rng.state==rng_before,label+" preserves campaign and RNG")
func roundtrip(sim: GameSimulation, label: String) -> GameSimulation:
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),label+" survives actual JSON validation/restore")
	return restored
func _initialize() -> void:
	_test_six_maps_and_all_points()
	_test_actual_rites_and_proximity()
	_test_companion_persistence_and_stale_actions()
	_test_corruption_and_legacy()
	_test_expedition_lifecycle()
	print("HOMELAND INTEGRATION: %d checks, %d failures. Real city/home/expedition commands, dynamic walking routes, NPC rites and validated saves exercised." % [checks,failures])
	quit(1 if failures else 0)
func _test_six_maps_and_all_points() -> void:
	for ancestry: String in Catalog.ANCESTRIES:
		var sim := fresh(ancestry); var rng_before: int=sim.rng.state; var gold: int=sim.state.gold; var xp: int=sim.state.xp
		check(sim.enter_homeland(ancestry).is_empty(),"Actual wrapper enters "+ancestry+" homeland")
		var layout: Dictionary=Map.layout_for(ancestry)
		check(sim.homeland_position()==layout.entrance and layout.interactables.size()==6,"Actual homeland begins at its map entrance with six active points")
		for position: Vector2i in [Vector2i(-1,1),layout.exit,layout.interactables[0].cell,layout.buildings[0].rect.position]:
			var before: String=var_to_str(sim.state)
			check(not sim.record_homeland_position(position) and var_to_str(sim.state)==before,"Movement recorder rejects bounds/exit/person/solid geometry atomically")
		for point: Dictionary in layout.interactables:
			check(approach(sim,point.id),"A legal route exists to every "+ancestry+" map point")
			var result: Dictionary=sim.homeland_interact(point.id,"hero")
			check(result.get("ok",false),"Actual nearby point responds: "+point.id)
			if point.action in ["lore","artifact_blessing"]:
				check(sim.state.homeland.discoveries.has(ancestry+":"+point.id),"Observation records actual campaign discovery")
				var before: String=var_to_str(sim.state)
				check(sim.homeland_interact(point.id).ok and var_to_str(sim.state)==before,"Repeated discovery is idempotent and offers no farm reward")
		check(sim.state.gold==gold and sim.state.xp==xp and sim.rng.state==rng_before,"Walking, observation and rite previews grant no money/XP and consume no RNG")
		var saved_position: Vector2i=sim.homeland_position()
		check(sim.leave_homeland().is_empty() and sim.enter_homeland(ancestry).is_empty() and sim.homeland_position()==saved_position,"Leaving/revisiting preserves the actual homeland walking position")
func _test_actual_rites_and_proximity() -> void:
	var barb := fresh("barbarian"); barb.enter_homeland("barbarian")
	var shaman: Dictionary=point_for("barbarian","undying")
	var before: String=var_to_str(barb.state); var rng_before: int=barb.rng.state
	check(not barb.homeland_interact(shaman.id).ok and not barb.homeland_perform("undying","hero",shaman.id).ok and var_to_str(barb.state)==before and barb.rng.state==rng_before,"Distant shaman cannot preview or perform a rite through wrappers")
	var response: Dictionary=request(barb,"undying"); var gold: int=barb.state.gold; barb.hero().hp=7
	check(commit(barb,response).ok and barb.hero().racial.engraving_path=="undying" and barb.state.gold==gold-800 and barb.hero().hp==7,"Nearby shaman performs actual paid permanent Undying without healing")
	rejected_commit(barb,response,"Duplicate permanent engraving")
	var beast := fresh("beastman"); check(beast.buy("frost_spirit_ring").is_empty() and beast.equip("frost_spirit_ring").is_empty(),"Actual Skadia catalyst is purchased and worn")
	check(beast.buy("sword").is_empty() and beast.equip("sword").is_empty(),"Destructive ritual fixture prepares another actual worn item")
	beast.enter_homeland("beastman"); response=request(beast,"skadia"); beast.hero().hp=7
	check("ALL WORN EQUIPMENT" in response.message and "Sword" in response.message,"Nearby rite exposes the concrete full equipment loss before confirmation")
	check(commit(beast,response).ok and beast.hero().racial.soul_beast=="skadia" and beast.hero().equipment.values().all(func(id: String)->bool:return id.is_empty()) and beast.hero().hp==7,"Nearby soul keeper performs real destruction/awakening without health refill")
	rejected_commit(beast,response,"Duplicate awakening without ring")
	var dwarf := fresh("dwarf"); dwarf.enter_homeland("dwarf"); dwarf.hero().durability=10
	response=request(dwarf,"repair"); gold=dwarf.state.gold
	check(commit(dwarf,response).ok and dwarf.hero().durability==100 and dwarf.state.gold==gold-6,"Nearby Dwarf smith repairs actual durability for existing service price")
	dwarf.hero().hp=1; var xp_before: int=dwarf.state.xp; var strength_before: int=dwarf.hero().str
	response=request(dwarf,"training"); gold=dwarf.state.gold
	check(commit(dwarf,response).ok and dwarf.hero().hp==dwarf.hero().max_hp and dwarf.state.gold==gold-6 and dwarf.state.xp==xp_before and dwarf.hero().str==strength_before,"Nearby coached recovery is a real paid service without farmable XP or permanent stats")
	var fairy := fresh("fairy"); fairy.enter_homeland("fairy"); response=request(fairy,"spirit_lesson"); fairy.hero().hp=7; gold=fairy.state.gold
	check(commit(fairy,response).ok and fairy.hero().natural_energy_current==20 and fairy.state.gold==gold-120 and fairy.state.day==4 and fairy.hero().hp==7,"Nearby Fairy tutor performs actual time/cost/resource contract without HP refill")
	rejected_commit(fairy,response,"Duplicate Fire contract")
	check(fairy.buy("spirit_stone").is_empty(),"Additional homeland rite purchases a real catalyst")
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1,10000):
		probe.seed=candidate
		if probe.randi_range(1,100)==10: fairy.rng.seed=candidate; break
	response=request(fairy,"spirit_stone")
	check(commit(fairy,response).ok and fairy.hero().wind_contract and not fairy.state.inventory.has("spirit_stone"),"Nearby stone keeper executes actual seeded additional-contract consumer")
	check(fairy.buy("bow").is_empty() and fairy.equip("bow").is_empty(),"Actual bow equips for homeland Wind guide")
	response=request(fairy,"wind_guidance")
	check(commit(fairy,response).ok and fairy.hero().wind_guidance,"Nearby guide activates actual bow Accuracy/Natural Energy behavior")
	var human := fresh("human")
	for candidate: int in range(1,100):
		if ProfessionRules.assessment(human.hero(),candidate)=="limited": human.state.seed=candidate; break
	human.enter_homeland("human"); response=request(human,"magic_assess"); gold=human.state.gold
	check(commit(human,response).ok and human.hero().magic_assessment=="limited" and human.state.gold==gold-10,"Nearby assessor applies actual paid aptitude record")
	rejected_commit(human,response,"Duplicate aptitude assessment")
	response=request(human,"magic_study"); gold=human.state.gold; human.hero().hp=7
	check(commit(human,response).ok and human.hero().profession=="mage" and human.hero().spells.has("ice_spear") and not human.hero().can_absorb_essences and human.state.gold==gold-600 and human.hero().hp==7,"Nearby tutor commits actual mage transition, spell and tuition without HP refill")
	rejected_commit(human,response,"Duplicate magic lessons")
	var dragon := fresh("draconian"); dragon.enter_homeland("draconian"); response=request(dragon,"dragon_fear")
	check(commit(dragon,response).ok and not dragon.hero().dragon_fear_enabled,"Nearby Dragon mentor suppresses the actual racial aura")
	response=request(dragon,"dragon_fear")
	check(commit(dragon,response).ok and dragon.hero().dragon_fear_enabled,"Dragon mentor releases the same actual controllable aura")
	var visitor := fresh("human"); visitor.enter_homeland("barbarian"); approach(visitor,shaman.id)
	before=var_to_str(visitor.state); rng_before=visitor.rng.state
	check(not visitor.homeland_interact(shaman.id).ok and not visitor.homeland_perform("undying","hero",shaman.id).ok and var_to_str(visitor.state)==before and visitor.rng.state==rng_before,"Nearby visitor cannot bypass racial eligibility by calling wrappers")
func _test_companion_persistence_and_stale_actions() -> void:
	var sim := fresh(); check(sim.recruit("barbarian_warrior").is_empty(),"Actual Barbarian companion recruits")
	var actor: Dictionary=sim.state.party[0]; var id: String=actor.id
	sim.enter_homeland("barbarian"); check(sim.select_homeland_actor(id).is_empty(),"Actual homeland wrapper selects a living companion")
	var response: Dictionary=request(sim,"undying",id)
	var saved_position: Vector2i=sim.homeland_position()
	var restored := roundtrip(sim,"Pending companion rite and walking position")
	check(restored.state.homeland.selected==id and restored.homeland_position()==saved_position and restored.state.homeland.visited.has("barbarian"),"JSON restores selected companion, route position and visit history")
	check(commit(restored,response).ok and restored.state.party[0].racial.engraving_path=="undying","Restored nearby companion receives actual rite")
	var history := roundtrip(restored,"Successful homeland history")
	check(history.state.homeland.used.get("barbarian:undying:"+id,0)==1,"Successful NPC action history survives validated save")
	var lore: Dictionary=point_for("barbarian","lore"); approach(history,lore.id); history.homeland_interact(lore.id,id)
	var observed := roundtrip(history,"Observed source landmark")
	check(observed.state.homeland.discoveries.has("barbarian:"+lore.id),"Actual source discovery survives validated save")
	var distancing := fresh("barbarian"); distancing.enter_homeland("barbarian"); var distant_request: Dictionary=request(distancing,"undying")
	check(approach(distancing,point_for("barbarian","return").id),"Test walks to the actual map return point after reviewing a rite")
	rejected_commit(distancing,distant_request,"Confirmation after walking away from its NPC")
	var stale := fresh(); stale.recruit("barbarian_warrior"); var companion: Dictionary=stale.state.party[0]
	stale.enter_homeland("barbarian"); stale.select_homeland_actor(companion.id); response=request(stale,"undying",companion.id)
	stale.leave_homeland(); rejected_commit(stale,response,"Confirmation after leaving homeland")
	stale.enter_homeland("barbarian"); approach(stale,response.point_id); companion.hp=0
	rejected_commit(stale,response,"Confirmation whose selected companion has fallen")
	companion.hp=10; stale.select_homeland_actor(companion.id); response=request(stale,"undying",companion.id)
	stale.dismiss(companion.id)
	check(stale.state.homeland.selected=="hero","Actual dismissal repairs homeland actor selection")
	rejected_commit(stale,response,"Confirmation whose participant left active party")
	var travel := fresh("barbarian"); travel.enter_homeland("barbarian"); response=request(travel,"undying"); travel.enter_homeland("dwarf")
	rejected_commit(travel,response,"Confirmation after changing homeland")
func _test_corruption_and_legacy() -> void:
	var sim := fresh(); sim.enter_homeland("human"); var lore: Dictionary=point_for("human","lore"); approach(sim,lore.id); sim.homeland_interact(lore.id)
	var restored := roundtrip(sim,"Valid visited homeland baseline")
	var layout: Dictionary=Map.layout_for("human")
	for changes: Dictionary in [{"positions":{"human":Vector2i(-1,1)}},{"positions":{"human":Vector2i(38,1)}},{"positions":{"human":layout.buildings[0].rect.position}},{"positions":{"human":layout.interactables[0].cell}},{"positions":{"human":layout.exit}},{"positions":{"invented":Vector2i(1,1)}},{"selected":"missing"},{"visited":["human","human"]},{"visited":["invented"]},{"discoveries":["human:missing"]},{"discoveries":["human:"+lore.id,"human:"+lore.id]},{"used":{"human:invented:hero":1}},{"used":{"human:magic_assess:hero":-1}},{"location":"invented"}]:
		var raw: Dictionary=sim.snapshot(); raw.homeland.merge(changes,true)
		var before: String=var_to_str(restored.state); var rng_before: int=restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed saved homeland rejects: "+str(changes))
		check(var_to_str(restored.state)==before and restored.rng.state==rng_before,"Rejected homeland restore preserves campaign and RNG")
	for changes: Dictionary in [{"team":{}},{"summon":[]},{"dead":{}}]:
		var raw_actor: Dictionary=sim.snapshot(); raw_actor.hero.merge(changes,true)
		var before_actor: String=var_to_str(restored.state); var rng_actor: int=restored.rng.state
		check(not restored.restore(raw_actor) and var_to_str(restored.state)==before_actor and restored.rng.state==rng_actor,"Malformed active homeland actor rejects without script errors or mutation: "+str(changes))
	var outside := fresh(); check(outside.enter_region(1),"Wrong-mode payload uses an otherwise real expedition")
	var raw: Dictionary=outside.snapshot(); raw["homeland"]={"location":"human","selected":"hero","visited":["human"],"discoveries":[],"used":{}}
	var before: String=var_to_str(restored.state); var rng_before: int=restored.rng.state
	check(not restored.restore(raw) and var_to_str(restored.state)==before and restored.rng.state==rng_before,"Active home location cannot load into an expedition or consume RNG")
	var legacy := fresh(); raw=legacy.snapshot(); raw.erase("homeland")
	var loaded := Sim.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(raw))) and loaded.enter_homeland("human").is_empty(),"Legacy save without optional homeland state loads and enters a real homeland")
func _test_expedition_lifecycle() -> void:
	var sim := fresh(); sim.enter_homeland("human")
	var before: String=var_to_str(sim.state.homeland); var rng_before: int=sim.rng.state
	check(not sim.enter_region(1) and sim.state.mode=="city" and var_to_str(sim.state.homeland)==before and sim.rng.state==rng_before,"Active homeland blocks Labyrinth entry without changing visit or RNG")
	check(sim.leave_homeland().is_empty() and sim.enter_region(1),"Leaving homeland allows actual expedition entry")
	check(sim.state.homeland.location=="" and not sim.record_homeland_position(Vector2i(1,1)),"Expedition cannot retain an active home or write home movement")
	sim.state.units=[]; sim.state.combat=false
	sim.state.time=sim.portal_limit()-1
	sim.advance_time(1)
	check(sim.state.mode=="city" and sim.state.homeland.location=="","Actual portal closure returns to city without reopening a stale homeland")
	check(sim.enter_homeland("human").is_empty(),"Returned campaign can revisit the homeland normally")
	roundtrip(sim,"Returned expedition homeland visit")
