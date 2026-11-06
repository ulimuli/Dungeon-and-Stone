class_name EarlyFloorContent
extends RefCounted
## Early-floor species reconstructed from documented encounters. Names/rank/XP
## retain citations; ordinary combat profiles and all pixel interpretations are
## provisional. Unspecified essence packages are deliberately absent.
const DEAD_SOURCE: String = "https://martialrealm.com/novel/sgb/chapter-22-23-24/"
const DEN_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/"
const ROCK_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
const RANK9_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
const RANK8_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8"
const FLOOR_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor"
const ART_IDS: Dictionary = {"canon_elder_ghoul":"elder","canon_skeleton_warrior":"bone_guard","canon_skeleton_archer":"bone_bow","canon_kobold_shield_soldier":"kobold","canon_sandman":"sand","canon_wall_mole_rat":"mole","canon_giant_blade_wolf":"giant_wolf","canon_moon_rock_bear":"bear","canon_queen_wall_mole":"queen_mole","canon_bloody_blade_wolf":"blood_wolf","canon_saber_tiger":"tiger","canon_werewolf":"werewolf","canon_death_fiend":"death_fiend"}
static var _textures: Dictionary = {}

static func monsters() -> Dictionary:
	var result: Dictionary = {
		"canon_elder_ghoul": _monster("Elder Ghoul","ambusher",9,34,8,1,4,82,1,1,"Land of the Dead",DEAD_SOURCE,"An enlarged ghoul; the novel describes twice the ordinary size.","elder"),
		"canon_skeleton_warrior": _monster("Skeleton Warrior","tank",9,27,7,4,2,82,1,1,"Land of the Dead",DEAD_SOURCE,"An armed skeleton variant. Its exposed rib core matters against blades.","bone_guard"),
		"canon_skeleton_archer": _monster("Skeleton Archer","ranged",9,17,5,1,5,84,5,1,"Land of the Dead",DEAD_SOURCE,"A skeleton bowman that fights from range.","bone_bow"),
		"canon_kobold_shield_soldier": _monster("Kobold Shield Soldier","tank",9,29,6,5,1,80,1,1,"Black Rock Mountain",ROCK_SOURCE,"A shield-bearing kobold from the southern route.","kobold"),
		"canon_sandman": _monster("Sandman","tank",8,50,8,3,1,78,1,1,"Black Rock Mountain",RANK8_SOURCE,"A rank-eight resident of Black Rock Mountain. Its complete skill kit is unknown.","sand"),
		"canon_wall_mole_rat": _monster("Wall-Mole Rat","ambusher",9,18,5,0,7,84,1,2,"Den of Beasts",DEN_SOURCE,"A cave-dwelling den creature; also translated Wall Mole.","mole"),
		"canon_giant_blade_wolf": _monster("Giant Blade Wolf","skirmisher",9,34,8,1,5,84,1,2,"Den of Beasts",DEN_SOURCE,"A larger Blade Wolf variant encountered on the canyon route.","giant_wolf"),
		"canon_moon_rock_bear": _monster("Half-Moon Rock Bear","tank",9,39,8,3,0,78,1,1,"Den of Beasts",DEN_SOURCE,"A ninth-rank canyon bear; also translated Moon Rock Bear.","bear"),
		"canon_queen_wall_mole": _monster("Wall-Mole Queen","tank",9,31,7,2,3,82,1,1,"Den of Beasts",DEN_SOURCE,"A larger Wall-Mole variant from the canyon route.","queen_mole"),
		"canon_bloody_blade_wolf": _monster("Bloodstained Blade Wolf","skirmisher",9,24,9,0,9,86,1,2,"Den of Beasts",DEN_SOURCE,"A distinct ninth-rank Blade Wolf variant. Its full skills are unknown.","blood_wolf"),
		"canon_saber_tiger": _monster("Saber Tiger","skirmisher",8,43,12,1,8,88,1,2,"Den of Beasts",DEN_SOURCE,"A rank-eight canyon predator; also translated Sabertooth Tiger.","tiger"),
		"canon_werewolf": _monster("Werewolf","skirmisher",8,51,10,2,6,86,1,2,"Den of Beasts",DEN_SOURCE,"A rank-eight den creature. No regeneration or transformation is inferred from its name.","werewolf"),
		"canon_death_fiend": _monster("Death Fiend","summoner",8,72,11,5,0,80,1,1,"Land of the Dead",DEAD_SOURCE,"Physical Preservation heals wounds; Call of the Dead brings Ghouls. Slow and territorial.","death_fiend")
	}
	for id: String in ["canon_skeleton_warrior","canon_skeleton_archer"]:
		result[id].core_targeting = {"known":"Bladed weapons can kill by aiming at the core between the ribs.","implemented":false,"reference_url":DEAD_SOURCE}
	result.canon_kobold_shield_soldier.reference_urls.append(RANK9_SOURCE)
	result.canon_kobold_shield_soldier.reference_urls.append(FLOOR_SOURCE)
	result.canon_kobold_shield_soldier.verification_level = "primary_generic_kobold_location_secondary_shield_variant_and_rank"
	result.canon_sandman.reference_urls.append(FLOOR_SOURCE)
	result.canon_sandman.verification_level = "secondary_rank_and_location_unknown_skill_kit"
	result.canon_saber_tiger.aliases = ["Sabertooth Tiger","Sabre Tiger"]
	result.canon_wall_mole_rat.aliases = ["Wall Mole"]
	result.canon_queen_wall_mole.aliases = ["Queen Wall Mole"]
	result.canon_moon_rock_bear.aliases = ["Moon Rock Bear"]
	result.canon_bloody_blade_wolf.aliases = ["Bloody Blade Wolf","Blood Blade Wolf"]
	var fiend: Dictionary=result.canon_death_fiend
	fiend.essence="canon_death_fiend"
	fiend.regeneration={"amount":8,"interval":"round_start","nonlethal_only":true,"experimental_numeric_fields":["amount","interval"]}
	fiend.summoning={"monster":"canon_ghoul","count":10,"cooldown":6,"radius":3,"telegraph_rounds":1,"count_verified":true,"experimental_numeric_fields":["cooldown","radius","telegraph_rounds"]}
	fiend.territorial={"pursuit_radius":10,"experimental_numeric_fields":["pursuit_radius"]}
	fiend.source_behavior = ["Physical Preservation closes minor wounds rapidly.","Call of the Dead summons ten Ghouls.","Slow and stops pursuit outside its territory.","Cannot rise unaided after being knocked onto its back."]
	return result

