class_name GameContent
extends RefCounted
## Shared Dungeon & Stone catalog. Research sources live beside entries.
## Numeric attributes, prices, weights, fees and combat coefficients are current
## implementation balance values; they are not claimed as exact novel statistics.

const OPENING_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-1-2-3/"
const POTION_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-4-5-6/"
const CLOTHING_SOURCE: String = "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-16-17-18/"
const WIKI: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/"

static func ancestries() -> Dictionary:
	return {
		"barbarian": _ancestry("Barbarian", "Powerful physical abilities and Soul Engraving traditions.", 4, 1, 1, 4, 34, "Undying I can be purchased at the sanctuary; further Soul Engraving is unfinished.", OPENING_SOURCE),
		"beastman": _ancestry("Beastman", "Agile explorers; talented individuals may form Soul Beast contracts.", 2, 4, 2, 2, 25, "The Ring of the Frost Spirit awakens Skadia; initial cold affects unarmed strikes. Further awakenings are unfinished.", "https://hennoveltranslations.com/episodes/stgb-episode-52/"),
		"draconian": _ancestry("Draconian", "A race associated with Dragon Fear and Dragon Language.", 2, 2, 4, 2, 26, "Innate Dragon Fear can be suppressed. Dragon Language is unfinished.", "https://hennoveltranslations.com/episodes/stgb-episode-159/"),
		"dwarf": _ancestry("Dwarf", "A race whose blessing improves the use of Numbered Items.", 3, 1, 2, 4, 32, "Guardian’s Braces protection lasts1.5× as long. Other Numbered Item interactions are unfinished.", "https://hennoveltranslations.com/episodes/stgb-episode-52/"),
		"fairy": _ancestry("Fairy", "A race with an affinity for spirits.", 1, 3, 4, 2, 25, "Spirit instruction and illumination use Natural Energy. Initial acquisition is provisional.", "https://hennoveltranslations.com/episodes/stgb-episode-52/"),
		"human": _ancestry("Human", "Humans train in many occupations, including magic and divine professions.", 3, 2, 2, 3, 29, "Magic aptitude assessment and paid Ice Spear instruction are available. Other careers remain unfinished.", "https://hennoveltranslations.com/episodes/stgb-episode-52/")
	}

static func _ancestry(unit_name: String, description: String, strength: int, agility: int, wit: int, vitality: int, health: int, trait_description: String, source: String) -> Dictionary:
	return {"name":unit_name, "desc":description, "str":strength, "agi":agility, "wit":wit, "vig":vitality, "hp":health, "armor":0, "resist":{}, "trait":trait_description, "drawback":"Displayed starting attributes are provisional reconstruction values.", "experimental_balance":true, "reference_urls":[source]}

static func backgrounds() -> Dictionary:
	return {"adventurer":{"name":"Adventurer", "desc":"A common starting profile for an explorer entering the Labyrinth. Starting supplies are provisional.", "gold":60, "food":10, "potions":2, "rep":"explorers_guild", "event_tag":"adventurer", "experimental_balance":true}}

