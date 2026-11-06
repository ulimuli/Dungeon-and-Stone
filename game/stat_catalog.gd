class_name StatCatalog
extends RefCounted
## Shared names, numeric domains and legacy adapters for consumed statistics.
## Implemented means the simulation adapter consumes the stat, not that the
## formula is an exact novel rule. All current defaults, bounds, rounding and
## reconstruction formulas are experimental. Provisional qualitative mechanics
## are explicitly disclosed; informational indices never directly buff damage.
## This is a selected catalog, not an exhaustive list of the novel's stats.
const STATS_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-463"
const ESSENCE_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Essences"
const MUSCLE_SOURCE: String = "https://hennoveltranslations.org/episodes/stgb-episode-337/"
const ARCHER_SOURCE: String = "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
const HEIGHT_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-446"
const ROUNDING_MODES: Array[String] = ["floor","ceil","nearest","none"]
static var _entries: Dictionary = {}

static func definitions() -> Dictionary:
	if _entries.is_empty(): _entries = _build()
	return _entries

static func _row(display_name: String, description: String, initial: float, low: float, high: float, rounding: String, aliases: Array, note: String, sources: Array = [STATS_SOURCE], implemented: bool = true) -> Dictionary:
	return {"name":display_name,"description":description,"default":initial,"min":low,"max":high,"rounding":rounding,"aliases":aliases,"implemented":implemented,"formula_note":note,"reference_urls":sources,"experimental_balance":true,"source_status":"reconstruction" if implemented else "novel_stat_research"}

