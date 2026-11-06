class_name GameSimulation
extends RefCounted

# The simulation owns every consequential rule. Presentation calls commands only.
signal message(text: String)
signal cue(name: String)
var state: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var trigger_depth: int = 0
var resolving_round: bool = false
var stat_cache: Dictionary = {}
var item_defs: Dictionary = GameContent.weapons()
var essence_defs: Dictionary = GameContent.essences()
var monster_defs: Dictionary = GameContent.monsters()
var region_defs: Dictionary = GameContent.regions()
var companion_defs: Dictionary = GameContent.companions()
var faction_defs: Dictionary = GameContent.factions()
var ancestry_defs: Dictionary = GameContent.ancestries()
var background_defs: Dictionary = GameContent.backgrounds()
const RacialProgression = preload("res://game/racial_rules.gd")
const CombatStats = preload("res://game/stat_combat_rules.gd")
const Awareness = preload("res://game/stat_awareness.gd")
const Numbered = preload("res://game/numbered_rules.gd")
const MAX_TRIGGER_DEPTH: int = 4
# Contextual interpretation of the early novel table; see REFERENCE_RULES.md.
const LEVEL_THRESHOLDS: Dictionary = {2: 6, 3: 30, 4: 150}
# Clock values are real expedition minutes; grid action durations remain estimates.
const MINUTES_PER_DAY: int = 1440
const RECOVERY_INTERVAL_MINUTES: int = 90
const UNCONTAINED_ESSENCE_LIFETIME_MINUTES: int = 30
const SEAL_DURATION_MINUTES: int = 15
const CAMP_DURATION_MINUTES: int = 480
# Current compressed currency estimate; normal novel quote is800,000 stones.
const UNDYING_SERVICE_COST: int = 800
const STATUS_ORDER: Array[String] = ["bleeding", "poison", "burning", "chilled", "stunned", "weakened", "marked", "frightened", "ward", "transformed", "paralyzed", "suppressed", "stealth", "concealed", "status_immunity", "pained", "distressed", "toppled", "anchored", "frenzy", "field_disoriented", "field_hallucinations", "field_pain"]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func say(text: String) -> void:
	if not state.has("log"): state.log = []
	state.log.append(text)
	if state.log.size() > 160: state.log.pop_front()
	message.emit(text)

func new_campaign(hero_name: String, ancestry_id: String, background_id: String, campaign_seed: int, appearance: Dictionary = {}) -> void:
	configure_content()
	stat_cache.clear()
	var ancestry: Dictionary = ancestry_defs[ancestry_id]
	var background: Dictionary = background_defs[background_id]
	rng.seed = campaign_seed
	state = {"version": 3, "seed": campaign_seed, "mode": "city", "day": 1, "gold": int(background.get("gold", 90)), "food": int(background.get("food", 8)), "water": EarlyFloorRules.WATER_START, "level": 1, "xp": 0, "unlocked": 1, "region": 1, "visited": [], "inventory": {}, "storage": {}, "party": [], "roster": [], "fallen": [], "units": [], "map": {}, "seen": {}, "visible": {}, "killed": {}, "journal": [], "flags": {}, "rep": {}, "log": [], "fatigue": 0, "time": 0, "combat": false, "round": 0, "selected": "hero", "loot_gold": 0, "loot_items": {}, "loot_essences": {}, "disarmed": [], "light": 1, "terrain_effects": [], "hardship_day": 0}
	for id: String in faction_defs: state.rep[id] = 0
	if state.rep.has(str(background.get("rep", ""))): state.rep[background.rep] = 2
	var hero: Dictionary = make_unit("hero", hero_name if not hero_name.strip_edges().is_empty() else "Wayfarer", "ally", "vanguard")
	hero.ancestry = ancestry_id
	hero.appearance = CharacterArt.normalize(appearance, ancestry_id, campaign_seed)
	hero.background = background_id
	hero.str = 4 + int(ancestry.get("str", 0))
	hero.agi = 4 + int(ancestry.get("agi", 0))
	hero.wit = 4 + int(ancestry.get("wit", 0))
	hero.vig = 4 + int(ancestry.get("vig", 0))
	hero.base_hp = 24 + int(ancestry.get("hp", 0))
	hero.base_armor = int(ancestry.get("armor", 0))
	hero.resist = ancestry.get("resist", {}).duplicate(true)
	hero.trait_effect = ancestry.get("trait_effect", "")
	var items: Dictionary = item_defs
	var starter_weapon: String = ""
	var starter_armor: String = ""
	for id: String in items:
		if items[id].get("kind", "") == "weapon" and starter_weapon.is_empty(): starter_weapon = id
		if items[id].get("kind", "") == "armor" and starter_armor.is_empty(): starter_armor = id
	hero.equipment = {"weapon": starter_weapon, "armor": starter_armor, "charm": ""}
	state.hero = hero
	state.month = 1
	state.player_traps = []
	state.essence_drops = []
	state.floor_memory = {}
	state.visited_regions = []
	for id: String in items:
		if items[id].get("effect", "") == "heal":
			add_item(id, int(background.get("potions", 3)))
			break
	recalculate(hero, true)
	ensure_city_state()
	state.log = []
	state.journal = []
	journal("Labyrinth rules", "Only the first defeat of each species grants XP. Essence slots equal level. Crystal Cave closes after seven days; second-floor areas after ten; the third floor after fifteen. Survivors return at closure.")
	say("Arrived in Rafdonia.")



func configure_content() -> void:
	item_defs = GameContent.weapons()
	monster_defs = ReferenceRuntime.monsters()
	essence_defs = ReferenceRuntime.essences()
	region_defs = ReferenceRuntime.regions()

func floor_number() -> int:
	return int(region_data().get("floor", state.get("region", 1)))

func portal_limit() -> int:
	return int(region_data().get("portal_closes_after_days", 7)) * MINUTES_PER_DAY

func elapsed_hours() -> float:
	return float(state.get("time", 0)) / 60.0

func make_unit(id: String, unit_name: String, team: String, role: String) -> Dictionary:
	return {"id": id, "name": unit_name, "team": team, "role": role, "pos": Vector2i.ZERO, "base_hp": 24, "hp": 24, "max_hp": 24, "str": 4, "agi": 4, "wit": 4, "vig": 4, "base_power": 2, "base_armor": 0, "armor": 0, "power": 6, "accuracy": 85, "evasion": 4, "range": 1, "resist": {}, "statuses": {}, "status_power": {}, "cooldowns": {}, "essences": [], "equipment": {"weapon": "", "armor": "", "charm": ""}, "energy": 12, "max_energy": 12, "mana": 0, "max_mana": 0, "spells": [], "profession": "explorer", "can_absorb_essences": true, "ap": 2, "attacked": false, "injuries": 0, "loyalty": 60, "behavior": "manual", "guard": false, "intent": {}, "dead": false, "durability": 100, "summon": false}

func recalculate(unit: Dictionary, refill: bool = false) -> void:
	if unit.team == "enemy": return
	_sync_ring_seal(unit)
	var resolved: Dictionary = _permanent_stats(unit)
	if not resolved.errors.is_empty(): say("Stat configuration: " + str(resolved.errors[0])); return
	var values: Dictionary = resolved.values
	for pair: Array in [["max_hp","max_health"],["power","attack"],["armor","armor"],["accuracy","accuracy"],["evasion","evasion"],["max_energy","max_soul_power"],["max_mana","max_mana"],["range","attack_range"],["sight","sight"],["carry_bonus","carry_bonus"]]: unit[pair[0]] = int(values[pair[1]])
	unit.hp = unit.max_hp if refill else mini(int(unit.hp),int(unit.max_hp))
	unit.energy = unit.max_energy if refill else mini(int(unit.energy),int(unit.max_energy))
	unit.mana = unit.max_mana if refill else mini(int(unit.get("mana",0)),int(unit.max_mana))
	if unit.has("natural_energy_current"):
		unit.natural_energy_current = mini(int(unit.natural_energy_current),maxi(0,int(values.natural_energy)))
		if int(unit.natural_energy_current)<=0:
			if unit.get("spirit") is Dictionary: unit.spirit.active = false
			if unit.has("wind_guidance"): unit.wind_guidance = false

func hero() -> Dictionary:
	return state.get("hero", {})

func allies() -> Array:
	var result: Array = [hero()]
	for unit: Dictionary in state.get("party", []):
		if not unit.get("dead", false): result.append(unit)
	for unit: Dictionary in state.get("units", []):
		if unit.get("summon", false) and unit.team == "ally" and unit.hp > 0: result.append(unit)
	return result

func enemies() -> Array:
	return state.get("units", []).filter(func(u: Dictionary) -> bool: return u.team == "enemy" and u.hp > 0)

func unit_by_id(id: String) -> Dictionary:
	for unit: Dictionary in allies() + enemies():
		if unit.id == id: return unit
	return {}

func unit_at(pos: Vector2i) -> Dictionary:
	for unit: Dictionary in allies() + enemies():
		if unit.hp > 0 and unit.pos == pos: return unit
	return {}

func selected() -> Dictionary:
	var unit: Dictionary = unit_by_id(str(state.get("selected", "hero")))
	return hero() if unit.is_empty() else unit

func journal(title: String, text: String) -> void:
	for entry: Dictionary in state.journal:
		if entry.title == title: return
	state.journal.append({"title": title, "text": text})

func add_item(id: String, amount: int, expedition: bool = false) -> void:
	if id.is_empty() or amount <= 0 or not item_defs.has(id): return
	var bag: Dictionary = state.loot_items if expedition else state.inventory
	bag[id] = int(bag.get(id, 0)) + amount

func take_item(id: String, amount: int = 1) -> bool:
	if amount <= 0: return false
	if int(state.inventory.get(id, 0)) < amount: return false
	state.inventory[id] -= amount
	if state.inventory[id] <= 0: state.inventory.erase(id)
	return true

func weight() -> float:
	var total: float = 0.0
	for bag: Dictionary in [state.inventory, state.loot_items]:
		for id: String in bag: total += float(item_defs.get(id, {}).get("weight", 0)) * int(bag[id])
	for u: Dictionary in allies():
		for slot: String in u.equipment:
			total += float(item_defs.get(u.equipment[slot], {}).get("weight", 0))
	return total

func capacity() -> int:
	var total: float = 14.0
	for unit: Dictionary in allies():
		if not unit.get("summon",false): total += stat_value(unit,"carry_capacity")+stat_value(unit,"carry_bonus")
	return maxi(0,int(total))

func region_data(index: int = -1) -> Dictionary:
	return region_defs["r%02d" % (int(state.region) if index < 0 else index)]

func enter_region(index: int) -> bool:
	if not str(state.get("homeland",{}).get("location","")).is_empty(): say("Return to Rafdonia before entering the Labyrinth."); return false
	if state.mode != "city" or index < 1 or index > int(state.unlocked): return false
	if int(state.day) != 1: say("The Labyrinth opens at the start of the month. Prepare, then wait for the next opening."); return false
	if index != 1: say("Enter through Crystal Cave. Reach other areas through their Labyrinth portals."); return false
	if hero().hp <= 0: return false
	if weight() > capacity(): say("Over capacity. Sell or store equipment before descending."); return false
	state.region = index
	state.map = DungeonWorld.generate(int(state.seed) + int(state.day) * 7919, index)
	if not DungeonWorld.validate(state.map).is_empty(): say("Generation validation failed. Your expedition was not started."); return false
	state.mode = "dungeon"
	state.units = []
	state.seen = {}
	state.visible = {}
	state.time = 0
	state["hut_until"]=0
	state.fatigue = 0
	state.round = 0
	state.combat = false
	state.loot_gold = 0
	state.loot_items = {}
	state.loot_essences = {}
	state.disarmed = []
	state.terrain_effects = []
	state.player_traps = []
	state.essence_drops = []
	state.floor_memory = {}
	state.light = 1
	state["torch_until"]=0
	state.selected = "hero"
	rng.seed = int(state.seed) + index * 104729 + int(state.day) * 17
	var region: Dictionary = region_data()
	var i: int = 0
	for unit: Dictionary in allies():
		unit.pos = nearest_free(state.map.entrance + Vector2i(i % 2, i / 2))
		unit.statuses = {}
		unit.status_power = {}
		unit.cooldowns = {}
		unit.ap = 2
		unit.attacked = false
		i += 1
	EarlyFloorRules.population(self)
	state.visited.append(index)
	if not state.visited_regions.has(index): state.visited_regions.append(index)
	journal(region.name, str(region.lore))
	say("Entered %s. %s" % [region.name, region.hazard_desc])
	if index == 1 and not state.flags.has("tutorial"):
		say("Entered Crystal Cave.")
		state.flags.tutorial = true
	update_visibility()
	return true



func wait_for_opening() -> bool:
	if state.mode != "city": return false
	if int(state.day) == 1: say("The Labyrinth is already open."); return false
	state.month = int(state.get("month", 1)) + 1
	state.day = 1
	say("A new month begins. The Labyrinth opens.")
	return true

func unit_visible(unit: Dictionary) -> bool:
	if not visible(unit.pos): return false
	if unit.team == "ally": return true
	if unit.statuses.has("concealed") or unit.statuses.has("stealth"):
		for ally: Dictionary in allies():
			if ally.hp > 0 and distance(ally.pos, unit.pos) <= 1: return true
		return false
	return true

func update_concealment_fields() -> void:
	for effect: Dictionary in state.terrain_effects:
		if effect.type != "concealment": continue
		var owner: Dictionary = unit_by_id(str(effect.get("owner", "")))
		if owner.is_empty() or owner.hp <= 0 or owner.pos != effect.pos:
			effect.turns = 0
			for unit: Dictionary in allies() + enemies():
				if unit.get("concealment_owner", "") == effect.get("owner", ""):
					unit.statuses.erase("concealed")
					unit.erase("concealment_owner")
	state.terrain_effects = state.terrain_effects.filter(func(e: Dictionary) -> bool: return int(e.turns) > 0)