static func _monster(unit_name: String, role: String, rank: int, health: int, power: int, armor: int, evasion: int, accuracy: int, reach: int, movement: int, location: String, source: String, description: String, art: String) -> Dictionary:
	return {"name":unit_name,"role":role,"hp":health,"power":power,"armor":armor,"evasion":evasion,"accuracy":accuracy,"range":reach,"move":movement,"xp":10-rank,"gold":0,"essence":"","affinity":"physical","status":"","desc":description,"telegraph":"","phase_power":0,"rank":rank,"documented_locations":[location],"reference_urls":[source],"verification_level":"primary_species_and_xp_combat_estimates","experimental_numeric_fields":["hp","power","armor","evasion","accuracy","range","move"],"fidelity_note":"Species/rank/XP are sourced; HP, damage, armor, accuracy, evasion, movement and grid timing are provisional. Only basic combat is implemented for species whose complete kits are unknown; no unverified essence is awarded.","art_id":art,"art_provisional":true,"aliases":[],"source_chapters":[23] if location=="Land of the Dead" else [50] if location=="Den of Beasts" else [27,89]}

static func essences() -> Dictionary:
	return {"canon_death_fiend":{"name":"Death Fiend","tier":8,"affinity":"body","desc":"Physical Preservation improves regeneration. Call of the Dead summons Ghouls.","passive":"physical_preservation","passive_name":"Physical Preservation","value":2.0,"drawback":"No drawback established by the sources reviewed.","ability":{"name":"Call of the Dead","effect":"call_dead","power":0,"cost":12,"cooldown":6,"range":4,"radius":4,"status":"","status_duration":0,"damage_type":"","summon_id":"canon_ghoul","summon_count":10,"summon_duration":12,"description":"Calls Ghouls. Ten Ghouls. Player12SP,6-round cooldown,12-round lifetime and tile distances are provisional; the ten-Ghoul monster pattern is sourced.","numeric_parameters_verified":false},"source_stats":{},"modifiers":[],"passive_modifiers":[{"stat":"natural_recovery","op":"multiply","value":2.0}],"reference_urls":[DEAD_SOURCE,RANK8_SOURCE],"novel_chapters":[23,24],"verification_level":"primary_passive_and_active_transfer_unknown_attribute_package","essence_transfer_verified":true,"full_kit_verified":false,"partial_component_reconstruction":true,"playable":true,"requires_implementation":false,"experimental_balance":true,"experimental_numeric_fields":["passive_multiplier","player_summon_count","cost","cooldown","range","radius","summon_duration","regen_cadence"],"fidelity_note":"The novel discusses both transferable skills, with weaker regeneration than the monster. Attribute bonuses, player summon count, resource costs and tactical cadence are unknown; current conversions are provisional. Passive skill modifiers must respect sealing and remain separate from retained essence attributes."}}

