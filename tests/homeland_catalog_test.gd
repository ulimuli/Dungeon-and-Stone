extends SceneTree
## Pure catalog protocol and disclosure checks. No maps or campaigns are mutated.
const Catalog = preload("res://game/homeland_catalog.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func reject(entries: Dictionary, expected: String, label: String) -> void:
	var before: String = var_to_str(entries)
	var errors: Array[String] = Catalog.validate_entries(entries)
	check(not errors.is_empty() and errors.any(func(error: String) -> bool: return error.contains(expected)),label+" has actionable diagnostic: "+str(errors))
	check(var_to_str(entries) == before,label+" validation leaves its input untouched")

func _initialize() -> void:
	var entries: Dictionary = Catalog.definitions()
	check(entries.size() == 6 and Catalog.validate().is_empty(),"Six source-aware homelands satisfy the shared protocol")
	var ids: Dictionary = {}
	var seen_themes: Dictionary = {}
	for ancestry: String in Catalog.ANCESTRIES:
		var entry: Dictionary = entries[ancestry]
		check(entry.points.size() == 6 and entry.npcs.size() == 3 and entry.landmarks.size() == 3,"Each land supplies six actual targets for the map's fixed slots: "+ancestry)
		check(not seen_themes.has(entry.theme),"Each race has a distinct map theme: "+ancestry)
		seen_themes[entry.theme] = true
		var actions: Array = []
		for point: Dictionary in Catalog.points(ancestry):
			check(not ids.has(point.id) and str(point.id).begins_with(ancestry+"_"),"Interaction identity is global and stable: "+str(point.id))
			ids[point.id] = true
			check(not point.has("pos") and point.ancestry == ancestry,"Map placement and actor eligibility remain separate from content: "+str(point.id))
			check(point.authored and not point.canonical_identity,"Operators/landmarks never impersonate novel companions: "+str(point.id))
			check(Catalog.point(ancestry,point.id) == point and not point.message.is_empty(),"Lookup returns an actionable description: "+str(point.id))
			var spoken: String = point.line.to_lower()
			check(not spoken.contains("authored") and not spoken.contains("unimplemented") and not spoken.contains("provisional") and not spoken.contains("free statistics"),"Source/process metadata stays out of spoken dialogue: "+str(point.id))
			check(point.line.split(" ",false).size() <= (28 if point.kind == "npc" else 40),"Dialogue remains concise for exploration: "+str(point.id))
			actions.append(point.action)
		check(actions.count("return") == 1 and actions.has("lore"),"Each land offers a return route and meaningful lore or teaching targets: "+ancestry)
		check(actions.count("return") == 1,"Each land has exactly one reachable return action: "+ancestry)
	var required: Dictionary = {"barbarian":["undying","training","lore"],"beastman":["skadia","lore","rest"],"dwarf":["artifact_blessing","repair","lore"],"fairy":["spirit_lesson","spirit_stone","wind_guidance"],"human":["magic_assess","magic_study","training"],"draconian":["dragon_fear","lore","rest"]}
	for ancestry: String in required:
		var actions: Array = Catalog.points(ancestry).map(func(point: Dictionary) -> String: return point.action)
		for action: String in required[ancestry]: check(actions.has(action),"Supported race interaction is represented: "+ancestry+"/"+action)
	check(entries.fairy.name == "Barharium" and not entries.fairy.provisional_location,"Fairy homeland uses the primary novel's actual proper name")
	check(entries.human.name == "Rafdonia" and entries.human.theme == "city" and not entries.human.provisional_location and entries.human.reference_urls.has("https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"),"Human home is the shared city rather than a fabricated exclusive sanctuary")
	check(entries.dwarf.provisional_location and entries.dwarf.name == "Dwarven Forge Quarter" and str(entries.dwarf.estimate_notes).contains("does not identify"),"Unverified Dwarf homeland staging label is explicitly provisional")
	check(str(entries.dwarf.estimate_notes).contains("innate") and Catalog.point("dwarf","dwarf_item_keeper").action == "artifact_blessing","Dwarf artifact inspection does not sell an invented blessing ritual")
	check(Catalog.point("barbarian","barbarian_memorial").action == "lore" and Catalog.point("barbarian","barbarian_storykeeper").action == "lore","Funeral/hair/tattoo traditions are optional lore interactions")
	check(Catalog.point("barbarian","barbarian_weapon_circle").action == "coming_of_age","Coming-of-age observation cannot imply repeatable starting-gear refunds")
	check(Catalog.point("beastman","beastman_ring_stand").message.contains("equipment worn at the rite"),"Skadia ritual landmark discloses the destructive equipment condition")
	check(str(entries.fairy.estimate_notes).contains("provisional") and Catalog.point("fairy","fairy_stone_keeper").message.contains("one-in-ten"),"Provisional first lesson remains distinct from documented additional-affinity chance")
	check(Catalog.point("draconian","draconian_language_guide").action == "dragon_blessing" and str(entries.draconian.estimate_notes).contains("public teleport"),"Dragon Language and transport are not presented as completed public services")
	var points: Array = Catalog.points("fairy")
	points[0].name = "Changed by caller"
	check(Catalog.point("fairy","fairy_tutor").name == "Spirit Tutor","Point lookup gives consumers a safe copy for map decoration")
	check(Catalog.points("unknown").is_empty() and Catalog.point("human","missing").is_empty(),"Unknown homeland/point lookups fail closed")
	var missing: Dictionary = entries.duplicate(true); missing.erase("human")
	reject(missing,"required ancestry missing","Missing race")
	var unknown: Dictionary = entries.duplicate(true); unknown["gnome"] = entries.human.duplicate(true)
	reject(unknown,"unknown ancestry","Unsupported race")
	var malformed: Dictionary = entries.duplicate(true); malformed.human.points = "not an array"
	reject(malformed,"points must be an array","Malformed point list")
	var duplicate: Dictionary = entries.duplicate(true); duplicate.human.points[1].id = duplicate.human.points[0].id
	reject(duplicate,"duplicate stable point ID","Duplicate interaction identity")
	var wrong: Dictionary = entries.duplicate(true); wrong.human.points[0].action = "free_magic_mastery"
	reject(wrong,"unsupported semantic action","Unimplemented service action")
	var geometry: Dictionary = entries.duplicate(true); geometry.human.points[0].pos = Vector2i(1,1)
	reject(geometry,"position belongs to the map provider","Catalog steals geometry ownership")
	var identity: Dictionary = entries.duplicate(true); identity.human.points[0].canonical_identity = true
	reject(identity,"must not impersonate","Silent canonical NPC impersonation")
	var unsafe_return: Dictionary = entries.duplicate(true); unsafe_return.human.points[5].action = "lore"
	reject(unsafe_return,"exactly one return route","Missing return route")
	var unsourced: Dictionary = entries.duplicate(true); unsourced.fairy.reference_urls = []
	reject(unsourced,"source context","Unsourced homeland")
	check(Catalog.validate_entries(JSON.parse_string(JSON.stringify(entries))).is_empty(),"Position-free catalog protocol survives JSON roundtrip")
	print("HOMELAND CATALOG: %d checks, %d failures. Six sourced/provisionally staged locations,36 authored points; existing commands own all progression." % [checks,failures])
	quit(1 if failures else 0)
