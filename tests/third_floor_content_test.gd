extends SceneTree
## Pure content and pixel asset checks. Actual combat/field integration is separate.
const Catalog=preload("res://game/third_floor_content.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var rows: Dictionary=Catalog.monsters(); var names: Dictionary={}; var hashes: Dictionary={}; var xp: int=0
	check(rows.size()==14,"Fourteen sourced species, no synthetic padding")
	check(Catalog.validate().is_empty(),"Third-floor definitions validate")
	for id: String in rows:
		var row: Dictionary=rows[id]; xp+=row.xp
		check(id.begins_with("canon_") and not names.has(row.name),"Stable species identity: "+id); names[row.name]=true
		check(row.rank in [7,8,9] and row.xp==10-row.rank,"Rank/first-species XP agree: "+id)
		check(row.gold==0 and row.status=="" and row.phase_power==0,"No fabricated coin drops, poisons or boss phases: "+id)
		check(not row.reference_urls.is_empty() and not row.documented_locations.is_empty() and not row.full_kit_verified,"Known sources and incomplete skill package explicit: "+id)
		check(row.essence==("canon_iron_tusk" if id=="canon_iron_tusk" else ""),"Only known transferable active awards an essence: "+id)
		var estimated: bool=true
		for key: String in ["hp","power","armor","accuracy","evasion","range","move"]: estimated=estimated and row.experimental_numeric_fields.has(key)
		check(estimated,"All unsupported ordinary combat coefficients marked provisional: "+id)
		var image: Image=Catalog.sprite_image(id); var visible: int=0; var hard_edges: bool=true
		check(image.get_size()==Vector2i(32,32) and image.get_format()==Image.FORMAT_RGBA8,"Native32px pixel sprite: "+id)
		for y: int in range(32):
			for x: int in range(32):
				var alpha: float=image.get_pixel(x,y).a
				if alpha>0: visible+=1
				hard_edges=hard_edges and (alpha==0 or alpha==1)
		check(visible>80 and visible<850 and hard_edges and image.get_pixel(0,31).a==0,"Readable binary-alpha silhouette without solid background: "+id)
		var digest: int=hash(image.get_data())
		check(not hashes.has(digest),"No identical species sprite placeholder: "+id); hashes[digest]=true
		check(Catalog.sprite_image(id,1).get_data()!=image.get_data(),"Second pose produces actual pixel motion: "+id)
		check(Catalog.sprite(id)==Catalog.sprite(id,2) and Catalog.sprite(id)!=Catalog.sprite(id,1),"Texture cache isolates species and pose: "+id)
	check(xp==29,"Fourteen additional first-species rewards total29XP")
	var regions: Dictionary=Catalog.regions()
	check(regions.size()==4,"Four researched habitats; no claim the entire third floor has only four areas")
	var canonical_terrain: Dictionary={"canon_ironrock_hill":"ironrock_hills","canon_orc_colony":"orc_colony","canon_witch_forest":"witch_forest","canon_dark_river_estuary":"dark_estuary"}
	for id: String in regions:
		var area: Dictionary=regions[id]
		check(area.floor==3 and area.portal_closes_after_days==15 and area.terrain==canonical_terrain[id],"Third-floor identity, closure and generator key: "+id)
		check(not area.geography_complete and area.layout_provisional and not area.unimplemented_features.is_empty(),"Geography limits remain explicit: "+id)
		check(not area.has("exit_regions"),"Partial catalog does not invent a third-to-fourth portal graph: "+id)
		for species: String in area.enemy_ids:
			check(rows.has(species) and rows[species].documented_locations.has(area.name),"Pool contains only species documented in habitat: "+species)
	check(not Catalog.region_pools().canon_witch_forest.has("canon_carnivaro"),"WitchEye hunter reserved for actual field encounter")
	var frog: Dictionary=rows.canon_frogman
	check(frog.blunt_evasion.while_mobile and frog.blunt_evasion.disabled_by.has("chilled") and frog.blunt_evasion.disabled_by.has("toppled"),"Mobile blunt evasion has explicit mobility/cold counterconditions")
	check(frog.cold_stiffening.status=="chilled" and frog.cold_stiffening.experimental_numeric_fields.has("duration"),"Cold counter has explicitly estimated grid duration")
	check(not rows.canon_frogman_shaman.has("blunt_evasion") and not rows.canon_frogman_shaman.has("spell"),"Unknown shaman spell or inherited mucus is not fabricated")
	var frenzy: Dictionary=rows.canon_orc_sorcerer.ally_buff
	check(frenzy.stat=="physical_resistance" and frenzy.op=="multiply" and frenzy.value==3 and frenzy.source_duration_seconds==10,"Frenzy preserves sourced resistance×3, not attack damage")
	check(frenzy.status=="frenzy" and frenzy.duration==2 and frenzy.radius==3 and frenzy.cooldown==4,"Tactical Frenzy conversion matches agreed resolver metadata")
	for id: String in ["canon_orc_warrior","canon_orc_archer","canon_orc_sorcerer","canon_mighty_orc_warrior"]:
		check(rows[id].base_stats.physical_resistance==25 and rows[id].experimental_numeric_fields.has("physical_resistance"),"Raw resistance baseline is explicit and Frenzy has nonzero input: "+id)
	check(rows.canon_wraith.physical_immunity and rows.canon_wraith.rank==9,"Wraith preserves incorporeal defense without changing documented rank")
	check(rows.canon_carnivaro.persistent_pursuit and rows.canon_carnivaro.aliases.has("Cannibalo") and rows.canon_carnivaro.unimplemented_skills.has("Mana Mine"),"Hunter source identity/pursuit and missing kit are explicit")
	var essence: Dictionary=Catalog.essences().canon_iron_tusk
	check(essence.essence_transfer_verified and not essence.full_kit_verified and essence.source_stats.is_empty() and essence.modifiers.is_empty() and essence.passive_modifiers.is_empty(),"Known IronTusk active is not a fabricated full essence attribute package")
	check(essence.ability.effect=="counterweight" and essence.ability.status=="anchored" and essence.ability.cost==3 and essence.ability.status_duration==4 and essence.ability.cooldown==6 and not essence.ability.numeric_parameters_verified,"Counterweight active uses agreed status and explicit estimates")
	check(Catalog.sprite("missing")==null,"Missing monster does not draw a misleading fallback")
	var copy: Dictionary=Catalog.monsters(); copy.canon_frogman.blunt_evasion.disabled_by.clear()
	check(Catalog.monsters().canon_frogman.blunt_evasion.disabled_by.has("chilled"),"Nested rule metadata cannot mutate future catalog queries")
	print("THIRD FLOOR CONTENT: %d checks, %d failures.14 sourced species,4 partial habitats,1 partial essence, original32px art. Definition/asset checks only; no claim of complete skill kits." % [checks,failures])
	quit(1 if failures else 0)
