class_name SaveValidation
extends RefCounted
## Pure validation of encoded snapshots or decoded state. Never mutates payload.
const LIMIT: int = 1000000000
const STATUSES: Array[String] = ["bleeding","poison","burning","chilled","stunned","weakened","marked","frightened","ward","transformed","paralyzed","suppressed","stealth","concealed","status_immunity","pained","distressed","toppled","anchored","frenzy","field_disoriented","field_hallucinations","field_pain"]

static func validate(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var copied: Variant = _copy(payload, "$", errors, [200000], 0)
	if not copied is Dictionary:
		errors.append("$: expected state dictionary")
		return errors
	var state: Dictionary = copied
	if not errors.is_empty(): return errors
	var kinds: Dictionary = {"hero":TYPE_DICTIONARY,"inventory":TYPE_DICTIONARY,"storage":TYPE_DICTIONARY,"loot_items":TYPE_DICTIONARY,"loot_essences":TYPE_DICTIONARY,"party":TYPE_ARRAY,"units":TYPE_ARRAY,"roster":TYPE_ARRAY,"fallen":TYPE_ARRAY,"map":TYPE_DICTIONARY,"seen":TYPE_DICTIONARY,"visible":TYPE_DICTIONARY,"killed":TYPE_DICTIONARY,"journal":TYPE_ARRAY,"flags":TYPE_DICTIONARY,"rep":TYPE_DICTIONARY,"log":TYPE_ARRAY,"disarmed":TYPE_ARRAY,"visited":TYPE_ARRAY,"terrain_effects":TYPE_ARRAY,"selected":TYPE_STRING,"combat":TYPE_BOOL,"player_traps":TYPE_ARRAY,"essence_drops":TYPE_ARRAY,"floor_memory":TYPE_DICTIONARY,"visited_regions":TYPE_ARRAY,"rng_state":TYPE_STRING}
	for key: String in kinds:
		if not state.has(key) or typeof(state[key]) != kinds[key]: errors.append("$.%s: missing or invalid type" % key)
	for key: String in ["seed","version","day","gold","food","level","xp","unlocked","region","fatigue","time","round","loot_gold","light","hardship_day"]:
		_num(state, key, errors, "$", -9007199254740991 if key == "seed" else 0, 9007199254740991 if key == "seed" else LIMIT)
	if not errors.is_empty(): return errors
	if int(state.version) not in [2,3]: errors.append("$.version: expected supported campaign schema 2 or 3")
	if state.get("mode") not in ["city","dungeon","dead"]: errors.append("$.mode: unknown mode")
	if int(state.day) < 1 or int(state.level) < 1 or int(state.level) > 11: errors.append("$.day/level: outside supported range")
	if not _area(state.region) or not _area(state.unlocked): errors.append("$.region/unlocked: unknown area")
	if state.has("entity_serial"): _num(state,"entity_serial",errors,"$",0,LIMIT)
	if state.has("torch_until"): _num(state,"torch_until",errors,"$",0,LIMIT)
	if state.has("water"): _num(state,"water",errors,"$",0,LIMIT)
	if state.has("month"): _num(state, "month", errors, "$", 1)
	if state.has("rng_state"):
		if not state.rng_state is String or not state.rng_state.is_valid_int(): errors.append("$.rng_state: expected integer string")
	if state.has("numbered_state"):
		if not state.numbered_state is Dictionary: errors.append("$.numbered_state: expected dictionary")
		else:
			for id: String in state.numbered_state:
				if not NumberedCatalog.definitions().has(id) or not state.numbered_state[id] is Dictionary: errors.append("$.numbered_state: unknown or malformed artifact"); continue
				var record: Dictionary = state.numbered_state[id]
				_num(record,"charge",errors,"$.numbered_state." + id,0,1000)
				_num(record,"remainder",errors,"$.numbered_state." + id,0,99)
				_num(record,"cooldown",errors,"$.numbered_state." + id,0,int(NumberedCatalog.definitions()[id].get("active", {}).get("cooldown",0))*int(StatCatalog.definitions().cooldown_multiplier.max)+1)
				for key: String in record:
					if key not in ["charge","remainder","cooldown"]: errors.append("$.numbered_state: unknown field")
	if state.has("hunger_remainder") and (not (state.hunger_remainder is int or state.hunger_remainder is float) or not is_finite(float(state.hunger_remainder)) or float(state.hunger_remainder)<0 or float(state.hunger_remainder)>=1): errors.append("$.hunger_remainder: invalid fractional hunger")
	var items: Dictionary = GameContent.weapons()
	var essences: Dictionary = GameContent.essences()
	var monsters: Dictionary = GameContent.monsters()
	var companions: Dictionary = GameContent.companions()
	for old: String in ["ainar","erwen","hikurod","rotmiller","dwalkie","missha"]: companions[old] = companions[Recruitment.neutral_id(old)]
	for key: String in ["inventory","storage","loot_items"]: _counts(state[key], items, errors, "$." + key)
	_counts(state.loot_essences, essences, errors, "$.loot_essences")
	_counts(state.killed, monsters, errors, "$.killed")
	_counts(state.rep, GameContent.factions(), errors, "$.rep", -100000)
	for key: String in ["visited","visited_regions"]:
		if not state.has(key): continue
		if not state[key] is Array: errors.append("$.%s: expected array" % key); continue
		for entry: Variant in state[key]:
			if not _area(entry): errors.append("$.%s: invalid area" % key)
	_strings(state.roster, errors, "$.roster", companions)
	_strings(state.fallen, errors, "$.fallen")
	if state.has("fallen_ids"):
		if not state.fallen_ids is Array: errors.append("$.fallen_ids: expected array")
		else: _strings(state.fallen_ids, errors, "$.fallen_ids", companions)
	if state.has("recruits"):
		if not state.recruits is Dictionary: errors.append("$.recruits: expected dictionary")
		else:
			for id: String in state.recruits:
				var offer: Variant = state.recruits[id]
				if not companions.has(id) or not offer is Dictionary: errors.append("$.recruits: invalid identity record"); continue
				if not offer.get("name") is String or str(offer.name).strip_edges().is_empty() or str(offer.name).length() > 80: errors.append("$.recruits." + id + ": invalid name")
				if not offer.get("appearance") is Dictionary: errors.append("$.recruits." + id + ": invalid appearance")
	_strings(state.log, errors, "$.log")
	_strings(state.disarmed, errors, "$.disarmed")
	for entry: Variant in state.journal:
		if not entry is Dictionary or not entry.get("title") is String or not entry.get("text") is String: errors.append("$.journal: entries need string title/text")
	for key: String in state.flags:
		if not state.flags[key] is bool: errors.append("$.flags.%s: expected boolean" % key)
	var map_ok: bool = false
	if not state.map.is_empty(): map_ok = _map(state.map, errors, "$.map")
	elif state.mode == "dungeon": errors.append("$.map: dungeon requires map")
	_hut(state, errors)
	if map_ok and int(state.map.area) != int(state.region): errors.append("$.map.area: does not match current area")
	var active_map: Dictionary = state.map if map_ok and state.mode == "dungeon" else {}
	_unit(state.hero, errors, "$.hero", items, essences, monsters, companions, active_map, true, int(state.level))
	if _int(state.hero.get("hp")) and state.hero.get("dead") is bool:
		if state.mode == "dead" and (state.hero.hp != 0 or not state.hero.dead): errors.append("$.hero: death screen requires a fallen hero")
		if state.mode in ["city","dungeon"] and (state.hero.hp <= 0 or state.hero.dead): errors.append("$.hero: active campaign requires a living hero")
	if state.hero.get("essences") is Array and state.hero.essences.size() > int(state.level): errors.append("$.hero.essences: exceeds level capacity")
	if state.has("last_hit"):
		if not state.last_hit is Dictionary: errors.append("$.last_hit: expected dictionary")
		else:
			if not _position(state.last_hit.get("pos")) or not state.last_hit.get("kind") is String: errors.append("$.last_hit: invalid hit record")
			_num(state.last_hit,"amount",errors,"$.last_hit")
	var ids: Dictionary = {}
	if state.hero.get("id") is String: ids[state.hero.id] = true
	if state.party.size() > 4: errors.append("$.party: at most four companions")
	for collection: String in ["party","units"]:
		for index: int in range(state[collection].size()):
			var unit: Variant = state[collection][index]
			var path: String = "$.%s[%d]" % [collection,index]
			if not unit is Dictionary: errors.append(path + ": expected unit dictionary"); continue
			_unit(unit, errors, path, items, essences, monsters, companions, active_map, false, int(state.level))
			if unit.get("id") is String:
				if ids.has(unit.id): errors.append(path + ".id: duplicate entity ID")
				ids[unit.id] = true
			if collection == "party" and unit.get("team") != "ally": errors.append(path + ".team: companion must be ally")
			if collection == "party" and unit.get("essences") is Array and unit.essences.size() > int(state.level): errors.append(path + ".essences: exceeds level capacity")
	if state.has("benched"):
		if not state.benched is Dictionary: errors.append("$.benched: expected dictionary")
		else:
			for id: String in state.benched:
				var unit: Variant = state.benched[id]
				var path: String = "$.benched." + id
				if not companions.has(id) or not unit is Dictionary: errors.append(path + ": invalid benched companion"); continue
				_unit(unit, errors, path, items, essences, monsters, companions, {}, false, int(state.level))
				if unit.get("essences") is Array and unit.essences.size() > int(state.level): errors.append(path + ".essences: exceeds level capacity")
				if unit.get("team") != "ally" or unit.get("content_id") != id or unit.get("dead", false) or not _int(unit.get("hp")) or unit.hp <= 0: errors.append(path + ": invalid benched identity/life state")
				if ids.has(str(unit.get("id", ""))): errors.append(path + ": duplicate active/benched ID")
				ids[str(unit.get("id", ""))] = true
	for key: String in ["seen","visible"]: _visibility(state[key], errors, "$." + key)
	_records(state.get("player_traps", []), "trap", errors, "$.player_traps", active_map, essences)
	_records(state.get("essence_drops", []), "drop", errors, "$.essence_drops", {}, essences)
	_records(state.terrain_effects, "terrain", errors, "$.terrain_effects", active_map, essences)
	if state.has("floor_memory"):
		if not state.floor_memory is Dictionary: errors.append("$.floor_memory: expected dictionary")
		else:
			for key: String in state.floor_memory:
				var path: String = "$.floor_memory." + key
				var memory: Variant = state.floor_memory[key]
				if not key.is_valid_int() or str(int(key)) != key or not _area(int(key)) or not memory is Dictionary: errors.append(path + ": invalid area memory"); continue
				if not memory.get("map") is Dictionary or not memory.get("units") is Array or not memory.get("seen") is Dictionary or not memory.get("disarmed") is Array or not memory.get("player_traps") is Array: errors.append(path + ": invalid memory structure"); continue
				var valid_map: bool = _map(memory.map, errors, path + ".map")
				if valid_map and int(memory.map.area) != int(key): errors.append(path + ".map.area: does not match memory area")
				for unit: Variant in memory.units:
					if not unit is Dictionary: errors.append(path + ".units: expected dictionary"); continue
					_unit(unit, errors, path + ".units", items, essences, monsters, companions, memory.map if valid_map else {}, false, int(state.level))
				_visibility(memory.seen, errors, path + ".seen")
				_strings(memory.disarmed, errors, path + ".disarmed")
				_records(memory.player_traps, "trap", errors, path + ".player_traps", memory.map if valid_map else {}, essences)
	for error: String in HomelandRules.validate(state): errors.append("$.homeland: "+error)
	if state.get("homeland") is Dictionary and state.homeland.get("positions") is Dictionary:
		for id: Variant in state.homeland.positions:
			if not id is String or not HomelandCatalog.definitions().has(id): continue
			var position: Variant = state.homeland.positions[id]
			if not position is Vector2i: continue
			var layout: Dictionary = HomelandMap.layout_for(id)
			if not layout.walkable.has(position) or position==layout.exit: errors.append("$.homeland.positions: solid terrain or departure tile")
			for point: Dictionary in layout.interactables:
				if point.cell==position: errors.append("$.homeland.positions: occupied interaction point")
	return errors

static func _int(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and absf(value) <= 9007199254740991.0)

static func _area(value: Variant) -> bool:
	return _int(value) and GameContent.regions().has("r%02d" % int(value))

static func _hut(state: Dictionary, errors: Array[String]) -> void:
	if state.has("hut_until"): _num(state,"hut_until",errors,"$",0,LIMIT)
	if state.has("hut_region"):
		_num(state,"hut_region",errors,"$",-1,LIMIT)
		if _int(state.hut_region) and int(state.hut_region) not in [-1,0] and not _area(state.hut_region): errors.append("$.hut_region: unknown refuge area")
	if state.has("hut_site") and not (_position(state.hut_site) or state.hut_site == Vector2i(-1,-1)): errors.append("$.hut_site: invalid refuge entrance")
	if not _int(state.get("hut_until",0)) or not _int(state.get("time",0)) or int(state.get("hut_until",0))<=int(state.time): return
	if state.get("mode","")!="dungeon" or not _int(state.get("hut_region")) or int(state.hut_region)!=int(state.get("region",0)):
		errors.append("$.hut_until: active refuge requires the current dungeon area"); return
	if not state.get("map") is Dictionary or state.map.get("terrain","")!="witch_forest": errors.append("$.hut_until: refuge belongs to Witch's Forest"); return
	if not state.map.get("hut_sites") is Array or not state.map.hut_sites.has(state.get("hut_site")): errors.append("$.hut_site: active refuge must use a prepared purple tree")

static func _num(record: Dictionary, key: String, errors: Array[String], path: String, minimum: int = 0, maximum: int = LIMIT) -> void:
	if not record.has(key) or not _int(record[key]): errors.append(path + "." + key + ": expected integral number"); return
	if record[key] < minimum or record[key] > maximum: errors.append(path + "." + key + ": outside allowed range")

static func _copy(value: Variant, path: String, errors: Array[String], budget: Array, depth: int) -> Variant:
	budget[0] -= 1
	if budget[0] < 0 or depth > 32:
		if errors.size() < 20: errors.append(path + ": payload too large or deeply nested")
		return null
	if value is Dictionary:
		if value.size() > 8192: errors.append(path + ": dictionary too large"); return {}
		if value.has("@v") or value.has("@r"):
			var tag: String = "@v" if value.has("@v") else "@r"
			var length: int = 2 if tag == "@v" else 4
			if value.size() != 1 or not value[tag] is Array or value[tag].size() != length: errors.append(path + ": malformed coordinate tag"); return null
			for coordinate: Variant in value[tag]:
				if not _int(coordinate) or coordinate < -LIMIT or coordinate > LIMIT: errors.append(path + ": invalid coordinate component"); return null
			if tag == "@v": return Vector2i(int(value[tag][0]),int(value[tag][1]))
			return Rect2i(int(value[tag][0]),int(value[tag][1]),int(value[tag][2]),int(value[tag][3]))
		var result: Dictionary = {}
		for key: Variant in value:
			if not key is String: errors.append(path + ": dictionary keys must be strings"); continue
			result[key] = _copy(value[key], path + "." + key, errors, budget, depth + 1)
		return result
	if value is Array:
		if value.size() > 8192: errors.append(path + ": array too large"); return []
		var result: Array = []
		for index: int in range(value.size()): result.append(_copy(value[index], path + "[%d]" % index, errors, budget, depth + 1))
		return result
	if value is float and not is_finite(value): errors.append(path + ": nonfinite number"); return null
	if typeof(value) not in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_VECTOR2I,TYPE_RECT2I]: errors.append(path + ": unsupported value type"); return null
	if value is String and value.length() > 16384: errors.append(path + ": string too long")
	return value

