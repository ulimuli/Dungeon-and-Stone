class_name StatSources
extends RefCounted
## Shared data adapters. Canonical modifiers are {stat,op,value}; stable IDs and
## provenance are supplied by the source that owns the modifier. Unit-authored
## saved modifiers additionally supply their own globally unique id/source.
const ATTRIBUTES: Array[String] = ["strength","agility","wit","vigor"]
const SENSES: Array[String] = ["muscle_mass","flexibility","vision","smell","natural_regeneration","soul_power","soul_regeneration","luck","endurance","bone_strength","bone_density","weight","height","leg_power","lung_capacity","jumping_power","absorption","appetite","perception","cognition","cognitive_interference","dexterity","obsession","impulse","distrust","possessiveness","fighting_spirit","mana_sensitivity"]
const INDICES: Array[String] = ["body_index","mind_index","ability_index","combat_index"]
const LEGACY_ITEM: Dictionary = {"power":"attack","armor":"armor","accuracy":"accuracy","evasion":"evasion","carry_bonus":"carry_bonus"}
const DAMAGE_KINDS: Array[String] = ["physical","fire","cold","poison","dark","mana","ground","solar","lightning"]

static func decorate_item(item: Dictionary) -> Dictionary:
	var result: Dictionary = item.duplicate(true)
	if not result.has("modifiers"):
		result.modifiers = []
		for key: String in LEGACY_ITEM:
			if result.has(key) and float(result[key]) != 0: result.modifiers.append({"stat":LEGACY_ITEM[key],"op":"add","value":result[key]})
	if not result.has("base_stats"): result.base_stats = {}
	if result.get("kind", "") == "weapon" and not result.base_stats.has("attack_range"): result.base_stats.attack_range = result.get("range",1)
	# Read-only compatibility views for existing UI. Modifier data is authoritative.
	for key: String in LEGACY_ITEM:
		var value: float = 0.0
		for modifier: Dictionary in result.modifiers:
			if modifier.get("stat", "") == LEGACY_ITEM[key] and modifier.get("op", "add") == "add": value += float(modifier.get("value",0))
		result[key] = value
	if result.base_stats.has("attack_range"): result.range = int(result.base_stats.attack_range)
	return result

static func content_modifiers(rows: Variant, prefix: String, source: String, condition: float = 1.0) -> Array:
	if not rows is Array: return [{"id":prefix,"source":source,"stat":"","op":"invalid","value":0}]
	var result: Array = []
	for index: int in range(rows.size()):
		var row: Variant = rows[index]
		if not row is Dictionary:
			result.append({"id":prefix+":"+str(index),"source":source,"stat":"","op":"invalid","value":0}); continue
		var value: Variant = row.get("value")
		if row.get("stat", "") in ["attack","armor"] and row.get("op", "add") == "add" and not is_equal_approx(condition,1.0) and (value is int or value is float): value = int(float(value)*condition)
		result.append({"id":prefix+":"+str(row.get("id",index)),"source":source,"stat":row.get("stat", ""),"op":row.get("op","add"),"value":value})
	return result

