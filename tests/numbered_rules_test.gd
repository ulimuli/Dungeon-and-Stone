extends SceneTree
## Pure passive arithmetic and active duration boundaries; Simulation owns combat.
const Rules = preload("res://game/numbered_rules.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func fixture(ancestry: String = "human") -> Dictionary:
	return {"ancestry":ancestry, "equipment":{"accessory":Rules.ID}, "braces_remainder":0}

func _initialize() -> void:
	var human: Dictionary = fixture()
	var dwarf: Dictionary = fixture("dwarf")
	check(Rules.is_equipped(human), "Braces recognized in accessory slot")
	check(Rules.is_equipped({"equipment":{"wrist":Rules.ID}}), "Equipment detection is slot independent")
	for malformed: Variant in [null, [], "guardians_braces", true]:
		check(not Rules.is_equipped({"equipment":malformed}), "Malformed equipment has no passive")
	check(not Rules.is_equipped({}), "Missing equipment has no passive")
	for charge: int in [-100, -1, 0, 9]:
		check(Rules.duration(human, charge) == 2, "Uncharged human duration remains base at " + str(charge))
	check(Rules.duration(human, 10) == 3 and Rules.duration(human, 19) == 3, "Charge awards complete ten-damage steps")
	check(Rules.duration(human, 39) == 5 and Rules.duration(human, 40) == 6, "Duration cap starts at forty prevented damage")
	check(Rules.duration(human, 9223372036854775807) == 6, "Large charge safely caps")
	check(Rules.duration(dwarf, 0) == 3 and Rules.duration(dwarf, 10) == 5, "Dwarf multiplies active duration and rounds upward")
	check(Rules.duration(dwarf, 40) == 9, "Dwarf multiplies after base duration cap")
	check(Rules.duration({"ancestry":"dwarf"}, 100) == 0, "Unequipped Dwarf retains zero duration")
	var before: Dictionary = human.duplicate(true)
	check(Rules.mitigate(human, 100) == {"damage":95,"prevented":5,"remainder":0}, "Passive prevents exactly five percent")
	check(human == before, "Mitigation query is pure")
	check(Rules.mitigate(dwarf, 100) == Rules.mitigate(human, 100), "Dwarf does not multiply passive reduction")
	var ordinary: Dictionary = {"ancestry":"dwarf", "equipment":{"weapon":"club"}}
	check(Rules.mitigate(ordinary, 100) == {"damage":100,"prevented":0,"remainder":0}, "Dwarf ordinary equipment receives no mitigation")
	var prevented: int = 0
	var damage: int = 0
	for hit: int in range(100):
		var result: Dictionary = Rules.mitigate(human, 1)
		prevented += int(result.prevented)
		damage += int(result.damage)
		human.braces_remainder = result.remainder
	check(prevented == 5 and damage == 95 and human.braces_remainder == 0, "One hundred one-HP hits preserve five percent")
	human.braces_remainder = 95
	check(Rules.mitigate(human, 1) == {"damage":0,"prevented":1,"remainder":0}, "Nineteen carried fractions prevent the twentieth HP")
	for incoming: int in [-100, -1, 0]:
		check(Rules.mitigate(human, incoming) == {"damage":0,"prevented":0,"remainder":95}, "Nonpositive input causes no harm or charge")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(human))
	check(Rules.mitigate(loaded, 1).prevented == 1, "JSON float remainder preserves fractional mitigation")
	for invalid: Variant in [-1, 100, 100000, 0.5, NAN, INF, "95", true, [], null]:
		var malformed: Dictionary = fixture()
		malformed.braces_remainder = invalid
		check(Rules.mitigate(malformed, 1) == {"damage":1,"prevented":0,"remainder":5}, "Invalid fractional remainder cannot create charge")
	var large: Dictionary = Rules.mitigate(fixture(), 9223372036854775807)
	check(large.prevented == 461168601842738790 and large.remainder == 35, "Passive arithmetic avoids signed overflow")
	check(large.damage == 8762203435012037017, "Large hit preserves damage accounting")
	check(Rules.BASE_DURATION == 2 and Rules.MAX_BASE_DURATION == 6 and Rules.DAMAGE_PER_EXTRA_ROUND == 10, "Estimated charge values explicit")
	check(Rules.COOLDOWN == 6 and Rules.RADIUS == 3 and Rules.KNOCKBACK == 2, "Estimated active values explicit")
	check(Rules.SOURCE.begins_with("https://") and Rules.ACQUISITION_SOURCE.begins_with("https://"), "Novel provenance retained")
	for failure: String in failures: push_error(failure)
	print("NUMBERED RULES TEST: %d checks; %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