static func region_pools() -> Dictionary:
	return {"canon_land_of_dead":["canon_ghoul","canon_elder_ghoul","canon_skeleton","canon_skeleton_warrior","canon_skeleton_archer","canon_death_fiend"],"canon_black_rock_mountain":["canon_gnome","canon_kobold_shield_soldier","canon_sandman","canon_stone_golem"],"canon_den_of_beasts":["canon_blade_wolf","canon_wall_mole_rat","canon_giant_blade_wolf","canon_moon_rock_bear","canon_queen_wall_mole","canon_bloody_blade_wolf","canon_saber_tiger","canon_werewolf"]}

static func den_bands() -> Dictionary:
	return {"ordinary":["canon_blade_wolf","canon_wall_mole_rat","canon_giant_blade_wolf","canon_moon_rock_bear","canon_queen_wall_mole","canon_bloody_blade_wolf"],"deep":["canon_saber_tiger","canon_werewolf"],"deep_rank":8,"reference_url":DEN_SOURCE,"note":"The latter canyon has black cliffs and rank-eight creatures only; omitted Bulkar skills/rank remain unverified."}

static func validate() -> Array[String]:
	var errors: Array[String]=[]
	var rows: Dictionary=monsters()
	for id: String in rows:
		var row: Dictionary=rows[id]
		if not id.begins_with("canon_") or row.name.is_empty(): errors.append(id+": missing stable identity")
		if row.rank not in [8,9] or row.xp!=10-row.rank: errors.append(id+": rank/XP mismatch")
		if row.hp<=0 or row.power<=0 or row.range<1 or row.move<1: errors.append(id+": invalid combat profile")
		if row.reference_urls.is_empty() or row.documented_locations.is_empty() or row.experimental_numeric_fields.is_empty(): errors.append(id+": missing provenance/estimate metadata")
		if row.essence not in ["","canon_death_fiend"]: errors.append(id+": unsupported essence package")
		if sprite_image(id).get_size()!=Vector2i(32,32): errors.append(id+": invalid art dimensions")
	return errors

static func sprite(id: String, frame: int = 0) -> Texture2D:
	if not ART_IDS.has(id): return null
	var key: String=id+":"+str(posmod(frame,2))
	if not _textures.has(key): _textures[key]=ImageTexture.create_from_image(sprite_image(id,frame))
	return _textures[key]

