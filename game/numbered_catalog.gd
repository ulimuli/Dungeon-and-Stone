class_name NumberedCatalog
extends RefCounted
## One locally bundled data file supplies item metadata, passive operations,
## active effect sequences, targeting, balance estimates and source citations.
## Resolver code is shared. Unknown operations fail validation before play.
const DATA_PATH: String = "res://game/numbered_items.json"
const SUPPORTED_PASSIVES: Array[String] = ["seal_essence", "damage_reduction", "extra_weapon_damage"]
const SUPPORTED_ACTIVES: Array[String] = ["cleanse", "status_immunity", "knockback"]
static var _entries: Dictionary = {}
static var _load_errors: Array[String] = []

static func definitions() -> Dictionary:
	if _entries.is_empty() and _load_errors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary and not parsed.is_empty(): _entries = parsed
		else: _load_errors.append(DATA_PATH + ": expected a nonempty JSON object")
	return _entries

static func items() -> Dictionary:
	var result: Dictionary = {}
	for id: String in definitions():
		if not definitions()[id] is Dictionary or not validate_entries({id:definitions()[id]}).is_empty(): continue
		var row: Dictionary = definitions()[id]
		var item: Dictionary = {"name":row.name, "number":int(row.number), "kind":row.kind, "slot":row.slot, "price":int(row.price), "weight":float(row.weight), "desc":"No. %d. %s" % [row.number,row.desc], "market_unlocked":true, "market_limit":int(row.market_limit), "experimental_balance":true, "implementation_note":row.estimates, "reference_urls":row.reference_urls.duplicate()}
		for key: String in ["power","armor","accuracy","evasion","range","str_req","agi_req"]:
			if row.has(key): item[key] = int(row[key])
		if row.has("weapon_style"): item.weapon_style = row.weapon_style
		if row.has("modifiers"): item.modifiers = row.modifiers.duplicate(true)
		if row.has("base_stats"): item.base_stats = row.base_stats.duplicate(true)
		result[id] = item
	return result

static func validate() -> Array[String]:
	var errors: Array[String] = validate_entries(definitions())
	errors.append_array(_load_errors)
	return errors

