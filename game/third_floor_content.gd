class_name ThirdFloorContent
extends RefCounted
## Source-backed identities and selected behaviors; tactical coefficients are estimates.
## This is a subset of the third floor, not an exhaustive map or complete essence registry.
const HILL_SOURCE: String="https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/"
const FOREST_SOURCE: String="https://wuxiaworld.site/novel/surviving-the-game-as-a-barbarian/chapter-60/"
const HUNTER_SOURCE: String="https://bape-clothing.com/book/surviving-the-game-as-a-barbarian-2/chapter-61"
const ESTUARY_SOURCE: String="https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-115-116-117/"
const THIRD_SOURCE: String="https://slashrealm.com/novel/stabmtl/chapter-52-53-54/"
const RANK8_SOURCE: String="https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8"
const RANK7_SOURCE: String="https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_7"
const ART_IDS: Dictionary={"canon_iron_tusk":"tusk","canon_wormstone":"worm","canon_iron_falcon":"falcon","canon_ironrock_hill_guardian_soldier":"guardian","canon_orc_warrior":"orc","canon_orc_archer":"orc_bow","canon_orc_sorcerer":"orc_staff","canon_mighty_orc_warrior":"mighty","canon_woodman":"wood","canon_owl_bear":"owl","canon_wraith":"wraith","canon_frogman":"frog","canon_frogman_shaman":"frog_staff","canon_carnivaro":"hunter"}
static var _textures: Dictionary={}