static func weapons() -> Dictionary:
	var items: Dictionary = {
		"club": _weapon("Club", "A simple blunt weapon.", 12, 3, 4, 1, 0, 0, OPENING_SOURCE),
		"spear": _weapon("Spear", "A reach weapon; keep space between you and an enemy.", 32, 4, 5, 2, 2, 0, OPENING_SOURCE),
		"sword": _weapon("Sword", "A one-handed blade.", 28, 3, 5, 1, 1, 3, OPENING_SOURCE),
		"greatsword": _weapon("Greatsword", "A heavy two-handed sword.", 60, 7, 8, 1, 5, -4, OPENING_SOURCE),
		"battleaxe": _weapon("Two-handed Axe", "A heavy cutting weapon.", 48, 6, 7, 1, 4, -3, OPENING_SOURCE),
		"bow": _weapon("Bow", "A ranged weapon. Clear line of sight is required.", 38, 2, 4, 5, 0, 2, WIKI + "Erwen_Fornacci_di_Tersia"),
		"shield": _shield(),
		"cloth_armor": _armor("Cloth Clothing", "Ordinary clothing; little protection, no heavy movement penalty.", 12, 1, 0, 2, 0, WIKI + "Erwen_Fornacci_di_Tersia"),
		"leather_armor": _armor("Leather Clothing", "Leather garments for exploration.", 28, 3, 2, 0, 0, CLOTHING_SOURCE),
		"healing_potion": _consumable("Healing Potion", "Restores 24 health outside combat. Recovery amount is provisional.", 12, 0.3, "heal", 24, POTION_SOURCE),
		"magic_torch": _consumable("Magic Torch","A cool-burning magical light. Lasts about three expedition days once lit. Grid illumination radius is provisional.",10,0.3,"light",4320,"https://martialrealm.com/novel/sgb/chapter-22-23-24/"),
		"water_skin": _consumable("Drinking Water","Four shared water supplies. Daily need and supply units are provisional.",4,1.0,"water",4,"https://martialrealm.com/novel/sgb/chapter-22-23-24/"),
		"food_ration": _consumable("Food Ration", "Adds three units to shared expedition food.", 6, 0.5, "food", 3, "https://hennoveltranslations.com/episodes/stgb-episode-405/"),
		"antidote": _consumable("Antidote", "Removes ordinary poison. Special poison categories are not yet modeled.", 10, 0.2, "antidote", 0, "https://dkrc.org/webnovel/277654/90385.html"),
		"mana_stone_rank_9": _mana_stone(9, 6),
		"mana_stone_rank_8": _mana_stone(8, 12),
		"mana_stone_rank_7": _mana_stone(7, 18),
		"spirit_stone":{"name":"Spirit Stone","kind":"supply","slot":"","price":SpiritStones.PRICE,"weight":0.1,"desc":"A Fairy with an existing spirit contract can attempt another affinity.10% success; consumed on failure too. Current additional affinity: Wind.","market_unlocked":true,"experimental_balance":true,"reference_urls":[SpiritStones.SOURCE]},
		"essence_test_tube": {"name":"Essence Test Tube","kind":"supply","slot":"","price":1000,"weight":0.3,"desc":"A mage seals one loose essence inside. Single use.","market_unlocked":true,"experimental_balance":true,"reference_urls":["https://hennoveltranslations.com/archives/episodes/stgb-episode-380", "https://hennoveltranslations.com/archives/episodes/stgb-episode-243"]}
	}
	for id: String in essences():
		items["sealed_" + id] = {"name":str(essences()[id].name) + " Test Tube","kind":"material","slot":"","price":300,"weight":0.3,"contained_essence":id,"desc":"Sealed essence. Open to absorb; the tube is destroyed.","experimental_balance":true,"reference_urls":["https://hennoveltranslations.com/archives/episodes/stgb-episode-243","https://hennoveltranslations.com/episodes/stgb-episode-621/"]}
	# Weapon behavior tags drive shared cutting/blunt stat rules, never name tests.
	for id: String in ["sword","greatsword","battleaxe"]: items[id].weapon_style = "slashing"
	for id: String in ["club","shield"]: items[id].weapon_style = "blunt"
	items.spear.weapon_style = "piercing"
	items.bow.weapon_style = "ranged"
	items.merge(NumberedCatalog.items())
	for id: String in items: items[id] = StatSources.decorate_item(items[id])

	return items

static func _weapon(item_name: String, description: String, price: int, weight: float, power: int, reach: int, strength: int, accuracy: int, source: String) -> Dictionary:
	return {"name":item_name,"kind":"weapon","slot":"weapon","price":price,"weight":weight,"desc":description,"power":power,"range":reach,"accuracy":accuracy,"str_req":strength,"agi_req":0,"experimental_balance":true,"reference_urls":[source]}

static func _armor(item_name: String, description: String, price: int, weight: float, armor: int, evasion: int, strength: int, source: String) -> Dictionary:
	return {"name":item_name,"kind":"armor","slot":"armor","price":price,"weight":weight,"desc":description,"armor":armor,"evasion":evasion,"str_req":strength,"experimental_balance":true,"reference_urls":[source]}

static func _shield() -> Dictionary:
	var item: Dictionary = _weapon("Shield", "Occupies the primary weapon slot; lower damage and additional armor in this implementation.", 45, 5, 1, 1, 0, 0, OPENING_SOURCE)
	item.armor = 2
	item.evasion = -2
	return item