static func _counts(bag: Dictionary, definitions: Dictionary, errors: Array[String], path: String, minimum: int = 0) -> void:
	for id: String in bag:
		if not definitions.has(id): errors.append(path + "." + id + ": unknown content ID")
		_num(bag,id,errors,path,minimum)

static func _strings(values: Array, errors: Array[String], path: String, definitions: Dictionary = {}) -> void:
	for value: Variant in values:
		if not value is String: errors.append(path + ": expected strings")
		elif not definitions.is_empty() and not definitions.has(value): errors.append(path + ": unknown content ID " + value)

static func _visibility(values: Dictionary, errors: Array[String], path: String) -> void:
	for key: String in values:
		var coordinates: PackedStringArray = key.split(",")
		if coordinates.size() != 2 or not coordinates[0].is_valid_int() or not coordinates[1].is_valid_int(): errors.append(path + ": invalid tile key"); continue
		if int(coordinates[0]) < 0 or int(coordinates[0]) >= 96 or int(coordinates[1]) < 0 or int(coordinates[1]) >= 64 or not values[key] is bool: errors.append(path + ": invalid explored tile")

static func _map(map: Dictionary, errors: Array[String], path: String) -> bool:
	var before: int = errors.size()
	_num(map,"width",errors,path,1,96)
	_num(map,"height",errors,path,1,64)
	_num(map,"area",errors,path,1,LIMIT)
	if not _area(map.get("area")): errors.append(path+".area: unknown area")
	_num(map,"seed",errors,path,-9007199254740991,9007199254740991)
	if errors.size() != before: return false
	if not ((int(map.width) == 38 and int(map.height) == 25) or (int(map.width) == 96 and int(map.height) == 64)):
		errors.append(path + ": unsupported map dimensions"); return false
	if not map.get("tiles") is Array or map.get("tiles",[]).size() != int(map.get("height",0)): errors.append(path + ".tiles: row count does not match height")
	else:
		for row: Variant in map.tiles:
			if not row is Array or row.size() != int(map.get("width",0)): errors.append(path + ".tiles: row width does not match width"); continue
			for tile: Variant in row:
				if not _int(tile) or tile < DungeonWorld.FLOOR or tile > DungeonWorld.SECRET: errors.append(path + ".tiles: invalid tile")
	for key: String in ["entrance","exit"]:
		if not _position(map.get(key)): errors.append(path + "." + key + ": invalid portal position")
	for key: String in ["spawns","traps"]:
		if not map.get(key) is Array: errors.append(path + "." + key + ": expected coordinate array"); continue
		for point: Variant in map[key]:
			if not _position(point): errors.append(path + "." + key + ": invalid coordinate")
	if not map.get("rooms") is Array: errors.append(path + ".rooms: expected rectangles")
	else:
		for room: Variant in map.rooms:
			if not room is Rect2i: errors.append(path + ".rooms: expected Rect2i"); continue
			if room.position.x < 0 or room.position.y < 0 or room.size.x <= 0 or room.size.y <= 0 or room.end.x > int(map.width) or room.end.y > int(map.height): errors.append(path + ".rooms: invalid bounds")
	if errors.size() != before: return false
	_map_routes(map, errors, path)
	_map_environment(map, errors, path)
	if errors.size() != before: return false
	var world_errors: Array[String] = ThirdFloorWorld.validate(map) if str(map.get("terrain","")) in ThirdFloorWorld.TERRAINS else DungeonWorld.validate(map)
	for issue: String in world_errors: errors.append(path + ": " + issue)
	if map.has("harvested_flowers"):
		if not map.get("corpse_flowers") is Array: errors.append(path+".harvested_flowers: missing valid source sites")
		elif not map.harvested_flowers is Array or map.harvested_flowers.size()>64: errors.append(path+".harvested_flowers: invalid history")
		else:
			var seen_flowers: Dictionary={}
			for flower: Variant in map.harvested_flowers:
				if not flower is Vector2i or not map.get("corpse_flowers",[]).has(flower) or seen_flowers.has(flower): errors.append(path+".harvested_flowers: unknown/duplicate flower")
				if flower is Vector2i: seen_flowers[flower]=true
	return errors.size() == before

