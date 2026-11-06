extends SceneTree
## Pure helper verification; conversion coefficients are explicit estimates.
const Rules = preload("res://game/stat_combat_rules.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	for kind: String in ["physical","fire","cold","poison","dark","mana","ground","solar","lightning"]: check(Rules.supports_damage_kind(kind),"Known damage category retained: "+kind)
	check(not Rules.supports_damage_kind("unverified") and not Rules.supports_damage_kind(""),"Unknown categories are not silently given semantics")
	check(Rules.sensitivity_multiplier(0) == 1.0,"Zero sensitivity preserves damage baseline")
	check(Rules.sensitivity_multiplier(50) == 1.5 and Rules.sensitivity_multiplier(-50) == 0.5,"Estimated sensitivity curve preserves signed points")
	check(Rules.sensitivity_multiplier(-1000000) == 0.1 and Rules.sensitivity_multiplier(1000000) == 5.0,"Sensitivity factor obeys explicit bounds")
	for value: float in [NAN,INF,-INF]: check(Rules.sensitivity_multiplier(value) == 1.0,"Nonfinite sensitivity safely preserves baseline")
	check(Rules.mana_sensitivity_multiplier(0) == 1.0,"Zero Mana Sensitivity preserves spell baseline")
	check(Rules.mana_sensitivity_multiplier(50) == 1.5 and Rules.mana_sensitivity_multiplier(-50) == 0.5,"Mana Sensitivity uses the authorized signed spell-power estimate")
	check(Rules.mana_sensitivity_multiplier(-1000000) == 0.1 and Rules.mana_sensitivity_multiplier(1000000) == 5.0,"Estimated Mana Sensitivity spell factor remains bounded")
	for value: float in [NAN,INF,-INF]: check(Rules.mana_sensitivity_multiplier(value) == 1.0,"Nonfinite Mana Sensitivity preserves baseline")
	var slash: Dictionary = {"category":"weapon","weapon_style":"slashing","damage_type":"physical"}
	var before: Dictionary = slash.duplicate(true)
	check(Rules.cutting_multiplier(50,slash) == 1.5 and Rules.cutting_multiplier(0,slash) == 1.0,"Cutting Force scales an explicitly slashing physical weapon hit")
	check(slash == before,"Cutting query does not mutate context")
	for changes: Dictionary in [{"category":"spell"},{"category":"secondary"},{"weapon_style":"blunt"},{"weapon_style":"piercing"},{"damage_type":"cold"},{"fixed":true},{"fixed_damage":4},{"dot":true},{"secondary":true}]:
		var context: Dictionary = slash.duplicate(true); context.merge(changes,true)
		check(Rules.cutting_multiplier(50,context) == 1.0,"Cutting Force cannot affect unrelated or bypass damage: "+str(changes))
	check(Rules.cutting_multiplier(50,{}) == 1.0,"Missing weapon classification never guesses a cutting bonus")
	var rng := RandomNumberGenerator.new(); rng.seed = 7213
	var state_before: int = rng.state
	var weapon: Dictionary = {"category":"weapon"}
	var result: Dictionary = Rules.critical(0,1.5,rng,weapon)
	check(result.critical == false and result.multiplier == 1.0 and result.roll == null and rng.state == state_before,"Zero critical chance consumes no RNG and changes no damage")
	for chance: float in [-100,NAN,INF,-INF]:
		result = Rules.critical(chance,1.5,rng,weapon)
		check(not result.critical and result.roll == null and rng.state == state_before,"Invalid or nonpositive critical chance cannot alter baseline RNG")
	for context: Dictionary in [{},{"category":"spell"},{"category":"secondary"},{"category":"weapon","normal_attack":false},{"category":"weapon","fixed":true},{"category":"weapon","fixed_damage":20},{"category":"weapon","dot":true},{"category":"weapon","secondary":true}]:
		result = Rules.critical(50,2,rng,context)
		check(not result.critical and result.multiplier == 1.0 and result.roll == null and rng.state == state_before,"Ineligible damage consumes no critical RNG: "+str(context))
	result = Rules.critical(100,2.5,rng,weapon)
	check(result.critical and result.multiplier == 2.5 and result.roll == null and rng.state == state_before,"Guaranteed chance uses the caller's target-specific critical factor without unnecessary RNG")
	check(Rules.critical(200,200,rng,weapon).multiplier == 10.0,"Chance and critical factor respect explicit upper bounds")
	check(Rules.critical(100,0.5,rng,weapon).multiplier == 1.0,"A critical factor cannot turn a critical into reduced damage")
	check(Rules.critical(100,NAN,rng,weapon).multiplier == 1.0,"Nonfinite critical factor cannot create nonfinite damage")
	check(not Rules.critical(50,2,null,weapon).critical,"Missing explicit RNG never invokes a hidden global RNG")
	var a := RandomNumberGenerator.new(); var b := RandomNumberGenerator.new(); a.seed = 384771; b.seed = 384771
	var successes: int = 0
	for index: int in range(100):
		var left: Dictionary = Rules.critical(35,1.7,a,weapon)
		var right: Dictionary = Rules.critical(35,1.7,b,weapon)
		check(left == right and a.state == b.state,"Explicit equal RNG states produce exactly equal critical rolls")
		if left.critical: successes += 1
	check(successes > 0 and successes < 100,"Seeded nontrivial chance includes both success and failure")
	check(weapon == {"category":"weapon"},"Critical helper leaves attack context untouched")
	check(Rules.pain_multiplier(0) == 1.0 and Rules.perceived_pain(20,0) == 20,"Zero Pain Resistance preserves perceived intensity")
	check(Rules.perceived_pain(20,100) == 10 and Rules.perceived_pain(20,-100) == 40,"Pain Resistance modifies sensory intensity in the sourced direction")
	check(Rules.pain_multiplier(1000000) == 0.1 and Rules.pain_multiplier(-1000000) == 5.0,"Estimated sensory curve remains bounded")
	check(Rules.perceived_pain(-1,0) == 0 and Rules.perceived_pain(INF,0) == 0,"Invalid pain input cannot create negative or nonfinite intensity")
	check(Rules.perceived_pain(20,NAN) == 20,"Malformed Pain Resistance preserves baseline perception")
	var unit: Dictionary = {"hp":20,"armor":4,"ap":2,"statuses":{"stunned":2},"pain_resistance":100}
	var unit_before: Dictionary = unit.duplicate(true)
	Rules.perceived_pain(20,float(unit.pain_resistance))
	check(unit == unit_before,"Pain calculation grants no HP, armor, AP, injury or status immunity")
	print("STAT COMBAT RULES: %d checks, %d failures. Point conversions and critical eligibility are reconstruction estimates." % [checks,failures])
	quit(1 if failures else 0)