static func _build() -> Dictionary:
	var rows: Dictionary = {
		"strength": _row("Strength","Physical strength used by attack and carrying calculations.",4,0,1000000,"floor",["str"],"Current estimate: contributes one Attack and two carrying units per Strength; racial starting values vary."),
		"agility": _row("Agility","Agility used by accuracy and evasion calculations.",4,0,1000000,"floor",["agi"],"Current estimate: Accuracy78+2×Agility; Evasion2×Agility. Initiative has its own resolved stat."),
		"wit": _row("Wit","Reconstruction attribute used for resource pools and sight.",4,0,1000000,"floor",[],"Current estimate: resource pools6+2×Wit; sight6+floor(Wit/3). This four-attribute model is not the novel's full stat system."),
		"vigor": _row("Vigor","Reconstruction attribute used for maximum health.",4,0,1000000,"floor",["vig"],"Current estimate: Max Health=base health+4×Vigor−5×injuries, subject to minimum health."),
		"attack": _row("Attack","Damage power before armor, resistance and situational effects.",6,0,1000000,"floor",["power"],"Current estimate: base Attack+Strength, then equipment, racial and other modifiers. Minimum actual damage is handled at resolution."),
		"armor": _row("Armor","Flat defense applied to ordinary physical damage.",0,-1000000,1000000,"floor",[],"Current estimate: subtract Armor before resistance for physical hits; nonphysical hits bypass this subtraction."),
		"accuracy": _row("Accuracy","Accuracy score used to resolve hit chance.",85,0,1000000,"floor",[],"Current estimate: attacker Accuracy−target Evasion with situational adjustments; final hit chance separately clamped20–98 percent."),
		"evasion": _row("Evasion","Defense score subtracted from an attacker's accuracy.",4,-1000000,1000000,"floor",[],"Current estimate:2×Agility plus modifiers. This score is not a standalone percentage dodge probability."),
		"max_health": _row("Max Health","Upper limit of the character's current health pool.",24,1,1000000,"floor",["max_hp"],"Current derived health formula is an estimate. Resolving this maximum does not itself heal the character."),
		"max_soul_power": _row("Max Soul Power","Upper limit of Soul Power used by essence skills.",12,0,1000000,"floor",["max_energy"],"Current estimate:6+2×Wit; nonmages gain10 at level2. Stored current Soul Power remains a separate resource."),
		"max_mana": _row("Max Mana","Upper limit of mana used by learned magic.",0,0,1000000,"floor",[],"Current estimate:6+2×Wit for characters with learned spells; otherwise0. Resolving a maximum does not refill mana."),
		"attack_range": _row("Attack Range","Maximum tile distance of an ordinary weapon attack.",1,1,128,"floor",["range"],"Current estimate in grid tiles; default1, modified by equipped weapon and effects. Tiles are not novel meters."),
		"sight": _row("Sight","Tile radius used for current visibility calculations.",6,0,256,"floor",[],"Current estimate:6+floor(Wit/3), modified by effects and visibility rules. This is not a novel Vision-point conversion."),
		"carry_bonus": _row("Carry Bonus","Additional carrying allowance supplied by modifiers.",0,-1000000,1000000,"none",[],"Current carrying units and bonuses are estimates; fractional item weights remain meaningful."),
		"carry_capacity": _row("Carry Capacity","Maximum combined party carrying allowance contribution.",14,0,1000000,"none",[],"Current shared-pack estimate: base14 plus each living party member's2×Strength and Carry Bonus. Party aggregation is performed by the adapter."),
		"initiative": _row("Initiative","Order score for resolving actors in a combat phase.",4,0,1000000,"floor",[],"Current estimate: larger Initiative acts earlier; adapter supplies the existing actor-order baseline."),
		"damage_dealt_multiplier": _row("Damage Dealt Multiplier","Scales outgoing damage before final damage resolution.",1,0,100,"none",[],"Current gameplay factor:1 preserves damage; multiplication order and bounds are estimates."),
		"damage_taken_multiplier": _row("Damage Taken Multiplier","Scales incoming damage at the adapter's damage-resolution stage.",1,0,100,"none",[],"Current gameplay factor:1 preserves damage. This factor does not imply immunity or alter fixed-damage bypass rules."),
		"healing_received_multiplier": _row("Healing Received Multiplier","Scales health restored by supported healing actions.",1,0,100,"none",[],"Current gameplay factor:1 preserves healing; the adapter caps actual healing at missing health and never revives by default."),
		"skill_power_multiplier": _row("Skill Power Multiplier","Scales supported skill durations, tracking reach and learned-spell damage.",1,0,100,"none",[],"Chapter202 describes about30% better skill performance. PROVISIONAL conversion: multiply essence status/field durations and scent radius, rounding up; multiply learned-spell damage. Targeting range, AP/SP cost, cooldown and ordinary weapon damage are unchanged. Numbered Item and racial powers are outside this adapter.",["https://hennoveltranslations.com/archives/episodes/stgb-episode-202"]),
		"soul_cost_multiplier": _row("Soul Power Cost Multiplier","Scales the Soul Power cost of supported essence skills.",1,0,100,"none",[],"Current gameplay factor:1 preserves cost; final cost rounding belongs to the resource-spending adapter."),
		"mana_cost_multiplier": _row("Mana Cost Multiplier","Scales the mana cost of supported learned spells.",1,0,100,"none",[],"Current gameplay factor:1 preserves cost; Soul Power and mana remain distinct resources."),
		"cooldown_multiplier": _row("Cooldown Multiplier","Scales supported cooldown durations.",1,0,100,"none",[],"Current gameplay factor:1 preserves duration; the adapter applies the supported whole-round rounding policy."),
		"natural_recovery": _row("Natural Recovery","Health regained at a supported safe recovery interval; fractional amounts carry forward.",1,0,100,"none",[],"Current gameplay factor:1 preserves ordinary recovery. Recovery still requires the elapsed safe-rest interval and applicable nourishment rules."),
		"flexibility": _row("Flexibility","Raw Flexibility points used by the current evasion adapter.",0,-1000000,1000000,"none",[],"Named novel attribute. Its contribution to Evasion and all numeric bounds are explicit gameplay estimates.",[ESSENCE_SOURCE,ARCHER_SOURCE]),
		"vision": _row("Vision","Raw Vision points used by current sight and ranged-reach adapters.",0,-1000,1000000,"none",[],"Named novel attribute. Conversion to grid Sight or ranged reach is an explicit estimate; Vision points are not tiles.",[ARCHER_SOURCE]),
		"smell": _row("Smell","Raw Smell points used by the current scent-tracking adapter.",0,-1000,1000000,"none",[],"Named novel attribute. Conversion to scent-tracking distance is an explicit estimate; Smell points are not tiles.",[ARCHER_SOURCE]),
		"armor_penetration": _row("Armor Penetration","Percentage of supported physical Armor bypassed by an attack.",0,0,100,"none",[],"Percentage0..100 and damage-resolution order are current reconstruction values; this is separate from Armor itself."),
		"resistance_penetration": _row("Resistance Penetration","Percentage of supported resistance ignored by an attack.",0,0,100,"none",[],"Percentage0..100 and conversion order are gameplay estimates; raw resistance remains a distinct stat."),
		"weapon_damage_multiplier": _row("Weapon Damage Multiplier","Scales supported weapon damage.",1,0,100,"none",[],"Gameplay factor:1 preserves weapon damage; stacks through the shared modifier pipeline."),
		"spell_damage_multiplier": _row("Spell Damage Multiplier","Scales supported learned-spell damage.",1,0,100,"none",[],"Gameplay factor:1 preserves spell damage; essence costs remain a separate resource calculation."),
		"movement_cost": _row("Movement Cost","Action Point cost of one supported movement step.",1,1,20,"ceil",[],"Current AP cost and1..20 bounds are gameplay estimates, applied by movement validation."),
		"attack_ap_cost": _row("Attack AP Cost","Action Point cost of an ordinary attack.",1,1,20,"ceil",[],"Current normal attack cost is1AP; modified costs remain estimates and must be affordable before acting."),
		"soul_recovery": _row("Soul Power Recovery","Soul Power recovered by a supported recovery tick.",1,0,1000000,"floor",[],"Current per-tick recovery and timing are estimates; recovery is capped at missing Soul Power."),
		"mana_recovery": _row("Mana Recovery","Mana recovered by a supported recovery tick.",1,0,1000000,"floor",[],"Current per-tick recovery and timing are estimates; recovery is capped at missing mana."),
		"muscle_mass": _row("Muscle Mass","Each point increases total Strength by1%.",0,-99,10000,"none",[],"Chapter337 verifies1% total Strength per point. Numeric bounds and final integer rounding are reconstruction estimates; the modifier provider applies the relationship.",[MUSCLE_SOURCE]),
		"action_points": _row("Action Points per Phase","Action budget available in a combat phase.",2,0,100,"floor",["ap"],"Current turn-budget estimate:2AP per normal phase; inability to act and per-action costs are checked separately.")
	}
	for kind: String in ["physical","fire","cold","poison","dark","mana"]:
		rows[kind+"_resistance"] = _row(kind.capitalize()+" Resistance","Raw resistance points for the matching damage category.",0,-1000,1000000,"none",[],"Raw novel-style points are not percentages. The adapter converts points through an explicitly estimated damage curve; numeric bounds are also estimates.",[STATS_SOURCE,ESSENCE_SOURCE,MUSCLE_SOURCE])
		rows[kind+"_resistance"].unit = "points"
		for direction: String in ["dealt","taken"]:
			rows[kind+"_damage_"+direction+"_multiplier"] = _row(kind.capitalize()+" Damage "+direction.capitalize()+" Multiplier","Scales "+kind+" damage "+direction+" by supported damage actions.",1,0,100,"none",[],"Current gameplay factor:1 preserves damage. Per-category and all-damage modifiers combine through the shared pipeline; order is estimated.")
		rows[kind+"_damage_reduction"] = _row(kind.capitalize()+" Damage Reduction","Direct percentage reduction for existing matching damage effects.",0,-50,80,"none",[],"Legacy percentage compatibility only: clamp−50..80. Keep this separate from raw Resistance points and combine only in the adapter's documented order.",[STATS_SOURCE])
		rows[kind+"_damage_reduction"].unit = "percent"
	rows.muscle_mass.strength_increase_per_point = 0.01
	rows.muscle_mass.verified_relationship = true
	# The source establishes aggregate-stat coefficients, not tactical percentages.
	rows.mana_resistance.novel_coefficient = 3.0
	rows.mana_resistance.novel_coefficient_scope = "Magic Resistance in chapter463's aggregate stat calculation; not the current percent-resistance formula."
	rows.mana_resistance.coefficient_implemented = false
	var research: Dictionary = {
		"body_index":["Physical","Aggregate physical score; distinct from the current Attack stat.",STATS_SOURCE],
		"mind_index":["Mental","Aggregate mental score; its complete coefficient system is not reconstructed.",STATS_SOURCE],
		"ability_index":["Special Ability","Aggregate special-ability score used in chapter463 coefficient examples.",STATS_SOURCE],
		"perception":["Perception","Named among Goblin Archer essence attributes.",ARCHER_SOURCE],
		"cognitive_interference":["Cognitive Interference","Named among Goblin Archer essence attributes.",ARCHER_SOURCE],
		"obsession":["Obsession","Named among Goblin Archer essence attributes.",ARCHER_SOURCE],
		"possessiveness":["Possessiveness","Chapter463 excludes this stat from its calculation because the aggregate coefficient is0.",STATS_SOURCE],
		"endurance":["Endurance","Named among essence attribute bonuses.",ESSENCE_SOURCE],
		"bone_strength":["Bone Strength","Named among essence attribute bonuses.",ESSENCE_SOURCE],
		"bone_density":["Bone Density","An innate stat excluded from the chapter463 Chaos increase.",STATS_SOURCE],
		"height":["Height","Chapter446 shows height changing when Bone Density changes; no general conversion is established.",HEIGHT_SOURCE],
		"hearing":["Hearing","Named among essence attribute bonuses.",ESSENCE_SOURCE],
		"jumping_power":["Jumping Power","Named among essence attribute bonuses.",ESSENCE_SOURCE],
		"natural_energy":["Natural Energy","Chapter463 names this resource in spirit use and Chaos Circuit.",STATS_SOURCE],
		"control":["Control","Chapter463 names a−30 Control essence penalty.",STATS_SOURCE],
		"dexterity":["Dexterity","Chapter463 links this stat to an aggregate Special Ability score.",STATS_SOURCE],
		"luck":["Luck","An innate stat excluded from the chapter463 Chaos increase.",STATS_SOURCE],
		"impulse":["Impulse","Chapter463 identifies this as a stat with a negative aggregate coefficient.",STATS_SOURCE],
		"distrust":["Distrust","Chapter463 identifies a negative aggregate contribution and states its coefficient magnitude.",STATS_SOURCE],
		"mana_sensitivity":["Mana Sensitivity","Named among Vampire essence attribute bonuses.",ESSENCE_SOURCE]
	}
	research["leg_power"] = ["Leg Power","Named physical stat; exact movement or attack conversion remains unresolved.",ESSENCE_SOURCE]
	research["lung_capacity"] = ["Lung Capacity","Named physical stat; breathing and endurance interactions remain unresolved.",ESSENCE_SOURCE]
	research["cognition"] = ["Cognition","Named mental stat; distinct from the temporary Wit reconstruction attribute.",ESSENCE_SOURCE]
	research["sixth_sense"] = ["Sixth Sense","Named sensory stat; no general perception formula is verified.",ESSENCE_SOURCE]
	research["pain_resistance"] = ["Pain Resistance","Named resistance stat; no universal numeric injury formula is verified.",ESSENCE_SOURCE]
	research["ground_resistance"] = ["Ground Resistance","Named attribute resistance; no currently integrated ground damage category.",ESSENCE_SOURCE]
	research["cold_sensitivity"] = ["Cold Sensitivity","Named elemental sensitivity; point-to-skill coefficient remains unresolved.",ESSENCE_SOURCE]
	research["cutting_force"] = ["Cutting Force","Named stat associated with cutting attacks; no universal conversion is verified.",ESSENCE_SOURCE]
	research["fighting_spirit"] = ["Fighting Spirit","Named mental stat; no general combat conversion is verified.",ESSENCE_SOURCE]
	research["natural_regeneration"] = ["Natural Regeneration","Raw novel stat points, distinct from the current estimated HP-per-interval recovery output.",ESSENCE_SOURCE]
	research["soul_power"] = ["Soul Power","Named novel stat/resource; current maximum Soul Power is a separate implemented output.",ESSENCE_SOURCE]
	research["solar_resistance"] = ["Solar Resistance","Named attribute resistance; no integrated solar damage category.",ESSENCE_SOURCE]
	research["lightning_resistance"] = ["Lightning Resistance","Named attribute resistance; no integrated lightning damage category.",ESSENCE_SOURCE]
	research["appetite"] = ["Appetite","Named stat; do not infer a universal ration cost from its numeric value.",ESSENCE_SOURCE]
	research["soul_regeneration"] = ["Soul Regeneration","Raw novel stat; current per-tick SP recovery is a separate estimated output.",ESSENCE_SOURCE]
	research["adaptability"] = ["Adaptability","Named stat; full interactions remain unresolved.",ESSENCE_SOURCE]
	research["absorption"] = ["Absorption","Named stat; do not infer extra essence slots from its value.",ESSENCE_SOURCE]
	research["weight"] = ["Weight","Character body weight, distinct from the shared inventory weight calculation.",ESSENCE_SOURCE]
	research["critical_chance"] = ["Critical Chance","Critical hits are discussed in the novel; current combat has no critical-roll resolver.",ESSENCE_SOURCE]
	research["critical_damage_multiplier"] = ["Critical Damage Multiplier","Catalog-only critical damage factor; current combat has no critical-hit resolver.",ESSENCE_SOURCE]
	research["combat_index"] = ["Combat Index","Aggregate estimate in recorded character snapshots; conflicting translated examples prevent an exact universal formula.",ESSENCE_SOURCE]
	for id: String in research:
		var fact: Array = research[id]
		rows[id] = _row(fact[0],fact[1],0,-1000000,1000000,"none",[],"Research only; no gameplay resolver. Default0 and numeric storage bounds are placeholders, not novel base values or limits.",[fact[2]],false)
	rows.possessiveness.novel_coefficient = 0.0
	rows.possessiveness.novel_coefficient_scope = "Aggregate coefficient in chapter463; no gameplay effect is inferred."
	rows.possessiveness.coefficient_implemented = false
	rows.dexterity.novel_coefficient = 0.5
	rows.dexterity.novel_coefficient_scope = "Aggregate Special Ability score per Dexterity point in chapter463."
	rows.dexterity.coefficient_implemented = false
	rows.distrust.novel_coefficient = -0.6
	rows.distrust.novel_coefficient_magnitude = 0.6
	rows.distrust.novel_coefficient_sign = -1
	rows.distrust.novel_coefficient_scope = "Chapter463 describes a negative aggregate coefficient, then gives its magnitude as0.6; stored separately to preserve that distinction."
	rows.distrust.coefficient_implemented = false
	var integrated: Dictionary = {
		"natural_regeneration":["Raw natural-regeneration points scale safe HP recovery through the shared provider. Estimated factor clamp(1+points/100,0,100); zero points preserve the baseline.",StatPhysiology.NATURAL_SOURCE],
		"soul_power":["Raw Soul Power adds to maximum SP, estimated one resource unit per point. Changing the maximum never refills current SP.",StatPhysiology.SOUL_SOURCE],
		"soul_regeneration":["Raw Soul Regeneration scales SP recovery, estimated factor clamp(1+points/100,0,100). Fractional recovery carries between ticks and survives saves.",StatPhysiology.RECOVERY_SOURCE],
		"weight":["Body Weight points, separate from carried inventory weight. Estimated blunt physical factor clamp(1+points×0.005,0.25,4); pushes resist fraction 1−1/max(1,factor), with final distance rounded up. Default0 is a neutral stat baseline, not a weightless body.",StatPhysiology.WEIGHT_SOURCE],
		"hearing":["Recent movement/attacks leave anonymous sound cues for3 estimated minutes. Audible path radius=floor(max(0,points)/20), cap8 tiles. Silent/old events, enclosed walls, identity and visibility are never revealed.",StatPhysiology.SENSE_SOURCE],
		"sixth_sense":["Provides a generic warning of nearby hidden danger, without coordinates or identity. Estimated connected path radius ceil(max(0,points)/20), cap6. Does not reveal fog or make a target attackable.",StatAwareness.SIXTH_SOURCE],
		"luck":["Luck contributes an estimated0.05 critical-chance percentage points per raw point. Signed penalties reverse this benefit. Other random-factor interactions remain unresolved; it does not currently alter loot rolls.",StatMentalRules.REFERENCE_URLS[0]],
		"control":["Control resists fear, not physical restraint. Estimated fear-duration factor100/(100+Control) for positive values; negative values lengthen by1+abs(Control)/100, capped10×. Combined durations round up and remain at least1 turn.",StatMentalRules.REFERENCE_URLS[0]],
		"adaptability":["Shortens harmful status duration using estimated100/(100+max(0,points)); compose with applicable mental resistance, round up, minimum1. It does not grant immunity or change beneficial durations.",StatMentalRules.REFERENCE_URLS[1]],
		"cold_sensitivity":["Scales outgoing cold damage, not incoming vulnerability. Estimated factor clamp(1+points/100,0.1,5). Fixed damage and damage-over-time are excluded.",StatCombatRules.SENSITIVITY_SOURCE],
		"cutting_force":["Scales explicitly slashing physical weapon hits. Estimated factor clamp(1+points/100,0.1,5). Does not affect clubs, bows, magic or fixed damage.",StatCombatRules.CUTTING_SOURCE],
		"critical_chance":["Percentage chance of a critical on a successful normal weapon strike; Flexibility contributes an estimated0.1 percentage point per point. Spells, opportunity reactions, secondary procs, DOT and fixed damage never roll.0/100 consume no critical RNG.",StatCombatRules.CRITICAL_SOURCE],
		"critical_damage_multiplier":["Actual critical damage factor; current default1.5 is estimated. The novel describes weak-point-dependent damage, whose full targeting system remains unfinished. Only a successful qualifying critical uses this factor.",StatCombatRules.CRITICAL_SOURCE]
	}
	for id: String in integrated:
		rows[id].implemented = true
		rows[id].source_status = "sourced_relationship_estimated_conversion"
		rows[id].formula_note = integrated[id][0]
		rows[id].reference_urls = [integrated[id][1]]
	for kind: String in ["ground","solar","lightning"]:
		var id: String = kind+"_resistance"
		rows[id].implemented = true
		rows[id].source_status = "sourced_stat_estimated_category_conversion"
		rows[id].min = -1000
		rows[id].unit = "points"
		rows[id].formula_note = "Raw matching elemental resistance points; separate from fire/mana. The shared estimated curve100×points/(100+abs(points)) feeds typed damage, bounded−50..80 percent. No terrain, gravity, paralysis or sunlight immunity is inferred. Category existence does not add a new attack or region."
	rows.critical_chance.default = 0
	rows.critical_chance.min = 0
	rows.critical_chance.max = 100
	rows.critical_chance.unit = "percent"
	rows.critical_damage_multiplier.default = 1.5
	rows.critical_damage_multiplier.min = 1
	rows.critical_damage_multiplier.max = 10
	for id: String in ["soul_recovery","mana_recovery"]:
		rows[id].rounding = "none"
		rows[id].formula_note += " Fractional amounts accumulate in a saved remainder and are discarded at the full pool to prevent banking."
	_activate_remaining(rows)
	_aggregate_metadata(rows)
	return rows

