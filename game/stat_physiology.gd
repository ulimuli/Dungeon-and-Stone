class_name StatPhysiology
extends RefCounted
## Pure mappings of resolved raw points to sourced or explicitly provisional effects.
## Every coefficient, cap, tile and second below is a gameplay estimate.
## Zero raw points preserve the existing engine baseline exactly.
## Context helpers neither grant actions/contracts nor reveal a map/target.

const WEIGHT_SOURCE: String = "https://noveltune.net/book/surviving-the-game-as-a-barbarian-2/31.html"
const SOUL_SOURCE: String = "https://noveltune.net/book/surviving-the-game-as-a-barbarian-2/22.html"
const RECOVERY_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-383/"
const NATURAL_SOURCE: String = "https://martialrealm.com/novel/sgb/chapter-19-20-21/"
const SOUL_REGENERATION_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Spirit_Imprint"
const SENSE_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-625/"
const HEARING_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-244/"
const BREATH_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-324/"
const JUMP_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-228/"
const DENSITY_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-446/"
const ENERGY_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-463/"
const NAMED_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence"
const MAX_ABSOLUTE_POINTS: float = 1000000.0
const REGENERATION_PER_POINT: float = 0.01
const SOUL_CAPACITY_PER_POINT: float = 1.0
const SOUL_REGENERATION_PER_POINT: float = 0.01
const WEIGHT_DAMAGE_PER_POINT: float = 0.005
const MIN_WEIGHT_FACTOR: float = 0.25
const MAX_WEIGHT_FACTOR: float = 4.0
const HEARING_POINTS_PER_TILE: float = 20.0
const MAX_EXTRA_HEARING_TILES: int = 8
const JUMP_DISTANCE_PER_POINT: float = 0.01
const BREATH_DURATION_PER_POINT: float = 0.01
const MAX_DURATION_FACTOR: float = 100.0
## Provisional qualitative mappings authorized by the user; these are not novel formulas.
const ENDURANCE_HEALTH_PER_POINT: float = 1.0
const BONE_STRENGTH_ARMOR_PER_POINT: float = 0.05
const BONE_DENSITY_ARMOR_PER_POINT: float = 0.025
const BONE_DENSITY_WEIGHT_PER_POINT: float = 0.2
const BONE_DENSITY_HEIGHT_PER_POINT: float = -0.2
const BASE_HEIGHT: float = 180.0
const HEIGHT_PER_RANGE_TILE: float = 120.0
const APPETITE_HUNGER_PER_POINT: float = 0.02
const ABSORPTION_HEALING_PER_POINT: float = 0.005

static func morphology_modifiers(values: Dictionary) -> Array:
	# Resolve these against raw stats FIRST, then pass the resulting values to
	# derived_modifiers. Keeping this pass separate avoids stale Height/Weight.
	# Bone Strength and Bone Density remain independent provisional domains;
	# translations do not establish their equivalence or these conversions.
	var density: float = _points(values.get("bone_density",0))
	if density == 0: return []
	return [_modifier("bone_density","weight","add",density*BONE_DENSITY_WEIGHT_PER_POINT),_modifier("bone_density","height","add",density*BONE_DENSITY_HEIGHT_PER_POINT)]

static func derived_modifiers(values: Dictionary) -> Array:
	var rows: Array = []
	var regeneration: float = _points(values.get("natural_regeneration",0))
	if regeneration != 0:
		rows.append(_modifier("natural_regeneration","natural_recovery","multiply",_factor(regeneration,REGENERATION_PER_POINT)))
	var soul: float = _points(values.get("soul_power",0))
	if soul != 0: rows.append(_modifier("soul_power","max_soul_power","add",soul*SOUL_CAPACITY_PER_POINT))
	var soul_regeneration: float = _points(values.get("soul_regeneration",0))
	if soul_regeneration != 0:
		rows.append(_modifier("soul_regeneration","soul_recovery","multiply",_factor(soul_regeneration,SOUL_REGENERATION_PER_POINT)))
	for mapping: Array in [["endurance","max_health",ENDURANCE_HEALTH_PER_POINT],["bone_strength","armor",BONE_STRENGTH_ARMOR_PER_POINT],["bone_density","armor",BONE_DENSITY_ARMOR_PER_POINT]]:
		var points: float = _points(values.get(mapping[0],0))
		if points != 0: rows.append(_modifier(mapping[0],mapping[1],"add",points*float(mapping[2])))
	var height: float = _points(values.get("height",BASE_HEIGHT))
	var reach: int = floori(maxf(0.0,height-BASE_HEIGHT)/HEIGHT_PER_RANGE_TILE)
	if reach > 0: rows.append(_modifier("height","attack_range","add",float(reach)))
	var absorption: float = _points(values.get("absorption",0))
	if absorption != 0:
		rows.append(_modifier("absorption","healing_received_multiplier","multiply",healing_received_multiplier(absorption)))
	return rows