func travel_region(index: int) -> bool:
	if state.mode != "dungeon" or index < 1 or index > region_defs.size(): return false
	if ThirdFloorRules.in_refuge(self): say("Leave the refuge before traveling."); return false
	if index not in portal_choices(): say("Reach the matching area portal first."); return false
	if state.combat and enemies().any(func(e: Dictionary) -> bool: return e.alert and distance(e.pos, hero().pos) <= 4): say("Enemies interrupt the portal crossing."); return false
	if int(state.region) == 1 and index == 1: return false
	if int(state.time)>=int(region_data(index).portal_closes_after_days)*MINUTES_PER_DAY:
		say("%s has closed. Survive until the current floor closes." % region_data(index).name); return false
	var departed_region: int=int(state.region)
	state["hut_until"]=0
	ThirdFloorRules.apply_environment(self)
	state.units=state.units.filter(func(u: Dictionary)->bool:return not u.get("summon",false))
	state.floor_memory[str(int(state.region))] = {"map": state.map, "seen": state.seen, "units": state.units, "disarmed": state.disarmed, "player_traps": state.player_traps}
	state.region = index
	state.units = []
	state.combat = false
	state.selected = "hero"
	state.player_traps = []
	if state.floor_memory.has(str(index)):
		var memory: Dictionary = state.floor_memory[str(index)]
		state.map = memory.map
		state.seen = memory.seen
		state.units = memory.units
		state.disarmed = memory.disarmed
		state.player_traps = memory.player_traps
	else:
		state.map = DungeonWorld.generate(int(state.seed) + int(state.day) * 7919, index)
		state.seen = {}
		state.disarmed = []
		EarlyFloorRules.population(self)
	var arrival: Vector2i = FloorConnections.arrival(state.map,departed_region)
	var i: int = 0
	for unit: Dictionary in allies():
		unit.pos = nearest_free(arrival + Vector2i(i % 2, i / 2))
		unit.ap = 2; unit.attacked = false
		i += 1
	ThirdFloorRules.apply_environment(self)
	if not state.visited_regions.has(index): state.visited_regions.append(index)
	state.unlocked = maxi(int(state.unlocked), index)
	journal(region_data().name, str(region_data().lore))
	say("Entered %s. Portal closure: day %d of the expedition." % [region_data().name, region_data().portal_closes_after_days])
	advance_time(1)
	update_visibility()
	return true

func spawn_enemy(content_id: String, pos: Vector2i, summoned: bool = false) -> Dictionary:
	if not monster_defs.has(content_id): return {}
	var definition: Dictionary = monster_defs[content_id]
	state["entity_serial"]=int(state.get("entity_serial",0))+1
	var spawn_id: String="enemy_spawn_%d" % int(state.entity_serial)
	while not unit_by_id(spawn_id).is_empty():
		state.entity_serial+=1; spawn_id="enemy_spawn_%d" % int(state.entity_serial)
	var unit: Dictionary = make_unit(spawn_id, definition.name, "enemy", definition.role)
	unit.content_id = content_id
	unit.pos = pos
	unit["spawn_origin"]=pos
	unit.base_hp = int(definition.hp)
	unit.max_hp = int(definition.hp)
	unit.hp = int(definition.hp)
	unit.power = int(definition.power)
	unit.armor = int(definition.get("armor", 0))
	unit.evasion = int(definition.get("evasion", 0))
	unit.accuracy = int(definition.get("accuracy", 85))
	unit.agi = int(definition.get("move", 2)) + (5 if definition.role == "skirmisher" else 2)
	unit.range = int(definition.get("range", 1))
	unit.resist = definition.get("resist", {}).duplicate(true)
	unit.base_stats = definition.get("base_stats",{}).duplicate(true)
	unit.base_stats["action_points"]=mini(2,int(definition.get("move",1)))+1
	unit.alert = false
	unit.last_seen = Vector2i(-1, -1)
	unit.phase = 1
	unit.summon = summoned
	unit.intent = {}
	state.units.append(unit)
	ThirdFloorRules.apply_environment(self)
	return unit

func nearest_free(pos: Vector2i) -> Vector2i:
	for radius: int in range(0, 12):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				var check: Vector2i = pos + Vector2i(x, y)
				if DungeonWorld.walkable(state.map, check) and unit_at(check).is_empty(): return check
	return state.map.entrance

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

func visible(pos: Vector2i) -> bool:
	return state.get("visible", {}).has(pos_key(pos))

func update_visibility() -> void:
	if ThirdFloorRules.in_refuge(self): state.combat=false; return
	if state.get("mode", "") != "dungeon": return
	state.visible = {}
	for unit: Dictionary in allies():
		if unit.hp <= 0: continue
		var radius: int = int(stat_value(unit,"sight")) + int(state.light) + SpiritRules.visibility_bonus(self,unit) - (2 if region_data().terrain == "darkness" else 0)
		var dark: bool=(floor_number()==1 and (DungeonWorld.is_dark_zone(state.map,unit.pos) if state.map.has("area_portals") else distance(unit.pos,state.map.entrance)>=(int(state.map.width)+int(state.map.height))/3)) or int(state.region)==3
		if dark:
			var lit: bool=int(state.get("torch_until",0))>int(state.time) or SpiritRules.visibility_bonus(self,unit)>0
			radius=mini(radius,5) if lit else mini(radius,2)
		for y: int in range(maxi(0, unit.pos.y - radius), mini(state.map.height, unit.pos.y + radius + 1)):
			for x: int in range(maxi(0, unit.pos.x - radius), mini(state.map.width, unit.pos.x + radius + 1)):
				var pos: Vector2i = Vector2i(x, y)
				if distance(pos, unit.pos) <= radius and DungeonWorld.line_of_sight(state.map, unit.pos, pos):
					state.visible[pos_key(pos)] = true
					state.seen[pos_key(pos)] = true
	var detected: bool = false
	for enemy: Dictionary in enemies():
		if unit_visible(enemy): journal("Creature: " + str(enemy.name), str(monster_defs[enemy.content_id].desc))
		var closest: Dictionary={}; var best: int=1000000
		var enemy_vision: int=int(stat_value(enemy,"sight"))
		var territory: Dictionary=monster_defs[enemy.content_id].get("territorial",{})
		for ally: Dictionary in allies():
			if ally.hp<=0: continue
			var span: int=distance(enemy.pos,ally.pos)
			if span>enemy_vision or not DungeonWorld.line_of_sight(state.map,enemy.pos,ally.pos): continue
			if span>1 and (ally.statuses.has("stealth") or ally.statuses.has("concealed")): continue
			if not territory.is_empty() and distance(enemy.get("spawn_origin",enemy.pos),ally.pos)>int(territory.pursuit_radius): continue
			if span<best: best=span; closest=ally
		if not closest.is_empty(): enemy.alert=true; enemy.last_seen=closest.pos
		if enemy.alert: detected=true
	if detected and not state.combat:
		state.combat = true
		state.round += 1
		for unit: Dictionary in allies(): unit.ap = int(stat_value(unit,"action_points")); unit.attacked = false
		plan_intents()
		say("Combat started.")
	elif state.combat and not enemies().any(func(e: Dictionary) -> bool: return e.alert):
		state.combat = false
		say("The chamber falls quiet. Wounds persist. Your energy slowly returns as you explore.")

func valid_move(unit: Dictionary, pos: Vector2i) -> bool:
	if not DungeonWorld.walkable(state.map, pos): return false
	return unit_at(pos).is_empty()

func move_unit(direction: Vector2i) -> bool:
	if state.mode != "dungeon": return false
	var unit: Dictionary = selected() if state.combat else hero()
	if unit.hp <= 0: return false
	var move_cost: int = int(stat_value(unit,"movement_cost"))
	if state.combat and int(unit.ap) < move_cost: say("No action points. Select a companion or end the round."); return false
	if unable_to_act(unit): say("This character cannot move while stunned, suppressed or paralyzed."); return false
	var destination: Vector2i = unit.pos + direction
	if ThirdFloorRules.in_refuge(self):
		state["hut_until"]=0; ThirdFloorRules.apply_environment(self); say("Left the Witch’s Cabin.")
	var occupant: Dictionary = unit_at(destination)
	if not occupant.is_empty() and occupant.team == "enemy": return attack(unit, occupant)
	if not valid_move(unit, destination):
		if not occupant.is_empty() and occupant.team == "ally" and not state.combat:
			occupant.pos = unit.pos
		else:
			cue.emit("blocked")
			return false
	var old: Vector2i = unit.pos
	# Leaving a threatened square costs blood; each foe can react once per round.
	if state.combat:
		for enemy: Dictionary in enemies():
			var threat: int = threat_range(enemy)
			if threat>0 and distance(enemy.pos,old)<=threat and distance(enemy.pos,destination)>threat and not enemy.get("reacted",false) and not unable_to_act(enemy):
				enemy.reacted = true
				hit(enemy,unit,maxi(1,int(stat_value(enemy,"attack"))/2),RacialProgression.weapon_damage_type(enemy),"Opportunity",true,false,-1,{"attack_resolved":true,"category":"weapon"})
				if unit.hp <= 0: return true
	unit.pos = destination
	unit.facing = 1 if direction.x < 0 else 2 if direction.x > 0 else 3 if direction.y < 0 else 0
	update_concealment_fields()
	if unit.statuses.has("concealed"): unit.statuses.erase("concealed")
	if state.combat: unit.ap -= move_cost
	cue.emit("move")
	if not state.combat:
		var follow: Vector2i = old
		for ally: Dictionary in state.party:
			if ally.hp <= 0: continue
			var was: Vector2i = ally.pos
			if valid_move(ally, follow): ally.pos = follow
			else: ally.pos = nearest_free(old)
			follow = was
	step_hazards(unit)
	advance_time(1)
	update_visibility()
	if state.combat: auto_end_if_spent()
	return true

func attack(attacker: Dictionary, target: Dictionary) -> bool:
	if ThirdFloorRules.in_refuge(self): say("Leave the refuge before attacking."); return false
	if attacker.hp <= 0 or target.hp <= 0 or attacker.team == target.team: return false
	if unable_to_act(attacker): say("Stunned, suppressed or paralyzed: cannot attack."); return false
	var attack_cost: int = int(stat_value(attacker,"attack_ap_cost"))
	if attacker.team == "ally" and (not unit_visible(target) or (state.combat and int(attacker.ap) < attack_cost) or attacker.attacked): say("Attack unavailable: already attacked, no AP, or target unseen."); return false
	if distance(attacker.pos, target.pos) > int(stat_value(attacker,"attack_range")): say("Out of reach (%d). Move closer or use a ranged ability." % attacker.range); return false
	if not DungeonWorld.line_of_sight(state.map, attacker.pos, target.pos): say("Stone blocks the attack."); return false
	attacker.statuses.erase("stealth")
	attacker.statuses.erase("concealed")
	if state.combat: attacker.ap -= attack_cost
	attacker.attacked = bool(state.combat)
	hit(attacker,target,int(stat_value(attacker,"attack")),RacialProgression.weapon_damage_type(attacker),"Attack",true,false,-1,{"attack_resolved":true,"category":"weapon"})
	SpiritStones.finish_attack(self,attacker)
	if attacker.team == "ally":
		attacker.durability = maxi(0, int(attacker.durability) - 1)
		if attacker.durability == 0: recalculate(attacker)
		advance_time(1)
		update_visibility()
		auto_end_if_spent()
	return true

func resistance(unit: Dictionary, damage_type: String) -> int:
	var kind: String = damage_type if damage_type in StatSources.DAMAGE_KINDS else "mana"
	var values: Dictionary = stat_breakdown(unit).values
	var value: float = float(values.get(kind+"_damage_reduction",0))+StatSources.percent_from_points(float(values.get(kind+"_resistance",0)))
	for id: String in active_essences(unit):
		var essence: Dictionary = essence_defs[id]
		if essence.get("passive", "") == "resist" and (str(essence.affinity) == damage_type or damage_type != "physical"): value += int(essence.get("value",0))
	return clampi(roundi(value),-50,80)

func damage_amount(raw: int, armor: int, resist: int, physical: bool) -> int:
	var after_armor: int = maxi(1, raw - armor) if physical else maxi(1, raw)
	return maxi(1, int(ceil(float(after_armor) * (100.0 - clampi(resist, -50, 80)) / 100.0)))

