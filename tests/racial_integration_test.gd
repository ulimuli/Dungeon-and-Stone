extends SceneTree
const Sim = preload("res://game/simulation.gd")
const Validator = preload("res://game/save_validation.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(race: String = "barbarian") -> GameSimulation:
	var sim := Sim.new(); sim.new_campaign("Engraving test",race,"adventurer",74119)
	sim.state.gold = 2000
	return sim
func stats(unit: Dictionary) -> Array:
	return [unit.str,unit.agi,unit.wit,unit.vig,unit.hp,unit.max_hp,unit.energy,unit.mana]
func safe_expedition(sim: GameSimulation) -> void:
	check(sim.enter_region(1),"Actual expedition entry")
	sim.state.units = []; sim.state.combat = false
	sim.hero().hp = int(sim.hero().max_hp)-20
func _init() -> void:
	var sim := fresh()
	var before: Array = stats(sim.hero())
	check(sim.learn_undying().is_empty(),"City sanctuary performs actual purchased engraving")
	check(int(sim.state.gold) == 1200 and sim.hero().racial.engraving_path == "undying","Exact displayed fee and permanent path recorded")
	check(stats(sim.hero()) == before,"Purchase does not invent Strength/health/resource bonuses or instant healing")
	var gold: int = sim.state.gold
	check(not sim.learn_undying().is_empty() and int(sim.state.gold) == gold,"Duplicate path rejects without charge")
	for race: String in ["human","fairy","dwarf","beastman","draconian"]:
		var other := fresh(race)
		check(not other.learn_undying().is_empty() and int(other.state.gold) == 2000,"No free or wrong-race engraving: "+race)
	var poor := fresh(); poor.state.gold = 799
	check(not poor.learn_undying().is_empty() and not poor.hero().has("racial"),"Insufficient currency preserves unset path")
	var baseline := fresh(); safe_expedition(baseline); safe_expedition(sim)
	var hp: int = sim.hero().hp; var plain_hp: int = baseline.hero().hp
	sim.advance_time(89); baseline.advance_time(89)
	check(int(sim.hero().hp) == hp and int(baseline.hero().hp) == plain_hp,"Natural healing respects the elapsed recovery interval")
	sim.advance_time(1); baseline.advance_time(1)
	check(int(sim.hero().hp) == hp+2 and int(baseline.hero().hp) == plain_hp+1,"Undying adds the explicitly estimated recovery bonus")
	sim.state.combat = true; hp = sim.hero().hp; sim.advance_time(90)
	check(int(sim.hero().hp) == hp,"No passive resting heal during combat")
	sim.state.combat = false; sim.state.food = 0; hp = sim.hero().hp; sim.advance_time(90)
	check(int(sim.hero().hp) == hp,"Starvation does not produce free natural healing")
	check(not sim.learn_undying().is_empty(),"Sanctuary unavailable inside dungeon")
	var restored := Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))),"Actual engraving survives validated JSON restore")
	check(restored.hero().racial.engraving_path == "undying","Restored path remains permanent")
	var city := fresh(); city.state.gold = 4000
	check(city.recruit("barbarian_warrior").is_empty(),"Generated Barbarian recruits normally")
	var id: String = city.state.party[0].id
	check(city.learn_undying(id).is_empty(),"Living recruited Barbarian can purchase same supported service")
	city.dismiss(id)
	check(restored.restore(JSON.parse_string(JSON.stringify(city.snapshot()))),"Benched engraving saves")
	check(restored.recruit("barbarian_warrior").is_empty() and restored.state.party[0].racial.engraving_level == 1,"Rejoining preserves paid engraving")
	for path: Variant in [42,{},[],true,"other"]:
		var raw: Dictionary = city.snapshot(); raw.hero.racial = {"engraving_path":path,"engraving_level":1}
		var saved: String = var_to_str(restored.state); var rng_state: int = restored.rng.state
		check(not Validator.validate(raw).is_empty() and not restored.restore(raw),"Malformed path rejected before state assignment")
		check(var_to_str(restored.state) == saved and restored.rng.state == rng_state,"Bad engraving leaves campaign and RNG unchanged")
	print("RACIAL INTEGRATION: %d checks, %d failures. Actual city fee, recovery, race guards, JSON and bench persistence; numerical conversion is provisional." % [checks,failures])
	quit(1 if failures else 0)
