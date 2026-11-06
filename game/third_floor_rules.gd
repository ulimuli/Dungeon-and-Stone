class_name ThirdFloorRules
extends RefCounted
## Source facts: Witch field cleansing/statuses (56–57), stationary pursuit (61),
## 8h cabin refuge (62–63), estuary tides (115). Grid radii, field-stat conversions,
## refuge appearance cadence and the discrete Eye escalation are estimates.
const FIELD_STATUSES: Array[String] = ["field_disoriented", "field_hallucinations", "field_pain"]
const FIELD_DURATION: int = 1000000
const DAY: int = 1440
const HUT_LIFETIME: int = 480
const EYE_LATE_EXPOSURE: int = 84 * 60
const NO_DEADLINE: int = 2147483647
const EYE_MONSTER: String = "canon_carnivaro"

static func _kind(sim: RefCounted) -> String:
	if sim.state.get("mode", "") != "dungeon": return ""
	var definition: Dictionary = sim.region_data()
	var terrain: String = str(definition.get("terrain", sim.state.get("map", {}).get("terrain", ""))).to_lower()
	var label: String = str(definition.get("name", "")).to_lower()
	if "witch" in terrain or "witch" in label: return "witch"
	if "estuary" in terrain or "estuary" in label: return "estuary"
	return ""

static func in_refuge(sim: RefCounted) -> bool:
	return _kind(sim) == "witch" and int(sim.state.get("hut_region", -1)) == int(sim.state.get("region", -2)) and int(sim.state.get("hut_until", 0)) > int(sim.state.get("time", 0))

static func field_active(sim: RefCounted) -> bool:
	return _kind(sim) == "witch" and not in_refuge(sim)

static func _units(sim: RefCounted) -> Array:
	return sim.allies() + sim.enemies()

static func _sync_eye_position(sim: RefCounted) -> void:
	var map: Dictionary = sim.state.map
	if not map.has("witch_eye_exposure_minutes"): map["witch_eye_exposure_minutes"] = 0
	if not map.has("witch_eye_stationary_minutes"): map["witch_eye_stationary_minutes"] = 0
	var current: Vector2i = sim.hero().get("pos", Vector2i.ZERO)
	if map.get("last_hero_position", Vector2i(-1, -1)) != current:
		map["last_hero_position"] = current
		map["witch_eye_stationary_minutes"] = 0

static func apply_environment(sim: RefCounted) -> void:
	var active: bool = field_active(sim)
	if _kind(sim) == "witch": _sync_eye_position(sim)
	var changed: bool = false
	for unit: Dictionary in _units(sim):
		if unit.is_empty(): continue
		if not unit.has("statuses"): unit["statuses"] = {}
		if not unit.has("status_power"): unit["status_power"] = {}
		if active and int(unit.get("hp", 0)) > 0:
			for id: String in unit.statuses.keys():
				if id not in FIELD_STATUSES:
					unit.statuses.erase(id); unit.status_power.erase(id); changed = true
			for id: String in unit.status_power.keys():
				if id not in FIELD_STATUSES: unit.status_power.erase(id); changed = true
			for id: String in FIELD_STATUSES:
				if int(unit.statuses.get(id, 0)) != FIELD_DURATION: changed = true
				unit.statuses[id] = FIELD_DURATION
		else:
			for id: String in FIELD_STATUSES:
				if unit.statuses.has(id): changed = true
				unit.statuses.erase(id); unit.status_power.erase(id)
	if changed: sim.stat_cache.clear()

static func blocks_status(sim: RefCounted, _unit: Dictionary, status_id: String) -> bool:
	return field_active(sim) and status_id not in FIELD_STATUSES

static func high_tide(sim: RefCounted) -> bool:
	if _kind(sim) != "estuary": return false
	var minute: int = int(sim.state.get("time", 0)) % DAY
	# Source gives high water00–06 and rising water before midnight; the one-hour
	# preparation window is a conservative playability estimate, not an exact tide.
	return minute < 360 or minute >= 1380

static func _on_shelter(map: Dictionary, position: Vector2i) -> bool:
	if DungeonWorld.tile_at(map, position) != DungeonWorld.FLOOR: return false
	for point: Vector2i in map.get("shelter_mounds", []):
		if absi(position.x-point.x)+absi(position.y-point.y) <= 1: return true
	return false

static func can_camp(sim: RefCounted) -> String:
	if sim.state.get("mode", "") != "dungeon": return "Enter the Labyrinth before camping."
	if field_active(sim): return "Witch’s Eye makes a long rest unsafe. Find a glowing purple tree refuge."
	if high_tide(sim):
		for unit: Dictionary in sim.allies():
			if int(unit.get("hp", 0)) <= 0 or unit.get("summon", false): continue
			if not _on_shelter(sim.state.map, unit.get("pos", Vector2i(-1, -1))): return "Rising estuary water: gather the party on a dry red mound before resting."
	return ""

static func _eye_alive(sim: RefCounted) -> bool:
	for unit: Dictionary in sim.enemies():
		if unit.get("witch_eye", false) and int(unit.get("hp", 0)) > 0: return true
	return false

static func _eye_interval(map: Dictionary) -> int:
	# Only the two observed endpoints are supported; do not invent a smooth curve.
	return 10 if int(map.get("witch_eye_exposure_minutes", 0)) >= EYE_LATE_EXPOSURE else 60