static func modifiers(unit: Dictionary, items: Dictionary, essences: Dictionary, ancestries: Dictionary) -> Array:
	var result: Array = []
	var equipment: Dictionary = unit.get("equipment", {})
	for slot: String in equipment:
		var id: String = str(equipment[slot])
		if not items.has(id): continue
		result.append_array(content_modifiers(items[id].get("modifiers",[]),"item:"+slot+":"+id,"item:"+id,1.0 if int(unit.get("durability",100)) > 0 else 0.5))
	# Attribute bonuses survive skill sealing. A ring disables effects, not stats.
	for id: String in unit.get("essences",[]):
		if essences.has(id):
			var rows: Array=content_modifiers(essences[id].get("modifiers",[]),"essence:"+id,"essence:"+id)
			for row: Dictionary in rows:
				# Earth scales the signed, flat essence attribute package only.
				if row.op=="add" and (row.value is int or row.value is float): row.value=float(row.value)*DragonBlessingRules.essence_scale(unit)
			result.append_array(rows)
			var sealed: bool=unit.get("equipment",{}).get("charm","")=="frost_spirit_ring" and unit.get("ring_sealed_essence","")==id
			if not sealed: result.append_array(content_modifiers(essences[id].get("passive_modifiers",[]),"essence_skill:"+id,"essence_skill:"+id))
	var ancestry: String = str(unit.get("ancestry", ""))
	result.append_array(content_modifiers(ancestries.get(ancestry,{}).get("modifiers",[]),"ancestry:"+ancestry,"ancestry:"+ancestry))
	if RacialRules.has_skadia(unit):
		result.append({"id":"racial:skadia:attack","source":"racial:skadia","stat":"attack","op":"add","value":RacialRules.STRENGTHENING_POWER_ESTIMATE})
		result.append({"id":"racial:skadia:evasion","source":"racial:skadia","stat":"evasion","op":"add","value":RacialRules.STRENGTHENING_EVASION_ESTIMATE})
	result.append_array(DragonBlessingRules.derived_modifiers(unit))
	var recovery: int = RacialRules.natural_heal_bonus(unit)
	if recovery > 0: result.append({"id":"racial:undying:recovery","source":"racial:undying","stat":"natural_recovery","op":"add","value":recovery})
	if unit.get("modifiers",[]) is Array: result.append_array(unit.get("modifiers",[]).duplicate(true))
	else: result.append({"id":"unit:invalid","source":"unit","stat":"","op":"invalid","value":0})
	return result