func hit(source: Dictionary, target: Dictionary, raw: int, damage_type: String, label: String, can_trigger: bool = true, guaranteed: bool = false, fixed_damage: int = -1, context: Dictionary = {}) -> int:
	if target.hp <= 0: return 0
	var hit_context: Dictionary=context.duplicate()
	if not hit_context.has("category"): hit_context["category"]="weapon" if label in ["Attack","Opportunity","Enemy attack"] else ""
	if ThirdFloorCombat.evades_weapon(self,source,target,damage_type,fixed_damage,hit_context):
		say("Slimy Mucus: %s evades the blunt strike. Cold or restraint opens a hit." % target.name); cue.emit("blocked"); return 0
	var attacking: Dictionary = stat_breakdown(source)
	var defending: Dictionary = stat_breakdown(target)
	var attack_values: Dictionary = attacking.values
	var defense_values: Dictionary = defending.values
	var fear_penalty: int = dragon_fear_penalty(source)
	if fear_penalty > 0: say("Dragon Fear: %s loses %d accuracy." % [source.get("name","Target"),fear_penalty])
	var chance: int = clampi(int(attack_values.get("accuracy",source.get("accuracy",90)))+ThirdFloorCombat.accuracy_bonus(self,source,hit_context)-int(defense_values.get("evasion",target.get("evasion",0))),20,98)
	if not guaranteed and rng.randi_range(1,100) > chance:
		say("%s: %s evades (%d%% hit)." % [label,target.name,chance])
		cue.emit("blocked")
		return 0
	var power: int = raw
	if not context.get("attack_resolved",false):
		var attack_context: Dictionary = StatRules.evaluate({"attack":raw},StatSources.combat_modifiers(source,item_defs).filter(func(row: Dictionary) -> bool: return row.stat=="attack"),{"attack":StatCatalog.definitions().attack})
		power = int(attack_context.values.attack)
	var kind: String = damage_type if damage_type in StatSources.DAMAGE_KINDS else "mana"
	var outgoing: float = float(attack_values.get("damage_dealt_multiplier",1))*float(attack_values.get(kind+"_damage_dealt_multiplier",1))
	var category: String = str(context.get("category","weapon" if label in ["Attack","Opportunity","Enemy attack"] else ""))
	if category in ["weapon","spell"]: outgoing *= float(attack_values.get(category+"_damage_multiplier",1))
	if category=="spell": outgoing *= float(attack_values.get("skill_power_multiplier",1))
	var weapon: Dictionary = item_defs.get(str(source.get("equipment",{}).get("weapon","")),{})
	var damage_context: Dictionary = {"category":category,"weapon_style":weapon.get("weapon_style",source.get("weapon_style","")),"damage_type":damage_type,"fixed_damage":fixed_damage,"normal_attack":label in ["Attack","Enemy attack"],"secondary":context.get("secondary",false),"dot":context.get("dot",false)}
	if fixed_damage<0:
		if damage_type=="cold" and not damage_context.dot: outgoing *= CombatStats.sensitivity_multiplier(float(attack_values.get("cold_sensitivity",0)))
		outgoing *= CombatStats.cutting_multiplier(float(attack_values.get("cutting_force",0)),damage_context)
		if category=="weapon" and damage_type=="physical" and damage_context.weapon_style=="blunt" and not damage_context.dot and not damage_context.secondary: outgoing *= StatPhysiology.blunt_damage_multiplier(attack_values.get("weight",0))
	var critical: Dictionary = CombatStats.critical(float(attack_values.get("critical_chance",0)),float(attack_values.get("critical_damage_multiplier",1.5)),rng,damage_context)
	if critical.critical:
		outgoing *= float(critical.multiplier)
		say("Critical hit: ×%.2f." % float(critical.multiplier))
	power = int(floor(float(power)*outgoing))
	var armor: int = int(floor(float(defense_values.get("armor",target.get("armor",0)))*(1.0-float(attack_values.get("armor_penetration",0))/100.0)))
	var effective_resist: int = resistance(target,damage_type)
	if effective_resist > 0: effective_resist = int(floor(float(effective_resist)*(1.0-float(attack_values.get("resistance_penetration",0))/100.0)))
	var incoming: float = float(defense_values.get("damage_taken_multiplier",1))*float(defense_values.get(kind+"_damage_taken_multiplier",1))
	if fixed_damage > 0: power = fixed_damage; armor = 0; effective_resist = 0
	var value: int = fixed_damage if fixed_damage > 0 else (0 if outgoing<=0 or incoming<=0 else ceili(float(damage_amount(power,armor,effective_resist,damage_type=="physical"))*incoming))
	if fixed_damage < 0:
		for id: String in Numbered.equipped_ids(target):
			var has_reduction: bool = false
			for passive: Dictionary in NumberedCatalog.definitions()[id].get("passives", []):
				if passive.op == "damage_reduction": has_reduction = true
			if not has_reduction: continue
			var record: Dictionary = numbered_record(id)
			var reduction: Dictionary = Numbered.mitigate_for(id,value,int(record.remainder))
			record.remainder = reduction.remainder
			record.charge = mini(1000,int(record.charge)+int(reduction.prevented))
			value = int(reduction.damage)
			if int(reduction.prevented) > 0: say("%s prevents %d damage." % [item_defs[id].name,reduction.prevented])
	if ThirdFloorCombat.physical_immune(self,target,damage_type,fixed_damage,hit_context):
		value=0; say("Incorporeal: %s ignores physical damage. Elemental attacks can connect." % target.name)
	target.hp = maxi(0, int(target.hp) - value)
	ThirdFloorCombat.on_damage(self,target,damage_type,value,hit_context)
	if target.hp>0 and value>0 and fixed_damage<0 and not context.get("dot",false) and category=="weapon":
		var intensity: float = 100.0*float(value)/maxf(1.0,float(target.max_hp))
		if CombatStats.perceived_pain(intensity,float(defense_values.get("pain_resistance",0)))>=20.0: status(target,"pained",2)
	if value > 0 and target.statuses.has("suppressed"):
		target.statuses.erase("suppressed")
		target.status_power.erase("suppressed")
		say("Damage breaks %s’s Suppression." % target.name)
	say("%s → %s: %d %s [%d − %d armor, %d%% resist; %d%% hit]." % [source.get("name", "Labyrinth"), target.name, value, damage_type, power, armor if damage_type == "physical" else 0, effective_resist, chance])
	state.last_hit = {"pos": target.pos, "amount": value, "kind": damage_type}
	cue.emit("hit")
	if can_trigger and trigger_depth < MAX_TRIGGER_DEPTH:
		trigger_depth += 1
		trigger(source, "on_hit", target, value, label in ["Attack", "Opportunity"])
		if target.hp > 0 and label in ["Attack", "Opportunity"]: numbered_on_hit(source,target)
		if target.hp > 0: trigger(target, "on_hurt", source, value)
		trigger_depth -= 1
	if target.hp <= 0: on_death(target, source)
	return value

func status(unit: Dictionary, status_id: String, duration: int, potency: int = 0) -> void:
	if ThirdFloorRules.blocks_status(self,unit,status_id): return
	if status_id.is_empty() or unit.hp <= 0 or duration <= 0: return
	if status_id in HARMFUL_STATUSES and unit.statuses.has("status_immunity"): say("Guardian’s protection blocks %s." % status_id); return
	var original_duration: int = duration
	duration = mini(1000000,StatMentalRules.incoming_duration(status_id,duration,stat_breakdown(unit).values))
	if duration!=original_duration: say("%s: %s duration %d → %d from defensive stats." % [unit.name,status_id,original_duration,duration])
	# Refresh duration, never add stacks. Turns are counted at round start.
	unit.statuses[status_id] = maxi(int(unit.statuses.get(status_id, 0)), duration)
	if potency > 0:
		if not unit.has("status_power"): unit.status_power = {}
		unit.status_power[status_id] = maxi(int(unit.status_power.get(status_id, 0)), potency)
	say("%s gains %s (%d rounds)." % [unit.name, status_id, duration])

func trigger(unit: Dictionary, event: String, other: Dictionary, dealt: int, weapon_attack: bool = false) -> void:
	if trigger_depth >= MAX_TRIGGER_DEPTH or event != "on_hit" or dealt <= 0 or not weapon_attack: return
	var weapon_id: String = str(unit.get("equipment", {}).get("weapon", ""))
	if weapon_id.is_empty(): return
	for id: String in active_essences(unit):
		var passive: String = str(essence_defs[id].get("passive", ""))
		if passive == "goblin_poison" and int(unit.range) <= 2: status(other, "paralyzed", skill_duration(unit,2))
		if passive == "poison_arrow" and weapon_id.contains("bow"): status(other, "poison", skill_duration(unit,3))

func heal(unit: Dictionary, amount: int) -> void:
	if unit.hp <= 0: return
	var gained: int = mini(maxi(0,ceili(float(amount)*stat_value(unit,"healing_received_multiplier"))),int(unit.max_hp)-int(unit.hp))
	unit.hp += gained
	if gained > 0: say("%s recovers %d health." % [unit.name, gained])

func use_ability(slot: int, target_pos: Vector2i) -> bool:
	if ThirdFloorRules.in_refuge(self): say("Leave the refuge before using combat abilities."); return false
	if state.mode != "dungeon": return false
	var caster: Dictionary = selected()
	if slot < 0 or slot >= caster.essences.size(): return false
	var essence_id: String = caster.essences[slot]
	if not active_essences(caster).has(essence_id): say("The ring seals this essence’s skills."); return false
	var ability: Dictionary = resolved_essence_ability(caster,essence_id)
	if str(ability.get("effect", "")).is_empty(): say("This essence has no active technique."); return false
	var cost: int = ability_cost(caster,int(ability.cost),"soul")
	if caster.hp <= 0 or unable_to_act(caster): return false
	if int(caster.energy) < cost: say("Need %d SP." % cost); return false
	if int(caster.cooldowns.get(essence_id, 0)) > 0: say("Cooldown: %d turns." % caster.cooldowns[essence_id]); return false
	if state.combat and int(caster.ap) < 2: say("Need 2 AP."); return false
	if distance(caster.pos, target_pos) > int(ability.range) or not visible(target_pos): say("Out of visible range."); return false
	if not DungeonWorld.line_of_sight(state.map, caster.pos, target_pos): say("No line of effect."); return false
	var effect: String = str(ability.effect)
	if effect == "create_trap" and not DungeonWorld.walkable(state.map, target_pos): say("A trap requires open ground."); return false
	if effect not in ["create_trap", "stealth", "stationary_concealment", "stationary_concealment_field", "suppression", "call_dead", "counterweight"]: return false
	if ThirdFloorRules.field_active(self) and effect!="call_dead": say("The Witch’s field nullifies non-field status abilities."); return false
	if effect=="call_dead":
		var failure: String=EarlyMonsterRules.can_call(self,caster,ability,target_pos)
		if not failure.is_empty(): say(failure); return false
	caster.energy -= cost
	if state.combat: caster.ap -= 2
	caster.cooldowns[essence_id] = ability_cooldown(caster,int(ability.cooldown))+1
	say("%s uses %s." % [caster.name, ability.name])
	cue.emit("cast")
	match effect:
		"counterweight": status(caster,"anchored",int(ability.status_duration))
		"call_dead": EarlyMonsterRules.call_dead(self,caster,ability,target_pos)
		"suppression": apply_suppression(caster, target_pos, int(ability.get("radius", 1)), int(ability.status_duration))
		"create_trap": state.player_traps.append({"pos": target_pos, "team": caster.team, "owner": caster.id, "status_duration": skill_duration(caster,2)})
		"stealth": status(caster, "stealth", int(ability.effect_duration))
		"stationary_concealment", "stationary_concealment_field":
			status(caster, "concealed", int(ability.effect_duration))
			state.terrain_effects.append({"pos": caster.pos, "radius": 3, "turns": int(ability.effect_duration), "damage": 0, "type": "concealment", "team": caster.team, "owner": caster.id, "status_duration": skill_duration(caster,2)})
			for ally: Dictionary in allies():
				if ally.hp > 0 and distance(ally.pos, caster.pos) <= 3:
					status(ally, "concealed", skill_duration(caster,2))
					ally.concealment_owner = caster.id
	advance_time(2)
	update_visibility()
	auto_end_if_spent()
	return true

func skill_duration(unit: Dictionary, base: int) -> int:
	return clampi(ceili(base*stat_value(unit,"skill_power_multiplier")),1,1000000)

func resolved_essence_ability(unit: Dictionary, id: String) -> Dictionary:
	var result: Dictionary=essence_defs[id].get("ability",{}).duplicate(true)
	if result.has("status_duration"): result.status_duration=skill_duration(unit,int(result.status_duration))
	match result.get("effect",""):
		"stealth": result.effect_duration=skill_duration(unit,4)
		"stationary_concealment","stationary_concealment_field": result.effect_duration=skill_duration(unit,5)
		"create_trap": result.status_duration=skill_duration(unit,2)
		"call_dead": result.summon_duration=skill_duration(unit,int(result.summon_duration)); result.effect_duration=result.summon_duration
	if not is_equal_approx(stat_value(unit,"skill_power_multiplier"),1.0):
		result.description=str(result.get("description",""))+" Skill power ×%.2f; current duration %d rounds. Range and costs unchanged." % [stat_value(unit,"skill_power_multiplier"),int(result.get("effect_duration",result.get("status_duration",0)))]
	return result

# Techniques share targeting and input but retain distinct SP/mana resources.
func techniques(unit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(unit.get("essences", []).size()):
		var id: String = str(unit.essences[index])
		if not active_essences(unit).has(id): continue
		var ability: Dictionary = resolved_essence_ability(unit,id)
		if not str(ability.get("effect", "")).is_empty(): result.append({"id":id,"kind":"essence","essence_slot":index,"ability":ability})
	for id: String in Numbered.equipped_ids(unit):
		var active: Dictionary = NumberedCatalog.definitions()[id].get("active", {})
		if not active.is_empty(): result.append({"id":id,"kind":"numbered","ability":{"name":active.name,"range":0,"cost":0,"cooldown":int(active.cooldown),"description":str(item_defs[id].desc) + " " + str(item_defs[id].implementation_note)}})
	for id: String in unit.get("spells", []):
		if GameContent.spells().has(id): result.append({"id":id,"kind":"spell","ability":GameContent.spells()[id]})
	return result

func use_technique(slot: int, target: Vector2i) -> bool:
	if ThirdFloorRules.in_refuge(self): say("Leave the refuge before using combat techniques."); return false
	var entries: Array[Dictionary] = techniques(selected())
	if slot < 0 or slot >= entries.size(): return false
	if entries[slot].kind == "essence": return use_ability(int(entries[slot].essence_slot), target)
	if entries[slot].kind == "numbered": return activate_numbered(str(entries[slot].id),selected().id).is_empty()
	return _cast_spell(selected(), str(entries[slot].id), target)

func _cast_spell(caster: Dictionary, spell_id: String, target_pos: Vector2i) -> bool:
	if state.mode != "dungeon" or caster.hp <= 0 or caster.team != "ally": return false
	if not caster.get("spells", []).has(spell_id) or not GameContent.spells().has(spell_id): return false
	if unable_to_act(caster): say("Cannot cast while unable to act."); return false
	var spell: Dictionary = GameContent.spells()[spell_id]
	if state.combat and int(caster.ap) < 2: say("Need 2 AP."); return false
	var cost: int = ability_cost(caster,int(spell.cost),"mana")
	if int(caster.get("mana",0)) < cost: say("Need %d mana." % cost); return false
	if int(caster.cooldowns.get(spell_id, 0)) > 0: say("Spell is cooling down."); return false
	var target: Dictionary = unit_at(target_pos)
	if target.is_empty() or target.team != "enemy" or not unit_visible(target): say("Choose a visible enemy."); return false
	if distance(caster.pos, target_pos) > int(spell.range) or not DungeonWorld.line_of_sight(state.map, caster.pos, target_pos): say("Outside spell range or line of effect."); return false
	caster.mana -= cost
	if state.combat: caster.ap -= 2
	caster.cooldowns[spell_id] = ability_cooldown(caster,int(spell.cooldown))+1
	caster.statuses.erase("stealth")
	caster.statuses.erase("concealed")
	cue.emit("cast")
	# Reuses the current attack coefficient; exact spell potency is unverified.
	hit(caster,target,int(stat_value(caster,"attack")),str(spell.damage_type),str(spell.name),false,false,-1,{"attack_resolved":true,"category":"spell"})
	advance_time(2)
	update_visibility()
	auto_end_if_spent()
	return true

func on_death(unit: Dictionary, killer: Dictionary) -> void:
	if unit.get("dead", false): return
	unit.dead = true
	cue.emit("death")
	say("%s falls." % unit.name)
	if unit.team == "enemy":
		if not unit.get("summon", false):
			var definition: Dictionary = monster_defs[unit.content_id]
			var count: int = int(state.killed.get(unit.content_id, 0))
			var reward: int = int(definition.get("xp", 1)) if count == 0 else 0
			state.killed[unit.content_id] = count + 1
			state.xp += reward
			add_item("mana_stone_rank_%d" % int(definition.get("rank", 9)), 1, true)
			if count == 0:
				say("First %s: +%d XP." % [unit.name, reward])
				journal(str(unit.name), str(definition.get("desc", "")))
			var essence_id: String = str(definition.get("essence", ""))
			if essence_defs.has(essence_id) and rng.randf() < float(definition.essence_drop_chance):
				state.essence_drops.append({"id": essence_id, "pos": unit.pos, "region": int(state.region), "expires_at": int(state.time) + UNCONTAINED_ESSENCE_LIFETIME_MINUTES})
				_recount_essence_drops()
				say("%s dropped. Expires in 30 minutes." % essence_defs[essence_id].name)
				cue.emit("loot")
			check_level()
		trigger(killer, "on_kill", unit, 0)
	elif not unit.get("summon", false):
		if unit.id == "hero":
			state.mode = "dead"
			say("You have died.")
		else:
			unit.injuries = 3
			state.fallen.append(unit.name)
			if not state.fallen_ids.has(str(unit.get("content_id", ""))): state.fallen_ids.append(str(unit.get("content_id", "")))
			journal("Lost: " + str(unit.name), "Death is permanent.")

func check_level() -> void:
	while LEVEL_THRESHOLDS.has(int(state.level) + 1) and int(state.xp) >= int(LEVEL_THRESHOLDS[int(state.level) + 1]):
		state.level += 1
		for unit: Dictionary in allies(): recalculate(unit)
		say("Level %d. Essence capacity: %d." % [state.level, essence_capacity()])

func next_level_xp() -> int:
	return int(LEVEL_THRESHOLDS.get(int(state.level) + 1, -1))

func essence_capacity(unit: Dictionary = {}) -> int:
	if unit.get("profession", "explorer") == "mage" or not unit.get("can_absorb_essences", true): return 0
	return int(state.level)

func end_phase() -> void:
	if state.get("mode", "") != "dungeon": return
	var actor: Dictionary = selected()
	actor.guard = bool(state.combat) and actor.hp > 0 and int(actor.ap) > 0 and not unable_to_act(actor)
	if state.combat: actor.ap = 0
	end_round()

func end_round() -> void:
	if resolving_round: return
	resolving_round = true
	_resolve_round()
	resolving_round = false

func _resolve_round() -> void:
	if state.mode != "dungeon": return
	if not state.combat:
		advance_time(1)
		for unit: Dictionary in allies(): tick_unit(unit)
		tick_numbered_cooldown()
		update_visibility()
		return
	var autonomous: Array = allies().duplicate()
	autonomous.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return stat_value(a,"initiative")>stat_value(b,"initiative"))
	for unit: Dictionary in autonomous:
		if unit.hp > 0 and unit.behavior != "manual": ally_ai(unit)
	var foes: Array = enemies()
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return stat_value(a,"initiative") > stat_value(b,"initiative"))
	for enemy: Dictionary in foes:
		if state.mode != "dungeon": return
		if enemy.hp > 0: enemy_turn(enemy)
	if state.mode != "dungeon": return
	state.round += 1
	tick_numbered_cooldown()
	for unit: Dictionary in allies() + enemies():
		if unit.hp > 0: tick_unit(unit)
	for effect: Dictionary in state.terrain_effects:
		effect.turns -= 1
		if effect.type == "concealment":
			var owner: Dictionary = unit_by_id(str(effect.get("owner", "")))
			if owner.is_empty() or owner.pos != effect.pos: effect.turns = 0
			else:
				for ally: Dictionary in allies():
					if ally.hp > 0 and distance(ally.pos, effect.pos) <= int(effect.radius): status(ally, "concealed", int(effect.get("status_duration",2)))
	state.terrain_effects = state.terrain_effects.filter(func(e: Dictionary) -> bool: return int(e.turns) > 0)
	for unit: Dictionary in allies():
		unit.ap = int(stat_value(unit,"action_points"))
		unit.attacked = false
		unit.guard = false
	for enemy: Dictionary in enemies(): enemy.reacted = false
	advance_time(2)
	plan_intents()
	update_visibility()