static func _activate_remaining(rows: Dictionary) -> void:
	var physical: Dictionary = StatPhysiology.support_metadata()
	for id: String in physical:
		var context: Dictionary = physical[id]
		rows[id].implemented = true
		rows[id].description = context.qualitative_effect
		rows[id].qualitative_estimate = bool(context.qualitative_estimate)
		rows[id].source_status = "provisional_qualitative_and_numeric" if context.qualitative_estimate else "sourced_relationship_estimated_conversion"
		rows[id].reference_urls = context.reference_urls.duplicate()
		rows[id].known_effect = str(context.get("unknown_reason",context.qualitative_effect))
		rows[id].provisional_effect = str(context.get("estimated_formula","Numerical conversion is estimated; see formula note."))
		if context.qualitative_estimate:
			rows[id].formula_note = "PROVISIONAL qualitative mechanic: " + context.qualitative_effect + " Estimated formula: " + str(context.get("estimated_formula","Context-dependent conversion.")) + ". " + str(context.get("unknown_reason",""))
	# These are live consumers supplied by the shared mental-stat provider.
	var mental: Dictionary = StatMentalRules.provisional_notes()
	for id: String in mental:
		if id in ["absorption","sixth_sense"]: continue
		var note: Dictionary = mental[id]
		rows[id].implemented = true
		rows[id].known_effect = note.proven_effect
		rows[id].provisional_effect = note.provisional_effect
		rows[id].qualitative_estimate = id not in ["luck","control","adaptability"]
		rows[id].source_status = "provisional_qualitative_and_numeric" if rows[id].qualitative_estimate else "sourced_relationship_estimated_conversion"
		rows[id].reference_urls = note.reference_urls.duplicate()
		rows[id].formula_note = ("PROVISIONAL qualitative mechanic. " if rows[id].qualitative_estimate else "Sourced qualitative direction; numeric conversion estimated. ") + note.proven_effect + " " + note.provisional_effect
		rows[id].description = note.provisional_effect
	rows.height.default = 180.0
	rows.height.min = 30.0
	rows.height.max = 1000.0
	rows.height.unit = "estimated_centimeters"
	rows.height.formula_note += " Ordinary default180 and bounds30..1000 are estimated; Height is absolute stature, not a zero-baseline point bonus."
	rows.natural_energy.min = 0.0
	rows.natural_energy.description = "Resource capacity for Spirit Magic after the required spirit lesson or contract."
	rows.natural_energy.formula_note = "PROVISIONAL acquisition: Fairy Fire Spirit lesson supplies an explicit first contract. Capacity=max(0,raw points), with estimated costs/recovery supplied by the spirit module. A stat bonus alone never grants a contract or spell."
	rows.mana_sensitivity.implemented = true
	rows.mana_sensitivity.description = "Raw Mana Sensitivity provisionally amplifies learned-spell power."
	rows.mana_sensitivity.source_status = "provisional_qualitative_and_numeric"
	rows.mana_sensitivity.qualitative_estimate = true
	rows.mana_sensitivity.known_effect = "Named novel stat; universal spell amplification is not verified."
	rows.mana_sensitivity.provisional_effect = "Learned spell damage factor clamp(1+points/100,0.1,5)."
	rows.mana_sensitivity.formula_note = "PROVISIONAL qualitative mechanic: " + rows.mana_sensitivity.provisional_effect + " Does not merge mana and Soul Power or amplify every essence ability."
	rows.pain_resistance.implemented = true
	rows.pain_resistance.description = "Changes perceived pain from a direct hit, independently of actual health loss."
	rows.pain_resistance.source_status = "sourced_sensation_provisional_status"
	rows.pain_resistance.qualitative_estimate = true
	rows.pain_resistance.reference_urls = [StatCombatRules.PAIN_SOURCE]
	rows.pain_resistance.known_effect = "Pain Resistance changes felt pain; a universal combat-status threshold is not verified."
	rows.pain_resistance.provisional_effect = "Direct-hit perceived pain reaching20% maximum health causes pained for2 turns: Accuracy×0.9 and Movement Cost+1."
	rows.pain_resistance.formula_note = "PROVISIONAL qualitative mechanic: " + rows.pain_resistance.provisional_effect + " Perceived-pain factor clamp(100/(100+points),0.1,5) for nonnegative points; negative points use clamp(1-points/100,0.1,5). This never reduces HP damage directly or grants immunity."
	for id: String in ["body_index","mind_index","ability_index","combat_index"]:
		rows[id].implemented = true
		rows[id].name = "Estimated " + {"body_index":"Physical Index","mind_index":"Mental Index","ability_index":"Special Ability Index","combat_index":"Combat Index"}[id]
		rows[id].description = "Informational estimated summary used by inspection and threat comparison."
		rows[id].source_status = "informational_estimate"
		rows[id].qualitative_estimate = true
		rows[id].min = -1000000000000.0
		rows[id].max = 1000000000000.0
		rows[id].formula_note = "Estimated informational index from resolved stats and registry aggregate weights. This index never directly changes damage, accuracy, defenses or resources. Most weights are provisional; individually verified novel coefficients retain their source metadata."
	rows.combat_index.formula_note += " Estimated Combat Index=Physical Index+Mental Index+Special Ability Index+Attack+2×Armor+0.25×Accuracy+0.25×Evasion+Attack Range; resolved inputs are counted once without reapplying modifiers."
	for id: String in rows:
		if not rows[id].has("qualitative_estimate"): rows[id].qualitative_estimate = rows[id].source_status == "reconstruction"
		rows[id].numerical_estimate = true

