extends SceneTree
const Research = preload("res://game/content_reference.gd")
const Runtime = preload("res://game/reference_runtime.gd")
var failures: Array[String] = []
var checks: int = 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func _initialize() -> void:
	var essences: Dictionary = Research.essences()
	var monsters: Dictionary = Research.monsters()
	var regions: Dictionary = Research.regions()
	check(essences.size() == 9,"Nine researched essence families")
	check(regions.size() == 5,"Five researched areas")
	for essence_id: String in essences:
		var row: Dictionary = essences[essence_id]
		check(not row.reference_urls.is_empty(),"Research essence needs source " + essence_id)
		check(not row.playable and row.requires_implementation,"Research entry cannot imply implemented effect " + essence_id)
		check(not str(row.fidelity_note).is_empty(),"Research uncertainty is explicit " + essence_id)
	for region_id: String in regions:
		var region: Dictionary = regions[region_id]
		check(not region.reference_urls.is_empty(),"Research region needs source " + region_id)
		check(not region.get("verified_novel_directly",false),"Exact geography must not be declared verified " + region_id)
		for monster_id: String in region.enemy_ids: check(monsters.has(monster_id),"Research region enemy exists " + monster_id)
	for monster_id: String in monsters:
		var monster: Dictionary = monsters[monster_id]
		check(not monster.reference_urls.is_empty(),"Monster needs source " + monster_id)
		check(not monster.experimental_numeric_fields.is_empty(),"Monster provisional numeric fields identified " + monster_id)
		var essence_id: String = str(monster.get("essence",""))
		check(essence_id.is_empty() or essences.has(essence_id),"Research monster essence exists " + monster_id)
	check(essences.has("canon_blade_wolf") and essences.has("canon_stone_golem"),"Both new runtime essence families retain research definitions")
	var cave: Dictionary = regions.canon_crystal_cave
	check(cave.enemy_ids == ["canon_goblin","canon_ghoul","canon_gnome","canon_blade_wolf"],"Crystal Cave native species")
	check(not regions.canon_green_iron_mine.playable,"Rift is not offered as an implemented area")
	check(essences.canon_orc_hero_tarugas.ability.effect == "giantization","Researched Orc Hero effect retains its identity")
	check(Runtime.regions().size() == 9 and Runtime.essences().size() == 7,"Playable adapters are separate from research breadth")
	for error: String in failures: push_error(error)
	print("REFERENCE CONTENT TEST: %d checks; %d failures; %d researched essences; %d researched areas" % [checks,failures.size(),essences.size(),regions.size()])
	quit(0 if failures.is_empty() else 1)
