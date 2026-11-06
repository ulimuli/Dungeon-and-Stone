extends SceneTree
## Generate the developer-facing master list from the same registry the game uses.
func _initialize() -> void:
	var definitions: Dictionary = StatCatalog.definitions()
	var active: int = 0
	for row: Dictionary in definitions.values():
		if row.implemented: active += 1
	var body: String = "# Shared stat reference\n\nGenerated from `game/stat_catalog.gd`. %d registered IDs: %d with simulation consumers or informational summaries, %d catalogued for future implementation. This is the known catalog in this project, not a claim that all of the novel's thousands of substats are reconstructed.\n\n" % [definitions.size(),active,definitions.size()-active]
	body += "## Numeric modifier format\n\nEquipment, essences and racial definitions use `modifiers` entries with `stat`, `op` and `value`. The owning definition supplies stable provenance automatically. Saved unit modifiers additionally provide unique `id` and `source` fields. `base_stats` supplies explicit intrinsic baselines. Registry defaults are calculator fallbacks, not novel starting attributes.\n\n"
	body += "```json\n{\"modifiers\":[{\"stat\":\"attack\",\"op\":\"add\",\"value\":8},{\"stat\":\"attack\",\"op\":\"multiply\",\"value\":1.25},{\"stat\":\"armor\",\"op\":\"add\",\"value\":3}]}\n```\n\n"
	body += "Operations: `add` is a flat bonus; `increase` is an additive fractional increase (0.25 means25%); `multiply` is an independent factor (1.25 means×1.25); `at_least` sets a lower result bound. Formula: `(base + flat bonuses) × (1 + summed increases) × multiplied factors`, then minimum bound, stat rounding and caps. Source IDs sort deterministically; duplicate modifier IDs, unknown stats, NaN/Infinity and invalid combined results are rejected. Primary attributes feed derived values before secondary modifiers. Muscle Mass contributes its sourced1% total Strength per point.\n\n"
	body += "Raw resistance points, flat armor, direct percentage reduction and damage multipliers are distinct. The current raw-point conversion `100×points/(100+abs(points))`, tactical bounds, HP/attack/resource formulas and most baseline values are explicit estimates. Known novel coefficients below weight aggregate indices; they are not damage-reduction percentages. Stateful abilities such as storing prevented damage, suppression, summoning or essence sealing still use the shared effect rules.\n\n"
	body += "## Registered stats\n\n| ID | Name | Gameplay | Unit/default | Formula or limitation |\n| --- | --- | --- | --- | --- |\n"
	var ids: Array = definitions.keys(); ids.sort()
	for id: String in ids:
		var row: Dictionary = definitions[id]
		var unit: String = str(row.get("unit","factor" if id.ends_with("_multiplier") else "value"))
		body += "| `%s` | %s | %s | %s / %s | %s |\n" % [id,row.name,"Live" if row.implemented else "Catalog only",unit,str(row.default),str(row.formula_note).replace("|","/").replace("\n"," ")]
	body += "\n## Verified relationships and source metadata\n\n"
	for id: String in ids:
		var row: Dictionary = definitions[id]
		if row.has("novel_coefficient"): body += "- `%s`: aggregate coefficient%s; %s Gameplay conversion implemented: %s.\n" % [id,str(row.novel_coefficient),row.get("novel_coefficient_scope",""),str(row.get("coefficient_implemented",false))]
	body += "\nSource URLs and the verified/estimated distinction remain beside each registry entry. Gameplay UI excludes catalog-only entries from the working stat panel. Equipment comparison resolves the whole build without spending resources or mutating saves. Recalculating maxima never refills current HP, SP or mana.\n"
	var file := FileAccess.open("res://STAT_REFERENCE.md",FileAccess.WRITE)
	file.store_string(body); file.close()
	print("STAT REFERENCE: %d registered; %d live; %d catalog only." % [definitions.size(),active,definitions.size()-active])
	quit()