static func _consumable(item_name: String, description: String, price: int, weight: float, effect: String, amount: int, source: String) -> Dictionary:
	return {"name":item_name,"kind":"consumable","slot":"","price":price,"weight":weight,"desc":description,"effect":effect,"amount":amount,"experimental_balance":true,"reference_urls":[source]}

static func _mana_stone(rank_value: int, price: int) -> Dictionary:
	return {"name":"Rank %d Mana Stone" % rank_value,"kind":"material","slot":"","price":price,"weight":0.1,"desc":"A monster mana stone. Exchange value is provisional.","experimental_balance":true,"reference_urls":[POTION_SOURCE, WIKI + "Bestiary/Rank_%d" % rank_value]}

static func companions() -> Dictionary:
	# Neutral combat templates. Campaign-specific identities come from Recruitment.
	return {
		"barbarian_warrior": _adventurer_template("Barbarian Warrior", "barbarian", "skirmisher", "greatsword", 35, 36, 5),
		"barbarian_guard": _adventurer_template("Barbarian Guard", "barbarian", "tank", "shield", 40, 34, 3),
		"fairy_archer": _adventurer_template("Fairy Archer", "fairy", "ranged", "bow", 35, 25, 3),
		"fairy_scout": _adventurer_template("Fairy Spearfighter", "fairy", "skirmisher", "spear", 35, 27, 3),
		"dwarf_guard": _adventurer_template("Dwarf Guard", "dwarf", "tank", "shield", 40, 34, 3),
		"dwarf_axefighter": _adventurer_template("Dwarf Axefighter", "dwarf", "skirmisher", "battleaxe", 40, 28, 4),
		"human_scout": _adventurer_template("Human Swordsman", "human", "skirmisher", "sword", 35, 27, 3),
		"human_mage": _adventurer_template("Human Mage", "human", "controller", "", 25, 24, 2, ["ice_spear"]),
		"beastman_swordsman": _adventurer_template("Beastman Swordsman", "beastman", "skirmisher", "sword", 40, 28, 4),
		"beastman_archer": _adventurer_template("Beastman Archer", "beastman", "ranged", "bow", 35, 25, 3),
		"draconian_warrior": _adventurer_template("Draconian Warrior", "draconian", "skirmisher", "greatsword", 35, 36, 5),
		"draconian_spearman": _adventurer_template("Draconian Spearman", "draconian", "skirmisher", "spear", 35, 27, 3)
	}

static func _adventurer_template(template_name: String, ancestry: String, role: String, weapon: String, cost: int, health: int, power: int, known_spells: Array = []) -> Dictionary:
	var description: String = "Ice Spear targets one enemy and consumes mana." if not known_spells.is_empty() else "Bow attacks reach five tiles." if role == "ranged" else "Shield trades attack power for armor." if role == "tank" else "Spear attacks reach two tiles." if weapon == "spear" else "Close-range weapon fighter."
	return {"name":template_name,"ancestry":ancestry,"role":role,"desc":description,"cost":cost,"loyalty":60,"weapon":weapon,"essences":[],"spells":known_spells.duplicate(),"hp":health,"power":power,"quest":"","unlock_region":1,"appearance":{},"generated_adventurer":true,"profession":"mage" if not known_spells.is_empty() else "explorer","can_absorb_essences":known_spells.is_empty(),"experimental_balance":true,"implementation_note":"Generated adventurer; recruitment fees, equipment and combat numbers are provisional.","reference_urls":[]}

static func spells() -> Dictionary:
	return {"ice_spear": {"name": "Ice Spear", "rank": 8, "effect": "single_target_damage", "damage_type": "cold", "range": 5, "cost": 3, "cooldown": 3, "description": "A single-target ice projectile. Uses mana, not Soul Power. Range, cost, cooldown and damage coefficient are provisional.", "experimental_balance": true, "reference_urls": ["https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/"]}}

