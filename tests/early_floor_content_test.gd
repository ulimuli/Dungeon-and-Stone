extends SceneTree
## Independent content/art validation. Actual AI/combat/drop/save integration is
## covered separately; these fixtures never claim all novel skill kits are known.
const Catalog=preload("res://game/early_floor_content.gd")
const Stats=preload("res://game/stat_rules.gd")
const Sources=preload("res://game/stat_sources.gd")
const Registry=preload("res://game/stat_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var monsters: Dictionary=Catalog.monsters()
	check(monsters.size()==13,"Thirteen researched early-floor additions, no synthetic rows")
	check(Catalog.validate().is_empty(),"Bundled content validates")
	var base: Array[String]=["canon_goblin","canon_ghoul","canon_gnome","canon_blade_wolf","canon_goblin_archer","canon_goblin_swordsman","canon_skeleton","canon_stone_golem"]
	var names: Dictionary={}; var pixel_hashes: Dictionary={}; var profiles: Dictionary={}
	for id: String in monsters:
		var row: Dictionary=monsters[id]
		check(not names.has(row.name),"Species display identity is unique: "+id); names[row.name]=true
		check(row.rank in [8,9] and row.xp==10-row.rank,"Documented rank/XP agree: "+id)
		check(row.gold==0 and row.status=="" and row.affinity=="physical","No unsourced coins, poisons, magic or statuses added: "+id)
		check(row.get("essence","")==("canon_death_fiend" if id=="canon_death_fiend" else ""),"Only a researched transferable essence is enabled: "+id)
		check(not row.reference_urls.is_empty() and not row.documented_locations.is_empty() and row.art_provisional,"Provenance and provisional art retained: "+id)
		for key: String in ["hp","power","armor","accuracy","evasion","range","move"]:
			check(row.experimental_numeric_fields.has(key),"Unsupported numeric coefficient explicitly estimated: "+id+"/"+key)
		var signature: String=var_to_str([row.hp,row.power,row.armor,row.evasion,row.accuracy,row.range,row.move])
		check(not profiles.has(signature),"Current tactical stat profiles are not duplicate clones: "+id); profiles[signature]=true
		var image: Image=Catalog.sprite_image(id)
		check(image.get_size()==Vector2i(32,32) and image.get_format()==Image.FORMAT_RGBA8,"Native32px crisp transparent sprite exists: "+id)
		check(image.get_pixel(0,0).a==0 and image.get_pixel(31,31).a==0,"No opaque fallback background: "+id)
		var visible: int=0; var binary_alpha: bool=true
		for y: int in range(32):
			for x: int in range(32):
				var alpha: float=image.get_pixel(x,y).a
				if alpha>0: visible+=1
				binary_alpha=binary_alpha and (alpha==0 or alpha==1)
		check(binary_alpha,"Pixel edges preserve binary alpha: "+id)
		check(visible>80 and visible<850,"Species has substantial readable transparent silhouette: "+id)
		var hash_value: int=hash(image.get_data())
		check(not pixel_hashes.has(hash_value),"Species art isn't an identical placeholder: "+id); pixel_hashes[hash_value]=true
		check(Catalog.sprite_image(id,1).get_data()!=image.get_data(),"Second pose changes rendered pixels: "+id)
		check(Catalog.sprite(id)==Catalog.sprite(id,2) and Catalog.sprite(id,1)!=Catalog.sprite(id),"Animation textures cache by stable pose without shared wrong species: "+id)
	for region: String in Catalog.region_pools():
		var seen: Dictionary={}
		for id: String in Catalog.region_pools()[region]:
			check((monsters.has(id) or id in base) and not seen.has(id),"Every habitat ID is available and not repeated: "+region+"/"+id); seen[id]=true
			if monsters.has(id): check(monsters[id].documented_locations.has({"canon_land_of_dead":"Land of the Dead","canon_black_rock_mountain":"Black Rock Mountain","canon_den_of_beasts":"Den of Beasts"}[region]),"Species is not transplanted into an unsourced biome: "+id)
	for id: String in Catalog.den_bands().ordinary:
		check(id in base or monsters[id].rank==9,"Ordinary canyon band contains only rank-nine creatures")
	for id: String in Catalog.den_bands().deep: check(monsters[id].rank==8,"Deep canyon excludes rank-nine creatures")
	var essence: Dictionary=Catalog.essences().canon_death_fiend
	check(essence.source_stats.is_empty() and essence.modifiers.is_empty(),"Unknown raw essence stat package remains unknown")
	check(essence.passive=="physical_preservation" and essence.passive_modifiers.size()==1 and essence.passive_modifiers[0].stat=="natural_recovery" and essence.passive_modifiers[0].op=="multiply","Recovery passive targets shared stats separately from retained attributes")
	check(Stats.validate_modifiers(Sources.content_modifiers(essence.passive_modifiers,"passive:test","essence:test"),Registry.definitions()).is_empty(),"Passive modifier passes the actual shared rules validator")
	check(essence.ability.effect=="call_dead" and essence.ability.summon_id=="canon_ghoul" and essence.ability.summon_count==10,"Transferred active names actual Ghouls and sourced ten-creature pattern")
	check(essence.ability.cost==12 and essence.ability.cooldown==6 and essence.ability.radius==4 and essence.ability.summon_duration==12 and not essence.ability.numeric_parameters_verified,"Estimated player resource/cooldown/lifetime limits stay explicit")
	check(monsters.canon_death_fiend.summoning.count==10 and monsters.canon_death_fiend.summoning.count_verified,"Monster ten-Ghoul summon count is source evidence, not arbitrary reduction")
	check(monsters.canon_death_fiend.regeneration.nonlethal_only and monsters.canon_death_fiend.territorial.pursuit_radius==10,"Death Fiend real behavior conditions and estimated range are structured")
	check(not essence.full_kit_verified and essence.partial_component_reconstruction and essence.essence_transfer_verified,"Known skill transfer does not claim every attribute/formula is recovered")
	check(not monsters.canon_werewolf.has("regeneration") and not monsters.canon_saber_tiger.has("leap"),"Creature names never silently invent unsupported passive/active kits")
	check(not monsters.has("canon_vulkars"),"Unknown Bulkar rank/kit is not fabricated as a completed entry")
	var mutated: Dictionary=Catalog.monsters(); mutated.canon_saber_tiger.hp=0; mutated.canon_saber_tiger.reference_urls.clear()
	check(Catalog.monsters().canon_saber_tiger.hp>0 and not Catalog.monsters().canon_saber_tiger.reference_urls.is_empty(),"Queries cannot corrupt later content/provenance")
	check(Catalog.sprite("not_a_monster")==null,"Missing species yields no misleading fallback art")
	print("EARLY FLOOR CONTENT: %d checks, %d failures.13 sourced species additions, original13-sprite art,1 partial DeathFiend essence; tactical coefficients explicit estimates. Pure definition/art coverage, not AI integration." % [checks,failures])
	quit(1 if failures else 0)