static func _map_routes(map: Dictionary, errors: Array[String], path: String) -> void:
	if not map.has("floor_portals"): return
	if not map.floor_portals is Array or map.floor_portals.size()>16: errors.append(path+".floor_portals: expected bounded portal array"); return
	var destinations: Dictionary = {}; var positions: Dictionary = {}
	var reachable: Dictionary = DungeonWorld.reachable(map,map.entrance)
	for index: int in range(map.floor_portals.size()):
		var gate: Variant = map.floor_portals[index]
		var gate_path: String = path+".floor_portals[%d]" % index
		if not gate is Dictionary: errors.append(gate_path+": expected portal object"); continue
		if not _area(gate.get("region")) or int(gate.get("region",0))==int(map.area): errors.append(gate_path+".region: unknown/self destination")
		elif destinations.has(int(gate.region)): errors.append(gate_path+".region: duplicate destination")
		else: destinations[int(gate.region)] = true
		if not _position(gate.get("pos")): errors.append(gate_path+".pos: invalid coordinate"); continue
		if not reachable.has(gate.pos): errors.append(gate_path+".pos: unreachable portal")
		if positions.has(gate.pos): errors.append(gate_path+".pos: duplicate gate position")
		positions[gate.pos] = true

static func _map_environment(map: Dictionary, errors: Array[String], path: String) -> void:
	for key: String in ["witch_eye_exposure_minutes","witch_eye_stationary_minutes","witch_eye_entered_at"]:
		if not map.has(key): continue
		_num(map,key,errors,path,0,60 if key=="witch_eye_stationary_minutes" else LIMIT)
		if map.get("terrain","")!="witch_forest": errors.append(path+"."+key+": Witch's Eye belongs to Witch's Forest")
	if map.has("last_hero_position"):
		if not _position(map.last_hero_position) or not DungeonWorld.walkable(map,map.last_hero_position): errors.append(path+".last_hero_position: invalid previous explorer position")
	if map.has("witch_eye_spawn_uid") and (not map.witch_eye_spawn_uid is String or map.witch_eye_spawn_uid.length()>128): errors.append(path+".witch_eye_spawn_uid: invalid encounter identity")
	if map.has("connection_sites") and not map.connection_sites is Dictionary: errors.append(path+".connection_sites: expected named coordinates")
	# ThirdFloorWorld validates all huts, mounds, channels and neutral connections;
	# disallow those feature families on lower-floor maps instead of silently
	# accepting malformed metadata that a future traversal could consume.
	if str(map.get("terrain","")) not in ThirdFloorWorld.TERRAINS:
		for key: String in ["hut_sites","witch_tree_sites","shelter_mounds","dry_mounds","water_channels"]:
			if map.has(key): errors.append(path+"."+key+": unsupported lower-floor feature")