static func factions() -> Dictionary:
	return {
		"explorers_guild":{"name":"Explorers Guild","desc":"Registers explorers and expedition teams in Rafdonia.","reference_urls":["https://levelingods.shop/novel/barbnov/chapter-46-47-48/"]},
		"temple":{"name":"Church of Reatlas","desc":"A church in Rafdonia. The current temple-service prices are provisional.","reference_urls":["https://hennoveltranslations.com/episodes/stgb-episode-159/"]}
	}

static func monsters() -> Dictionary:
	return ReferenceRuntime.monsters()

static func essences() -> Dictionary:
	return ReferenceRuntime.essences()

static func regions() -> Dictionary:
	return ReferenceRuntime.regions()

static func events() -> Dictionary:
	return {}

static func recipes() -> Dictionary:
	return {}

static func validate() -> Array[String]:
	var errors: Array[String] = NumberedCatalog.validate()
	errors.append_array(EarlyFloorContent.validate())
	errors.append_array(ThirdFloorContent.validate())
	errors.append_array(StatCatalog.validate())
	var items: Dictionary = weapons()
	var races: Dictionary = ancestries()
	var essences_data: Dictionary = essences()
	var monsters_data: Dictionary = monsters()
	for required: String in ["barbarian","beastman","draconian","dwarf","fairy","human"]:
		if not races.has(required): errors.append("Missing race: " + required)
	if races.size() != 6: errors.append("The character catalog must contain exactly six races.")
	for item_id: String in items:
		var item: Dictionary = items[item_id]
		for error: String in StatRules.validate_modifiers(StatSources.content_modifiers(item.get("modifiers",[]),"item:"+item_id,"item:"+item_id),StatCatalog.definitions()): errors.append(item_id+": "+error)
		if float(item.get("price", -1)) < 0 or float(item.get("weight", -1)) < 0: errors.append("Item %s has invalid price or weight." % item_id)
		if item.has("weapon_style") and item.weapon_style not in ["slashing","blunt","piercing","ranged"]: errors.append("Item %s has unsupported weapon style." % item_id)
		if item.has("contained_essence") and not essences_data.has(str(item.contained_essence)): errors.append("Item %s contains unknown essence." % item_id)
		if item.kind in ["weapon","armor"] and str(item.get("slot", "")).is_empty(): errors.append("Item %s has no equipment slot." % item_id)
		if item.kind == "consumable" and str(item.get("effect", "")).is_empty(): errors.append("Consumable %s has no effect." % item_id)
	for companion_id: String in companions():
		var companion: Dictionary = companions()[companion_id]
		if not races.has(companion.ancestry): errors.append("Companion %s has unknown ancestry." % companion_id)
		if not str(companion.weapon).is_empty() and not items.has(companion.weapon): errors.append("Companion %s has unknown weapon." % companion_id)
	for essence_id: String in essences_data:
		var essence: Dictionary = essences_data[essence_id]
		for error: String in StatRules.validate_modifiers(StatSources.content_modifiers(essence.get("modifiers",[]),"essence:"+essence_id,"essence:"+essence_id),StatCatalog.definitions()): errors.append(essence_id+": "+error)
		for error: String in StatRules.validate_modifiers(StatSources.content_modifiers(essence.get("passive_modifiers",[]),"essence_skill:"+essence_id,"essence_skill:"+essence_id),StatCatalog.definitions()): errors.append(essence_id+": "+error)
		if not essence.has("ability") or (str(essence.ability.get("effect", "")).is_empty() and essence.get("passive", "") != "scent_tracking"): errors.append("Essence %s has no implemented effect." % essence_id)
	for monster_id: String in monsters_data:
		var monster: Dictionary = monsters_data[monster_id]
		if int(monster.get("hp", 0)) <= 0: errors.append("Monster %s has no health." % monster_id)
		var essence_id: String = str(monster.get("essence", ""))
		if not essence_id.is_empty() and not essences_data.has(essence_id): errors.append("Monster %s drops an unavailable essence." % monster_id)
	for region_id: String in regions():
		var region: Dictionary = regions()[region_id]
		for monster_id: String in region.get("enemy_ids", []):
			if not monsters_data.has(monster_id): errors.append("Region %s has unknown enemy %s." % [region_id,monster_id])
		if not str(region.get("resource", "")).is_empty() and not items.has(region.resource): errors.append("Region %s has unknown resource %s." % [region_id,region.resource])
	return errors
