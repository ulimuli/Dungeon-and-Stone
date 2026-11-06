class_name ReferenceRuntime
extends RefCounted
## Playable implementations of researched mechanics. Numerical timing/damage is
## provisional, explicitly distinguished from sourced facts in REFERENCE_RULES.md.
const REGION_IDS: Array[String] = ["canon_crystal_cave", "canon_goblin_forest", "canon_land_of_dead", "canon_black_rock_mountain", "canon_den_of_beasts", "canon_ironrock_hill", "canon_orc_colony", "canon_witch_forest", "canon_dark_river_estuary"]
# Episode 457's ordinary rank-nine baseline. Higher ranks and special variants
# require their own evidence; this is not a universal monster drop table.
const ORDINARY_RANK_NINE_ESSENCE_CHANCE: float = 0.0001
# Rank-eight rate is an estimate, not covered by the rank-nine source.
const ESTIMATED_RANK_EIGHT_ESSENCE_CHANCE: float = 0.0001
# Enabled only after the simulation resolves the documented components.
const EXPANDED_ESSENCE_RESOLVERS_READY: bool = true

static func regions() -> Dictionary:
	var result: Dictionary = {}
	var source: Dictionary = ReferenceContent.regions()
	source["canon_den_of_beasts"]=EarlyFloorRules.den_region()
	source.merge(ThirdFloorContent.regions())
	for id: String in EarlyFloorContent.region_pools():
		if source.has(id): source[id].enemy_ids=EarlyFloorContent.region_pools()[id]
	for index: int in range(REGION_IDS.size()):
		var region: Dictionary = source[REGION_IDS[index]].duplicate(true)
		if index<5: region.resource = "mana_stone_rank_8" if index in [3,4] else "mana_stone_rank_9"
		if index==0:
			region.lore="Crystal-lit routes surround dark outskirts and a separate dark central Great Sage memorial. Four directional boundary steles lead to the second-floor regions. Exact generated geography is provisional."
			region.exit_regions=["canon_goblin_forest","canon_land_of_dead","canon_black_rock_mountain","canon_den_of_beasts"]
			region.unimplemented_exits=[]
		if index==2: region.hazard_desc="Undead roam black ground and ruined stonework. Corpse flowers bloom from day2 and provide drinking water."
		region.playable = true
		result["r%02d" % (index + 1)] = region
	return result

static func monsters() -> Dictionary:
	var source: Dictionary = ReferenceContent.monsters()
	var result: Dictionary = {}
	for id: String in ["canon_goblin", "canon_ghoul", "canon_gnome", "canon_blade_wolf", "canon_goblin_archer", "canon_goblin_swordsman", "canon_skeleton", "canon_stone_golem"]: result[id] = source[id].duplicate(true)
	result.merge(EarlyFloorContent.monsters())
	result.merge(ThirdFloorContent.monsters())
	# Gnome concealment is resolved by the dedicated AI branch, not generic blasts.
	result.canon_gnome.role = "ambusher"
	result.canon_goblin.status = "paralyzed"
	result.canon_goblin_swordsman.status = "paralyzed"
	result.canon_goblin_archer.status = "poison"
	for monster: Dictionary in result.values():
		if int(monster.rank) == 9:
			monster.essence_drop_chance = ORDINARY_RANK_NINE_ESSENCE_CHANCE
			monster.drop_rate_source = "https://hennoveltranslations.com/archives/episodes/stgb-episode-457"
		else:
			monster.essence_drop_chance = ESTIMATED_RANK_EIGHT_ESSENCE_CHANCE
			monster.essence_drop_chance_verified = false
			monster.drop_rate_source = ""
			monster.drop_rate_note = "Higher-rank probability is a temporary estimate."
		if not EXPANDED_ESSENCE_RESOLVERS_READY and str(monster.essence) in ["canon_blade_wolf", "canon_stone_golem"]: monster.essence = ""
	return result

static func essences() -> Dictionary:
	var source: Dictionary = ReferenceContent.essences()
	var result: Dictionary = {}
	for id: String in ["canon_goblin", "canon_goblin_archer", "canon_gnome"]:
		var essence: Dictionary = source[id].duplicate(true)
		essence.affinity = "poison" if id != "canon_gnome" else "concealment"
		essence.experimental_balance = true
		essence.playable = true
		essence.requires_implementation = false
		essence.ability.cost = 3
		essence.ability.cooldown = 3
		essence.ability.range = 3 if id == "canon_goblin" else 0
		essence.ability.status_duration = 3
		essence.ability.damage_type = "poison"
		essence.value = 2
		essence.fidelity_note += " Qualitative effects now implemented; cost, cooldown, tile range, poison severity and duration remain experimental."
		result[id] = essence
	if EXPANDED_ESSENCE_RESOLVERS_READY:
		result.merge(expanded_essences())
	result.merge(EarlyFloorContent.essences())
	result.merge(ThirdFloorContent.essences())
	for essence: Dictionary in result.values():
		essence.modifiers = []
		if str(essence.get("verification_level", "")).contains("and_stats"):
			for stat: String in essence.get("source_stats", {}):
				var value: Variant = essence.source_stats[stat]
				if value is int or value is float: essence.modifiers.append({"stat":stat,"op":"add","value":value,"source_verified":true})
	return result

static func expanded_essences() -> Dictionary:
	var source: Dictionary = ReferenceContent.essences()
	var result: Dictionary = {}
	for id: String in ["canon_blade_wolf", "canon_stone_golem"]:
		var essence: Dictionary = source[id].duplicate(true)
		essence.experimental_balance = true
		essence.partial_component_reconstruction = true
		essence.playable = EXPANDED_ESSENCE_RESOLVERS_READY
		essence.requires_implementation = not EXPANDED_ESSENCE_RESOLVERS_READY
		if id == "canon_blade_wolf":
			essence.scent_range = 6
			essence.experimental_numeric_fields = ["scent_range"]
		else:
			essence.ability.cost = 3
			essence.ability.cooldown = 4
			essence.ability.range = 4
			essence.ability.radius = 1
			essence.ability.status_duration = 2
			essence.experimental_numeric_fields = ["cost", "cooldown", "range", "radius", "status_duration"]
		result[id] = essence
	return result