func auto_end_if_spent() -> void:
	if resolving_round or state.mode != "dungeon" or not state.combat: return
	if allies().all(func(u: Dictionary) -> bool: return u.hp <= 0 or int(u.ap) <= 0 or u.behavior != "manual"):
		end_round()

func tick_unit(unit: Dictionary) -> void:
	if unit.hp <= 0: return
	for id: String in unit.cooldowns: unit.cooldowns[id] = maxi(0, int(unit.cooldowns[id]) - 1)
	for id: String in STATUS_ORDER:
		if not unit.statuses.has(id): continue
		if id=="toppled" or id in ThirdFloorRules.FIELD_STATUSES: continue
		if id in ["bleeding", "poison", "burning"]:
			var kind: String = "physical" if id == "bleeding" else ("fire" if id == "burning" else "poison")
			hit({"name": id, "accuracy": 100, "statuses": {}}, unit, 3 + int(state.region) / 3, kind, id, false, true, -1, {"dot":true})
			# Defeat may clear statuses or leave this unit downed. Stop this tick.
			if unit.hp <= 0 or state.mode != "dungeon": return
		if not unit.statuses.has(id): continue
		unit.statuses[id] -= 1
		if int(unit.statuses[id]) <= 0:
			unit.statuses.erase(id)
			unit.get("status_power", {}).erase(id)
	for id: String in active_essences(unit):
		var essence: Dictionary = essence_defs[id]
		if essence.get("passive", "") == "regen": heal(unit, int(essence.get("value", 1)))
	EarlyMonsterRules.tick(self,unit)
	trigger(unit, "turn_start", unit, 0)
	recover_resource(unit,"soul")
	recover_resource(unit,"mana")
	if unit.get("summon", false) and unit.has("lifetime"):
		unit.lifetime -= 1
		if unit.lifetime <= 0: unit.hp = 0

func ally_ai(unit: Dictionary) -> void:
	if unit.hp <= 0 or unable_to_act(unit): return
	if unit.behavior == "guard": unit.guard = true; unit.ap = 0; return
	var targets: Array = enemies().filter(func(e: Dictionary) -> bool: return unit_visible(e))
	if targets.is_empty(): return
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return distance(unit.pos, a.pos) < distance(unit.pos, b.pos))
	var target: Dictionary = targets[0]
	var move_cost: int = int(stat_value(unit,"movement_cost"))
	if not unit.get("spells", []).is_empty():
		var spell: Dictionary = GameContent.spells()[unit.spells[0]]
		if int(unit.ap) >= 2 and _cast_spell(unit, str(unit.spells[0]), target.pos): return
		for step: int in range(int(unit.ap)):
			if int(unit.ap)<move_cost: break
			if distance(unit.pos, target.pos) <= int(spell.range) and DungeonWorld.line_of_sight(state.map, unit.pos, target.pos): break
			var destination: Vector2i = path_step(unit.pos, target.pos)
			if destination != unit.pos and valid_move(unit, destination): unit.pos = destination; unit.ap -= move_cost; step_hazards(unit)
		unit.guard = true
		unit.ap = 0
		return
	for step: int in range(int(unit.ap)):
		if distance(unit.pos, target.pos) <= int(stat_value(unit,"attack_range")) and not unit.attacked:
			attack(unit, target)
			break
		if int(unit.ap)<move_cost: break
		var destination: Vector2i = path_step(unit.pos, target.pos)
		if destination != unit.pos and valid_move(unit, destination): unit.pos = destination; unit.ap -= move_cost; step_hazards(unit)
	unit.ap = 0

func enemy_turn(enemy: Dictionary) -> void:
	if ThirdFloorRules.in_refuge(self): return
	if not enemy.get("alert", false) or enemy.hp <= 0: return
	if unable_to_act(enemy): say("%s cannot act while restrained." % enemy.name); return
	enemy.ap = int(stat_value(enemy,"action_points"))
	if int(enemy.ap)<=0: return
	var move_cost: int = int(stat_value(enemy,"movement_cost"))
	var attack_cost: int = int(stat_value(enemy,"attack_ap_cost"))
	var reach: int = int(stat_value(enemy,"attack_range"))
	var vision: int = int(stat_value(enemy,"sight"))
	var targets: Array = allies().filter(func(u: Dictionary) -> bool: return u.hp > 0 and distance(enemy.pos,u.pos) <= vision and DungeonWorld.line_of_sight(state.map, enemy.pos, u.pos) and (not (u.statuses.has("stealth") or u.statuses.has("concealed")) or distance(enemy.pos, u.pos) <= 1))
	if ThirdFloorCombat.enemy_action(self,enemy): return
	if EarlyMonsterRules.enemy_action(self,enemy,{} if targets.is_empty() else targets[0]): return
	if targets.is_empty():
		# Alert foes remember last sighting, but cannot track through walls.
		var step: Vector2i = path_step(enemy.pos, enemy.last_seen)
		if int(enemy.ap)>=move_cost and valid_move(enemy,step):
			enemy.ap -= move_cost
			var origin: Vector2i = enemy.pos
			enemy.pos = step
			record_noise(enemy)
			break_moving_concealment(enemy,origin)
		if enemy.pos == enemy.last_seen: enemy.alert = false
		return
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return distance(enemy.pos, a.pos) < distance(enemy.pos, b.pos))
	var target: Dictionary = targets[0]
	if str(enemy.content_id) == "canon_gnome" and not enemy.statuses.has("concealed") and int(state.round) % 3 == 0:
		status(enemy, "concealed", 3)
		say("The Gnome conceals its position while stationary.")
		return
	enemy.last_seen = target.pos
	var definition: Dictionary = monster_defs[enemy.content_id]
	if definition.has("suppression") and enemy.intent.get("kind", "") == "suppression" and int(enemy.cooldowns.get("suppression", 0)) == 0:
		var center: Vector2i = enemy.intent.pos
		if distance(enemy.pos, center) <= int(definition.suppression.range) and DungeonWorld.line_of_sight(state.map, enemy.pos, center):
			say("%s releases Suppression." % enemy.name)
			apply_suppression(enemy, center, int(definition.suppression.radius), int(definition.suppression.duration))
			enemy.cooldowns.suppression = int(definition.suppression.cooldown) + 1
			return
	# Retreat only when the foe can still attack from its new square this turn.
	# Melee skirmishers otherwise spend their budget leaving their own reach.
	if enemy.role in ["ranged","skirmisher"] and reach>1 and distance(enemy.pos,target.pos)<=1 and int(enemy.ap)>=move_cost+attack_cost:
		var retreat: Vector2i = enemy.pos
		for direction: Vector2i in DIRS:
			if valid_move(enemy, enemy.pos + direction) and distance(enemy.pos + direction, target.pos) > distance(retreat, target.pos): retreat = enemy.pos + direction
		var origin: Vector2i = enemy.pos
		if retreat!=origin: enemy.ap -= move_cost
		enemy.pos = retreat
		if retreat!=origin: record_noise(enemy)
		break_moving_concealment(enemy,origin)
	if distance(enemy.pos,target.pos)>reach:
		var steps: int = maxi(0,int(enemy.ap)-attack_cost)/move_cost
		for i: int in range(steps):
			var destination: Vector2i = path_step(enemy.pos, target.pos)
			if valid_move(enemy, destination):
				var origin: Vector2i = enemy.pos
				enemy.ap -= move_cost
				enemy.pos = destination
				record_noise(enemy)
				break_moving_concealment(enemy,origin)
				step_hazards(enemy)
			if distance(enemy.pos,target.pos)<=reach: break
	if enemy.hp <= 0: return
	if int(enemy.ap)>=attack_cost and distance(enemy.pos,target.pos)<=reach and DungeonWorld.line_of_sight(state.map,enemy.pos,target.pos):
		enemy.ap -= attack_cost
		record_noise(enemy)
		var dealt: int = hit(enemy,target,int(stat_value(enemy,"attack")), "physical" if enemy.role in ["tank", "ambusher", "skirmisher"] else str(definition.get("affinity", "physical")), "Enemy attack",true,false,-1,{"attack_resolved":true,"category":"weapon"})
		if dealt > 0: status(target, str(definition.get("status", "")), 2)
	if enemy.role == "tank": enemy.guard = true

func plan_intents() -> void:
	for enemy: Dictionary in enemies():
		if not enemy.get("alert", false): enemy.intent = {}; continue
		enemy.intent = {"kind":"advance","pos":enemy.last_seen,"radius":0}
		EarlyMonsterRules.plan_intent(self,enemy)
		ThirdFloorCombat.plan_intent(self,enemy)
		var definition: Dictionary = monster_defs[enemy.content_id]
		if not definition.has("suppression") or int(enemy.cooldowns.get("suppression", 0)) > 0 or unable_to_act(enemy): continue
		var targets: Array = allies().filter(func(u: Dictionary) -> bool: return u.hp > 0 and distance(enemy.pos, u.pos) <= int(definition.suppression.range) and DungeonWorld.line_of_sight(state.map, enemy.pos, u.pos) and (not (u.statuses.has("stealth") or u.statuses.has("concealed")) or distance(enemy.pos, u.pos) <= 1))
		if targets.is_empty(): continue
		targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return distance(enemy.pos,a.pos) < distance(enemy.pos,b.pos))
		enemy.intent = {"kind":"suppression","pos":targets[0].pos,"radius":int(definition.suppression.radius)}

func path_step(from: Vector2i, target: Vector2i) -> Vector2i:
	if from == target: return from
	var frontier: Array[Vector2i] = [from]
	var came: Dictionary = {from: from}
	var cursor: int = 0
	while cursor < frontier.size() and cursor < 1000:
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction: Vector2i in DIRS:
			var next: Vector2i = current + direction
			if came.has(next) or not DungeonWorld.walkable(state.map, next): continue
			if next != target and not unit_at(next).is_empty(): continue
			came[next] = current
			if next == target:
				var step: Vector2i = next
				while came[step] != from: step = came[step]
				return step
			frontier.append(next)
	return from

func step_hazards(unit: Dictionary) -> void:
	if unit.hp <= 0: return
	var key: String = pos_key(unit.pos)
	if state.map.get("sewage_pits",[]).has(unit.pos) and not state.disarmed.has(key):
		state.disarmed.append(key); say("%s falls into a hidden sewage pit." % unit.name)
		hit({"name":"Sewage pit","accuracy":100,"statuses":{}},unit,4,"fall","Sewage pit",false,true,4)
	for trap: Dictionary in state.get("player_traps", []):
		if trap.pos == unit.pos and trap.team != unit.team and not trap.get("spent", false):
			trap.spent = true
			status(unit, "paralyzed", int(trap.get("status_duration",2)))
			say("%s steps into a poisoned trap." % unit.name)
	if state.map.traps.has(unit.pos) and not state.disarmed.has(key):
		state.disarmed.append(key)
		hit({"name": "Wire trap", "accuracy": 100, "statuses": {}}, unit, 6 + int(state.region), "physical", "Trap", false, true)
		status(unit, "bleeding", 3)

func _recount_essence_drops() -> void:
	var counts: Dictionary = {}
	for drop: Dictionary in state.get("essence_drops", []):
		var id: String = str(drop.get("id", ""))
		if essence_defs.has(id): counts[id] = int(counts.get(id, 0)) + 1
	state.loot_essences = counts

func _expire_essence_drops() -> void:
	var remaining: Array = []
	var expired: int = 0
	for drop: Dictionary in state.get("essence_drops", []):
		if int(drop.get("expires_at", 0)) <= int(state.time): expired += 1
		else: remaining.append(drop)
	state.essence_drops = remaining
	_recount_essence_drops()
	if expired > 0: say("%d uncontained essence%s %s after thirty minutes." % [expired, "" if expired == 1 else "s", "fades" if expired == 1 else "fade"])

