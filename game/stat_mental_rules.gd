class_name StatMentalRules
extends RefCounted
## Novel349: Luck affects critical chance; Control resists fear/mental effects.
## Novel383: Adaptability shortens debuffs. Numerical curves below are gameplay
## estimates, not verified novel coefficients. Additional effects below are
## explicitly provisional qualitative interpretations authorized for this game.
## This pure helper rolls no RNG; provenance IDs identify every contribution.

const LUCK_CRITICAL_PERCENT_PER_POINT: float = 0.05
const DURATION_CURVE_SCALE: float = 100.0
const HARMFUL_STATUSES: Array[String] = ["bleeding", "poison", "burning", "chilled", "stunned", "weakened", "marked", "frightened", "paralyzed", "suppressed", "distressed", "pained"]
const REFERENCE_URLS: Array[String] = [
	"https://hennoveltranslations.org/episodes/stgb-episode-349/",
	"https://hennoveltranslations.org/episodes/stgb-episode-383/"
]

static func derived_modifiers(values: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_add(result, "luck", "critical_chance", _stat(values, "luck") * LUCK_CRITICAL_PERCENT_PER_POINT)
	# PROVISIONAL qualitative mappings: these are not claimed novel mechanics.
	_add(result, "perception", "accuracy", _stat(values, "perception") * 0.25)
	_add(result, "cognition", "initiative", _stat(values, "cognition") * 0.25)
	_add(result, "cognitive_interference", "evasion", _stat(values, "cognitive_interference") * 0.25)
	_add(result, "dexterity", "accuracy", _stat(values, "dexterity") * 0.1)
	_add(result, "obsession", "accuracy", _stat(values, "obsession") * -0.1)
	_add(result, "obsession", "critical_chance", _stat(values, "obsession") * 0.05)
	_add(result, "impulse", "attack", _stat(values, "impulse") * 0.1)
	_add(result, "impulse", "accuracy", _stat(values, "impulse") * -0.2)
	var distrust: float = maxf(0.0, _stat(values, "distrust"))
	if distrust > 0.0:
		result.append({"id":"derived:distrust:natural_recovery", "source":"derived:distrust", "stat":"natural_recovery", "op":"multiply", "value":clampf(100.0 / (100.0 + distrust), 0.25, 1.0)})
	return result

static func _add(result: Array[Dictionary], from_stat: String, target_stat: String, value: float) -> void:
	if value == 0.0: return
	result.append({"id":"derived:" + from_stat + ":" + target_stat, "source":"derived:" + from_stat, "stat":target_stat, "op":"add", "value":value})

static func attachment_duration(values: Dictionary) -> int:
	# PROVISIONAL: losing worn gear creates temporary distress, not ownership loss.
	var attachment: float = maxf(0.0, _stat(values, "possessiveness"))
	return int(ceilf(minf(6.0, attachment / 20.0)))

static func provisional_notes() -> Dictionary:
	# A fresh dictionary prevents callers from altering the source/estimate labels.
	var novel349: String = REFERENCE_URLS[0]
	var novel383: String = REFERENCE_URLS[1]
	var novel463: String = "https://hennoveltranslations.com/archives/episodes/stgb-463"
	return {
		"luck":_note("Critical chance and other random factors; penalties reverse benefits.", "Coefficient +0.05 critical percentage points per point; no generic loot effect.", [novel349]),
		"control":_note("Resistance to mental magic and fear; penalties reverse benefits.", "Fear duration: positive100/(100+points); negative1+abs(points)/100, combined fear extension capped10x.", [novel349]),
		"adaptability":_note("Shortens debuff durations.", "Positive100/(100+points) duration curve; ceil/min1, no negative penalty.", [novel383]),
		"perception":_note("Novel252 links high Perception and magical talent to energy awareness.", "PROVISIONAL: awareness gives +0.25 Accuracy per point. Cognition translation overlap remains unresolved.", ["https://hennoveltranslations.com/episodes/stgb-episode-252/"]),
		"cognition":_note("Early Corpse Golem translation links cognition decline to worse sight/judgment; other translations label it Perception.", "PROVISIONAL: judgment speed gives +0.25 Initiative per point; treated separately in this game.", ["https://pdfcoffee.com/surviving-the-game-as-a-barbarian-01-pdf-free.html"]),
		"cognitive_interference":_note("Named bonus, also translated Perception Interference; direct effect unverified.", "PROVISIONAL: interfering with observation gives +0.25 Evasion per point, without invisibility.", ["https://martialrealm.com/novel/sgb/chapter-13-14-15/"]),
		"dexterity":_note("Novel463 gives +0.5 coefficient to Special Ability aggregate only.", "PROVISIONAL: fine motor control gives +0.1 Accuracy per point; separate from the known aggregate.", [novel463]),
		"obsession":_note("Novel90 associates accumulated Obsession with excessive fixation on strength.", "PROVISIONAL tunnel vision/focus: -0.1 Accuracy and +0.05 critical percentage points per point.", ["https://wuxiaworld.site/novel/surviving-the-game-as-a-barbarian/chapter-90/"]),
		"impulse":_note("Novel463 identifies a negative aggregate coefficient; direct behavior unverified.", "PROVISIONAL reckless aggression: +0.1 Attack and -0.2 Accuracy per point.", [novel463]),
		"distrust":_note("Novel463 identifies a negative aggregate coefficient, magnitude0.6.", "PROVISIONAL restless recovery: Natural Recovery multiplied by clamp(100/(100+max(0,points)),0.25,1).", [novel463]),
		"fighting_spirit":_note("Novel625 restores Ainar's combat motivation after replacing lost Fighting Spirit.", "PROVISIONAL morale: fear duration uses the signed Control curve; combined fear extension capped10x. No Attack bonus.", ["https://hennoveltranslations.org/episodes/stgb-episode-625/"]),
		"possessiveness":_note("Novel463 gives aggregate coefficient0; direct effect unverified.", "PROVISIONAL attachment: gear loss causes distressed for ceil(max(0,points)/20), cap6; temporary half SP/mana recovery applied by caller.", [novel463]),
		"sixth_sense":_note("Novel413 supports intuition warning of danger.", "Consumer/radius/chance supplied by simulation; warning must not become omniscient revelation.", ["https://hennoveltranslations.com/archives/episodes/stgb-episode-413"]),
		"absorption":_note("Novel625 lists Absorption+60 without explaining its effect.", "No consumer is assigned by this helper; any runtime interpretation must be explicitly provisional.", ["https://hennoveltranslations.org/episodes/stgb-episode-625/"])
	}

static func _note(proven: String, provisional: String, urls: Array) -> Dictionary:
	return {"proven_effect":proven, "provisional_effect":provisional, "experimental_balance":true, "reference_urls":urls}

static func incoming_duration(status_id: String, base: int, values: Dictionary) -> int:
	# Beneficial/unknown statuses are unchanged. Fighting Spirit is a provisional
	# morale interpretation; Control/Adaptability directions have novel support.
	if base <= 0 or status_id not in HARMFUL_STATUSES: return base
	var adaptability: float = maxf(0.0, _stat(values, "adaptability"))
	var control: float = _stat(values, "control") if status_id == "frightened" else 0.0
	var morale: float = _stat(values, "fighting_spirit") if status_id == "frightened" else 0.0
	if adaptability == 0.0 and control == 0.0 and morale == 0.0: return base
	var factor: float = DURATION_CURVE_SCALE / (DURATION_CURVE_SCALE + adaptability)
	factor *= minf(10.0, _mental_duration_factor(control) * _mental_duration_factor(morale))
	var scaled: float = float(base) * factor
	# Positive applications remain at least one turn; this cannot grant immunity.
	# Guard conversion at the int64 boundary without changing zero-stat behavior.
	if not is_finite(scaled) or scaled >= float(9223372036854775807): return 9223372036854775807
	if scaled <= 1.0: return 1
	return maxi(1, int(ceilf(scaled)))

static func _mental_duration_factor(points: float) -> float:
	if points >= 0.0: return DURATION_CURVE_SCALE / (DURATION_CURVE_SCALE + points)
	return minf(10.0, 1.0 + absf(points) / DURATION_CURVE_SCALE)

static func _stat(values: Dictionary, id: String) -> float:
	var value: Variant = values.get(id, 0.0)
	if not (value is int or value is float): return 0.0
	return float(value) if is_finite(float(value)) else 0.0
