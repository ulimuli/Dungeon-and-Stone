class_name HomelandCatalog
extends RefCounted
## Source-aware homeland interaction data only. Geometry, availability, payment,
## progression, persistence and UI are owned by their existing runtime modules.
## Every operator is an authored role, never a silently recruited novel companion.
const ANCESTRIES: Array[String] = ["barbarian","beastman","dwarf","fairy","human","draconian"]
const THEMES: Array[String] = ["camp","forest","forge","city","council","dragon"]
const ACTIONS: Array[String] = ["coming_of_age","dragon_blessing","undying","skadia","artifact_blessing","spirit_lesson","spirit_stone","wind_guidance","magic_assess","magic_study","dragon_fear","lore","rest","training","repair","return"]
static var _entries: Dictionary = {}

static func definitions() -> Dictionary:
	if _entries.is_empty(): _entries = _build()
	return _entries

static func points(ancestry: String) -> Array:
	return definitions().get(ancestry,{}).get("points",[]).duplicate(true)

static func point(ancestry: String, point_id: String) -> Dictionary:
	for row: Dictionary in points(ancestry):
		if row.id == point_id: return row
	return {}

static func _build() -> Dictionary:
	var entries: Dictionary = {
		"barbarian": {
			"name": "Barbarian Sanctuary",
			"theme": "camp",
			"description": "Tents, rough paths and training clearings shelter the tribe. Near the shaman’s fire, young warriors prepare to leave home.",
			"reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/", "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Barbarians", "https://hennoveltranslations.org/episodes/stgb-episode-454/", "https://hennoveltranslations.org/episodes/surviving-the-game-as-a-barbarian-episode-782/"],
			"estimate_notes": ["This compact visitor map, unnamed operators and exact service placement are authored for the game.", "Undying uses the existing supported engraving only. Other tattoo paths and Soul Succession are discussed as lore, not granted.", "Funeral and hair customs are optional observations. No blood offering, injury or haircut is required."],
			"provisional_location": false,
			"npcs": [
				{"id": "barbarian_shaman", "name": "Sanctuary Shaman", "role": "Soul Engraver", "ancestry": "barbarian", "action": "undying", "kind": "npc", "line": "A strong body carries a strong spirit. Sit by the fire, and we will speak of the Undying engraving.", "message": "A strong body carries a strong spirit. Sit by the fire, and we will speak of the Undying engraving.", "reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/"], "authored": true, "canonical_identity": false},
				{"id": "barbarian_trainer", "name": "Warrior Instructor", "role": "Training keeper", "ancestry": "barbarian", "action": "training", "kind": "npc", "line": "Feet apart! Shield high! We learn our first stances here, before the chief sends us into the city.", "message": "Feet apart! Shield high! We learn our first stances here, before the chief sends us into the city.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-454/"], "authored": true, "canonical_identity": false},
				{"id": "barbarian_storykeeper", "name": "Tradition Keeper", "role": "Keeper of customs", "ancestry": "barbarian", "action": "lore", "kind": "npc", "line": "Our first tattoos are made in childhood. At a funeral, a warrior may leave cut hair beside the fallen.", "message": "Our first tattoos are made in childhood. At a funeral, a warrior may leave cut hair beside the fallen.", "reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/", "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Barbarians"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "barbarian_memorial", "name": "Memorial Grove", "role": "Funeral place", "ancestry": "barbarian", "action": "lore", "kind": "landmark", "line": "The forest receives our dead, and wind and rain carry them home. Stand here awhile and remember those who did not return.", "message": "The forest receives our dead, and wind and rain carry them home. Stand here awhile and remember those who did not return.", "reference_urls": ["https://hennoveltranslations.org/episodes/surviving-the-game-as-a-barbarian-episode-782/"], "authored": true, "canonical_identity": false},
				{"id": "barbarian_weapon_circle", "name": "Coming-of-Age Clearing", "role": "Ceremonial clearing", "ancestry": "barbarian", "action": "coming_of_age", "kind": "landmark", "line": "At coming of age, young warriors choose a weapon in this clearing. Their first journey beyond the sanctuary begins here.", "message": "At coming of age, young warriors choose a weapon in this clearing. Their first journey beyond the sanctuary begins here.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-454/"], "authored": true, "canonical_identity": false},
				{"id": "barbarian_return", "name": "City Path", "role": "Return route", "ancestry": "barbarian", "action": "return", "kind": "landmark", "line": "The path leads through the trees to Rafdonia.", "message": "The path leads through the trees to Rafdonia.", "reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/"], "authored": true, "canonical_identity": false}
			]
		},
		"beastman": {
			"name": "Beastman Sanctuary",
			"theme": "council",
			"description": "Orderly streets gather around a domed council hall. Clan voices mingle at the hearths, and guides speak of Soul Beast bonds.",
			"reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Beastmen", "https://hennoveltranslations.com/episodes/stgb-episode-52/"],
			"estimate_notes": ["The developed sanctuary and council are supported by secondary research; the compact council courtyard and all visitor operators are authored.", "The Skadia interaction reuses the existing Ring of the Frost Spirit ritual and its explicit all-worn-equipment loss. It does not grant every Beastman an automatic contract."],
			"provisional_location": false,
			"npcs": [
				{"id": "beastman_soul_keeper", "name": "Soul Beast Guide", "role": "Contract adviser", "ancestry": "beastman", "action": "skadia", "kind": "npc", "line": "A Soul Beast is a bond, not an ornament. Bring the Frost Spirit Ring if you wish to speak of Skadia.", "message": "A Soul Beast is a bond, not an ornament. Bring the Frost Spirit Ring if you wish to speak of Skadia.", "reference_urls": ["https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false},
				{"id": "beastman_speaker", "name": "Council Steward", "role": "Clan liaison", "ancestry": "beastman", "action": "lore", "kind": "npc", "line": "Every clan has a voice beneath the council dome. Come closer; there is always news from the other hearths.", "message": "Every clan has a voice beneath the council dome. Come closer; there is always news from the other hearths.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Beastmen"], "authored": true, "canonical_identity": false},
				{"id": "beastman_trainer", "name": "Clan Instructor", "role": "Movement instructor", "ancestry": "beastman", "action": "training", "kind": "npc", "line": "Keep your weight light and your eyes forward. Watch the drill before you try to match our pace.", "message": "Keep your weight light and your eyes forward. Watch the drill before you try to match our pace.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Beastmen"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "beastman_ring_stand", "name": "Ring Display", "role": "Ritual explanation", "ancestry": "beastman", "action": "lore", "kind": "landmark", "line": "The Frost Spirit Ring can seal an essence’s skills. Skadia’s awakening consumes the equipment worn at the rite; set aside anything you wish to keep.", "message": "The Frost Spirit Ring can seal an essence’s skills. Skadia’s awakening consumes the equipment worn at the rite; set aside anything you wish to keep.", "reference_urls": ["https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false},
				{"id": "beastman_hearth", "name": "Council Hearth", "role": "Rest place", "ancestry": "beastman", "action": "rest", "kind": "landmark", "line": "The council hearth is warm. Sit down, loosen your pack, and ask the keeper for a place to rest.", "message": "The council hearth is warm. Sit down, loosen your pack, and ask the keeper for a place to rest.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Beastmen"], "authored": true, "canonical_identity": false},
				{"id": "beastman_return", "name": "City Gate", "role": "Return route", "ancestry": "beastman", "action": "return", "kind": "landmark", "line": "The sanctuary gate opens onto the road to Rafdonia.", "message": "The sanctuary gate opens onto the road to Rafdonia.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Beastmen"], "authored": true, "canonical_identity": false}
			]
		},
		"dwarf": {
			"name": "Dwarven Forge Quarter",
			"theme": "forge",
			"description": "Furnaces glow behind open workshop doors, and the sound of hammers carries across a busy Dwarven forge court.",
			"reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/", "https://hennoveltranslations.com/episodes/stgb-episode-52/", "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"],
			"estimate_notes": ["Novel640 confirms dwarven forge expansion in Gnome Tree but does not identify the full Dwarf homeland. This explorable forge court is a clearly provisional staging area.", "The blessing is an innate racial interaction with Numbered Items, not a newly invented paid initiation. Guardian’s Braces retain their existing supported Dwarf benefit.", "Smith, guide, forge court and service placement are authored operators and layout."],
			"provisional_location": true,
			"npcs": [
				{"id": "dwarf_item_keeper", "name": "Numbered Item Keeper", "role": "Blessing adviser", "ancestry": "dwarf", "action": "artifact_blessing", "kind": "npc", "line": "Numbered relics answer well to Dwarf hands. Let us examine your equipment and the blessing it already carries.", "message": "Numbered relics answer well to Dwarf hands. Let us examine your equipment and the blessing it already carries.", "reference_urls": ["https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false},
				{"id": "dwarf_smith", "name": "Workshop Smith", "role": "Repair operator", "ancestry": "dwarf", "action": "repair", "kind": "npc", "line": "Bring your worn gear. I can repair it while the forge is hot.", "message": "Bring your worn gear. I can repair it while the forge is hot.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/"], "authored": true, "canonical_identity": false},
				{"id": "dwarf_trainer", "name": "Forge Instructor", "role": "Craft demonstration", "ancestry": "dwarf", "action": "training", "kind": "npc", "line": "Watch the color of the iron, then the angle of the hammer. A hurried hand makes work twice.", "message": "Watch the color of the iron, then the angle of the hammer. A hurried hand makes work twice.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/", "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "dwarf_forge", "name": "Communal Forge", "role": "Workshop landmark", "ancestry": "dwarf", "action": "lore", "kind": "landmark", "line": "The forge rings with measured blows. Dwarven workshops help keep the city’s machinery turning, and more furnaces are being built around Gnome Tree.", "message": "The forge rings with measured blows. Dwarven workshops help keep the city’s machinery turning, and more furnaces are being built around Gnome Tree.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/", "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"], "authored": true, "canonical_identity": false},
				{"id": "dwarf_hearth", "name": "Workers’ Hearth", "role": "Rest place", "ancestry": "dwarf", "action": "rest", "kind": "landmark", "line": "Workers gather here when the hammers fall quiet. Ask for a bed and rest your hands.", "message": "Workers gather here when the hammers fall quiet. Ask for a bed and rest your hands.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/"], "authored": true, "canonical_identity": false},
				{"id": "dwarf_return", "name": "Workshop Road", "role": "Return route", "ancestry": "dwarf", "action": "return", "kind": "landmark", "line": "The workshop road leads back to Rafdonia’s streets.", "message": "The workshop road leads back to Rafdonia’s streets.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-640/"], "authored": true, "canonical_identity": false}
			]
		},
		"fairy": {
			"name": "Barharium",
			"theme": "forest",
			"description": "Homes blend with the forest beneath Barharium’s towering tree. Quiet garden paths wind toward teaching groves and sheltered ponds.",
			"reference_urls": ["https://hennoveltranslations.org/episodes/surviving-the-game-as-a-barbarian-episode-778/", "https://hennoveltranslations.org/episodes/stgb-episode-662/", "https://martialrealm.com/novel/sgb/chapter-19-20-21/"],
			"estimate_notes": ["Barharium is explicitly named in novel778. The small teaching grove, pond rest stop and unnamed operators are authored portions of that larger land.", "The first Fire Spirit lesson is the existing provisional acquisition rule. Spirit Stones use the supported additional-affinity attempt; current Wind-only scope and combat conversion remain provisional.", "No visit grants pure blood, an elite successor identity, a spirit king or a universal contract."],
			"provisional_location": false,
			"npcs": [
				{"id": "fairy_tutor", "name": "Spirit Tutor", "role": "First-contract instructor", "ancestry": "fairy", "action": "spirit_lesson", "kind": "npc", "line": "Begin with a small flame, and learn to listen before you command. We can prepare your first Fire Spirit lesson.", "message": "Begin with a small flame, and learn to listen before you command. We can prepare your first Fire Spirit lesson.", "reference_urls": ["https://hennoveltranslations.com/episodes/stgb-episode-52/", "https://martialrealm.com/novel/sgb/chapter-19-20-21/"], "authored": true, "canonical_identity": false},
				{"id": "fairy_stone_keeper", "name": "Spirit Stone Keeper", "role": "Affinity adviser", "ancestry": "fairy", "action": "spirit_stone", "kind": "npc", "line": "Already bound to a spirit? Each stone has a one-in-ten chance of another affinity, and crumbles whether the bond forms or not.", "message": "Already bound to a spirit? Each stone has a one-in-ten chance of another affinity, and crumbles whether the bond forms or not.", "reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/"], "authored": true, "canonical_identity": false},
				{"id": "fairy_wind_guide", "name": "Wind Guide", "role": "Bow guidance tutor", "ancestry": "fairy", "action": "wind_guidance", "kind": "npc", "line": "A willing wind can guide an arrow’s path. Bring your bow and call on the spirit you have befriended.", "message": "A willing wind can guide an arrow’s path. Bring your bow and call on the spirit you have befriended.", "reference_urls": ["https://martialrealm.com/novel/sgb/chapter-19-20-21/"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "fairy_great_tree", "name": "Towering Sacred Tree", "role": "Forest landmark", "ancestry": "fairy", "action": "lore", "kind": "landmark", "line": "An immense tree rises above Barharium’s homes. Between the trunks, buildings and garden paths seem to grow from the forest itself.", "message": "An immense tree rises above Barharium’s homes. Between the trunks, buildings and garden paths seem to grow from the forest itself.", "reference_urls": ["https://hennoveltranslations.org/episodes/surviving-the-game-as-a-barbarian-episode-778/"], "authored": true, "canonical_identity": false},
				{"id": "fairy_pond", "name": "Quiet Pond", "role": "Rest place", "ancestry": "fairy", "action": "rest", "kind": "landmark", "line": "Water stirs beneath the branches. A quiet shelter beside the pond offers weary travelers a place to rest.", "message": "Water stirs beneath the branches. A quiet shelter beside the pond offers weary travelers a place to rest.", "reference_urls": ["https://hennoveltranslations.org/episodes/surviving-the-game-as-a-barbarian-episode-778/"], "authored": true, "canonical_identity": false},
				{"id": "fairy_return", "name": "Forest Gate", "role": "Return route", "ancestry": "fairy", "action": "return", "kind": "landmark", "line": "A marked forest path leads back toward Rafdonia. The sanctuary’s outer boundary lies in the other direction.", "message": "A marked forest path leads back toward Rafdonia. The sanctuary’s outer boundary lies in the other direction.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-662/"], "authored": true, "canonical_identity": false}
			]
		},
		"human": {
			"name": "Rafdonia",
			"theme": "city",
			"description": "Rafdonia’s teaching quarter brings together apprentices, explorers and working people beneath the presence of the Magic Tower.",
			"reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia", "https://hennoveltranslations.org/episodes/stgb-episode-292/", "https://hennoveltranslations.org/episodes/stgb-episode-663/", "https://hennoveltranslations.com/episodes/stgb-episode-52/"],
			"estimate_notes": ["The city and Magic Tower are sourced; this compact public teaching quarter and its unnamed service operators are authored.", "Basic tuition and assessment retain the current explicit fees, elapsed days and talent restrictions. Private basic lessons do not automatically grant Magic Tower admission.", "Other human occupations can be discussed here but are not advertised as completed careers."],
			"provisional_location": false,
			"npcs": [
				{"id": "human_assessor", "name": "Aptitude Examiner", "role": "Magic assessor", "ancestry": "human", "action": "magic_assess", "kind": "npc", "line": "Some gifts take years to discover. Let us examine your aptitude before you commit to magical study.", "message": "Some gifts take years to discover. Let us examine your aptitude before you commit to magical study.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-292/", "https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false},
				{"id": "human_tutor", "name": "Basic Magic Tutor", "role": "Private instructor", "ancestry": "human", "action": "magic_study", "kind": "npc", "line": "We begin with Ice Spear: shape, focus, release. First, we must settle your eligibility and the terms of your lessons.", "message": "We begin with Ice Spear: shape, focus, release. First, we must settle your eligibility and the terms of your lessons.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-663/", "https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false},
				{"id": "human_guild_guide", "name": "Guild Instructor", "role": "Career guide", "ancestry": "human", "action": "training", "kind": "npc", "line": "The city needs more than swords. Listen to the apprentices and explorers; every profession begins with something worth learning.", "message": "The city needs more than swords. Listen to the apprentices and explorers; every profession begins with something worth learning.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-663/", "https://hennoveltranslations.com/episodes/stgb-episode-52/"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "human_tower_notice", "name": "Magic Tower Notice Board", "role": "Civic landmark", "ancestry": "human", "action": "lore", "kind": "landmark", "line": "The Tower gathers many schools beneath one roof. Talent assessment, specialist study and an instructor’s guidance each have their place.", "message": "The Tower gathers many schools beneath one roof. Talent assessment, specialist study and an instructor’s guidance each have their place.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-292/", "https://hennoveltranslations.org/episodes/stgb-episode-663/"], "authored": true, "canonical_identity": false},
				{"id": "human_square", "name": "Public Rest Court", "role": "Rest place", "ancestry": "human", "action": "rest", "kind": "landmark", "line": "Travelers share news around the public rest court. Ask the attendant for lodging before another long day.", "message": "Travelers share news around the public rest court. Ask the attendant for lodging before another long day.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"], "authored": true, "canonical_identity": false},
				{"id": "human_return", "name": "Main Street", "role": "Return route", "ancestry": "human", "action": "return", "kind": "landmark", "line": "The main street leads to Rafdonia’s shops, guild desks and city gates.", "message": "The main street leads to Rafdonia’s shops, guild desks and city gates.", "reference_urls": ["https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia"], "authored": true, "canonical_identity": false}
			]
		},
		"draconian": {
			"name": "Dragon Sanctuary",
			"theme": "dragon",
			"description": "A guarded mountain precinct rises toward the Dragon Temple, its monumental columns visible above the visitor terraces.",
			"reference_urls": ["https://hennoveltranslations.com/archives/episodes/stgb-episode-159", "https://hennoveltranslations.org/episodes/stgb-episode-642/", "https://hennoveltranslations.com/episodes/stgb-episode-52/"],
			"estimate_notes": ["The visitor terrace, unnamed attendants and exact walking route are authored. Temple descriptions from separate chapters do not establish a public teleport network.", "Dragon Fear is the existing controllable innate Draconian trait. It is distinct from a rank-one dragon’s lethal presence or an individual blessing.", "Dragon blessings use chapter202 effects. Native access at level2 for500 stones and one permanent slot are provisional. Dragon Language and the foreigner story bargain remain unfinished."],
			"provisional_location": false,
			"npcs": [
				{"id": "draconian_fear_mentor", "name": "Fear Mentor", "role": "Presence instructor", "ancestry": "draconian", "action": "dragon_fear", "kind": "npc", "line": "Master your presence before you raise your voice. Learn when to let others feel your Dragon Fear, and when to draw it inward.", "message": "Master your presence before you raise your voice. Learn when to let others feel your Dragon Fear, and when to draw it inward.", "reference_urls": ["https://hennoveltranslations.com/archives/episodes/stgb-episode-159"], "authored": true, "canonical_identity": false},
				{"id": "draconian_keeper", "name": "Temple Attendant", "role": "Visitor keeper", "ancestry": "draconian", "action": "lore", "kind": "npc", "line": "Walk with care beneath these columns. The temple has welcomed petitioners for longer than most city houses have stood.", "message": "Walk with care beneath these columns. The temple has welcomed petitioners for longer than most city houses have stood.", "reference_urls": ["https://hennoveltranslations.com/archives/episodes/stgb-episode-159", "https://hennoveltranslations.org/episodes/stgb-episode-642/"], "authored": true, "canonical_identity": false},
				{"id": "draconian_language_guide", "name": "Dragon Shaman", "role": "Blessing inscriber", "ancestry": "draconian", "action": "dragon_blessing", "kind": "npc", "line": "Earth strengthens the gifts of essences. Volcano strengthens skills. Sea deepens Soul Power. Choose the blessing that belongs on your path.", "message": "Earth strengthens the gifts of essences. Volcano strengthens skills. Sea deepens Soul Power. Choose the blessing that belongs on your path.", "reference_urls": ["https://hennoveltranslations.com/archives/episodes/stgb-episode-202"], "authored": true, "canonical_identity": false}
			],
			"landmarks": [
				{"id": "draconian_columns", "name": "Temple Columns", "role": "Sacred architecture", "ancestry": "draconian", "action": "lore", "kind": "landmark", "line": "Great pillars frame the Dragon Temple. Beyond the visitor terrace, guards watch the approach to the sacred halls.", "message": "Great pillars frame the Dragon Temple. Beyond the visitor terrace, guards watch the approach to the sacred halls.", "reference_urls": ["https://hennoveltranslations.com/archives/episodes/stgb-episode-159"], "authored": true, "canonical_identity": false},
				{"id": "draconian_lookout", "name": "Mountain Lookout", "role": "Rest place", "ancestry": "draconian", "action": "rest", "kind": "landmark", "line": "The mountain air is cool above the road. A sheltered bench offers a place to rest before the descent.", "message": "The mountain air is cool above the road. A sheltered bench offers a place to rest before the descent.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-642/"], "authored": true, "canonical_identity": false},
				{"id": "draconian_return", "name": "Sanctuary Gate", "role": "Return route", "ancestry": "draconian", "action": "return", "kind": "landmark", "line": "The guarded path descends toward Rafdonia.", "message": "The guarded path descends toward Rafdonia.", "reference_urls": ["https://hennoveltranslations.org/episodes/stgb-episode-642/"], "authored": true, "canonical_identity": false}
			]
		}
	}
	for ancestry: String in entries:
		entries[ancestry].points = entries[ancestry].npcs.duplicate(true)
		entries[ancestry].points.append_array(entries[ancestry].landmarks.duplicate(true))
	return entries