static func sprite_image(id: String, frame: int = 0) -> Image:
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	if not ART_IDS.has(id): return image
	var art: String=str(ART_IDS[id])
	var shift: int=posmod(frame,2)
	var outline:=Color("111b23"); var bone:=Color("c4c3a0"); var shade:=Color("707b72"); var metal:=Color("5b7075"); var glow:=Color("a3c7b3")
	if art in ["bone_guard","bone_bow"]:
		_rect(image,11,4+shift,10,9,outline); _rect(image,12,4+shift,8,8,bone); _rect(image,13,7+shift,2,2,outline); _rect(image,17,7+shift,2,2,outline); _rect(image,15,11+shift,2,2,shade)
		_rect(image,14,13,4,12,outline); _rect(image,15,13,2,12,bone)
		for y: int in [14,17,20]: _rect(image,11,y,10,2,bone)
		_rect(image,10,24,4,6,shade); _rect(image,18,24,4,6,shade)
		if art=="bone_guard":
			_rect(image,4,14,8,12,outline); _rect(image,5,15,6,10,metal); _rect(image,7,17,2,6,bone); _rect(image,24,9,2,17,bone); _rect(image,22,21,6,2,metal); _rect(image,11,14,10,4,metal)
		else:
			_rect(image,7,14,2,9,shade); _rect(image,22,9,2,18,shade); _rect(image,24,11,2,14,bone); _rect(image,26,14,1,9,shade); _rect(image,20,17,8,1,bone)
	elif art in ["elder","death_fiend","werewolf","kobold","sand"]:
		var skin:=Color("7d8270") if art=="elder" else Color("667b68") if art=="death_fiend" else Color("6e6865") if art=="werewolf" else Color("9b7955") if art=="kobold" else Color("b49c6e")
		var width: int=16 if art in ["elder","death_fiend","sand"] else 12
		_rect(image,16-width/2,11+shift,width,15,outline); _rect(image,17-width/2,12+shift,width-2,12,skin); _rect(image,16-width/2,15+shift,4,7,skin.lightened(0.1))
		_rect(image,10,3+shift,12,11,outline); _rect(image,11,4+shift,10,9,skin); _rect(image,12,7+shift,2,2,glow); _rect(image,18,7+shift,2,2,glow); _rect(image,14,11+shift,5,2,outline)
		_rect(image,5,13+shift,4,12,skin.darkened(0.2)); _rect(image,23,13+shift,4,12,skin.darkened(0.2)); _rect(image,10,25,5,5,skin.darkened(0.2)); _rect(image,18,25,5,5,skin.darkened(0.2))
		if art=="werewolf": _rect(image,10,2+shift,3,4,skin); _rect(image,19,2+shift,3,4,skin); _rect(image,13,10+shift,2,3,bone); _rect(image,18,10+shift,2,3,bone)
		if art=="kobold": _rect(image,10,2+shift,3,4,skin); _rect(image,19,2+shift,3,4,skin); _rect(image,3,15,10,12,outline); _rect(image,4,16,8,10,metal); _rect(image,7,18,2,6,bone); _rect(image,27,10,2,17,metal)
		if art=="death_fiend": _rect(image,2,14,9,14,outline); _rect(image,3,15,7,12,shade); _rect(image,26,5,3,22,bone); _rect(image,24,21,7,3,shade); _rect(image,12,16,9,5,Color("576253"))
		if art=="sand": _rect(image,5,26,23,4,skin.darkened(0.2)); _rect(image,8,22,17,5,skin); _rect(image,12,5+shift,7,2,skin.lightened(0.2)); _rect(image,11,16,2,2,skin.lightened(0.15)); _rect(image,20,21,2,2,skin.darkened(0.2))
	else:
		var fur:=Color("8c8770")
		if art in ["mole","queen_mole"]: fur=Color("766e64")
		elif art=="blood_wolf": fur=Color("985d51")
		elif art=="tiger": fur=Color("b79a58")
		elif art=="bear": fur=Color("747d78")
		var top: int=9 if art in ["giant_wolf","bear","queen_mole"] else 14
		_rect(image,5,top+shift,21,14,outline); _rect(image,6,top+1+shift,19,12,fur)
		_rect(image,21,top-2+shift,9,10,outline); _rect(image,22,top-1+shift,7,8,fur.lightened(0.08)); _rect(image,26,top+1+shift,2,2,glow); _rect(image,28,top+4+shift,2,2,outline)
		_rect(image,8,25,4,5,fur.darkened(0.2)); _rect(image,20,25,4,5,fur.darkened(0.2)); _rect(image,2,top+3+shift,4,3,fur)
		if art in ["mole","queen_mole"]:
			_rect(image,7,27,6,2,bone); _rect(image,20,27,6,2,bone); _rect(image,22,top+2+shift,2,1,outline)
		elif art=="tiger":
			for x: int in [8,13,18]: _rect(image,x,top+1+shift,2,7,outline)
			_rect(image,25,top+7+shift,2,5,bone); _rect(image,28,top+7+shift,2,4,bone)
		elif art=="bear": _rect(image,8,top+2+shift,3,3,shade); _rect(image,22,top-3+shift,3,3,fur); _rect(image,11,top+3+shift,9,3,bone)
		else: _rect(image,21,top-4+shift,3,4,fur); _rect(image,26,top-4+shift,3,4,fur); _rect(image,15,top-2+shift,4,3,shade)
	return image

static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var region:=Rect2i(x,y,width,height).intersection(Rect2i(0,0,32,32))
	if region.has_area(): image.fill_rect(region,color)
