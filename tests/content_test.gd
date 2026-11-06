extends SceneTree

const Content = preload("res://game/content.gd")
const Research = preload("res://game/content_reference.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	for error: String in Content.validate(): check(false,error)
	var races: Dictionary = Content.ancestries()
	var items: Dictionary = Content.weapons()
	var regions: Dictionary = Content.regions()
	var monsters: Dictionary = Content.monsters()
	var essences: Dictionary = Content.essences()
	var companions: Dictionary = Content.companions()
	check(races.size() == 6,"Six playable races")
	for race: String in ["barbarian","beastman","draconian","dwarf","fairy","human"]:
		check(races.has(race),"Missing canonical race " + race)
		check(races[race].experimental_balance and not races[race].reference_urls.is_empty(),"Race statistics/source must be identified " + race)
	check(Content.backgrounds().keys() == ["adventurer"],"One neutral adventurer starting profile")
	check(items.size() == 29,"Twenty-nine integrated item definitions")
	for item_id: String in items:
		var item: Dictionary = items[item_id]
		check(not item.reference_urls.is_empty(),"Item needs provenance " + item_id)
		check(item.experimental_balance,"Item numeric balance must be marked " + item_id)
		check(item.kind in ["weapon","armor","consumable","material","supply"],"Functional item category " + item_id)
		check(float(item.price) >= 0 and float(item.weight) >= 0,"Nonnegative economy values " + item_id)
		if item.kind == "consumable": check(item.effect in ["heal","food","water","light","antidote"],"Implemented consumable effect " + item_id)
	check(items.club.slot == "weapon" and items.cloth_armor.slot == "armor","Valid neutral starting gear")
	check(items.healing_potion.effect == "heal" and items.food_ration.effect == "food","Starting provisions functional")
	check(regions.size() == 9,"Nine playable areas")
	check(essences.size() == 7,"Seven obtainable essence families")
	for id: String in ["canon_goblin","canon_goblin_archer","canon_gnome","canon_blade_wolf","canon_stone_golem"]:
		check(essences.has(id),"Expected implemented essence has a runtime resolver " + id)
		check(items.has("sealed_" + id) and items["sealed_" + id].get("contained_essence","") == id,"Implemented essence has a functional preserved-item definition " + id)
	check(regions.has("r04") and regions.r04.enemy_ids.has("canon_stone_golem"),"Black Rock Mountain integrates the rank-eight Stone Golem encounter")
	var reachable: Dictionary = {}
	var drop_sources: Dictionary = {}
	for region: Dictionary in regions.values():
		check(not region.reference_urls.is_empty(),"Region has source")
		for monster_id: String in region.enemy_ids:
			reachable[monster_id] = true
			check(monsters.has(monster_id),"Region enemy exists " + monster_id)
			var essence_id: String = str(monsters[monster_id].get("essence",""))
			if not essence_id.is_empty(): drop_sources[essence_id] = true
	check(monsters.has(ThirdFloorRules.EYE_MONSTER),"Witch Eye event references an actual spawn definition")
	reachable[ThirdFloorRules.EYE_MONSTER]=true
	check(reachable.size() == 35,"Thirty-five spawnable enemy species including Witch Eye hunter")
	for essence_id: String in essences:
		var essence: Dictionary = essences[essence_id]
		check(drop_sources.has(essence_id),"Obtainable essence has an actual drop source " + essence_id)
		check(essence.playable and not essence.requires_implementation,"Only implemented effects are playable " + essence_id)
		check(essence.experimental_balance and not essence.reference_urls.is_empty(),"Essence balance/provenance explicit " + essence_id)
	check(companions.size() == 12,"Twelve neutral recruitment templates")
	var per_race: Dictionary = {}
	for companion_id: String in companions:
		var row: Dictionary = companions[companion_id]
		check(races.has(row.ancestry),"Recruit template race exists " + companion_id)
		per_race[row.ancestry] = int(per_race.get(row.ancestry,0)) + 1
		check(row.generated_adventurer and row.reference_urls.is_empty() and row.experimental_balance,"Generated identity is distinct from sourced combat mechanics " + companion_id)
		check(row.essences.is_empty(),"Recruit does not receive unavailable essence loadout " + companion_id)
		check(str(row.weapon).is_empty() or items.has(row.weapon),"Recruit equipment exists " + companion_id)
		for spell_id: String in row.spells: check(Content.spells().has(spell_id),"Recruit spell is implemented " + companion_id)
	check(per_race.size() == 6,"Every playable race has recruitment offers")
	for count: Variant in per_race.values(): check(int(count) == 2,"Recruitment templates represent each race equally")
	check(Content.events().is_empty() and Content.recipes().is_empty(),"No unsourced event or recipe entries")
	check(Content.factions().keys() == ["explorers_guild","temple"],"Two verified institutions")
	var manifest: Dictionary = {"schema":1,"title":"Dungeon & Stone","races":races.size(),"backgrounds":Content.backgrounds().size(),"items":items.size(),"companions":companions.size(),"institutions":Content.factions().size(),"playable_regions":regions.size(),"spawned_enemy_species":reachable.size(),"obtainable_essences":essences.size(),"events":0,"recipes":0,"research_catalog":{"essences":Research.essences().size(),"areas":Research.regions().size()},"numeric_balance":"provisional"}
	var manifest_file: FileAccess = FileAccess.open("res://game/content_manifest.json",FileAccess.WRITE)
	if manifest_file == null: check(false,"Cannot write current content manifest")
	else:
		manifest_file.store_string(JSON.stringify(manifest,"\t")+"\n")
		manifest_file.close()
	for error: String in failures: push_error(error)
	print("CONTENT TEST: %d checks; %d failures; %d spawnable species; %d obtainable essences" % [checks,failures.size(),reachable.size(),essences.size()])
	quit(0 if failures.is_empty() else 1)