static func _aggregate_metadata(rows: Dictionary) -> void:
	# Only selected raw domains contribute to headline indices. Resolved outputs,
	# percentages and multipliers are excluded to avoid silently counting twice.
	for id: String in rows:
		rows[id].aggregate_group = "none"
		rows[id].aggregate_weight = 0.0
		rows[id].combat_index_weight = 0.0
		rows[id].aggregate_weight_verified = false
		rows[id].aggregate_note = "Excluded from group indices; this does not disable its gameplay consumer."
	var groups: Dictionary = {
		"physical":["strength","agility","vigor","muscle_mass","flexibility","vision","smell","endurance","bone_strength","bone_density","height","hearing","jumping_power","leg_power","lung_capacity","pain_resistance","weight","physical_resistance","natural_regeneration","appetite"],
		"mental":["wit","perception","cognition","cognitive_interference","obsession","possessiveness","control","luck","impulse","distrust","sixth_sense","fighting_spirit","adaptability"],
		"ability":["natural_energy","dexterity","mana_sensitivity","soul_power","soul_regeneration","absorption","fire_resistance","cold_resistance","poison_resistance","dark_resistance","mana_resistance","ground_resistance","solar_resistance","lightning_resistance","cold_sensitivity","cutting_force"]
	}
	for group: String in groups:
		for id: String in groups[group]:
			rows[id].aggregate_group = group
			rows[id].aggregate_weight = 1.0
			rows[id].aggregate_note = "PROVISIONAL aggregate category and coefficient1; informational only, not a tactical modifier."
	for id: String in ["appetite","impulse"]:
		rows[id].aggregate_weight = -1.0
		rows[id].aggregate_note = "PROVISIONAL negative aggregate weight−1; not a damage penalty."
	for id: String in {"attack":1.0,"armor":2.0,"accuracy":0.25,"evasion":0.25,"attack_range":1.0}:
		rows[id].combat_index_weight = {"attack":1.0,"armor":2.0,"accuracy":0.25,"evasion":0.25,"attack_range":1.0}[id]
	var known: Dictionary = {"dexterity":["ability",0.5],"mana_resistance":["ability",3.0],"distrust":["mental",-0.6],"possessiveness":["mental",0.0]}
	for id: String in known:
		rows[id].aggregate_group = known[id][0]
		rows[id].aggregate_weight = known[id][1]
		rows[id].aggregate_weight_verified = true
		rows[id].coefficient_implemented = true
		rows[id].aggregate_note = "Verified chapter463 coefficient applied only to the informational aggregate; separate gameplay consumers remain explicitly estimated."