static func validate() -> Array[String]:
	return validate_entries(definitions())

static func validate_entries(entries: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for ancestry: String in ANCESTRIES:
		if not entries.has(ancestry): errors.append("Homeland " + ancestry + ": required ancestry missing")
	for ancestry: Variant in entries:
		var prefix: String = "Homeland " + str(ancestry) + ": "
		if ancestry not in ANCESTRIES: errors.append(prefix + "unknown ancestry")
		if not entries[ancestry] is Dictionary:
			errors.append(prefix + "expected entry dictionary"); continue
		var entry: Dictionary = entries[ancestry]
		for field: String in ["name","description"]:
			if not _text(entry.get(field)): errors.append(prefix + field + " requires nonempty text")
		if entry.get("theme") not in THEMES: errors.append(prefix + "unknown map theme")
		if not entry.get("estimate_notes") is Array or entry.get("estimate_notes",[]).is_empty(): errors.append(prefix + "explicit estimate_notes required")
		if not entry.get("provisional_location") is bool: errors.append(prefix + "provisional_location must be boolean")
		if not _sources(entry.get("reference_urls")): errors.append(prefix + "reference_urls requires source context")
		if not entry.get("points") is Array:
			errors.append(prefix + "points must be an array"); continue
		if entry.points.size() < 4: errors.append(prefix + "at least four meaningful interactables required")
		var return_count: int = 0
		var grouped: Array = []
		for field: String in ["npcs","landmarks"]:
			if not entry.get(field) is Array: errors.append(prefix + field + " must be an array")
			else: grouped.append_array(entry[field])
		if grouped != entry.points: errors.append(prefix + "points must combine npcs then landmarks without omissions")
		for row: Variant in entry.points:
			if not row is Dictionary:
				errors.append(prefix + "point requires dictionary"); continue
			var label: String = prefix + "point " + str(row.get("id","?")) + ": "
			for field: String in ["id","name","role","line","message"]:
				if not _text(row.get(field)): errors.append(label + field + " requires nonempty text")
			if row.get("ancestry") != ancestry: errors.append(label + "ancestry must match its homeland")
			if row.get("kind") not in ["npc","landmark"]: errors.append(label + "kind must be npc or landmark")
			if row.get("action") not in ACTIONS: errors.append(label + "unsupported semantic action")
			if row.get("action") == "return": return_count += 1
			if row.get("authored") != true or row.get("canonical_identity") != false: errors.append(label + "authored role must not impersonate a canonical companion")
			if row.has("pos"): errors.append(label + "position belongs to the map provider")
			if ids.has(row.get("id")): errors.append(label + "duplicate stable point ID")
			else: ids[row.get("id")] = true
			if not _sources(row.get("reference_urls")): errors.append(label + "source context required")
		if return_count != 1: errors.append(prefix + "exactly one return route required")
	errors.sort()
	return errors

static func _text(value: Variant) -> bool:
	return value is String and not str(value).strip_edges().is_empty()

static func _sources(value: Variant) -> bool:
	if not value is Array or value.is_empty(): return false
	for url: Variant in value:
		if not url is String or not str(url).begins_with("https://") or not str(url).contains("."): return false
	return true