static func monsters() -> Dictionary:
	var result: Dictionary={
		"canon_iron_tusk":_monster("Iron Tusk","tank",7,92,15,7,1,84,1,2,"Ironrock Hill",HILL_SOURCE,50,"A steel-tusked boar. Counterweight prevents knockback.","tusk"),
		"canon_wormstone":_monster("Wormstone","tank",8,55,10,5,0,80,1,1,"Ironrock Hill",HILL_SOURCE,50,"A documented hill creature; its complete skill kit is unknown.","worm"),
		"canon_iron_falcon":_monster("Iron Falcon","skirmisher",8,34,11,2,14,88,1,2,"Ironrock Hill",HILL_SOURCE,50,"A documented hill creature; flight does not imply terrain immunity in this reconstruction.","falcon"),
		"canon_ironrock_hill_guardian_soldier":_monster("Ironrock Hill Guardian Soldier","tank",8,64,11,7,0,82,1,1,"Ironrock Hill",HILL_SOURCE,50,"Also translated Steel Hill Guardian. An ordinary species, not an invented boss.","guardian"),
		"canon_orc_warrior":_monster("Orc Warrior","tank",8,52,12,4,2,84,1,1,"Orc Colony",HILL_SOURCE,51,"A front-line orc supported by the sorcerer's Frenzy.","orc"),
		"canon_orc_archer":_monster("Orc Archer","ranged",8,35,9,2,5,88,5,1,"Orc Colony",HILL_SOURCE,51,"An orc bowman encountered with warriors and a sorcerer.","orc_bow"),
		"canon_orc_sorcerer":_monster("Orc Sorcerer","support",8,39,7,1,3,82,1,1,"Orc Colony",HILL_SOURCE,51,"Frenzy triples an ally's physical resistance for a short time.","orc_staff"),
		"canon_mighty_orc_warrior":_monster("Mighty Orc Warrior","tank",7,87,16,6,2,86,1,1,"Orc Colony",RANK7_SOURCE,52,"A rank-seven orc; the ordinary profile does not claim a complete skill package.","mighty"),
		"canon_woodman":_monster("Woodman","tank",9,37,8,3,0,80,1,1,"Witch's Forest",FOREST_SOURCE,60,"A documented forest creature. Its complete skill kit is unknown.","wood"),
		"canon_owl_bear":_monster("Owl Bear","tank",8,68,13,3,1,84,1,1,"Witch's Forest",FOREST_SOURCE,60,"A documented forest creature. Its complete skill kit is unknown.","owl"),
		"canon_wraith":_monster("Wraith","skirmisher",9,24,7,0,8,84,1,1,"Witch's Forest",FOREST_SOURCE,60,"An incorporeal ghost. Physical strikes need an elemental or holy counter.","wraith"),
		"canon_frogman":_monster("Frogman","skirmisher",8,39,10,1,12,87,2,2,"Dark River Estuary",ESTUARY_SOURCE,115,"Slimy Mucus evades blunt weapons while mobile; cold stiffens the mucus.","frog"),
		"canon_frogman_shaman":_monster("Frogman Shaman","ranged",8,42,8,1,8,85,1,1,"Dark River Estuary",ESTUARY_SOURCE,115,"A documented collection target. Its spell kit is unknown; only an estimated basic strike is modeled.","frog_staff"),
		"canon_carnivaro":_monster("Carnivaro","ranged",7,96,17,4,10,104,6,2,"Witch's Forest",HUNTER_SOURCE,61,"An intelligent undead hunter with a crossbow. Persistent pursuit and accurate shots; Mana Mine and Hound remain incomplete.","hunter")
	}
	result.canon_wormstone.aliases=["Stoneworm"]
	result.canon_ironrock_hill_guardian_soldier.aliases=["Steel Hill Guardian","Steelrock Hill Guardian Soldier"]
	result.canon_iron_tusk.aliases=["Iron Ant (translation variant)"]
	result.canon_carnivaro.aliases=["Cannibalo","Canivaro"]
	result.canon_iron_tusk.essence="canon_iron_tusk"
	result.canon_iron_tusk.counterweight={"status":"anchored","duration":4,"cooldown":6,"reference_url":HILL_SOURCE,"experimental_numeric_fields":["duration","cooldown"]}
	for id: String in ["canon_orc_warrior","canon_orc_archer","canon_orc_sorcerer","canon_mighty_orc_warrior"]:
		result[id].base_stats={"physical_resistance":25.0}
		result[id].experimental_numeric_fields.append("physical_resistance")
	result.canon_orc_sorcerer.ally_buff={"status":"frenzy","radius":3,"duration":2,"cooldown":4,"stat":"physical_resistance","op":"multiply","value":3.0,"source_duration_seconds":10,"reference_url":HILL_SOURCE,"experimental_numeric_fields":["radius","duration","cooldown"]}
	result.canon_wraith.physical_immunity=true
	result.canon_wraith.source_behavior=["Incorporeal; ordinary physical attacks are ineffective. Holy water and cold attacks are used against forest ghosts."]
	result.canon_frogman.blunt_evasion={"while_mobile":true,"disabled_by":["chilled","stunned","paralyzed","suppressed","toppled"],"reference_url":ESTUARY_SOURCE,"fidelity_note":"Guaranteed evasion against blunt weapons while able to move; additional blade evasion uses the estimated ordinary evasion coefficient."}
	result.canon_frogman.cold_stiffening={"status":"chilled","duration":2,"reference_url":ESTUARY_SOURCE,"experimental_numeric_fields":["duration"],"fidelity_note":"Cold makes a blunt strike possible; two tactical rounds is an estimate."}
	result.canon_frogman_shaman.role="skirmisher"
	result.canon_frogman_shaman.full_kit_verified=false
	result.canon_frogman_shaman.verification_level="primary_identity_location_secondary_rank_unknown_spell_kit"
	result.canon_frogman_shaman.reference_urls.append(RANK8_SOURCE)
	result.canon_carnivaro.persistent_pursuit=true
	result.canon_carnivaro.tracking_arrow={"accuracy_bonus":20,"reference_url":HUNTER_SOURCE,"experimental_numeric_fields":["accuracy_bonus"]}
	result.canon_carnivaro.unimplemented_skills=["Mana Mine","Hound"]
	result.canon_carnivaro.reference_urls.append(RANK7_SOURCE)
	return result

static func _monster(unit_name: String, role: String, rank: int, health: int, power: int, armor: int, evasion: int, accuracy: int, reach: int, movement: int, location: String, source: String, chapter: int, description: String, art: String) -> Dictionary:
	return {"name":unit_name,"role":role,"rank":rank,"hp":health,"power":power,"armor":armor,"evasion":evasion,"accuracy":accuracy,"range":reach,"move":movement,"xp":10-rank,"gold":0,"essence":"","affinity":"physical","status":"","telegraph":"","phase_power":0,"desc":description,"documented_locations":[location],"reference_urls":[source],"source_chapters":[chapter],"verification_level":"primary_identity_xp_combat_estimates","experimental_numeric_fields":["hp","power","armor","evasion","accuracy","range","move"],"fidelity_note":"Identity, habitat and rank/XP are documented. Numerical combat coefficients, tactical roles and scale are estimates. Unknown skill kits and essence attributes are not invented.","full_kit_verified":false,"art_id":art,"art_provisional":true,"aliases":[]}