static func _modifier(raw_stat: String, target_stat: String, operation: String, amount: float) -> Dictionary:
	return {"id":"derived:physiology:"+raw_stat+":"+target_stat,"source":"derived:physiology:"+raw_stat,"stat":target_stat,"op":operation,"value":amount}

static func hearing_radius(points: Variant) -> int:
	# Extra audible-contact radius only. Caller must supply an actual sound and
	# enforce sound propagation; this is not vision or hidden-trap detection.
	return mini(MAX_EXTRA_HEARING_TILES,floori(maxf(0.0,_points(points))/HEARING_POINTS_PER_TILE))

static func jump_distance(points: Variant, base_distance: float = 1.0) -> float:
	# A scaling helper for an independently available jump action. Raw points
	# never grant Leap, collision bypass, terrain immunity or a new action.
	return _positive(base_distance)*_factor(_points(points),JUMP_DISTANCE_PER_POINT)

static func jump_range(points: Variant, leg_power: Variant = 0) -> int:
	# Generic utility-jump range only. Does not grant the essence active Leap,
	# its multiplier, its shockwave, or any terrain immunity.
	return clampi(floori(2.0*(1.0+_points(points)/100.0)+_points(leg_power)/50.0),1,6)

static func hunger_rate(points: Variant) -> float:
	return clampf(1.0+_points(points)*APPETITE_HUNGER_PER_POINT,0.25,20.0)

static func healing_received_multiplier(absorption: Variant) -> float:
	# Provisional uptake of healing only; never adds essence slots.
	return clampf(1.0+_points(absorption)*ABSORPTION_HEALING_PER_POINT,0.25,4.0)

static func blunt_damage_multiplier(weight: Variant) -> float:
	return clampf(1.0+_points(weight)*WEIGHT_DAMAGE_PER_POINT,MIN_WEIGHT_FACTOR,MAX_WEIGHT_FACTOR)

static func knockback_reduction(weight: Variant) -> float:
	# Fraction of an already resolved push distance resisted, not immunity.
	var factor: float = maxf(1.0,blunt_damage_multiplier(weight))
	return 1.0-1.0/factor

static func breath_duration(lung_capacity: Variant, base_seconds: float = 60.0) -> float:
	# Duration only; never grants underwater breathing or smoke immunity.
	return _positive(base_seconds)*_factor(_points(lung_capacity),BREATH_DURATION_PER_POINT)

static func breath_damage_multiplier(lung_capacity: Variant) -> float:
	# Apply only to an explicitly identified breathing hazard, never to all
	# poison damage. Positive capacity buys time; it never grants immunity.
	var points: float = _points(lung_capacity)
	if points >= 0: return 100.0/(100.0+points)
	return minf(4.0,1.0-points/100.0)

static func soul_recovery_rate(total_pool: float, baseline_pool: float = 12.0, baseline_rate: float = 1.0, soul_regeneration: Variant = 0) -> float:
	# Optional proportional-pool model from chapter383. Caller must choose this
	# OR the derived Soul Regeneration multiplier, never apply both twice.
	if not is_finite(baseline_pool) or baseline_pool <= 0: return 0.0
	return _positive(baseline_rate)*_positive(total_pool)/baseline_pool*_factor(_points(soul_regeneration),SOUL_REGENERATION_PER_POINT)

static func natural_energy_available(points: Variant, has_spirit_contract: bool = false) -> float:
	# One point per resource unit is an estimate. This gate requires an existing
	# contract; it does not supply a first contract or give every Fairy a spirit.
	return natural_energy_capacity(points) if has_spirit_contract else 0.0

static func natural_energy_capacity(points: Variant) -> float:
	# Capacity exists independently of permission to cast Spirit Magic.
	return maxf(0.0,_points(points))

