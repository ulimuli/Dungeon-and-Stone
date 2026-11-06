extends SceneTree
## Pure tests of confirmed effects and explicitly provisional interpretations.
## No campaign, RNG, persistent storage or natural progression is used.
const Mental = preload("res://game/stat_mental_rules.gd")
const Rules = preload("res://game/stat_rules.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_test_luck()
	_test_durations()
	_test_boundaries()
	_test_provisional_consumers()
	print("STAT MENTAL RULES: %d checks, %d failures. Confirmed and provisional effects labeled separately; numerical curves are estimates. No save files used." % [checks, failures])
	quit(1 if failures else 0)

func _test_luck() -> void:
	check(Mental.derived_modifiers({}).is_empty(), "Zero Luck adds no provenance noise")
	var fixture: Dictionary = {"luck":40.0,"future_unknown_stat":500,"distrust":-60,"possessiveness":900}
	var before: Dictionary = fixture.duplicate(true)
	var mods: Array[Dictionary] = Mental.derived_modifiers(fixture)
	check(fixture == before, "Derived modifier calculation preserves input values")
	check(mods.size() == 1, "Non-derived fields do not produce implicit modifiers")
	check(mods[0].id == "derived:luck:critical_chance" and mods[0].source == "derived:luck", "Luck has stable modifier and provenance IDs")
	check(mods[0].stat == "critical_chance" and mods[0].op == "add" and is_equal_approx(float(mods[0].value), 2.0), "Luck estimate uses percentage points rather than a second multiplier")
	check(Mental.derived_modifiers(fixture) == mods, "Repeated derived evaluation is deterministic")
	check(Mental.derived_modifiers({"luck":0.000001}).size() == 1, "Small finite Luck is not discarded by an arbitrary approximate-zero threshold")
	var registry: Dictionary = {"critical_chance":{"default":5.0,"min":0.0,"max":95.0,"rounding":"none"}}
	var positive: Dictionary = Rules.evaluate({}, mods, registry)
	check(positive.errors.is_empty() and positive.values.critical_chance == 7.0, "Luck integrates with the shared evaluator and preserves its base chance")
	var negative: Dictionary = Rules.evaluate({}, Mental.derived_modifiers({"luck":-200}), registry)
	check(negative.errors.is_empty() and negative.values.critical_chance == 0.0, "Negative Luck lowers actual critical chance without allowing a negative chance")
	var capped: Dictionary = Rules.evaluate({}, Mental.derived_modifiers({"luck":1000000}), registry)
	check(capped.errors.is_empty() and capped.values.critical_chance == 95.0, "Critical chance uses the caller registry cap")
	check(positive.breakdown.critical_chance.sources[0].id == mods[0].id, "Luck contribution remains visible in shared provenance")

func _test_durations() -> void:
	for status_id: String in Mental.HARMFUL_STATUSES:
		check(Mental.incoming_duration(status_id, 7, {}) == 7, "Zero stats preserve duration exactly: " + status_id)
		check(Mental.incoming_duration(status_id, 8, {"adaptability":100}) == 4, "Adaptability affects harmful duration: " + status_id)
		if status_id != "frightened":
			check(Mental.incoming_duration(status_id, 8, {"control":100}) == 8, "Control does not become a resistance to nonmental status: " + status_id)
	check(Mental.incoming_duration("frightened", 8, {"control":100}) == 4, "Control shortens fear through the estimated curve")
	check(Mental.incoming_duration("frightened", 8, {"adaptability":100,"control":100}) == 2, "Control and Adaptability compose once each")
	check(Mental.incoming_duration("poison", 3, {"adaptability":100}) == 2, "Positive fractional durations round upward")
	check(Mental.incoming_duration("frightened", 10, {"control":-30}) == 13, "Negative Control extends fear in the sourced reverse direction")
	check(Mental.incoming_duration("frightened", 10, {"control":-1000000}) == 100, "Estimated negative Control penalty has a tenfold safety cap")
	check(Mental.incoming_duration("frightened", 10, {"adaptability":100,"control":-100}) == 10, "Adaptability and Control penalty compose without duplicated duration application")
	for status_id: String in ["ward","transformed","stealth","concealed","status_immunity","unknown_future_status",""]:
		check(Mental.incoming_duration(status_id, 8, {"adaptability":100,"control":100}) == 8, "Beneficial or unknown status remains unchanged: " + status_id)

func _test_boundaries() -> void:
	var fixture: Dictionary = {"adaptability":100,"control":-50}
	var before: Dictionary = fixture.duplicate(true)
	Mental.incoming_duration("frightened", 7, fixture)
	check(fixture == before, "Incoming duration calculation preserves input values")
	check(Mental.incoming_duration("poison", 9, {"adaptability":-100}) == 9, "Negative Adaptability has no invented penalty")
	for base: int in [0,-1,-100]:
		check(Mental.incoming_duration("frightened", base, fixture) == base, "Nonpositive duration remains an invalid application")
	for status_id: String in Mental.HARMFUL_STATUSES:
		check(Mental.incoming_duration(status_id, 1, {"adaptability":1000000,"control":1000000}) == 1, "Even extreme stats do not grant status immunity: " + status_id)
	for invalid: Variant in [true,"100",null,NAN,INF,-INF,{},[]]:
		check(Mental.derived_modifiers({"luck":invalid}).is_empty(), "Invalid Luck is ignored safely")
		check(Mental.incoming_duration("frightened", 7, {"adaptability":invalid,"control":invalid}) == 7, "Invalid duration stats preserve compatibility")
	check(Mental.incoming_duration("frightened", 9223372036854775807, {}) == 9223372036854775807, "Zero stats preserve even the exact int64 boundary")
	check(Mental.incoming_duration("frightened", 9223372036854775807, {"control":-100}) == 9223372036854775807, "Extreme duration saturates instead of overflowing")
	check(Mental.incoming_duration("frightened", 30, {"control":-1.0e308,"adaptability":1.0e308}) == 1, "Finite extreme input cannot overflow duration arithmetic")

func _test_provisional_consumers() -> void:
	var expected: Dictionary = {
		"perception":{"accuracy":5.0}, "cognition":{"initiative":5.0},
		"cognitive_interference":{"evasion":5.0}, "dexterity":{"accuracy":2.0},
		"obsession":{"accuracy":-2.0,"critical_chance":1.0},
		"impulse":{"attack":2.0,"accuracy":-4.0}
	}
	for id: String in expected:
		var values: Dictionary = {id:20.0}
		var before: Dictionary = values.duplicate(true)
		var mods: Array[Dictionary] = Mental.derived_modifiers(values)
		check(values == before and mods == Mental.derived_modifiers(values), "Provisional conversion is pure and deterministic: " + id)
		check(mods.size() == expected[id].size(), "Provisional stat has exactly the declared tradeoff fields: " + id)
		for mod: Dictionary in mods:
			check(expected[id].has(mod.stat) and is_equal_approx(float(mod.value), float(expected[id].get(mod.stat, NAN))), "Provisional coefficient matches its declared units: " + id + "/" + str(mod.stat))
			check(mod.source == "derived:" + id and mod.id == "derived:" + id + ":" + str(mod.stat) and mod.op == "add", "Every provisional contribution has stable provenance: " + id)
		var negative: Array[Dictionary] = Mental.derived_modifiers({id:-20.0})
		for index: int in range(mods.size()):
			check(is_equal_approx(float(negative[index].value), -float(mods[index].value)), "Signed points reverse the declared tradeoff: " + id)
	var all_values: Dictionary = {"luck":20,"perception":20,"cognition":20,"cognitive_interference":20,"dexterity":20,"obsession":20,"impulse":20,"distrust":20}
	var registry: Dictionary = {}
	for id: String in ["critical_chance","accuracy","initiative","evasion","attack","natural_recovery"]:
		registry[id] = {"default":1.0 if id == "natural_recovery" else 10.0,"min":0.0,"max":100.0,"rounding":"none"}
	var combined: Array[Dictionary] = Mental.derived_modifiers(all_values)
	check(Rules.validate_modifiers(combined, registry).is_empty(), "All derived mental sources coexist without duplicate IDs or unsupported operations")
	var evaluated: Dictionary = Rules.evaluate({}, combined, registry)
	check(evaluated.errors.is_empty() and evaluated.values.accuracy == 11.0 and evaluated.values.attack == 12.0, "Shared evaluation combines positive bonuses and provisional tradeoffs exactly once")
	check(evaluated.values.critical_chance == 12.0 and evaluated.values.initiative == 15.0 and evaluated.values.evasion == 15.0, "Mental derived values reach their actual target stat IDs")
	for points: float in [0.0,-10.0]:
		check(Mental.derived_modifiers({"distrust":points}).is_empty(), "Nonpositive Distrust preserves baseline recovery")
	var previous_recovery: float = 1.0
	for points: float in [1.0,20.0,100.0,300.0,1000000.0,1.0e308]:
		var mods: Array[Dictionary] = Mental.derived_modifiers({"distrust":points})
		var recovery: float = float(mods[0].value)
		check(mods[0].op == "multiply" and recovery <= previous_recovery and recovery >= 0.25 and recovery <= 1.0, "Distrust recovery penalty is monotonic and bounded")
		previous_recovery = recovery
	check(previous_recovery == 0.25, "Distrust cannot suppress recovery below one quarter")
	check(Mental.incoming_duration("frightened", 8, {"fighting_spirit":100}) == 4, "Positive Fighting Spirit provisionally resists fear")
	check(Mental.incoming_duration("frightened", 10, {"fighting_spirit":-100}) == 20, "Negative Fighting Spirit provisionally extends fear")
	check(Mental.incoming_duration("frightened", 10, {"fighting_spirit":-1000000,"control":-1000000}) == 100, "Combined fear-specific extension retains its tenfold safety cap")
	check(Mental.incoming_duration("frightened", 16, {"fighting_spirit":100,"control":100,"adaptability":100}) == 2, "Morale, Control and Adaptability each contribute once")
	for id: String in Mental.HARMFUL_STATUSES:
		if id != "frightened": check(Mental.incoming_duration(id, 10, {"fighting_spirit":100}) == 10, "Morale does not become a blanket status resistance: " + id)
	var prior_duration: int = 0
	for points: float in [-100.0,0.0,0.1,20.0,20.1,100.0,120.0,1000000.0,1.0e308]:
		var duration: int = Mental.attachment_duration({"possessiveness":points})
		check(duration >= prior_duration and duration >= 0 and duration <= 6, "Provisional gear attachment is monotonic and bounded")
		prior_duration = duration
	check(Mental.attachment_duration({}) == 0 and Mental.attachment_duration({"possessiveness":20}) == 1 and Mental.attachment_duration({"possessiveness":20.1}) == 2, "Attachment duration keeps zero baseline and rounds positive partial turns upward")
	check(Mental.incoming_duration("distressed", 6, {"adaptability":100}) == 3, "Adaptability treats provisional distress as a harmful status")
	var ids: Array[String] = ["luck","control","adaptability","perception","cognition","cognitive_interference","dexterity","obsession","impulse","distrust","fighting_spirit","possessiveness","sixth_sense","absorption"]
	var notes: Dictionary = Mental.provisional_notes()
	for id: String in ids:
		check(notes.has(id) and not str(notes[id].proven_effect).is_empty() and not str(notes[id].provisional_effect).is_empty() and bool(notes[id].experimental_balance) and not notes[id].reference_urls.is_empty(), "Mental mechanics label evidence separately from provisional interpretation: " + id)
		notes[id].provisional_effect = "changed by caller"
	check(Mental.provisional_notes().luck.provisional_effect != "changed by caller", "Provisional note metadata cannot be globally mutated by a caller")
	for invalid: Variant in [true,"100",null,NAN,INF,-INF,{},[]]:
		var values: Dictionary = {}
		for id: String in ids: values[id] = invalid
		check(Mental.derived_modifiers(values).is_empty() and Mental.attachment_duration(values) == 0 and Mental.incoming_duration("frightened", 10, values) == 10, "Nonfinite or nonnumeric provisional inputs preserve baseline")