static func validate() -> Array[String]:
	return validate_entries(definitions())

static func validate_entries(entries: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if entries.is_empty(): errors.append("Stat catalog: expected nonempty definitions")
	var aliases: Dictionary = {}
	var names: Dictionary = {}
	for id: Variant in entries:
		var prefix: String = "Stat " + str(id) + ": "
		if not id is String or not _valid_id(id): errors.append(prefix+"ID must be lowercase snake_case")
		if not entries[id] is Dictionary: errors.append(prefix+"expected metadata dictionary"); continue
		var row: Dictionary = entries[id]
		for key: String in ["name","description","formula_note"]:
			if not row.get(key) is String or str(row.get(key,"")).strip_edges().is_empty(): errors.append(prefix+key+" must be nonempty text")
		if row.get("name") is String:
			var name_key: String = row.name.strip_edges().to_lower()
			if names.has(name_key): errors.append(prefix+"duplicate display name also used by "+str(names[name_key]))
			else: names[name_key] = id
		for key: String in ["default","min","max"]:
			if not _finite_number(row.get(key)): errors.append(prefix+key+" must be a finite number")
		if _finite_number(row.get("min")) and _finite_number(row.get("max")):
			if float(row.min) > float(row.max): errors.append(prefix+"min exceeds max")
			if _finite_number(row.get("default")) and (float(row.default) < float(row.min) or float(row.default) > float(row.max)): errors.append(prefix+"default is outside bounds")
		if row.get("rounding") not in ROUNDING_MODES: errors.append(prefix+"rounding must be floor, ceil, nearest or none")
		if row.get("rounding") in ["floor","ceil","nearest"] and _finite_number(row.get("default")) and float(row.default) != floorf(float(row.default)): errors.append(prefix+"integer rounding requires an integral default")
		for key: String in ["implemented","experimental_balance"]:
			if not row.get(key) is bool: errors.append(prefix+key+" must be boolean")
		if not row.get("aliases") is Array: errors.append(prefix+"aliases must be an array")
		else:
			for alias: Variant in row.aliases:
				if not alias is String or not _valid_id(alias): errors.append(prefix+"alias must be a lowercase identifier"); continue
				if entries.has(alias): errors.append(prefix+"alias "+alias+" collides with a canonical stat ID")
				if aliases.has(alias): errors.append(prefix+"duplicate alias "+alias+" also used by "+str(aliases[alias]))
				else: aliases[alias] = id
		if not row.get("reference_urls") is Array or row.get("reference_urls",[]).is_empty(): errors.append(prefix+"reference_urls requires source context")
		else:
			for url: Variant in row.reference_urls:
				if not url is String or not (str(url).begins_with("https://") or str(url).begins_with("http://")) or str(url).find(".") < 0: errors.append(prefix+"reference_urls contains an invalid web URL")
		if row.get("aggregate_group") not in ["none","physical","mental","ability"]: errors.append(prefix+"aggregate_group must be none, physical, mental or ability")
		if not _finite_number(row.get("combat_index_weight")): errors.append(prefix+"combat_index_weight must be finite")
		if not _finite_number(row.get("aggregate_weight")): errors.append(prefix+"aggregate_weight must be finite")
		if row.get("aggregate_group") == "none" and _finite_number(row.get("aggregate_weight")) and float(row.aggregate_weight) != 0.0: errors.append(prefix+"excluded aggregate weight must be0")
		if not row.get("aggregate_weight_verified") is bool: errors.append(prefix+"aggregate_weight_verified must be boolean")
		if not row.get("qualitative_estimate") is bool: errors.append(prefix+"qualitative_estimate must be boolean")
		if row.get("source_status") == "provisional_qualitative_and_numeric" and not str(row.get("formula_note","")).contains("PROVISIONAL"): errors.append(prefix+"provisional mechanic requires an explicit disclosure")
		for key: String in ["novel_coefficient","novel_coefficient_magnitude"]:
			if row.has(key) and not _finite_number(row[key]): errors.append(prefix+key+" must be a finite research number")
	return errors

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.begins_with("_") or value.ends_with("_"): return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not (code >= 97 and code <= 122) and code != 95 and not (index > 0 and code >= 48 and code <= 57): return false
	return true