func _nearby_essence_drop(id: String, unit: Dictionary) -> int:
	for index: int in range(state.get("essence_drops", []).size()):
		var drop: Dictionary = state.essence_drops[index]
		if str(drop.id) != id or int(drop.region) != int(state.region): continue
		if int(drop.expires_at) <= int(state.time): continue
		if distance(unit.pos, drop.pos) <= 1: return index
	return -1

func advance_time(amount: int) -> void:
	if state.mode != "dungeon" or amount <= 0: return
	if int(state.time) >= portal_limit(): extract(true); return
	update_concealment_fields()
	var target: int = mini(int(state.time) + amount, portal_limit())
	# Process deadlines in chronological order; large camp/wait advances must not
	# skip food, recovery, essence expiry or the closing portal.
	while int(state.time) < target and state.mode == "dungeon":
		var food_at: int = (int(state.time) / MINUTES_PER_DAY + 1) * MINUTES_PER_DAY
		var recovery_at: int = (int(state.time) / RECOVERY_INTERVAL_MINUTES + 1) * RECOVERY_INTERVAL_MINUTES
		var next: int = mini(target, mini(food_at, recovery_at))
		if allies().any(func(u: Dictionary) -> bool: return u.get("spirit",{}).get("active",false)):
			next = mini(next,(int(state.time)/SpiritRules.INTERVAL+1)*SpiritRules.INTERVAL)
		for summoned: Dictionary in state.get("units",[]):
			if summoned.get("summon",false) and summoned.hp>0 and int(summoned.get("summon_expires_at",0))>int(state.time): next=mini(next,int(summoned.summon_expires_at))
		for drop: Dictionary in state.get("essence_drops", []):
			if int(drop.expires_at) > int(state.time): next = mini(next, int(drop.expires_at))
		if int(state.get("torch_until",0))>int(state.time): next=mini(next,int(state.torch_until))
		next=mini(next,ThirdFloorRules.next_deadline(self))
		var elapsed: int = next-int(state.time)
		var visibility_changed: bool=int(state.get("torch_until",0))>int(state.time) and next>=int(state.get("torch_until",0))
		state.time = next
		ThirdFloorRules.advance(self,elapsed)
		for summoned: Dictionary in state.get("units",[]):
			if summoned.get("summon",false) and summoned.has("summon_expires_at") and int(summoned.summon_expires_at)<=next and summoned.hp>0: summoned.hp=0; visibility_changed=true
		prune_summons()
		advance_breath(elapsed)
		if state.mode!="dungeon": return
		if next%SpiritRules.INTERVAL==0: SpiritRules.advance_tick(self)
		if visibility_changed: update_visibility()
		_expire_essence_drops()
		if next == food_at:
			EarlyFloorRules.daily_water(self)
			if state.mode!="dungeon": return
			var appetite: float = 0.0
			for unit: Dictionary in allies():
				if unit.hp>0 and not unit.get("summon",false): appetite += stat_value(unit,"appetite")
			var food_due: float = float(state.get("hunger_remainder",0.0))+StatPhysiology.hunger_rate(appetite)
			var hunger: int = floori(food_due+0.000000001)
			state.hunger_remainder = clampf(food_due-float(hunger),0,0.999999999)
			for unit: Dictionary in allies():
				if unit.get("summon",false): continue
				for id: String in active_essences(unit):
					if essence_defs[id].get("drawback", "") == "hunger": hunger += 1
			if state.food >= hunger: state.food -= hunger
			else:
				state.food = 0
				state.fatigue += 1
				for unit: Dictionary in allies():
					if state.mode != "dungeon": return
					if unit.hp > 0: hit({"name":"Starvation","accuracy":100,"statuses":{}}, unit, 3 + int(state.fatigue), "physical", "Hunger", false, true)
				say("No food. Fatigue %d; every ration interval now wounds the party." % state.fatigue)
		if state.mode != "dungeon": return
		if not state.combat and next == recovery_at:
			for unit: Dictionary in allies():
				if unit.hp <= 0: continue
				tick_unit(unit)
				if unit.hp > 0 and int(state.food) > 0 and int(state.get("water",EarlyFloorRules.WATER_START))>0 and not unit.statuses.has("poison") and not unit.statuses.has("bleeding") and not unit.statuses.has("burning"):
					natural_recovery_tick(unit)
		if state.mode == "dungeon" and int(state.time) >= portal_limit():
			say("The Labyrinth closes. Every surviving explorer is returned to Rafdonia.")
			extract(true)
			return

func interact() -> String:
	if state.mode != "dungeon": return ""
	_expire_essence_drops()
	if ThirdFloorRules.in_refuge(self): return "hut"
	var pos: Vector2i = hero().pos
	for drop: Dictionary in state.essence_drops:
		if int(drop.region) == int(state.region) and distance(pos, drop.pos) <= 1: return "essence"
	if not portal_choices().is_empty(): return "portal"
	if state.map.get("central_spire") is Vector2i and distance(pos,state.map.central_spire)<=1:
		say("Central tower: the fourth floor is not implemented yet."); return "spire"
	if ThirdFloorRules.active_hut_site(self)!=Vector2i(-1,-1) and distance(pos,ThirdFloorRules.active_hut_site(self))<=1: return "hut"
	if state.map.get("central_memorial") is Vector2i and distance(pos,state.map.central_memorial)<=1:
		journal("Great Sage Memorial","A dark clearing surrounds the central monument. It is separate from the four outer portal steles. Its ritual rifts remain unimplemented.")
		return "memorial"
	for flower: Vector2i in state.map.get("corpse_flowers",[]):
		if distance(pos,flower)<=1:
			var failure: String=collect_corpse_flower()
			if not failure.is_empty(): say(failure)
			return "flower"
	for pit: Vector2i in state.map.get("sewage_pits",[]):
		if distance(pos,pit)<=1 and not state.disarmed.has(pos_key(pit)):
			state.disarmed.append(pos_key(pit)); say("Hidden sewage pit exposed and marked safe."); advance_time(1); return "trap"
	if distance(pos, state.map.entrance) <= 1:
		say("Arrival portal. Return occurs when the floor closes.")
		return ""
	for trap: Vector2i in state.map.traps:
		if distance(pos, trap) <= 1 and not state.disarmed.has(pos_key(trap)):
			state.disarmed.append(pos_key(trap))
			say("Trap disarmed.")
			advance_time(1)
			return "trap"
	say("Nothing within reach.")
	return ""



func camp() -> bool:
	if state.mode!="dungeon" or state.combat: say("Break contact before resting."); return false
	var failure: String=ThirdFloorRules.can_camp(self)
	if not failure.is_empty(): say(failure); return false
	if allies().any(func(u: Dictionary)->bool:return u.hp>0 and DungeonWorld.tile_at(state.map,u.pos)==DungeonWorld.HAZARD): say("Leave the choking mist before resting."); return false
	var duration: int=mini(CAMP_DURATION_MINUTES,portal_limit()-int(state.time))
	if ThirdFloorRules.in_refuge(self): duration=mini(duration,int(state.hut_until)-int(state.time))
	var nourished: bool=int(state.food)>0 and int(state.get("water",EarlyFloorRules.WATER_START))>0
	if nourished:
		var fraction: float=float(duration)/CAMP_DURATION_MINUTES
		for unit: Dictionary in allies():
			if unit.hp<=0 or unit.get("summon",false): continue
			heal(unit,floori((12+int(unit.vig))*fraction))
			unit.energy=mini(int(unit.max_energy),int(unit.energy)+floori(int(unit.max_energy)*fraction))
			unit.mana=mini(int(unit.get("max_mana",0)),int(unit.get("mana",0))+floori(int(unit.get("max_mana",0))*fraction))
	advance_time(duration)
	if state.mode=="dungeon": say("Rested %dh %dm." % [duration/60,duration%60] if nourished else "Waited without food or water. No camp recovery.")
	cue.emit("heal")
	return true

func extract(portal_closure: bool = false) -> bool:
	if state.mode != "dungeon": return false
	if not portal_closure: say("Survive until the floor closes."); return false
	state.gold += int(state.loot_gold)
	for id: String in state.loot_items: add_item(id, int(state.loot_items[id]))
	state.essence_drops = []
	state.loot_essences = {}
	return_city()
	cue.emit("loot")
	return true

func return_city() -> void:
	state["hut_until"]=0
	state.essence_drops = []
	state.mode = "city"
	state.day += 1
	state.combat = false
	state.units = []
	state.selected = "hero"
	state.loot_gold = 0
	state.loot_items = {}
	state.loot_essences = {}
	var expenses: int = mini(int(state.gold), 3 + state.party.size() * 2)
	state.gold -= expenses
	say("Returned to Rafdonia. Living costs: %d stones." % expenses)
	var survivors: Array = []
	for unit: Dictionary in state.party:
		if not unit.get("dead", false) and int(unit.hp) > 0:
			unit.statuses = {}
			unit.loyalty = mini(100, int(unit.loyalty) + 3)
			survivors.append(unit)
		else: state.roster.erase(unit.get("content_id", ""))
	state.party = survivors
	hero().statuses = {}
	for unit: Dictionary in allies(): recalculate(unit)



func absorb(id: String, unit_id: String = "hero", replace_slot: int = -1) -> String:
	if ThirdFloorRules.in_refuge(self): return "Leave the refuge before collecting forest drops."
	if state.mode != "dungeon": return "Absorb an essence beside its drop."
	_expire_essence_drops()
	if not essence_defs.has(id) or int(state.loot_essences.get(id, 0)) <= 0: return "No intact essence."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or int(unit.hp) <= 0 or bool(unit.get("dead", false)): return "Choose a living character."
	var drop_index: int = _nearby_essence_drop(id, unit)
	if drop_index < 0: return "Move within one tile of the essence."
	if unit.essences.has(id): return "Duplicate essences cannot be absorbed."
	if replace_slot != -1: return "The essence slot must be empty."
	if essence_capacity(unit) == 0: return "Mages cannot absorb essences."
	if unit.essences.size() >= essence_capacity(unit): return "All essence slots occupied."
	unit.essences.append(id)
	state.essence_drops.remove_at(drop_index)
	_recount_essence_drops()
	recalculate(unit)
	say("%s absorbed %s." % [unit.name, essence_defs[id].name])
	cue.emit("cast")
	return ""

# Fifteen minutes of uninterrupted work is an estimate, not a recovered novel timing.
func seal_essence(id: String, mage_id: String) -> String:
	if state.mode != "dungeon": return "Seal an essence at its drop."
	if state.combat: return "Break contact before sealing an essence."
	if not essence_defs.has(id): return "Unknown essence."
	var mage: Dictionary = unit_by_id(mage_id)
	if mage.is_empty() or int(mage.hp) <= 0 or mage.get("dead", false): return "Choose a living mage."
	if mage.get("profession", "explorer") != "mage": return "A mage must seal the essence."
	if unable_to_act(mage): return "The mage cannot act."
	var index: int = _nearby_essence_drop(id, mage)
	if index < 0: return "Move the mage within one tile of an intact essence."
	var drop: Dictionary = state.essence_drops[index]
	if int(drop.expires_at) < int(state.time) + SEAL_DURATION_MINUTES: return "Not enough time to seal this essence."
	if int(state.time) + SEAL_DURATION_MINUTES >= portal_limit(): return "The portal closes before sealing can finish."
	if int(state.inventory.get("essence_test_tube", 0)) < 1: return "Need an empty essence test tube."
	var filled: String = "sealed_" + id
	if weight() - float(item_defs.essence_test_tube.weight) + float(item_defs[filled].weight) > capacity(): return "Pack capacity exceeded."
	# Commit only after all preconditions pass. No empty-tube refund on opening.
	take_item("essence_test_tube")
	state.essence_drops.remove_at(index)
	_recount_essence_drops()
	add_item(filled, 1)
	advance_time(SEAL_DURATION_MINUTES)
	journal("Essence preservation", "A mage can seal a loose essence in a single-use test tube. Sealed essences survive extraction and can be stored or sold. Opening destroys the tube.")
	say("%s sealed %s." % [mage.name, essence_defs[id].name])
	cue.emit("cast")
	return ""

func absorb_sealed(id: String, unit_id: String = "hero") -> String:
	if state.mode not in ["city", "dungeon"]: return "Absorption unavailable."
	if state.combat: return "Break contact before opening the tube."
	if not essence_defs.has(id): return "Unknown essence."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or int(unit.hp) <= 0 or unit.get("dead", false): return "Choose a living character."
	if essence_capacity(unit) == 0: return "Mages cannot absorb essences."
	if unit.essences.has(id): return "Duplicate essences cannot be absorbed."
	if unit.essences.size() >= essence_capacity(unit): return "All essence slots occupied."
	if not take_item("sealed_" + id): return "No sealed essence in your pack."
	unit.essences.append(id)
	recalculate(unit)
	say("%s absorbed %s. The tube was destroyed." % [unit.name, essence_defs[id].name])
	cue.emit("cast")
	return ""

func remove_essence(_unit_id: String, _slot: int) -> String:
	return "Essence removal is not available."

func equip(id: String, unit_id: String = "hero", seal_id: String = "") -> String:
	if state.combat: return "Equipment cannot change during combat."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or not item_defs.has(id): return "Unknown item or character."
	var item: Dictionary = item_defs[id]
	var slot: String = str(item.get("slot", ""))
	if slot.is_empty() or not unit.equipment.has(slot): return "This is not wearable equipment."
	if unit.hp <= 0: return "Cannot equip a fallen character."
	if id == RacialProgression.FROST_RING and not unit.essences.is_empty() and not unit.essences.has(seal_id): return "Choose the essence whose skills will be sealed."
	if stat_value(unit,"strength") < int(item.get("str_req",0)) or stat_value(unit,"agility") < int(item.get("agi_req",0)): return "Requirements not met: STR %d / AGI %d." % [item.get("str_req", 0), item.get("agi_req", 0)]
	if not take_item(id): return "Item is not in your pack."
	var old: String = str(unit.equipment[slot])
	if not old.is_empty(): add_item(old, 1)
	if not old.is_empty() and old!=id: attachment_loss(unit)
	unit.equipment[slot] = id
	if id == RacialProgression.FROST_RING: unit.ring_sealed_essence = seal_id
	recalculate(unit)
	say("%s equips %s." % [unit.name, item.name])
	return ""

