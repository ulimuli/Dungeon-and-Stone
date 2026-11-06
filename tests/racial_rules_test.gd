extends SceneTree
## Pure rule coverage. Sanctuary charges/recovery-clock integration live in Simulation.
const Rules = preload("res://game/racial_rules.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func fixture(race: String = "barbarian") -> Dictionary:
	return {"id":"test_character", "ancestry":race, "hp":7, "max_hp":32, "dead":false, "str":4, "agi":2, "wit":3, "vig":4, "energy":2, "mana":0, "gold":800, "essences":["canon_goblin"], "equipment":{"weapon":"club"}, "racial":{}}

func reject_unchanged(unit: Dictionary, label: String) -> void:
	var before: String = var_to_str(unit)
	check(not Rules.can_unlock_undying(unit).is_empty(), label + ": eligibility rejected")
	check(var_to_str(unit) == before, label + ": eligibility is pure")
	check(not Rules.unlock_undying(unit).is_empty(), label + ": unlock rejected")
	check(var_to_str(unit) == before, label + ": rejection does not mutate unit")
	check(Rules.natural_heal_bonus(unit) == 0, label + ": no natural-heal bonus")

func _initialize() -> void:
	var unit: Dictionary = fixture()
	var before: Dictionary = unit.duplicate(true)
	check(Rules.can_unlock_undying(unit).is_empty(), "Living unengraved Barbarian is eligible")
	check(unit == before, "Eligibility leaves candidate unchanged")
	check(Rules.natural_heal_bonus(unit) == 0, "No engraving means no bonus")
	check(Rules.unlock_undying(unit).is_empty(), "First engraving unlocks")
	check(unit.racial == {"engraving_path":"undying", "engraving_level":1}, "Path and stage are explicit saved values")
	var expected: Dictionary = before.duplicate(true)
	expected.racial = {"engraving_path":"undying", "engraving_level":1}
	check(unit == expected, "Unlock alters no attributes, HP, resources, currency, equipment or essences")
	check(Rules.natural_heal_bonus(unit) == 1, "Purchased stage one adds only one estimated recovery HP")
	check(unit == expected, "Bonus query does not directly heal or change state")
	var committed: Dictionary = unit.duplicate(true)
	check(not Rules.unlock_undying(unit).is_empty() and unit == committed, "Duplicate unlock cannot stack or refill")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(unit))
	check(Rules.natural_heal_bonus(loaded) == 1, "JSON numeric representation preserves purchased effect")
	check(not Rules.can_unlock_undying(loaded).is_empty(), "JSON restore preserves irreversible choice")
	for race: String in ["human", "fairy", "dwarf", "beastman", "draconian", "unknown", ""]:
		reject_unchanged(fixture(race), "Wrong race " + race)
	for health: Variant in [0, -1, NAN, INF, -INF, "7", {}, [], true, null]:
		var fallen: Dictionary = fixture()
		fallen.hp = health
		reject_unchanged(fallen, "Nonliving/malformed HP " + str(health))
	var deceased: Dictionary = fixture()
	deceased.dead = true
	reject_unchanged(deceased, "Death flag with positive HP")
	var malformed_dead: Dictionary = fixture()
	malformed_dead.dead = "false"
	reject_unchanged(malformed_dead, "Malformed death flag")
	for record: Variant in [null, [], true, "undying", {"engraving_path":"slayer", "engraving_level":1}, {"engraving_path":"undying", "engraving_level":1}, {"engraving_path":5}, {"engraving_path":"", "engraving_level":2}, {"engraving_path":"", "engraving_level":0.5}, {"engraving_level":NAN}]:
		var invalid: Dictionary = fixture()
		invalid.racial = record
		if record is Dictionary and str(record.get("engraving_path", "")) == "undying":
			var prior: String = var_to_str(invalid)
			check(not Rules.unlock_undying(invalid).is_empty() and var_to_str(invalid) == prior, "Existing Undying cannot be purchased twice")
		else: reject_unchanged(invalid, "Invalid/locked progression " + str(record))
	var missing: Dictionary = fixture()
	missing.erase("racial")
	check(Rules.unlock_undying(missing).is_empty() and Rules.natural_heal_bonus(missing) == 1, "Older units without racial field can purchase normally")
	var unrelated: Dictionary = fixture()
	unrelated.racial = {"future_note":"keep"}
	check(Rules.unlock_undying(unrelated).is_empty() and unrelated.racial.future_note == "keep", "Unlock preserves unrelated saved progression fields")
	for stage: Variant in [null, -1, 0, 2, 999, 1.5, "1", true, NAN, INF]:
		var invalid_stage: Dictionary = fixture()
		invalid_stage.racial = {"engraving_path":"undying", "engraving_level":stage}
		check(Rules.natural_heal_bonus(invalid_stage) == 0, "Unknown/malformed stage cannot grant a bonus " + str(stage))
	unit.hp = 0
	check(Rules.natural_heal_bonus(unit) == 0, "Natural recovery never revives fallen unit")
	unit.hp = 7
	unit.dead = true
	check(Rules.natural_heal_bonus(unit) == 0, "Natural recovery never revives flagged-dead unit")
	check(Rules.RECOVERY_INTERVAL_MINUTES == 90 and Rules.UNDYING_HEAL_APPROXIMATION == 1, "Estimated clock magnitude is explicit")
	check(Rules.UNDYING_SOURCE.begins_with("https://"), "Qualitative rule retains chapter provenance")
	for failure: String in failures: push_error(failure)
	print("RACIAL RULES TEST: %d checks; %d failures. Purchased Undying1 only; not six complete racial trees." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