static func next_deadline(sim: RefCounted) -> int:
	if _kind(sim) != "witch": return NO_DEADLINE
	_sync_eye_position(sim)
	var now: int = int(sim.state.time)
	if in_refuge(sim): return int(sim.state.hut_until)
	var map: Dictionary = sim.state.map
	var result: int = NO_DEADLINE
	var exposure: int = int(map.get("witch_eye_exposure_minutes", 0))
	if exposure < EYE_LATE_EXPOSURE: result = now + EYE_LATE_EXPOSURE - exposure
	if not _eye_alive(sim):
		var remaining: int = maxi(1, _eye_interval(map)-int(map.get("witch_eye_stationary_minutes", 0)))
		result = mini(result, now+remaining)
	return result

static func _near_landmark(map: Dictionary, position: Vector2i) -> bool:
	var points: Array = []
	for key: String in ["entrance", "exit", "sky_tower"]:
		if map.get(key) is Vector2i: points.append(map[key])
	for key: String in ["area_portals", "floor_portals"]:
		for gate: Dictionary in map.get(key, []):
			if gate.get("pos") is Vector2i: points.append(gate.pos)
	points.append_array(map.get("hut_sites", []))
	for point: Vector2i in points:
		if absi(position.x-point.x)+absi(position.y-point.y) <= 2: return true
	return false

static func _spawn_eye(sim: RefCounted) -> bool:
	if not sim.monster_defs.has(EYE_MONSTER): return false
	var origin: Vector2i = sim.hero().get("pos", Vector2i.ZERO)
	# Deterministic ring search, no rejection sampling or RNG consumption.
	for radius: int in range(3, 7):
		for y: int in range(origin.y-radius, origin.y+radius+1):
			for x: int in range(origin.x-radius, origin.x+radius+1):
				var point := Vector2i(x, y)
				if absi(x-origin.x)+absi(y-origin.y) != radius: continue
				if not DungeonWorld.walkable(sim.state.map, point) or not sim.unit_at(point).is_empty(): continue
				if _near_landmark(sim.state.map, point) or not DungeonWorld.line_of_sight(sim.state.map, origin, point): continue
				var unit: Dictionary = sim.spawn_enemy(EYE_MONSTER, point, false)
				if unit.is_empty(): return false
				unit["witch_eye"] = true; unit["alert"] = true; unit["last_seen"] = origin
				sim.state["combat"] = true
				sim.say("Witch’s Eye: a Cannibalo finds the party’s lingering position.")
				apply_environment(sim)
				return true
	return false

static func advance(sim: RefCounted, elapsed: int) -> void:
	if elapsed <= 0 or _kind(sim) != "witch": return
	_sync_eye_position(sim)
	var map: Dictionary = sim.state.map
	var now: int = int(sim.state.time)
	var start: int = now-elapsed
	var deadline: int = int(sim.state.get("hut_until", 0)) if int(sim.state.get("hut_region", -1)) == int(sim.state.region) else 0
	var protected: int = clampi(deadline-start, 0, elapsed)
	var exposed: int = elapsed-protected
	if deadline > 0 and deadline <= now:
		sim.state["hut_until"] = 0
		sim.say("The Witch’s Cabin fades. The party returns to the forest.")
	map["witch_eye_exposure_minutes"] = mini(NO_DEADLINE, int(map.get("witch_eye_exposure_minutes", 0))+exposed)
	if protected > 0: map["witch_eye_stationary_minutes"] = 0
	map["witch_eye_stationary_minutes"] = mini(60, int(map.get("witch_eye_stationary_minutes", 0))+exposed)
	apply_environment(sim)
	if exposed > 0 and not _eye_alive(sim) and int(map.witch_eye_stationary_minutes) >= _eye_interval(map):
		if _spawn_eye(sim): map["witch_eye_stationary_minutes"] = 0

static func active_hut_site(sim: RefCounted) -> Vector2i:
	if _kind(sim) != "witch": return Vector2i(-1, -1)
	var sites: Array = sim.state.map.get("hut_sites", [])
	if sites.is_empty(): return Vector2i(-1, -1)
	# Placement/cadence estimate: one candidate site for each fixed8h window.
	# Lifetime is from appearance, so late arrival does not renew the refuge.
	var cycle: int = int(sim.state.time) / HUT_LIFETIME
	return sites[cycle % sites.size()]

static func interact_hut(sim: RefCounted) -> String:
	if _kind(sim) != "witch": return "The Witch’s Cabin is reached through a glowing tree in the forest."
	if in_refuge(sim): return ""
	if sim.state.get("combat", false): return "Break contact before entering the refuge."
	var site: Vector2i = active_hut_site(sim)
	var position: Vector2i = sim.hero().get("pos", Vector2i.ZERO)
	if site == Vector2i(-1, -1) or absi(position.x-site.x)+absi(position.y-site.y) > 1: return "No active purple tree within reach."
	var occupants: int = 0
	for unit: Dictionary in sim.allies():
		if int(unit.get("hp", 0)) > 0 and not unit.get("summon", false): occupants += 1
	if occupants > 5: return "The cabin admits at most five living explorers."
	var now: int = int(sim.state.time)
	sim.state["hut_region"] = int(sim.state.region)
	sim.state["hut_until"] = (now / HUT_LIFETIME+1)*HUT_LIFETIME
	sim.state["hut_site"] = site
	sim.state.map["witch_eye_stationary_minutes"] = 0
	apply_environment(sim)
	sim.say("Witch’s Cabin: safe from monsters and the forest’s field until %02d:%02d." % [(int(sim.state.hut_until)/60)%24, int(sim.state.hut_until)%60])
	return ""