func use_item(id: String, unit_id: String = "hero") -> String:
	if not item_defs.has(id): return "Unknown item."
	var item: Dictionary = item_defs[id]
	if str(item.get("effect",""))=="light":
		if state.mode!="dungeon": return "Light a torch after entering the Labyrinth."
		if int(state.get("torch_until",0))>int(state.time): return "A torch is already burning. Preserve the spare."
	if state.combat and str(item.get("effect", "")) == "heal": return "Healing potions cannot be used during combat. Break contact before drinking."
	if item.get("kind", "") != "consumable": return "Not a consumable."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.hp <= 0: return "Cannot use on a fallen character."
	if state.combat and unit.ap < 1: return "Need 1 AP."
	if not take_item(id): return "No item in pack."
	var amount: int = int(item.get("amount", 12))
	match str(item.get("effect", "heal")):
		"light": state["torch_until"]=int(state.time)+amount; say("Magic Torch lit: about three expedition days of light."); update_visibility()
		"water": state["water"]=mini(1000000000,int(state.get("water",EarlyFloorRules.WATER_START))+amount); say("Drinking water supplies replenished.")
		"heal": heal(unit, amount)
		"food": state.food += amount
		"antidote": unit.statuses.erase("poison")
		"energy": unit.energy = mini(int(unit.max_energy), int(unit.energy) + amount)
		"bomb":
			if state.mode == "dungeon":
				for enemy: Dictionary in enemies():
					if distance(unit.pos, enemy.pos) <= 4 and DungeonWorld.line_of_sight(state.map, unit.pos, enemy.pos): hit(unit, enemy, amount, "fire", "Firepot", true, true)
		"ward": status(unit, "ward", amount)
		_:
			heal(unit, amount)
	if state.combat: unit.ap -= 1
	cue.emit("heal")
	if state.mode == "dungeon": update_visibility(); auto_end_if_spent()
	return ""

func market_price(id: String, buying: bool = true, npc_id: String = "") -> int:
	var base: int = int(item_defs[id].get("price", 10))
	var reputation: int = 0
	for value: Variant in state.rep.values(): reputation = maxi(reputation, int(value))
	var fluctuation: float = 0.96 + float((int(state.day) * 3 + id.hash()) % 9) / 100.0
	var local_discount: float = 0.0 if npc_id.is_empty() else float(clampi(CityLife.market_discount(state, npc_id), 0, 8)) / 100.0
	return maxi(1, int(ceil(base * fluctuation * (1.0 - minf(0.18, reputation * 0.01)) * (1.0 - local_discount)))) if buying else maxi(1, base / 3)

func buy(id: String, npc_id: String = "") -> String:
	if state.mode != "city" or not item_defs.has(id): return "Market unavailable."
	var item: Dictionary = item_defs[id]
	if str(item.kind) in ["material"]: return "Materials must be recovered from the Labyrinth."
	if not item.get("market_unlocked", false) and int(item.get("price", 0)) > 80 + int(state.unlocked) * 50: return "This equipment is not available yet."
	if int(item.get("market_limit", 0)) > 0 and state.flags.get("consignment_" + id, false): return "This consignment has sold out."
	var cost: int = market_price(id, true, npc_id)
	if int(state.gold) < cost: return "Need %d coin." % cost
	if weight() + float(item.get("weight", 0)) > capacity(): return "Pack capacity exceeded."
	state.gold -= cost
	add_item(id, 1)
	if int(item.get("market_limit", 0)) > 0: state.flags["consignment_" + id] = true
	cue.emit("ui")
	return ""

func sell(id: String) -> String:
	if state.mode != "city" or not take_item(id): return "Cannot sell this item."
	state.gold += market_price(id, false)
	return ""

func store_item(id: String, withdraw: bool = false) -> String:
	if state.mode != "city": return "Storage is in the city."
	if withdraw:
		if int(state.storage.get(id, 0)) < 1: return "Not in storage."
		if weight() + float(item_defs[id].get("weight", 0)) > capacity(): return "Pack capacity exceeded."
		state.storage[id] -= 1
		if state.storage[id] <= 0: state.storage.erase(id)
		add_item(id, 1)
	else:
		if not take_item(id): return "Not in pack."
		state.storage[id] = int(state.storage.get(id, 0)) + 1
	return ""

func recruit(id: String) -> String:
	ensure_city_state()
	if state.mode != "city" or not companion_defs.has(id): return "Recruitment unavailable."
	if state.party.size() >= 4: return "Party limit reached. Dismiss a companion first."
	if state.roster.has(id): return "Already recruited."
	var definition: Dictionary = companion_defs[id]
	if int(definition.get("unlock_region", 1)) > int(state.unlocked): return "Meet this companion later."
	if state.fallen_ids.has(id): return "This companion is dead."
	var cost: int = maxi(0, int(definition.cost) - int(state.unlocked) * 2)
	if state.gold < cost: return "Joining supplies cost %d stones." % cost
	state.gold -= cost
	var unit: Dictionary = {}
	if state.benched.has(id):
		unit = state.benched[id].duplicate(true)
		state.benched.erase(id)
		unit.name = definition.name
		unit.appearance = definition.appearance.duplicate(true)
		recalculate(unit)
	else:
		unit = make_unit("comp_" + id, definition.name, "ally", definition.role)
		unit.content_id = id
		unit.ancestry = str(definition.ancestry)
		unit.appearance = CharacterArt.normalize(definition.get("appearance", {}), unit.ancestry, int(state.seed) + str(unit.id).hash())
		unit.base_hp = int(definition.get("hp", 28))
		unit.base_power = int(definition.get("power", 3))
		unit.equipment.weapon = definition.get("weapon", "")
		unit.essences = []
		unit.spells = definition.get("spells", []).duplicate()
		unit.profession = str(definition.get("profession", "explorer"))
		unit.can_absorb_essences = bool(definition.get("can_absorb_essences", true))
		unit.loyalty = int(definition.get("loyalty", 60))
		unit.behavior = "aggressive"
		if unit.role == "ranged": unit.agi = 6
		if not unit.spells.is_empty(): unit.wit = 6
		if unit.role == "tank": unit.base_armor = 3; unit.vig = 6
		recalculate(unit, true)
	state.party.append(unit)
	state.roster.append(id)
	say("%s joins the party." % unit.name)
	journal("Companion: " + str(unit.name), str(definition.desc))
	return ""

func dismiss(id: String) -> void:
	if state.mode != "city": return
	for unit: Dictionary in state.party:
		if unit.id == id and not unit.get("dead", false) and int(unit.hp) > 0:
			state.benched[str(unit.content_id)] = unit.duplicate(true)
	state.party = state.party.filter(func(u: Dictionary) -> bool: return u.id != id)
	state.roster = []
	for u: Dictionary in state.party: state.roster.append(u.content_id)
	if state.has("homeland"): HomelandRules.ensure_state(self)

func city_service(service: String) -> String:
	if state.mode != "city": return "Return to Rafdonia first."
	match service:
		"rest":
			var cost: int = 6 + state.party.size() * 3
			if state.gold < cost: return "Inn recovery costs %d coin. Relief work can fund it." % cost
			state.gold -= cost
			for unit: Dictionary in allies():
				recalculate(unit,true)
				if unit.has("spirit"):
					unit.natural_energy_current=maxi(0,int(stat_value(unit,"natural_energy")))
					unit.spirit.active=false
					if unit.has("wind_guidance"): unit.wind_guidance=false
			if state.get("numbered_state", {}).has(Numbered.ID): braces_record().cooldown = 0
			say("Rested. HP and SP restored.")
		"repair":
			var cost: int = 5 + int(state.unlocked)
			if state.gold < cost: return "Repair costs %d coin." % cost
			state.gold -= cost
			for unit: Dictionary in allies(): unit.durability = 100; recalculate(unit)
			say("Equipment repaired.")
		"rations":
			if state.gold < 8: return "Four rations cost 8 coin."
			state.gold -= 8
			state.food += 4
		"relief":
			if int(state.gold) >= 30: return "The relief desk reserves work for those below 30 coin."
			state.day += 1
			state.gold += 18
			state.food += 2
			heal(hero(), 10)
			say("You clear rubble for the city: +18 coin, +2 rations, +10 health. No living cost is charged for relief work.")
		_: return "Unknown city service."
	cue.emit("ui")
	return ""







func snapshot() -> Dictionary:
	state.rng_state = str(rng.state)
	return encode(state)

func restore(data: Dictionary) -> bool:
	if not preload("res://game/save_validation.gd").validate(data).is_empty(): return false
	var decoded: Variant = decode(data)
	if not decoded is Dictionary or int(decoded.get("version", 0)) not in [2, 3] or not decoded.has("hero") or not decoded.has("mode"): return false
	if decoded.mode not in ["city", "dungeon", "dead"]: return false
	if not GameContent.ancestries().has(str(decoded.hero.get("ancestry", ""))): return false
	if not decoded.hero is Dictionary or not decoded.hero.has("id") or not decoded.hero.has("hp"): return false
	if not decoded.has("seed") or not decoded.has("inventory") or not decoded.has("party"): return false
	if decoded.mode == "dungeon" and (not decoded.has("map") or not decoded.map.has("tiles")): return false
	if int(decoded.version) == 2:
		decoded.time = int(decoded.time) * 15
		for drop: Dictionary in decoded.essence_drops: drop.expires_at = int(drop.expires_at) * 15
		decoded.version = 3
	# Validate migration output too; malformed or overflowing old clocks never
	# replace the active campaign or consume its random stream.
	if not preload("res://game/save_validation.gd").validate(decoded).is_empty(): return false
	state = decoded
	if not state.has("water"): state["water"]=EarlyFloorRules.WATER_START
	for field: String in ["visited","visited_regions"]:
		var normalized: Array=[]
		for value: Variant in state[field]:
			var id: int=int(value)
			if field=="visited" or not normalized.has(id): normalized.append(id)
		state[field]=normalized
	stat_cache.clear()
	_migrate_companion_ids()
	ensure_city_state()
	configure_content()
	for restored_unit: Dictionary in [hero()]+state.get("party",[])+state.get("benched",{}).values(): recalculate(restored_unit)
	if not state.has("essence_drops"): state.essence_drops = []
	if state.mode != "dungeon": state.essence_drops = []
	_expire_essence_drops()
	rng.seed = int(state.seed)
	rng.state = int(state.get("rng_state", "0"))
	trigger_depth = 0
	if state.mode == "dungeon": ThirdFloorRules.apply_environment(self); prune_summons(); update_visibility()
	return true