static func validate_entries(entries: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var numbers: Dictionary = {}
	for id: String in entries:
		var prefix: String = "Numbered Item " + id + ": "
		if not entries[id] is Dictionary: errors.append(prefix + "expected object"); continue
		var row: Dictionary = entries[id]
		if not _whole(row.get("number")) or int(row.number) < 1 or int(row.number) > 9999: errors.append(prefix + "number must be1–9999")
		elif numbers.has(int(row.number)): errors.append(prefix + "duplicate number " + str(row.number))
		else: numbers[int(row.number)] = true
		if not row.get("name") is String or str(row.get("name", "")).is_empty(): errors.append(prefix + "name required")
		if not row.get("reference_urls") is Array or row.get("reference_urls", []).is_empty(): errors.append(prefix + "sources required")
		else:
			for source: Variant in row.reference_urls:
				if not source is String or not (str(source).begins_with("https://") or str(source).begins_with("http://")) or str(source).find(".") < 0: errors.append(prefix + "source must be a web URL")
		for key: String in ["desc","estimates"]:
			if not row.get(key) is String or str(row.get(key, "")).is_empty(): errors.append(prefix + key + " required")
		if row.get("kind", "") not in ["weapon","armor"]: errors.append(prefix + "unsupported equipment kind")
		if not _whole(row.get("market_limit")) or int(row.get("market_limit",-1)) not in [0,1]: errors.append(prefix + "market_limit must be0 or1")
		for key: String in ["power","armor","accuracy","evasion","range","str_req","agi_req"]:
			if row.has(key) and not _whole(row[key]): errors.append(prefix + "invalid " + key)
		if row.has("weapon_style") and row.weapon_style not in ["slashing","blunt","piercing","ranged"]: errors.append(prefix+"unsupported weapon style")
		if row.has("base_stats"):
			if not row.base_stats is Dictionary: errors.append(prefix+"base_stats must be an object")
			else:
				for stat: Variant in row.base_stats:
					var value: Variant = row.base_stats[stat]
					if not StatCatalog.definitions().has(stat) or not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1000000000: errors.append(prefix+"unknown or invalid intrinsic stat "+str(stat))
		if not row.get("ritual", {}) is Dictionary: errors.append(prefix + "ritual must be an object")
		elif not row.get("ritual", {}).is_empty():
			var ritual: Dictionary = row.ritual
			if not ritual.get("op") is String or str(ritual.get("op")) != "awaken_skadia" or not ritual.get("race") is String or str(ritual.get("race")) != "beastman" or not ritual.get("destroy_equipped") is bool or not ritual.get("destroy_equipped",false): errors.append(prefix + "unsupported ritual")
		if row.get("slot", "") not in ["weapon","armor","charm"]: errors.append(prefix + "unsupported slot")
		if not _whole(row.get("price")) or float(row.get("price", -1)) < 0: errors.append(prefix + "invalid price")
		if not (row.get("weight") is int or row.get("weight") is float) or not is_finite(float(row.get("weight", -1))) or float(row.get("weight", -1)) < 0: errors.append(prefix + "invalid weight")
		for error: String in StatRules.validate_modifiers(StatSources.content_modifiers(row.get("modifiers",[]),"item:"+id,"item:"+id),StatCatalog.definitions()): errors.append(prefix+error)
		if not row.get("passives", []) is Array: errors.append(prefix + "passives must be an array"); continue
		for effect: Variant in row.get("passives", []):
			if not effect is Dictionary or effect.get("op", "") not in SUPPORTED_PASSIVES: errors.append(prefix + "unsupported passive"); continue
			if effect.op == "damage_reduction" and (not _whole(effect.get("percent")) or int(effect.get("percent", -1)) < 0 or int(effect.get("percent", 101)) > 100): errors.append(prefix + "damage reduction must be0–100 percent")
			if effect.op == "extra_weapon_damage" and (not _whole(effect.get("amount")) or int(effect.get("amount", -1)) < 1 or effect.get("damage_type", "") not in StatSources.DAMAGE_KINDS): errors.append(prefix + "invalid added damage")
		if not row.get("active", {}) is Dictionary: errors.append(prefix + "active must be an object"); continue
		var active: Dictionary = row.get("active", {})
		if not active.is_empty():
			for key: String in ["ap","cooldown","base_duration","max_duration","charge_per_round"]:
				if not _whole(active.get(key)) or int(active.get(key, -1)) < 0: errors.append(prefix + "invalid active " + key)
			if not active.get("effects", []) is Array: errors.append(prefix + "active effects must be an array"); continue
			if active.has("dwarf_duration_multiplier") and (not (active.dwarf_duration_multiplier is int or active.dwarf_duration_multiplier is float) or not is_finite(float(active.dwarf_duration_multiplier)) or float(active.dwarf_duration_multiplier) <= 0): errors.append(prefix + "invalid Dwarf duration multiplier")
			for effect: Variant in active.get("effects", []):
				if not effect is Dictionary or effect.get("op", "") not in SUPPORTED_ACTIVES: errors.append(prefix + "unsupported active"); continue
				if effect.get("target", "") not in ["allies","enemies"] or not _whole(effect.get("radius")) or int(effect.get("radius", -1)) < 0: errors.append(prefix + "invalid targeting")
				if effect.op == "knockback" and (not _whole(effect.get("distance")) or int(effect.get("distance", -1)) < 0): errors.append(prefix + "invalid displacement")
		if row.get("passives", []).is_empty() and active.is_empty() and row.get("ritual", {}).is_empty(): errors.append(prefix + "no implemented effect")
	return errors

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0