static func _position(value: Variant) -> bool:
	return value is Vector2i and value.x >= 0 and value.y >= 0 and value.x < 96 and value.y < 64

static func _unit(unit: Dictionary, errors: Array[String], path: String, items: Dictionary, essences: Dictionary, monsters: Dictionary, companions: Dictionary, map: Dictionary, is_hero: bool = false, level: int = 1) -> void:
	var initial_errors: int = errors.size()
	for key: String in ["id","name","team","role","behavior"]:
		if not unit.get(key) is String or unit.get(key,"").is_empty():
			errors.append(path + "." + key + ": expected nonempty string")
			return
	if unit.get("team") not in ["ally","enemy"]: errors.append(path + ".team: unknown team")
	if is_hero and (unit.get("id") != "hero" or unit.get("team") != "ally"): errors.append(path + ": invalid hero identity")
	if is_hero or unit.has("ancestry"):
		if not GameContent.ancestries().has(unit.get("ancestry")): errors.append(path + ".ancestry: unknown ancestry")
	if is_hero and not GameContent.backgrounds().has(unit.get("background")): errors.append(path + ".background: unknown background")
	if unit.get("team") == "enemy" and not monsters.has(unit.get("content_id")): errors.append(path + ".content_id: unknown monster")
	if unit.get("team") == "ally" and not is_hero and not unit.get("summon",false) and not companions.has(unit.get("content_id")): errors.append(path + ".content_id: unknown companion")
	for key: String in ["base_hp","hp","max_hp","str","agi","wit","vig","base_power","base_armor","armor","power","accuracy","evasion","range","energy","max_energy","ap","injuries","loyalty","durability"]:
		_num(unit,key,errors,path,-1000 if key in ["armor","base_armor","accuracy","evasion"] else 0,1000000)
	for key: String in ["attacked","guard","dead","summon"]:
		if not unit.get(key) is bool: errors.append(path + "." + key + ": expected boolean")
	if _int(unit.get("hp")) and _int(unit.get("max_hp")) and (unit.max_hp <= 0 or unit.hp > unit.max_hp): errors.append(path + ".hp: invalid health bounds")
	if _int(unit.get("energy")) and _int(unit.get("max_energy")) and unit.energy > unit.max_energy: errors.append(path + ".energy: exceeds maximum")
	if not _position(unit.get("pos")): errors.append(path + ".pos: invalid position")
	elif not map.is_empty() and not DungeonWorld.walkable(map,unit.pos): errors.append(path + ".pos: solid terrain")
	for key: String in ["statuses","status_power","cooldowns","resist","equipment","intent"]:
		if not unit.get(key) is Dictionary: errors.append(path + "." + key + ": expected dictionary")
	if unit.get("equipment") is Dictionary:
		for slot: String in ["weapon","armor","charm"]:
			var id: Variant = unit.equipment.get(slot)
			if not id is String: errors.append(path + ".equipment." + slot + ": expected item ID"); continue
			if id.is_empty(): continue
			if not items.has(id) or items[id].get("slot") != slot: errors.append(path + ".equipment." + slot + ": incompatible item")
		for slot: String in unit.equipment:
			if slot not in ["weapon","armor","charm"]: errors.append(path + ".equipment: unknown slot")
	for key: String in ["statuses","status_power"]:
		if not unit.get(key) is Dictionary: continue
		for id: String in unit[key]:
			if id not in STATUSES: errors.append(path + "." + key + ": unknown status")
			_num(unit[key],id,errors,path + "." + key,0,1000000)
	if unit.get("resist") is Dictionary:
		for id: String in unit.resist: _num(unit.resist,id,errors,path + ".resist",-1000,1000)
	if not unit.get("essences") is Array: errors.append(path + ".essences: expected array")
	else:
		_strings(unit.essences,errors,path + ".essences",essences)
		var seen: Dictionary = {}
		for id: Variant in unit.essences:
			if not id is String: continue
			if seen.has(id): errors.append(path + ".essences: duplicate essence")
			seen[id] = true
	if unit.has("witch_eye"):
		if not unit.witch_eye is bool: errors.append(path+".witch_eye: expected boolean")
		elif unit.witch_eye and (unit.get("content_id","")!="canon_carnivaro" or unit.get("team","")!="enemy" or unit.get("summon",false)): errors.append(path+".witch_eye: requires an ordinary enemy Carnivaro")
	if unit.has("spawn_origin") and not _position(unit.spawn_origin): errors.append(path+".spawn_origin: invalid origin")
	if unit.has("encounter_group") and (not unit.encounter_group is String or unit.encounter_group.length()>128): errors.append(path+".encounter_group: invalid group")
	if unit.has("summoner") and (not unit.summoner is String or unit.summoner.is_empty() or not unit.get("summon",false)): errors.append(path+".summoner: invalid owner")
	if unit.has("lifetime"): _num(unit,"lifetime",errors,path,0,1000000)
	if unit.has("summon_expires_at"): _num(unit,"summon_expires_at",errors,path,0,LIMIT)
	if unit.get("summon",false) and not monsters.has(unit.get("content_id")): errors.append(path+".summon: unknown summoned species")
	if unit.has("recovery_remainder") and (not (unit.recovery_remainder is int or unit.recovery_remainder is float) or not is_finite(float(unit.recovery_remainder)) or float(unit.recovery_remainder)<0 or float(unit.recovery_remainder)>=1): errors.append(path+".recovery_remainder: invalid fractional recovery")
	for remainder: String in ["soul_recovery_remainder","mana_recovery_remainder"]:
		if unit.has(remainder) and (not (unit[remainder] is int or unit[remainder] is float) or not is_finite(float(unit[remainder])) or float(unit[remainder])<0 or float(unit[remainder])>=1): errors.append(path+"."+remainder+": invalid fractional recovery")
	for error: String in DragonBlessingRules.validate_unit(unit): errors.append(path+".dragon_blessing: "+error)
	if unit.has("dragon_blessing") and level<DragonBlessingRules.MIN_LEVEL: errors.append(path+".dragon_blessing: level requirement not met")
	for error: String in SpiritRules.validate_unit(unit): errors.append(path+".spirit: "+error)
	for error: String in SpiritStones.validate_unit(unit): errors.append(path+".wind: "+error)
	if unit.has("breath_remaining") and (not (unit.breath_remaining is int or unit.breath_remaining is float) or not is_finite(float(unit.breath_remaining)) or float(unit.breath_remaining)<0 or float(unit.breath_remaining)>6000): errors.append(path+".breath_remaining: invalid breath reserve")
	if unit.has("base_stats"):
		if not unit.base_stats is Dictionary: errors.append(path+".base_stats: expected dictionary")
		else:
			for id: Variant in unit.base_stats:
				if not StatCatalog.definitions().has(id) or not (unit.base_stats[id] is int or unit.base_stats[id] is float) or not is_finite(float(unit.base_stats[id])) or absf(float(unit.base_stats[id]))>1000000000: errors.append(path+".base_stats: unknown or invalid stat "+str(id))
	if unit.has("modifiers"):
		for error: String in StatRules.validate_modifiers(unit.modifiers,StatCatalog.definitions()): errors.append(path+".modifiers: "+error)
	var equipment_record: Dictionary = unit.equipment if unit.get("equipment") is Dictionary else {}
	var owned_essences: Array = unit.essences if unit.get("essences") is Array else []
	for error: String in RacialRules.validate_state(unit): errors.append(path + ".racial: " + error)
	if str(equipment_record.get("charm", "")) == "frost_spirit_ring" and not owned_essences.is_empty() and not unit.has("ring_sealed_essence"): errors.append(path + ".ring_sealed_essence: missing selected seal")
	if unit.has("ring_sealed_essence"):
		if not unit.ring_sealed_essence is String: errors.append(path + ".ring_sealed_essence: expected essence ID")
		elif str(equipment_record.get("charm", "")) != "frost_spirit_ring" or (not unit.ring_sealed_essence.is_empty() and not owned_essences.has(unit.ring_sealed_essence)) or (unit.ring_sealed_essence.is_empty() and not owned_essences.is_empty()): errors.append(path + ".ring_sealed_essence: incompatible seal")
	if unit.has("dragon_fear_enabled") and (not unit.dragon_fear_enabled is bool or str(unit.get("ancestry", "")) != "draconian"): errors.append(path + ".dragon_fear_enabled: invalid racial control")
	for error: String in ProfessionRules.validate(unit): errors.append(path + ".magic_assessment: " + error)
	if unit.has("magic_trained"):
		if not unit.magic_trained is bool: errors.append(path + ".magic_trained: expected boolean")
		elif unit.magic_trained and (unit.get("ancestry", "") != "human" or unit.get("profession", "") != "mage" or not unit.get("magic_assessment") is String or str(unit.get("magic_assessment", "")) != "limited" or unit.get("can_absorb_essences",true) or not unit.get("spells") is Array or not unit.spells.has("ice_spear")): errors.append(path + ".magic_trained: incompatible trained mage")
	if unit.has("profession") and unit.profession not in ["explorer", "mage"]: errors.append(path + ".profession: invalid profession")
	if unit.has("can_absorb_essences") and not unit.can_absorb_essences is bool: errors.append(path + ".can_absorb_essences: expected boolean")
	if unit.get("essences") is Array and not unit.essences.is_empty() and (unit.get("profession", "") == "mage" or unit.get("can_absorb_essences", true) == false): errors.append(path + ".essences: mage cannot absorb essences")
	if unit.get("essences") is Array and not unit.essences.is_empty() and companions.has(str(unit.get("content_id", ""))) and companions[str(unit.content_id)].get("profession", "explorer") == "mage": errors.append(path + ".essences: mage template cannot absorb essences")
	var spell_defs: Dictionary = GameContent.spells()
	if unit.get("cooldowns") is Dictionary:
		for id: String in unit.cooldowns:
			var native: Dictionary = monsters.get(str(unit.get("content_id","")),{})
			var native_cooldown: bool = unit.get("team","")=="enemy" and ((id=="frenzy" and native.has("ally_buff")) or (id=="counterweight" and native.has("counterweight")))
			if not essences.has(id) and not spell_defs.has(id) and not native_cooldown and not (id == "suppression" and unit.get("content_id", "") == "canon_stone_golem"): errors.append(path + ".cooldowns: unknown technique")
			_num(unit.cooldowns,id,errors,path + ".cooldowns")
	if unit.has("last_noise"):
		if not unit.last_noise is Dictionary: errors.append(path+".last_noise: expected sound record")
		else:
			if not _position(unit.last_noise.get("pos")): errors.append(path+".last_noise.pos: invalid sound position")
			_num(unit.last_noise,"time",errors,path+".last_noise")
	if unit.has("last_seen") and not (unit.last_seen is Vector2i and (_position(unit.last_seen) or unit.last_seen == Vector2i(-1,-1))): errors.append(path + ".last_seen: invalid position")
	if unit.get("intent") is Dictionary and not unit.intent.is_empty():
		if not unit.intent.get("kind") is String or not _position(unit.intent.get("pos")): errors.append(path + ".intent: invalid telegraph")
		_num(unit.intent,"radius",errors,path + ".intent",0,38)
	if unit.has("appearance") and not unit.appearance is Dictionary: errors.append(path + ".appearance: expected dictionary")
	for key: String in ["mana","max_mana","spell_power"]:
		if unit.has(key): _num(unit,key,errors,path)
	if unit.has("spells"):
		if not unit.spells is Array: errors.append(path + ".spells: expected array")
		else: _strings(unit.spells,errors,path + ".spells",spell_defs)

	if unit.has("mana") and unit.has("max_mana") and _int(unit.mana) and _int(unit.max_mana) and unit.mana > unit.max_mana: errors.append(path + ".mana: exceeds maximum")

	if errors.size()==initial_errors:
		var composed: Dictionary = StatSources.resolve(unit,level,items,essences,GameContent.ancestries())
		for error: String in composed.errors: errors.append(path+".stats: "+error)
		if composed.errors.is_empty() and unit.has("natural_energy_current") and float(unit.natural_energy_current)>float(composed.values.natural_energy): errors.append(path+".natural_energy_current: exceeds resolved capacity")

static func _records(records: Variant, kind: String, errors: Array[String], path: String, map: Dictionary, essences: Dictionary) -> void:
	if not records is Array: errors.append(path + ": expected array"); return
	for record: Variant in records:
		if not record is Dictionary: errors.append(path + ": expected dictionary record"); continue
		if not _position(record.get("pos")): errors.append(path + ".pos: invalid position")
		elif not map.is_empty() and not DungeonWorld.walkable(map,record.pos): errors.append(path + ".pos: solid terrain")
		if kind == "drop":
			if not essences.has(record.get("id")): errors.append(path + ".id: unknown essence")
			_num(record,"region",errors,path,1,LIMIT)
			if not _area(record.get("region")): errors.append(path+".region: unknown area")
			_num(record,"expires_at",errors,path)
		else:
			if record.get("team") not in ["ally","enemy"] or not record.get("owner") is String: errors.append(path + ": invalid owner/team")
		if kind in ["trap","terrain"] and record.has("status_duration"): _num(record,"status_duration",errors,path,1,1000000)
		if kind == "terrain":
			if record.get("type") not in ["concealment","fire","poison"]: errors.append(path + ".type: unknown terrain effect")
			for key: String in ["turns","radius","damage"]: _num(record,key,errors,path)