func encode(value: Variant) -> Variant:
	if value is Vector2i: return {"@v": [value.x, value.y]}
	if value is Rect2i: return {"@r": [value.position.x, value.position.y, value.size.x, value.size.y]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(encode(item))
		return result
	return value

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("@v"): return Vector2i(int(value["@v"][0]), int(value["@v"][1]))
		if value.has("@r"): return Rect2i(int(value["@r"][0]), int(value["@r"][1]), int(value["@r"][2]), int(value["@r"][3]))
		var result: Dictionary = {}
		for key: Variant in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(decode(item))
		return result
	# JSON numbers become floats. Rules explicitly cast where needed.
	return value

func ensure_city_state() -> void:
	if state.is_empty(): return
	if not state.has("fallen_ids"): state.fallen_ids = []
	if not state.has("benched"): state.benched = {}
	companion_defs = Recruitment.for_state(state)
	for member: Dictionary in state.get("party", []):
		var id: String = str(member.get("content_id", ""))
		if companion_defs.has(id):
			member.name = companion_defs[id].name
			if not member.get("magic_trained",false):
				member.profession = companion_defs[id].profession
				member.can_absorb_essences = companion_defs[id].can_absorb_essences
			if member.get("dead", false) and not state.fallen_ids.has(id): state.fallen_ids.append(id)
			state.recruits[id].appearance = member.get("appearance", companion_defs[id].appearance).duplicate(true)
	CityLife.ensure_state(state)
	if state.has("homeland"): HomelandRules.ensure_state(self)
	for unit: Dictionary in [hero()] + state.get("party", []):
		var ancestry: String = unit_ancestry(unit)
		unit.ancestry = ancestry
		unit.appearance = CharacterArt.normalize(unit.get("appearance", CharacterArt.seeded(ancestry, int(state.seed) + str(unit.id).hash())), ancestry)

func unit_ancestry(unit: Dictionary) -> String:
	if unit.has("ancestry"): return str(unit.ancestry)
	var title: String = str(unit.get("name", "")).to_lower()
	if title.contains("barbarian"): return "barbarian"
	if title.contains("beast"): return "beastman"
	if title.contains("dragon"): return "draconian"
	if title.contains("dwarf"): return "dwarf"
	if title.contains("elf") or title.contains("fairy"): return "fairy"
	return "human"

func customize(unit_id: String, appearance: Dictionary) -> String:
	if state.get("mode", "") != "city": return "Visit the tailor in the city."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.get("team", "") != "ally" or unit.get("summon", false) or int(unit.hp) <= 0: return "Choose a living party member."
	var updated: Dictionary = CharacterArt.normalize(appearance, unit_ancestry(unit))
	if updated == unit.get("appearance", {}): return "No changes."
	if int(state.gold) < 5: return "Need 5 stones."
	state.gold -= 5
	unit.appearance = updated
	if state.recruits.has(str(unit.get("content_id", ""))):
		state.recruits[unit.content_id].appearance = updated.duplicate(true)
		companion_defs = Recruitment.for_state(state)
	CityLife.ensure_state(state)
	say("%s's appearance updated." % unit.name)
	cue.emit("ui")
	return ""

func interact_npc(npc_id: String, choice_id: String) -> Dictionary:
	if state.get("mode", "") != "city": return {"ok": false, "message": "Return to the city first."}
	var result: Dictionary = CityLife.interact(state, npc_id, choice_id)
	if not result.get("ok", false): return result
	if result.has("service"):
		var failure: String = city_service(str(result.service))
		if not failure.is_empty(): return {"ok": false, "message": failure}
	if not str(result.get("message", "")).is_empty(): say(str(result.message))
	return result

func _migrate_companion_ids() -> void:
	var renamed: Dictionary = {}
	for member: Dictionary in state.get("party", []):
		var old: String = str(member.get("content_id", ""))
		var neutral: String = Recruitment.neutral_id(old)
		if old != neutral:
			renamed[str(member.id)] = "comp_" + neutral
			member.content_id = neutral
			member.id = "comp_" + neutral
	for index: int in range(state.roster.size()): state.roster[index] = Recruitment.neutral_id(str(state.roster[index]))
	state.selected = renamed.get(str(state.selected), state.selected)
	for collection: String in ["player_traps", "terrain_effects"]:
		for record: Dictionary in state.get(collection, []):
			if record.has("owner"): record.owner = renamed.get(str(record.owner), record.owner)

func unable_to_act(unit: Dictionary) -> bool:
	return unit.get("statuses", {}).has("stunned") or unit.get("statuses", {}).has("paralyzed") or unit.get("statuses", {}).has("suppressed") or unit.get("statuses",{}).has("toppled")

func apply_suppression(caster: Dictionary, center: Vector2i, radius: int, duration: int) -> void:
	for target: Dictionary in allies() + enemies():
		if target.team != caster.team and target.hp > 0 and distance(center, target.pos) <= radius and DungeonWorld.line_of_sight(state.map, center, target.pos): status(target, "suppressed", duration)

func release_suppression(target_id: String) -> String:
	if state.mode != "dungeon": return "Release a suppressed ally in the Labyrinth."
	var actor: Dictionary = selected()
	var target: Dictionary = unit_by_id(target_id)
	if target.is_empty() or target.team != "ally" or target.hp <= 0 or not target.statuses.has("suppressed"): return "Choose a suppressed living ally."
	if actor.id == target.id or actor.hp <= 0 or unable_to_act(actor): return "A free ally must make the cut."
	if distance(actor.pos, target.pos) > 1: return "Move beside the suppressed ally."
	if target.hp <= 1: return "A cut would kill this ally."
	if state.combat and (int(actor.ap) < 1 or actor.attacked): return "Need one AP and an unused attack."
	if state.combat:
		actor.ap -= 1
		actor.attacked = true
	hit(actor,target,1,"wound","Release cut",false,true,1)
	advance_time(1)
	update_visibility()
	auto_end_if_spent()
	return ""

func scent_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if state.get("mode", "") != "dungeon": return contacts
	for enemy: Dictionary in enemies():
		if unit_visible(enemy): continue
		for tracker: Dictionary in allies():
			if tracker.hp <= 0: continue
			var sensed: bool = false
			for id: String in active_essences(tracker):
				var essence: Dictionary = essence_defs[id]
				if essence.get("passive", "") == "scent_tracking" and distance(tracker.pos, enemy.pos) <= skill_duration(tracker,int(essence.get("scent_range",6)))+int(stat_value(tracker,"smell")/10.0): sensed = true; break
			if sensed:
				contacts.append({"pos":enemy.pos})
				break
	return contacts

func learn_undying(unit_id: String = "hero") -> String:
	if state.mode != "city": return "Visit the sanctuary in Rafdonia."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.team != "ally" or unit.get("summon", false): return "Choose a living party member."
	var failure: String = RacialProgression.can_unlock_undying(unit)
	if not failure.is_empty(): return failure
	if int(state.gold) < UNDYING_SERVICE_COST: return "Need %d stones." % UNDYING_SERVICE_COST
	failure = RacialProgression.unlock_undying(unit)
	if not failure.is_empty(): return failure
	state.gold -= UNDYING_SERVICE_COST
	journal("Soul Engraving: Undying", "A shaman engraves the Undying path. The choice is permanent. Natural recovery improves; the current price and recovery coefficient are estimates.")
	say("%s receives Undying I. This path is permanent." % unit.name)
	cue.emit("cast")
	return ""

func break_moving_concealment(unit: Dictionary, origin: Vector2i) -> void:
	if unit.get("content_id", "") == "canon_gnome" and unit.pos != origin and unit.statuses.has("concealed"):
		unit.statuses.erase("concealed")
		unit.status_power.erase("concealed")
		say("Movement breaks the Gnome’s stationary concealment.")

func active_essences(unit: Dictionary) -> Array:
	var sealed: String = str(unit.get("ring_sealed_essence", "")) if unit.get("equipment", {}).get("charm", "") == RacialProgression.FROST_RING else ""
	return unit.get("essences", []).filter(func(id: String) -> bool: return id != sealed)

func _sync_ring_seal(unit: Dictionary) -> void:
	if unit.get("equipment", {}).get("charm", "") != RacialProgression.FROST_RING:
		unit.erase("ring_sealed_essence")
	elif not unit.get("essences", []).has(str(unit.get("ring_sealed_essence", ""))):
		unit.ring_sealed_essence = "" if unit.essences.is_empty() else str(unit.essences[0])

func set_ring_seal(essence_id: String, unit_id: String = "hero") -> String:
	if state.mode not in ["city","dungeon"] or state.combat: return "Change the seal outside combat."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.hp <= 0: return "Choose a living character."
	if unit.equipment.get("charm", "") != RacialProgression.FROST_RING: return "Wear the Ring of the Frost Spirit first."
	if not unit.essences.has(essence_id): return "Choose an absorbed essence."
	unit.ring_sealed_essence = essence_id
	say("%s: %s’s skills are sealed." % [unit.name, essence_defs[essence_id].name])
	return ""

func unequip(slot: String, unit_id: String = "hero") -> String:
	if state.mode not in ["city","dungeon"] or state.combat: return "Change equipment outside combat."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.hp <= 0 or not unit.equipment.has(slot): return "Choose a living character and equipment slot."
	var id: String = str(unit.equipment[slot])
	if id.is_empty(): return "This slot is empty."
	# Worn gear is already included in party weight; moving it preserves weight.
	attachment_loss(unit)
	unit.equipment[slot] = ""
	add_item(id, 1)
	recalculate(unit)
	say("%s removes %s." % [unit.name,item_defs[id].name])
	return ""

func skadia_ritual_losses(unit: Dictionary) -> Array[String]:
	var losses: Array[String] = []
	for id: String in unit.get("equipment", {}).values():
		if item_defs.has(id): losses.append(str(item_defs[id].name))
	return losses

func awaken_skadia(unit_id: String = "hero") -> String:
	if state.mode not in ["city","dungeon"] or state.combat: return "Perform the ritual outside combat."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.team != "ally" or unit.get("summon", false): return "Choose a living party member."
	var failure: String = RacialProgression.can_awaken_skadia(unit)
	if not failure.is_empty(): return failure
	if unable_to_act(unit): return "Cannot accept the contract while unable to act."
	var lost: Array[String] = skadia_ritual_losses(unit)
	if not lost.is_empty(): attachment_loss(unit)
	for slot: String in unit.equipment: unit.equipment[slot] = ""
	unit.erase("ring_sealed_essence")
	unit.racial = {"soul_beast":"skadia","awakening":0}
	recalculate(unit)
	journal("Soul Beast: Skadia", "Breaking No. 9425 awakens the Ice Beast Skadia and destroys all worn equipment. Strengthening is permanent. Initial cold belongs to bare-handed strikes, not weapons. Physical coefficients and market availability are estimates.")
	say("%s contracts Skadia. Destroyed: %s." % [unit.name, ", ".join(lost)])
	cue.emit("cast")
	return ""

# Innate, controllable racial intimidation (novel159–160). The accuracy/radius
# conversion is estimated; this never stuns, skips turns or grants boss powers.
func dragon_fear_penalty(actor: Dictionary) -> int:
	if state.get("mode", "") != "dungeon" or not actor.get("pos") is Vector2i: return 0
	for carrier: Dictionary in allies() + enemies():
		if carrier.get("ancestry", "") != "draconian" or carrier.get("hp", 0) <= 0 or not carrier.get("dragon_fear_enabled", true): continue
		if carrier.team == actor.get("team", "") or distance(carrier.pos,actor.pos) > 3: continue
		if not DungeonWorld.line_of_sight(state.map, carrier.pos, actor.pos): continue
		return 10
	return 0

func set_dragon_fear(enabled: bool, unit_id: String = "hero") -> String:
	if state.mode not in ["city","dungeon"]: return "Choose a living Draconian."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.hp <= 0 or unit.get("ancestry", "") != "draconian": return "Dragon Fear belongs to Draconians."
	if unable_to_act(unit): return "Cannot control Dragon Fear while unable to act."
	unit.dragon_fear_enabled = enabled
	say("%s %s Dragon Fear." % [unit.name,"releases" if enabled else "suppresses"])
	return ""

const HARMFUL_STATUSES: Array[String] = ["bleeding","poison","burning","chilled","stunned","weakened","marked","frightened","paralyzed","suppressed","pained","distressed"]

func numbered_record(id: String) -> Dictionary:
	if not state.has("numbered_state"): state.numbered_state = {}
	if not state.numbered_state.has(id): state.numbered_state[id] = {"charge":0,"remainder":0,"cooldown":0}
	return state.numbered_state[id]

func braces_record() -> Dictionary:
	return numbered_record(Numbered.ID)

func tick_numbered_cooldown() -> void:
	for record: Dictionary in state.get("numbered_state", {}).values(): record.cooldown = maxi(0,int(record.cooldown)-1)

func activate_guardians_braces(unit_id: String = "hero") -> String:
	return activate_numbered(Numbered.ID,unit_id)

func activate_numbered(id: String, unit_id: String = "hero") -> String:
	if ThirdFloorRules.in_refuge(self): return "Leave the refuge before activating combat items."
	if state.mode != "dungeon": return "Activate Numbered Items in the Labyrinth."
	var active: Dictionary = NumberedCatalog.definitions().get(id, {}).get("active", {})
	if active.is_empty(): return "This item has no active power."
	var caster: Dictionary = unit_by_id(unit_id)
	if caster.is_empty() or caster.hp <= 0 or caster.team != "ally" or not Numbered.equipped_ids(caster).has(id): return "Equip this Numbered Item first."
	if unable_to_act(caster): return "Cannot activate while unable to act."
	if state.combat and int(caster.ap) < int(active.ap): return "Need %d AP." % active.ap
	if int(state.get("numbered_state", {}).get(id, {}).get("cooldown",0)) > 0: return "This Numbered Item is cooling down."
	var record: Dictionary = numbered_record(id)
	var duration: int = Numbered.duration_for(id,caster,int(record.charge))
	record.charge = 0
	record.cooldown = ability_cooldown(caster,int(active.cooldown))+1
	if state.combat: caster.ap -= int(active.ap)
	for effect: Dictionary in active.effects:
		var targets: Array = allies() if effect.target == "allies" else enemies()
		for target: Dictionary in targets:
			if target.hp <= 0 or distance(caster.pos,target.pos) > int(effect.radius) or not DungeonWorld.line_of_sight(state.map,caster.pos,target.pos): continue
			match str(effect.op):
				"cleanse":
					for status_id: String in HARMFUL_STATUSES: target.statuses.erase(status_id); target.status_power.erase(status_id)
				"status_immunity": status(target,"status_immunity",duration+1)
				"knockback":
					if ThirdFloorCombat.blocks_displacement(target): say("Counterweight anchors %s." % target.name); continue
					var direction: Vector2i = target.pos-caster.pos
					direction = Vector2i(signi(direction.x),0) if absi(direction.x) >= absi(direction.y) else Vector2i(0,signi(direction.y))
					var push_distance: int = int(ceil(float(effect.distance)*(1.0-StatPhysiology.knockback_reduction(stat_value(target,"weight")))))
					if push_distance>0 and EarlyMonsterRules.is_topple_vulnerable(target): status(target,"toppled",EarlyMonsterRules.TOPPLE_DURATION); target.ap=0; target.intent={}
					for step: int in range(push_distance):
						var destination: Vector2i = target.pos+direction
						if not DungeonWorld.walkable(state.map,destination) or not unit_at(destination).is_empty(): break
						target.pos = destination
					step_hazards(target)
	say("%s activates %s: %d rounds." % [caster.name,active.name,duration])
	cue.emit("cast")
	advance_time(2)
	update_visibility()
	auto_end_if_spent()
	return ""

func numbered_on_hit(source: Dictionary, target: Dictionary) -> void:
	if trigger_depth >= MAX_TRIGGER_DEPTH: return
	var weapon: String = str(source.get("equipment", {}).get("weapon", ""))
	for effect: Dictionary in NumberedCatalog.definitions().get(weapon, {}).get("passives", []):
		if effect.op == "extra_weapon_damage": hit(source,target,int(effect.amount),str(effect.damage_type),str(item_defs[weapon].name),false,true,-1,{"attack_resolved":true,"category":"weapon"})

func advance_city_days(days: int) -> void:
	if state.mode != "city" or days <= 0: return
	var elapsed: int = int(state.day)-1+days
	state.month = int(state.get("month",1)) + elapsed/30
	state.day = elapsed%30+1

func assess_magic(unit_id: String = "hero") -> String:
	if state.mode != "city": return "Seek magic instruction in the city."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.get("summon",false): return "Choose a living Human."
	var failure: String = ProfessionRules.can_assess(unit)
	if not failure.is_empty(): return failure
	if int(state.gold) < ProfessionRules.ASSESSMENT_COST: return "Need %d stones." % ProfessionRules.ASSESSMENT_COST
	var result: String = ProfessionRules.assessment(unit,int(state.seed))
	state.gold -= ProfessionRules.ASSESSMENT_COST
	unit.magic_assessment = result
	advance_city_days(ProfessionRules.ASSESSMENT_DAYS)
	journal("Magic assessment: " + str(unit.name),"An assessment found " + ("limited aptitude sufficient for private basic lessons, without promising Magic Tower admission." if result == "limited" else "no aptitude for the basic instruction currently offered.") + " Assessment cost, duration and aptitude frequency are estimates.")
	say("%s: %s." % [unit.name,"Suitable for basic magic lessons" if result == "limited" else "No aptitude for these magic lessons"])
	return ""

func study_magic(unit_id: String = "hero") -> String:
	if state.mode != "city": return "Study magic in the city."
	var unit: Dictionary = unit_by_id(unit_id)
	if unit.is_empty() or unit.get("summon",false): return "Choose a living Human."
	var failure: String = ProfessionRules.can_study(unit)
	if not failure.is_empty(): return failure
	if int(state.gold) < ProfessionRules.TUITION_COST: return "Need %d stones." % ProfessionRules.TUITION_COST
	state.gold -= ProfessionRules.TUITION_COST
	advance_city_days(ProfessionRules.TUITION_DAYS)
	unit.profession = "mage"
	unit.can_absorb_essences = false
	unit.magic_trained = true
	unit.spells = ["ice_spear"]
	recalculate(unit)
	unit.mana = unit.max_mana
	journal("Magic lessons: " + str(unit.name),"Paid private instruction teaches Ice Spear. Wizards use mana and cannot absorb essences. Tuition and study duration are estimates; this is not Magic Tower admission or a complete profession tree.")
	say("%s completes basic lessons and learns Ice Spear." % unit.name)
	cue.emit("cast")
	return ""

func _permanent_stats(unit: Dictionary) -> Dictionary:
	var source_mods: Array = StatSources.modifiers(unit,item_defs,essence_defs,ancestry_defs)
	var weapon_base: Dictionary = item_defs.get(str(unit.get("equipment",{}).get("weapon","")),{}).get("base_stats",{})
	var fingerprint: String = var_to_str([source_mods,weapon_base,unit.get("team",""),unit.get("str",4),unit.get("agi",4),unit.get("wit",4),unit.get("vig",4),unit.get("base_hp",24),unit.get("base_power",2),unit.get("base_armor",0),unit.get("equipment",{}),unit.get("essences",[]),unit.get("ancestry",""),unit.get("racial",{}),unit.get("dead",false),unit.get("injuries",0),unit.get("profession",""),unit.get("spells",[]),unit.get("resist",{}),unit.get("durability",100),unit.get("base_stats",{}),unit.get("modifiers",[]),state.get("level",1),unit.get("power",6) if unit.get("team","")=="enemy" else 0,unit.get("armor",0) if unit.get("team","")=="enemy" else 0,unit.get("accuracy",85) if unit.get("team","")=="enemy" else 0,unit.get("evasion",4) if unit.get("team","")=="enemy" else 0,unit.get("range",1) if unit.get("team","")=="enemy" else 0,unit.get("max_hp",24) if unit.get("team","")=="enemy" else 0])
	var id: String = str(unit.get("id","anonymous"))
	if stat_cache.has(id) and stat_cache[id].fingerprint==fingerprint: return stat_cache[id].result
	var result: Dictionary = StatSources.resolve(unit,int(state.get("level",1)),item_defs,essence_defs,ancestry_defs)
	stat_cache[id] = {"fingerprint":fingerprint,"result":result}
	return result

func stat_breakdown(unit: Dictionary, combat: bool = true) -> Dictionary:
	var permanent: Dictionary = _permanent_stats(unit)
	if not combat or not permanent.errors.is_empty(): return permanent
	var extra: Array = StatSources.combat_modifiers(unit,item_defs)
	# Compatibility fields remain available to encounter/dev scripts. Canonical
	# definitions and modifiers are the ordinary source of these derived values.
	for pair: Array in ([] if unit.get("team", "")=="enemy" else [["power","attack"],["armor","armor"],["accuracy","accuracy"],["evasion","evasion"],["range","attack_range"]]):
		if not unit.has(pair[0]): continue
		var difference: float = float(unit[pair[0]])-float(permanent.values[pair[1]])
		if not is_zero_approx(difference):
			var previous: Dictionary = permanent.breakdown[pair[1]]
			var factor: float = (1.0+float(previous.increased))*float(previous.multiplier)
			if not is_zero_approx(factor): extra.append({"id":"compatibility:"+pair[1],"source":"compatibility:direct_override","stat":pair[1],"op":"add","value":difference/factor})
	var fear: int = dragon_fear_penalty(unit)
	if fear>0: extra.append({"id":"racial:dragon_fear:accuracy","source":"racial:dragon_fear","stat":"accuracy","op":"add","value":-fear})
	if extra.is_empty(): return permanent
	return StatSources.resolve(unit,int(state.get("level",1)),item_defs,essence_defs,ancestry_defs,extra)

func stat_value(unit: Dictionary, id: String, combat: bool = true) -> float:
	var resolved: Dictionary = stat_breakdown(unit,combat)
	return float(resolved.values.get(id,StatCatalog.definitions().get(id,{}).get("default",0)))

func ability_cost(unit: Dictionary, base: int, resource: String = "soul") -> int:
	return maxi(0,ceili(float(base)*stat_value(unit,"mana_cost_multiplier" if resource=="mana" else "soul_cost_multiplier")))

func ability_cooldown(unit: Dictionary, base: int) -> int:
	return maxi(0,ceili(float(base)*stat_value(unit,"cooldown_multiplier")))

func preview_equipment(item_id: String, unit_id: String = "hero") -> Dictionary:
	var unit: Dictionary = unit_by_id(unit_id)
	var errors: Array[String] = []
	if unit.is_empty() or not item_defs.has(item_id): return {"before":{},"after":{},"delta":{},"errors":["Unknown item or character"]}
	var item: Dictionary = item_defs[item_id]
	var slot: String = str(item.get("slot",""))
	if slot.is_empty() or not unit.equipment.has(slot): return {"before":{},"after":{},"delta":{},"errors":["Item cannot be equipped"]}
	var candidate: Dictionary = unit.duplicate(true)
	candidate.equipment[slot] = item_id
	var before: Dictionary = StatSources.resolve(unit,int(state.get("level",1)),item_defs,essence_defs,ancestry_defs,StatSources.combat_modifiers(unit,item_defs))
	var after: Dictionary = StatSources.resolve(candidate,int(state.get("level",1)),item_defs,essence_defs,ancestry_defs,StatSources.combat_modifiers(candidate,item_defs))
	errors.append_array(before.errors); errors.append_array(after.errors)
	var delta: Dictionary = {}
	if errors.is_empty():
		for id: String in before.values:
			var difference: float = float(after.values[id])-float(before.values[id])
			if not is_zero_approx(difference): delta[id] = difference
	return {"before":before.values,"after":after.values,"delta":delta,"errors":errors}

func natural_recovery_tick(unit: Dictionary) -> void:
	var recovery_rate: float=maxf(0.0,stat_value(unit,"natural_recovery"))
	if active_essences(unit).has("canon_death_fiend"): recovery_rate*=stat_value(unit,"skill_power_multiplier")
	var total: float = float(unit.get("recovery_remainder",0.0))+recovery_rate
	var amount: int = floori(total+0.000000001)
	unit.recovery_remainder = clampf(total-float(amount),0.0,0.999999999)
	heal(unit,amount)

func threat_range(unit: Dictionary) -> int:
	if unit.get("role", "") == "ranged" or str(unit.get("equipment",{}).get("weapon", "")).contains("bow"): return 0
	return int(stat_value(unit,"attack_range"))

# Last audible location is saved but never grants enemy identity or current sight.
func record_noise(unit: Dictionary) -> void:
	if state.get("mode","")!="dungeon" or unit.get("hp",0)<=0: return
	unit.last_noise = {"pos":unit.pos,"time":int(state.time)}

func audible_contacts(observer: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.get("mode","")!="dungeon": return result
	var listener: Dictionary = hero() if observer.is_empty() else observer
	if listener.get("hp",0)<=0: return result
	var hearing: float = stat_value(listener,"hearing")
	var recorded: Dictionary = {}
	for unit: Dictionary in enemies():
		if unit_visible(unit) or not unit.get("last_noise") is Dictionary: continue
		var noise: Dictionary = unit.last_noise
		if Awareness.audible(state.map,listener.pos,noise,hearing,int(state.time)) and not recorded.has(pos_key(noise.pos)):
			recorded[pos_key(noise.pos)] = true
			result.append({"pos":noise.pos,"kind":"sound"})
	return result

func danger_warning(observer: Dictionary = {}) -> bool:
	if state.get("mode","")!="dungeon": return false
	var listener: Dictionary = hero() if observer.is_empty() else observer
	if listener.get("hp",0)<=0: return false
	var targets: Array = []
	for unit: Dictionary in enemies():
		if not unit_visible(unit): targets.append(unit.pos)
	for pos: Vector2i in state.map.traps+state.map.get("sewage_pits",[]):
		if not state.disarmed.has(pos_key(pos)): targets.append(pos)
	return Awareness.danger_near(state.map,listener.pos,targets,stat_value(listener,"sixth_sense"))

# Fractional recovery is accumulated rather than silently rounded away each tick.
func recover_resource(unit: Dictionary, resource: String) -> void:
	var key: String = "energy" if resource=="soul" else "mana"
	var maximum: String = "max_energy" if resource=="soul" else "max_mana"
	var carry: String = resource+"_recovery_remainder"
	if int(unit.get(key,0))>=int(unit.get(maximum,0)):
		unit.erase(carry)
		return
	var total: float = float(unit.get(carry,0.0))+maxf(0.0,stat_value(unit,resource+"_recovery"))
	var amount: int = floori(total+0.000000001)
	unit[carry] = clampf(total-float(amount),0.0,0.999999999)
	unit[key] = mini(int(unit.get(maximum,0)),int(unit.get(key,0))+amount)
	if int(unit[key])>=int(unit[maximum]): unit.erase(carry)

func attachment_loss(unit: Dictionary) -> void:
	var duration: int = StatMentalRules.attachment_duration(stat_breakdown(unit).values)
	if duration>0: status(unit,"distressed",duration)

func form_spirit_contract(unit_id: String = "hero") -> String:
	return SpiritRules.form_contract(self,unit_id)
func toggle_spirit_light(unit_id: String = "hero") -> String:
	return SpiritRules.toggle(self,unit_id)
func rest_spirit(unit_id: String = "hero") -> String:
	return SpiritRules.rest(self,unit_id)

func jump_range(unit: Dictionary) -> int:
	return StatPhysiology.jump_range(stat_value(unit,"jumping_power"),stat_value(unit,"leg_power"))

func jump_error(destination: Vector2i, actor: Dictionary = {}) -> String:
	if ThirdFloorRules.in_refuge(self): return "Leave the refuge before jumping."
	if state.get("mode","")!="dungeon": return "Jump inside the Labyrinth."
	var unit: Dictionary = (selected() if state.combat else hero()) if actor.is_empty() else actor
	if unit.hp<=0 or unable_to_act(unit): return "Cannot jump while restrained or fallen."
	if state.combat and int(unit.ap)<2*int(stat_value(unit,"movement_cost")): return "Need two movement actions to jump."
	if distance(unit.pos,destination)<1 or distance(unit.pos,destination)>jump_range(unit): return "Outside jump range."
	if not visible(destination) or not valid_move(unit,destination): return "Landing must be visible and unoccupied."
	if not DungeonWorld.line_of_sight(state.map,unit.pos,destination): return "Walls block the jump."
	return ""

func jump(destination: Vector2i) -> bool:
	var failure: String = jump_error(destination)
	if not failure.is_empty(): say(failure); return false
	var unit: Dictionary = selected() if state.combat else hero()
	var origin: Vector2i = unit.pos
	if state.combat:
		for enemy: Dictionary in enemies():
			var threat: int = threat_range(enemy)
			if threat>0 and distance(enemy.pos,origin)<=threat and distance(enemy.pos,destination)>threat and not enemy.get("reacted",false) and not unable_to_act(enemy):
				enemy.reacted = true
				hit(enemy,unit,maxi(1,int(stat_value(enemy,"attack"))/2),RacialProgression.weapon_damage_type(enemy),"Opportunity",true,false,-1,{"attack_resolved":true,"category":"weapon"})
				if unit.hp<=0: return true
		unit.ap -= 2*int(stat_value(unit,"movement_cost"))
	unit.pos = destination
	unit.statuses.erase("concealed"); unit.statuses.erase("stealth")
	if not state.combat:
		var follow: Vector2i = origin
		for ally: Dictionary in state.party:
			if ally.hp<=0: continue
			var old: Vector2i = ally.pos
			ally.pos = follow if valid_move(ally,follow) else nearest_free(origin)
			follow = old
	step_hazards(unit)
	cue.emit("move"); say("%s jumps %d tiles." % [unit.name,distance(origin,destination)])
	advance_time(2); update_visibility(); auto_end_if_spent()
	return true

func breath_capacity(unit: Dictionary) -> float:
	return StatPhysiology.breath_duration(stat_value(unit,"lung_capacity"))

func advance_breath(minutes: int) -> void:
	for unit: Dictionary in allies()+enemies():
		if unit.hp<=0: continue
		var capacity: float = breath_capacity(unit)
		if DungeonWorld.tile_at(state.map,unit.pos)!=DungeonWorld.HAZARD:
			unit.erase("breath_remaining"); continue
		var available: float = minf(capacity,float(unit.get("breath_remaining",capacity)))
		var exposure: float = maxf(0.0,float(minutes)*60.0-available)
		unit.breath_remaining = maxf(0.0,available-float(minutes)*60.0)
		if exposure>0:
			hit({"name":"Choking mist","accuracy":100,"statuses":{}},unit,ceili(exposure/60.0)*3,"poison","Choking mist",false,true,-1,{"dot":true})
			if state.mode!="dungeon": return

func attempt_spirit_stone(unit_id: String = "hero") -> String:
	return SpiritStones.attempt(self,unit_id)
func toggle_wind_guidance(unit_id: String = "hero") -> String:
	return SpiritStones.toggle(self,unit_id)

func enter_homeland(ancestry: String) -> String:
	return HomelandRules.enter(self,ancestry)
func leave_homeland() -> String:
	return HomelandRules.leave(self)
func select_homeland_actor(unit_id: String) -> String:
	return HomelandRules.select_actor(self,unit_id)

func homeland_position() -> Vector2i:
	var location: String = str(state.get("homeland",{}).get("location",""))
	var layout: Dictionary = HomelandMap.layout_for(location)
	return state.get("homeland",{}).get("positions",{}).get(location,layout.entrance)

func record_homeland_position(position: Vector2i) -> bool:
	if state.get("mode","")!="city" or not state.get("homeland") is Dictionary: return false
	var location: String = str(state.homeland.get("location",""))
	if not HomelandCatalog.definitions().has(location): return false
	var layout: Dictionary = HomelandMap.layout_for(location)
	if not layout.walkable.has(position) or position==layout.exit: return false
	for point: Dictionary in layout.interactables:
		if point.cell==position: return false
	if not state.homeland.has("positions"): state.homeland["positions"]={}
	state.homeland.positions[location]=position
	return true

func _homeland_point_near(point_id: String) -> bool:
	var location: String = str(state.get("homeland",{}).get("location",""))
	if not HomelandCatalog.definitions().has(location): return false
	var layout: Dictionary = HomelandMap.layout_for(location)
	var position: Vector2i = homeland_position()
	for point: Dictionary in layout.interactables:
		if point.id==point_id: return distance(position,point.cell)<=1
	return false

func homeland_interact(point_id: String, unit_id: String = "hero") -> Dictionary:
	if not _homeland_point_near(point_id): return {"ok":false,"message":"Move next to the person or landmark."}
	return HomelandRules.interact(self,point_id,unit_id)

func homeland_perform(action: String, unit_id: String, point_id: String, choice_id: String = "") -> Dictionary:
	if not _homeland_point_near(point_id): return {"ok":false,"message":"The participant is no longer near this activity."}
	return HomelandRules.perform(self,action,unit_id,point_id,choice_id)

func portal_choices() -> Array[int]:
	return FloorConnections.choices(self)

func collect_corpse_flower() -> String:
	return EarlyFloorRules.collect_flower(self)

func topple_target(target_id: String) -> String:
	if ThirdFloorRules.in_refuge(self): return "Leave the refuge before attacking."
	var failure: String=EarlyMonsterRules.topple(self,target_id)
	if not failure.is_empty(): return failure
	advance_time(2); update_visibility(); auto_end_if_spent()
	return ""

func enter_witch_hut() -> String:
	var result: String=ThirdFloorRules.interact_hut(self)
	if result.is_empty(): state.combat=false
	return result

func prune_summons() -> void:
	# Only temporary summoned entities are recyclable; ordinary death records and
	# species rewards stay intact. Stable entity_serial prevents ID reuse.
	state.units=state.get("units",[]).filter(func(unit: Dictionary)->bool:return not unit.get("summon",false) or int(unit.hp)>0)
	if str(state.get("selected","hero"))!="hero" and unit_by_id(str(state.selected)).is_empty(): state.selected="hero"

func leave_witch_hut() -> String:
	if not ThirdFloorRules.in_refuge(self): return "The refuge has already faded."
	state["hut_until"]=0
	ThirdFloorRules.apply_environment(self)
	say("Left the Witch’s Cabin.")
	return ""