static func _subset(ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ids: result[id] = StatCatalog.definitions()[id]
	return result

static func _filter(mods: Array, ids: Array, include: bool = true) -> Array:
	return mods.filter(func(row: Dictionary) -> bool: return ids.has(row.stat) == include)

static func resolve(unit: Dictionary, level: int, items: Dictionary, essences: Dictionary, ancestries: Dictionary, extra: Array = []) -> Dictionary:
	var registry: Dictionary = StatCatalog.definitions()
	var mods: Array = modifiers(unit,items,essences,ancestries)
	mods.append_array(extra)
	var errors: Array[String] = StatRules.validate_modifiers(mods,registry)
	var intrinsic: Variant = unit.get("base_stats",{})
	if not intrinsic is Dictionary: errors.append("base_stats must be a dictionary")
	else:
		for id: Variant in intrinsic:
			if not registry.has(id) or not (intrinsic[id] is int or intrinsic[id] is float) or not is_finite(float(intrinsic[id])): errors.append("Invalid base stat: "+str(id))
	if not errors.is_empty(): return {"values":{},"breakdown":{},"errors":errors}
	var base: Dictionary = intrinsic.duplicate(true)
	var senses_base: Dictionary = {}
	for id: String in SENSES: senses_base[id] = base.get(id,registry[id].default)
	var senses: Dictionary = StatRules.evaluate(senses_base,_filter(mods,SENSES),_subset(SENSES))
	if not senses.errors.is_empty(): return senses
	var morphology: Array = StatPhysiology.morphology_modifiers(senses.values)
	if not morphology.is_empty():
		var raw_mods: Array = _filter(mods,SENSES)
		raw_mods.append_array(morphology)
		senses = StatRules.evaluate(senses_base,raw_mods,_subset(SENSES))
		if not senses.errors.is_empty(): return senses
	var primary_base: Dictionary = {"strength":base.get("strength",unit.get("str",4)),"agility":base.get("agility",unit.get("agi",4)),"wit":base.get("wit",unit.get("wit",4)),"vigor":base.get("vigor",unit.get("vig",4))}
	var primary_mods: Array = _filter(mods,ATTRIBUTES)
	if float(senses.values.muscle_mass) != 0: primary_mods.append({"id":"derived:muscle_mass","source":"derived:muscle_mass","stat":"strength","op":"multiply","value":1.0+float(senses.values.muscle_mass)*0.01})
	var primary: Dictionary = StatRules.evaluate(primary_base,primary_mods,_subset(ATTRIBUTES))
	if not primary.errors.is_empty(): return primary
	var a: Dictionary = primary.values
	var enemy: bool = unit.get("team", "ally") == "enemy"
	var derived: Dictionary = {
		"attack":unit.get("power",6) if enemy else int(unit.get("base_power",2))+int(a.strength),
		"armor":unit.get("armor",0) if enemy else unit.get("base_armor",0),
		"accuracy":unit.get("accuracy",85) if enemy else 78+int(a.agility)*2,
		"evasion":unit.get("evasion",4) if enemy else int(a.agility)*2+floorf(float(senses.values.flexibility)*0.5),
		"max_health":unit.get("max_hp",24) if enemy else maxi(12,int(unit.get("base_hp",24))+int(a.vigor)*4-int(unit.get("injuries",0))*5),
		"max_soul_power":unit.get("max_energy",12) if enemy else 6+int(a.wit)*2+(10 if level>=2 and unit.get("profession","explorer")!="mage" else 0),
		"max_mana":unit.get("max_mana",0) if enemy else (6+int(a.wit)*2 if not unit.get("spells",[]).is_empty() else 0),
		"attack_range":unit.get("range",1) if enemy else 1,
		"sight":9 if enemy else 6+int(a.wit)/3+floorf(float(senses.values.vision)/10.0),
		"carry_bonus":0,"carry_capacity":int(a.strength)*2,"initiative":a.agility,
		"action_points":3 if int(a.agility)>=8 else 2
	}
	if not enemy:
		var weapon: Dictionary = items.get(str(unit.get("equipment",{}).get("weapon","")),{})
		derived.attack_range = int(weapon.get("base_stats",{}).get("attack_range",weapon.get("range",1)))
		if int(derived.attack_range)>1: derived.attack_range += floorf(float(senses.values.vision)/20.0)
	for kind: String in DAMAGE_KINDS:
		if registry.has(kind+"_damage_reduction"): derived[kind+"_damage_reduction"] = unit.get("resist",{}).get(kind,0)
	# Explicit canonical intrinsic values override compatibility baselines.
	derived.merge(base,true)
	for id: String in ATTRIBUTES: derived[id] = a[id]
	var secondary_mods: Array = _filter(_filter(mods,ATTRIBUTES,false),INDICES,false)
	secondary_mods.append_array(morphology)
	secondary_mods.append_array(StatPhysiology.derived_modifiers(senses.values))
	secondary_mods.append_array(StatMentalRules.derived_modifiers(senses.values))
	if float(senses.values.mana_sensitivity)!=0: secondary_mods.append({"id":"derived:mana_sensitivity:spell_damage_multiplier","source":"derived:mana_sensitivity","stat":"spell_damage_multiplier","op":"multiply","value":StatCombatRules.mana_sensitivity_multiplier(float(senses.values.mana_sensitivity))})
	if float(senses.values.flexibility)!=0: secondary_mods.append({"id":"derived:flexibility:critical_chance","source":"derived:flexibility","stat":"critical_chance","op":"add","value":float(senses.values.flexibility)*0.1})
	var resolved: Dictionary = StatRules.evaluate(derived,secondary_mods,registry)
	if not resolved.errors.is_empty(): return resolved
	for id: String in ATTRIBUTES: resolved.breakdown[id] = primary.breakdown[id]
	var totals: Dictionary = StatIndices.resolve(resolved.values,registry)
	if not totals.errors.is_empty(): return totals
	var group_ids: Array = ["body_index","mind_index","ability_index"]
	var group_base: Dictionary = {}
	for id: String in group_ids: group_base[id] = totals.values[id]
	var grouped: Dictionary = StatRules.evaluate(group_base,_filter(mods,group_ids),_subset(group_ids))
	if not grouped.errors.is_empty(): return grouped
	var combat_base: float = float(totals.values.combat_index)
	for id: String in group_ids: combat_base += float(grouped.values[id])-float(totals.values[id])
	var combined: Dictionary = StatRules.evaluate({"combat_index":combat_base},_filter(mods,["combat_index"]),_subset(["combat_index"]))
	if not combined.errors.is_empty(): return combined
	for id: String in INDICES:
		var index_final: Dictionary = combined if id=="combat_index" else grouped
		resolved.values[id] = index_final.values[id]
		resolved.breakdown[id] = index_final.breakdown[id]
		resolved.breakdown[id].sources = totals.breakdown[id].get("sources",[])+index_final.breakdown[id].get("sources",[])
	return resolved

static func combat_modifiers(unit: Dictionary, items: Dictionary = {}) -> Array:
	var result: Array = []
	var statuses: Dictionary = unit.get("statuses",{})
	# Frenzy's resistance multiplier is sourced (novel51). Field-to-stat
	# conversions are explicit tactical estimates, not quoted novel numbers.
	if statuses.has("frenzy"): result.append({"id":"status:frenzy:physical_resistance","source":"status:frenzy","stat":"physical_resistance","op":"multiply","value":3.0})
	for field: Array in [["field_disoriented","perception",-10],["field_hallucinations","cognition",-10],["field_pain","pain_resistance",-50]]:
		if statuses.has(field[0]): result.append({"id":"status:"+str(field[0])+":"+str(field[1]),"source":"status:"+str(field[0])+":estimate","stat":field[1],"op":"add","value":field[2]})
	var wind: int = SpiritStones.attack_bonus(unit,items)
	if wind>0: result.append({"id":"spirit:wind:accuracy","source":"spirit:wind","stat":"accuracy","op":"add","value":wind})
	if statuses.has("pained"):
		result.append({"id":"status:pained:accuracy","source":"status:pained","stat":"accuracy","op":"multiply","value":0.9})
		result.append({"id":"status:pained:movement","source":"status:pained","stat":"movement_cost","op":"add","value":1})
	if statuses.has("distressed"):
		for resource: String in ["soul_recovery","mana_recovery"]: result.append({"id":"status:distressed:"+resource,"source":"status:distressed","stat":resource,"op":"multiply","value":0.5})
	if statuses.has("weakened"): result.append({"id":"status:weakened","source":"status:weakened","stat":"attack","op":"multiply","value":0.75})
	if statuses.has("transformed"): result.append({"id":"status:transformed","source":"status:transformed","stat":"attack","op":"add","value":unit.get("status_power",{}).get("transformed",5)})
	if statuses.has("frightened"): result.append({"id":"status:frightened","source":"status:frightened","stat":"accuracy","op":"add","value":-20})
	if statuses.has("marked"): result.append({"id":"status:marked","source":"status:marked","stat":"evasion","op":"add","value":-15})
	if statuses.has("ward"): result.append({"id":"status:ward","source":"status:ward","stat":"armor","op":"add","value":unit.get("status_power",{}).get("ward",4)})
	if unit.get("guard",false): result.append({"id":"stance:guard","source":"stance:guard","stat":"armor","op":"add","value":4})
	if statuses.has("chilled"): result.append({"id":"status:chilled","source":"status:chilled","stat":"action_points","op":"add","value":-1})
	if statuses.has("poison"): result.append({"id":"status:poison:recovery","source":"status:poison","stat":"soul_recovery","op":"multiply","value":0})
	if statuses.has("stunned") or statuses.has("paralyzed") or statuses.has("suppressed") or statuses.has("toppled"): result.append({"id":"status:incapacitated","source":"status:incapacitated","stat":"action_points","op":"multiply","value":0})
	return result

static func percent_from_points(points: float) -> float:
	# Explicit numerical estimate, not a sourced novel resistance formula.
	return 100.0*points/(100.0+absf(points))
