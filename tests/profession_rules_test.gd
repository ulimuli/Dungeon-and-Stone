extends SceneTree
## Pure basic-human-magic eligibility; Simulation owns charges, days and spells.
const Rules = preload("res://game/profession_rules.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func fixture() -> Dictionary:
	return {"id":"candidate", "name":"A human", "ancestry":"human", "hp":12, "dead":false, "profession":"explorer", "essences":[], "gold":9999, "spells":[]}

func reject(unit: Dictionary, label: String, assess: bool = true, study: bool = true) -> void:
	var before: String = var_to_str(unit)
	if assess: check(not Rules.can_assess(unit).is_empty(), label + ": assessment rejected")
	if study: check(not Rules.can_study(unit).is_empty(), label + ": lessons rejected")
	check(var_to_str(unit) == before, label + ": eligibility is pure")

func _initialize() -> void:
	var human: Dictionary = fixture()
	var before: Dictionary = human.duplicate(true)
	check(Rules.can_assess(human).is_empty(), "Living unassessed human can be assessed")
	check(Rules.assessment(human, 42) == "none", "Fixed SHA256 seed42 candidate fixture")
	check(Rules.assessment(human, 43) == "limited", "Campaign seed changes aptitude for fixed identity")
	human.id = "unit_4"
	check(Rules.assessment(human, 42) == "limited", "Stable id changes aptitude for fixed campaign")
	human.id = "candidate"
	for cosmetic: String in ["Renamed", "", "candidate", "Érwen", "43:candidate"]:
		human.name = cosmetic
		check(Rules.assessment(human, 43) == "limited", "Cosmetic name cannot change aptitude")
	human.name = before.name
	check(human == before, "Assessment and eligibility do not mutate character")
	for seed_value: int in [0, 42, 43]:
		var count: int = 0
		for index: int in range(1000):
			var candidate: Dictionary = fixture()
			candidate.id = "unit_" + str(index)
			if Rules.assessment(candidate, seed_value) == "limited": count += 1
		var expected: int = {0:200, 42:230, 43:204}[seed_value]
		check(count == expected, "Independent SHA256 count fixture for seed " + str(seed_value))
	seed(98765)
	var expected_rng: int = randi()
	seed(98765)
	for iteration: int in range(20): Rules.assessment(human, iteration)
	check(randi() == expected_rng, "Assessment consumes no global/combat RNG draws")
	check(not Rules.can_study(human).is_empty(), "Unassessed human cannot take lessons")
	human.magic_assessment = "limited"
	check(Rules.can_study(human).is_empty(), "Suitable assessed human with no essences can study")
	check(Rules.validate(human).is_empty(), "Limited assessment is valid")
	reject(human, "Positive result cannot be reassessed", true, false)
	human.magic_assessment = "none"
	check(Rules.validate(human).is_empty(), "Negative assessment is a valid persistent result")
	reject(human, "Negative result cannot be rerolled or bypassed with wealth")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(human))
	reject(restored, "Negative assessment survives JSON save/load")
	human.profession = "mage"
	check(Rules.assessment(human, 42) == "limited", "Existing mage has demonstrated basic aptitude")
	check(not Rules.validate(human).is_empty(), "Existing mage with negative assessment is invalid")
	human.magic_assessment = "limited"
	check(Rules.validate(human).is_empty(), "Existing assessed mage remains valid")
	reject(human, "Mage cannot repeat assessment or buy profession again")
	var legacy: Dictionary = fixture()
	legacy.profession = "mage"
	check(Rules.validate(legacy).is_empty(), "Legacy mage may omit assessment")
	check(Rules.can_assess(legacy).is_empty(), "Unassessed human mage can record demonstrated talent")
	for race: String in ["barbarian", "fairy", "dwarf", "beastman", "draconian", "unknown", ""]:
		var other: Dictionary = fixture()
		other.ancestry = race
		other.magic_assessment = "limited"
		reject(other, "Other ancestry " + race)
		check(not Rules.validate(other).is_empty(), "Assessment on other ancestry is invalid")
		other.erase("magic_assessment")
		check(not Rules.can_assess(other).is_empty(), "Unassessed other ancestry is rejected")
	for health: Variant in [0, -1, NAN, INF, -INF, "12", [], {}, null, true]:
		var fallen: Dictionary = fixture()
		fallen.hp = health
		fallen.magic_assessment = "limited"
		reject(fallen, "Invalid/nonliving health " + str(health))
	for death: Variant in [true, "false", 0, null]:
		var fallen: Dictionary = fixture()
		fallen.dead = death
		fallen.magic_assessment = "limited"
		reject(fallen, "Death/malformed death flag " + str(death))
	for essence_record: Variant in [["canon_goblin"], null, {}, "", true]:
		var occupied: Dictionary = fixture()
		occupied.magic_assessment = "limited"
		occupied.essences = essence_record
		reject(occupied, "Occupied/malformed essence record", false, true)
	for malformed: Variant in ["", "LIMITED", "tower", "mage", 0, 1.0, true, null, [], {}]:
		var invalid: Dictionary = fixture()
		invalid.magic_assessment = malformed
		var snapshot: String = var_to_str(invalid)
		check(not Rules.validate(invalid).is_empty(), "Malformed assessment invalid: " + str(malformed))
		reject(invalid, "Malformed assessment cannot be rerolled or used")
		check(var_to_str(invalid) == snapshot, "Validation does not normalize malformed records")
	var unrelated: Dictionary = fixture()
	unrelated.future_field = {"keep":"untouched"}
	unrelated.racial = {"unknown":"outside scope"}
	check(Rules.validate(unrelated).is_empty(), "Validator leaves unrelated fields to their owners")
	check(Rules.ASSESSMENT_COST == 10 and Rules.ASSESSMENT_DAYS == 3, "Assessment numerical estimates explicit")
	check(Rules.TUITION_COST == 600 and Rules.TUITION_DAYS == 30, "Tuition numerical estimates explicit")
	check(Rules.TALENT_SOURCE.begins_with("https://") and Rules.ASSESSMENT_SOURCE.begins_with("https://") and Rules.TRAINING_SOURCE.begins_with("https://"), "Source URLs retained")
	for failure: String in failures: push_error(failure)
	print("PROFESSION RULES TEST: %d checks; %d failures. Basic human magic entry only; other careers remain unsupported." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