static func essences() -> Dictionary:
	return {"canon_iron_tusk":{"name":"Iron Tusk","tier":7,"affinity":"body","desc":"Counterweight prevents displacement while active. Unknown attributes are not supplied.","passive":"","value":0,"drawback":"No drawback established by the reviewed source.","ability":{"name":"Counterweight","effect":"counterweight","status":"anchored","status_duration":4,"cost":3,"cooldown":6,"range":0,"radius":0,"power":0,"damage_type":"","numeric_parameters_verified":false,"description":"Resist displacement for4turns.3SP,4turns and6-turn cooldown are provisional."},"source_stats":{},"modifiers":[],"passive_modifiers":[],"reference_urls":[HILL_SOURCE,RANK7_SOURCE],"novel_chapters":[50],"essence_transfer_verified":true,"full_kit_verified":false,"partial_component_reconstruction":true,"playable":true,"requires_implementation":false,"experimental_balance":true,"experimental_numeric_fields":["cost","cooldown","status_duration"],"verification_level":"primary_transferable_active_unknown_attribute_package","fidelity_note":"A dwarf's absorbed Iron Tusk essence grants knockback immunity through an active skill. Attribute package, cost and tactical duration are unknown."}}

static func regions() -> Dictionary:
	var pools: Dictionary=region_pools()
	return {
		"canon_ironrock_hill":_region("Ironrock Hill","ironrock_hills","8b8075","373c3d",pools.canon_ironrock_hill,[HILL_SOURCE],"Elevated rocky paths with steel-skinned creatures. The Den of Beasts connects here."),
		"canon_orc_colony":_region("Orc Colony","orc_colony","77845c","283c2c",pools.canon_orc_colony,[HILL_SOURCE,THIRD_SOURCE],"Orc groups combine front lines, archers and Frenzy support. Exact geography and clan occupation are not reproduced."),
		"canon_witch_forest":_region("Witch's Forest","witch_forest","7c6b8f","2b293c",pools.canon_witch_forest,[THIRD_SOURCE,FOREST_SOURCE,HUNTER_SOURCE],"The central forest surrounds the fourth-floor portal. Lingering worsens the Witch's Eye."),
		"canon_dark_river_estuary":_region("Dark River Estuary","dark_estuary","5d8890","253d45",pools.canon_dark_river_estuary,[ESTUARY_SOURCE],"Also translated Pitch-black Estuary. Shallow channels flood from midnight until06:00; red mounds are dry camps.")
	}

static func _region(region_name: String, terrain: String, color: String, wall: String, ids: Array, sources: Array, description: String) -> Dictionary:
	var names: Array=[]; var rows: Dictionary=monsters()
	for id: String in ids: names.append(rows[id].name)
	return {"name":region_name,"subtitle":"Third Floor","floor":3,"level":3,"color":color,"wall":wall,"terrain":terrain,"hazard_desc":description,"lore":description,"enemy_ids":ids,"documented_monsters":names,"resource":"","portal_closes_after_days":15,"reference_urls":sources,"verified_novel_directly":true,"layout_provisional":true,"geography_complete":false,"unimplemented_features":["Complete authored geography","Complete species skill and essence packages","Fourth-floor progression"]}

static func region_pools() -> Dictionary:
	return {"canon_ironrock_hill":["canon_wormstone","canon_iron_falcon","canon_ironrock_hill_guardian_soldier","canon_iron_tusk"],"canon_orc_colony":["canon_orc_warrior","canon_orc_archer","canon_orc_sorcerer","canon_mighty_orc_warrior"],"canon_witch_forest":["canon_woodman","canon_owl_bear","canon_wraith"],"canon_dark_river_estuary":["canon_frogman","canon_frogman_shaman"]}