static func support_metadata() -> Dictionary:
	# Helper availability is distinct from live Simulation integration.
	return {
		"endurance":_provisional("Increases maximum health without healing current health.","derived_modifiers",[NAMED_SOURCE],"derived_modifier_ready","Named stat; maximum-health mapping is provisional.","+1 maximum health per point"),
		"bone_strength":_provisional("Contributes independently to flat armor.","derived_modifiers",[WEIGHT_SOURCE,NAMED_SOURCE],"derived_modifier_ready","Translation ambiguity remains; this domain is not equated with Bone Density.","+0.05 armor per point"),
		"bone_density":_provisional("Contributes flat armor, body weight, and reduced height.","morphology_modifiers / derived_modifiers",[WEIGHT_SOURCE,DENSITY_SOURCE],"derived_modifier_ready","Density/height morphology is observed; general armor, weight and height conversions are provisional.","+0.025 armor, +0.2 weight and -0.2 height per point; morphology resolves before other derived stats"),
		"height":_provisional("Very large stature increases ordinary attack reach.","derived_modifiers",[HEARING_SOURCE,DENSITY_SOURCE],"derived_modifier_ready","Growth context supports size changes; ordinary-attack reach mapping is provisional.","base height180; +floor(max(0,height-180)/120) attack range"),
		"hearing":_supported("Audible sounds become clearer; hearing can locate attacks through smoke.","hearing_radius",[SENSE_SOURCE,HEARING_SOURCE],"context_helper_only"),
		"jumping_power":_provisional("Increases generic jump distance; does not grant essence Leap.","jump_distance / jump_range",[SENSE_SOURCE,JUMP_SOURCE],"context_helper_only","Jumping capability is sourced; generic utility-jump action and grid formula are provisional.","jump range clamp(floor(2*(1+jumping_power/100)+leg_power/50),1,6)"),
		"leg_power":_provisional("Adds to generic utility-jump range.","jump_range",[NAMED_SOURCE],"context_helper_only","Named stat; jump contribution is provisional.","+1 tile per50 points before final rounding/caps"),
		"lung_capacity":_provisional("Supports breath holding and reduces damage in an explicit breathing-hazard context.","breath_duration / breath_damage_multiplier",[BREATH_SOURCE],"context_helper_only","Breath holding is sourced; breathing-hazard damage conversion is provisional.","nonnegative points:100/(100+points); negative points:min(4,1-points/100)"),
		"natural_regeneration":_supported("Supports natural health regeneration.","derived_modifiers",[NATURAL_SOURCE],"derived_modifier_ready"),
		"soul_power":_supported("Soul Power supplies the resource used by essence abilities; increasing it expands the pool.","derived_modifiers",[SOUL_SOURCE,RECOVERY_SOURCE],"derived_modifier_ready"),
		"soul_regeneration":_supported("Soul regeneration concerns restoration of Soul Power; timing and coefficients are estimated.","derived_modifiers",[RECOVERY_SOURCE,SOUL_REGENERATION_SOURCE],"derived_modifier_ready"),
		"weight":_supported("Body Weight affects knockback and blunt damage; it is separate from carried inventory weight.","blunt_damage_multiplier / knockback_reduction",[WEIGHT_SOURCE],"context_helper_only"),
		"appetite":_provisional("Scales food consumption rate.","hunger_rate",[WEIGHT_SOURCE],"context_helper_only","Named and described as insignificant; food-consumption mapping is provisional.","clamp(1+points*0.02,0.25,20)"),
		"absorption":_provisional("Scales healing received; never increases essence slots.","derived_modifiers / healing_received_multiplier",[NAMED_SOURCE],"derived_modifier_ready","Named stat; uptake of healing is a provisional interpretation.","clamp(1+points*0.005,0.25,4)"),
		"natural_energy":_provisional("Supplies resource capacity; Spirit Magic still requires an existing spirit contract.","natural_energy_capacity / natural_energy_available",[ENERGY_SOURCE],"locked_context_helper_only","Spirit resource use is sourced; first-contract acquisition remains unknown and capacity units are estimated.","max(0,points) capacity; no resource regeneration or contract grant")
	}

static func _provisional(effect: String, helper: String, sources: Array, status: String, uncertainty: String, formula: String) -> Dictionary:
	var row: Dictionary = _supported(effect,helper,sources,status)
	row.qualitative_estimate = true
	row.estimate_authorization = "User authorized logical provisional qualitative effects where unspecified."
	row.unknown_reason = uncertainty
	row.estimated_formula = formula
	return row

static func _supported(effect: String, helper: String, sources: Array, status: String) -> Dictionary:
	return {"qualitative_effect":effect,"helper_available":true,"helper":helper,"integration_status":status,"numerical_estimate":true,"qualitative_estimate":false,"reference_urls":sources}

static func _unknown(reason: String, sources: Array) -> Dictionary:
	return {"qualitative_effect":"","helper_available":false,"unknown_reason":reason,"integration_status":"research_only","numerical_estimate":false,"reference_urls":sources}

static func _points(value: Variant) -> float:
	if not (value is int or value is float) or not is_finite(float(value)): return 0.0
	return clampf(float(value),-MAX_ABSOLUTE_POINTS,MAX_ABSOLUTE_POINTS)

static func _positive(value: float) -> float:
	return maxf(0.0,value) if is_finite(value) else 0.0

static func _factor(points: float, coefficient: float) -> float:
	return clampf(1.0+points*coefficient,0.0,MAX_DURATION_FACTOR)