static func validate() -> Array[String]:
	var errors: Array[String]=[]; var rows: Dictionary=monsters()
	for id: String in rows:
		var row: Dictionary=rows[id]
		if row.rank not in [7,8,9] or row.xp!=10-row.rank: errors.append(id+": invalid rank/XP")
		if row.hp<=0 or row.range<1 or row.move<1: errors.append(id+": invalid basic combat profile")
		if row.reference_urls.is_empty() or row.documented_locations.is_empty(): errors.append(id+": missing source provenance")
		if row.essence!="" and not essences().has(row.essence): errors.append(id+": unresolved essence")
	for area: String in region_pools():
		for id: String in region_pools()[area]:
			if not rows.has(id): errors.append(area+": unavailable monster "+id)
	return errors

static func sprite(id: String, frame: int=0) -> Texture2D:
	if not ART_IDS.has(id): return null
	var key: String=id+":"+str(posmod(frame,2))
	if not _textures.has(key): _textures[key]=ImageTexture.create_from_image(sprite_image(id,frame))
	return _textures[key]

static func sprite_image(id: String, frame: int=0) -> Image:
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	if not ART_IDS.has(id): return image
	var art: String=ART_IDS[id]; var d: int=posmod(frame,2)
	var ink:=Color("111b23"); var steel:=Color("899a9d"); var bone:=Color("d0c7a3"); var glow:=Color("c4dbab")
	if art in ["tusk","owl"]:
		var fur:=Color("6a7477") if art=="tusk" else Color("876d55")
		_rect(image,4,11+d,23,15,ink); _rect(image,5,12+d,21,12,fur); _rect(image,21,7+d,9,13,ink); _rect(image,22,8+d,7,11,fur.lightened(0.1))
		_rect(image,7,25,5,5,fur.darkened(0.2)); _rect(image,20,25,5,5,fur.darkened(0.2))
		if art=="tusk":
			for x: int in [7,11,15,19]: _rect(image,x,10+d,2,6,steel.darkened(0.2))
			_rect(image,25,15+d,2,9,steel); _rect(image,28,14+d,2,9,steel); _rect(image,26,11+d,2,2,glow)
		else:
			_rect(image,21,8+d,3,7,bone); _rect(image,27,8+d,3,7,bone); _rect(image,23,10+d,1,2,ink); _rect(image,28,10+d,1,2,ink); _rect(image,25,13+d,2,5,Color("c7a35f")); _rect(image,8,14+d,8,8,fur.lightened(0.16))
	elif art=="worm":
		for segment: int in range(5):
			var x: int=3+segment*5; var y: int=17-int(sin(float(segment)+d*0.5)*3)
			_rect(image,x,y,8,9,ink); _rect(image,x+1,y+1,6,7,Color("777b72")); _rect(image,x+2,y+1,3,2,steel)
		_rect(image,23,12+d,7,10,ink); _rect(image,24,13+d,5,8,Color("879184")); _rect(image,25,15+d,1,2,glow); _rect(image,28,15+d,1,2,glow)
	elif art=="falcon":
		_rect(image,12,10+d,8,16,ink); _rect(image,13,11+d,6,13,steel); _rect(image,15,5+d,9,9,ink); _rect(image,16,6+d,7,7,steel); _rect(image,21,9+d,6,3,bone); _rect(image,20,7+d,2,2,ink)
		for wing: int in range(3):
			_rect(image,2+wing*3,7+wing*3+d*2,4,13-wing*2,steel.darkened(0.15)); _rect(image,22+wing*2,11-wing*2+d*2,4,12-wing*2,steel.darkened(0.15))
		_rect(image,12,25,3,4,bone); _rect(image,18,25,3,4,bone)
	elif art in ["orc","orc_bow","orc_staff","mighty","guardian","hunter"]:
		var skin:=Color("7c8c63"); var coat:=Color("535e4a")
		if art=="guardian": skin=steel; coat=Color("5f6d72")
		if art=="hunter": skin=Color("a09382"); coat=Color("594c53")
		var width: int=18 if art=="mighty" else 14
		_rect(image,16-width/2,12+d,width,14,ink); _rect(image,17-width/2,13+d,width-2,12,coat); _rect(image,10,3+d,12,11,ink); _rect(image,11,4+d,10,9,skin)
		_rect(image,12,7+d,2,2,glow); _rect(image,18,7+d,2,2,glow); _rect(image,13,11+d,2,3,bone); _rect(image,18,11+d,2,3,bone)
		_rect(image,10,25,5,5,coat.darkened(0.2)); _rect(image,18,25,5,5,coat.darkened(0.2)); _rect(image,5,14+d,4,11,skin); _rect(image,23,14+d,4,11,skin)
		if art=="orc_staff":
			_rect(image,9,2+d,14,4,Color("5e4875")); _rect(image,11,0+d,10,4,Color("5e4875")); _rect(image,26,8,2,21,bone); _rect(image,24,5,6,6,Color("ad7e74"))
		elif art=="orc_bow":
			_rect(image,25,8,2,21,bone); _rect(image,28,11,1,15,bone); _rect(image,24,18,6,1,steel)
		elif art=="hunter":
			_rect(image,6,17,24,3,Color("8b705f")); _rect(image,23,12,2,14,bone); _rect(image,26,15,2,8,bone); _rect(image,14,18,2,8,steel); _rect(image,10,3+d,12,3,coat)
		elif art=="guardian":
			_rect(image,8,2+d,16,4,steel); _rect(image,3,14,9,15,steel.darkened(0.2)); _rect(image,6,17,3,9,steel); _rect(image,26,10,3,18,bone); _rect(image,24,9,7,5,steel)
		else:
			_rect(image,3,16,7,12,Color("8b705f")); _rect(image,5,18,2,8,steel); _rect(image,26,9,2,19,bone); _rect(image,23,6,7,8,steel)
			if art=="mighty": _rect(image,6,10+d,8,5,steel); _rect(image,19,10+d,8,5,steel); _rect(image,10,2+d,12,3,steel)
	elif art=="wood":
		var bark:=Color("817358")
		_rect(image,9,7+d,14,21,ink); _rect(image,10,8+d,12,19,bark); _rect(image,12,13+d,2,2,glow); _rect(image,18,13+d,2,2,glow); _rect(image,14,19+d,5,3,ink)
		for x: int in [11,16,21]: _rect(image,x,2,2,10,bark); _rect(image,x-3,3,4,2,bark)
		_rect(image,4,14+d,5,12,bark); _rect(image,23,12+d,5,14,bark); _rect(image,6,26,8,4,bark); _rect(image,18,26,8,4,bark)
	elif art=="wraith":
		var cloth:=Color("777d9a")
		_rect(image,10,4+d,12,13,ink); _rect(image,11,5+d,10,11,cloth); _rect(image,8,15+d,16,12,ink); _rect(image,9,16+d,14,10,cloth.darkened(0.2)); _rect(image,12,8+d,8,7,ink); _rect(image,13,10+d,2,2,glow); _rect(image,18,10+d,2,2,glow)
		for x: int in [7,12,17,22]: _rect(image,x,23+d,3,7-d,cloth.darkened(0.25))
		_rect(image,4,17+d,5,3,cloth); _rect(image,24,16+d,4,3,cloth)
	else:
		var skin:=Color("7b9b79"); var robe:=Color("635574") if art=="frog_staff" else Color("596d62")
		_rect(image,9,12+d,14,14,ink); _rect(image,10,13+d,12,12,robe); _rect(image,7,5+d,18,10,ink); _rect(image,8,6+d,16,8,skin); _rect(image,8,3+d,5,6,skin); _rect(image,20,3+d,5,6,skin); _rect(image,10,5+d,2,2,glow); _rect(image,21,5+d,2,2,glow); _rect(image,11,11+d,11,1,ink)
		_rect(image,5,16+d,4,8,skin); _rect(image,23,16+d,4,8,skin); _rect(image,6,25,8,5,skin); _rect(image,18,25,8,5,skin)
		_rect(image,27,8,2,21,bone)
		if art=="frog_staff": _rect(image,24,4,7,5,Color("b2957a")); _rect(image,12,14+d,8,4,Color("998ba6"))
		else: _rect(image,25,3,2,8,steel); _rect(image,29,3,2,8,steel); _rect(image,27,1,2,10,steel)
	return image

static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var region:=Rect2i(x,y,width,height).intersection(Rect2i(0,0,32,32))
	if region.has_area(): image.fill_rect(region,color)
