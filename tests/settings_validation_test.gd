extends SceneTree

const Validation = preload("res://game/settings_validation.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func defaults() -> Dictionary:
	return {"master":0.65,"music":0.45,"sfx":0.75,"muted":false,"text_scale":1.0,"reduced_motion":false,"shake":false,"fullscreen":false,"bindings":{"north":KEY_W,"south":KEY_S,"west":KEY_A,"east":KEY_D,"interact":KEY_E,"wait":KEY_SPACE,"inventory":KEY_I,"journal":KEY_J,"party":KEY_P,"camp":KEY_C}}

func _initialize() -> void:
	var base: Dictionary = defaults()
	check(Validation.sanitize({},base) == base,"Missing settings retain defaults")
	check(Validation.sanitize({"unknown":"ignored","control_map":[]},base) == base,"Unknown settings ignored")
	var partial: Dictionary = Validation.sanitize({"music":0.2,"muted":true},base)
	check(partial.music == 0.2 and partial.muted,"Partial valid overrides accepted")
	check(partial.master == base.master and partial.bindings == base.bindings,"Unspecified partial fields retained")
	for field: String in ["master","music","sfx"]:
		for malformed: Variant in [null,"0.5",[],{},true,false,NAN,INF,-INF]:
			check(Validation.sanitize({field:malformed},base)[field] == base[field],"Invalid volume rejected %s/%s" % [field,str(malformed)])
		check(Validation.sanitize({field:-4.0},base)[field] == 0.0,"Negative volume clamped " + field)
		check(Validation.sanitize({field:50},base)[field] == 1.0,"High integer volume clamped " + field)
		check(Validation.sanitize({field:0},base)[field] == 0.0,"Integer zero volume accepted " + field)
		check(Validation.sanitize({field:0.32},base)[field] == 0.32,"Finite fractional volume accepted " + field)
	for field: String in ["muted","reduced_motion","shake","fullscreen"]:
		for malformed: Variant in [null,1,0,"true",[],{},NAN,INF]:
			check(Validation.sanitize({field:malformed},base)[field] == base[field],"Strict boolean validation " + field)
		check(Validation.sanitize({field:true},base)[field] == true,"True boolean accepted " + field)
		var true_base: Dictionary = base.duplicate(true);true_base[field] = true
		check(Validation.sanitize({field:false},true_base)[field] == false,"False boolean accepted " + field)
	for malformed: Variant in [null,"1.1",true,[],{},NAN,INF,-INF]:
		check(Validation.sanitize({"text_scale":malformed},base).text_scale == 1.0,"Invalid text scale rejected")
	check(Validation.sanitize({"text_scale":0.5},base).text_scale == 1.0,"Text scale lower bound")
	check(Validation.sanitize({"text_scale":9000},base).text_scale == 1.2,"Text scale upper bound")
	check(Validation.sanitize({"text_scale":1.1},base).text_scale == 1.1,"Intermediate text scale")
	var changed: Dictionary = Validation.sanitize({"bindings":{"north":KEY_UP,"unknown":KEY_S}},base)
	check(changed.bindings.north == KEY_UP,"Known action override accepted")
	check(changed.bindings.size() == base.bindings.size() and changed.bindings.south == KEY_S,"Unknown action ignored; missing actions retained")
	for malformed: Variant in [null,true,"87",[],{},0,-1,1.5,NAN,INF,-INF,0x2000000,1e100]:
		check(Validation.sanitize({"bindings":{"north":malformed}},base).bindings == base.bindings,"Malformed/out-of-range binding rejected: " + str(malformed))
	for malformed: Variant in [null,[],"bindings",false,81]:
		check(Validation.sanitize({"bindings":malformed},base).bindings == base.bindings,"Malformed binding dictionary rejected")
	check(Validation.sanitize({"bindings":{"north":float(KEY_UP)}},base).bindings.north == KEY_UP,"Integral JSON float keycode accepted")
	check(Validation.sanitize({"bindings":{"north":1}},base).bindings.north == 1,"Minimum positive keycode accepted")
	check(Validation.sanitize({"bindings":{"north":0x1ffffff}},base).bindings.north == 0x1ffffff,"Maximum keycode accepted")
	var collided: Dictionary = Validation.sanitize({"bindings":{"north":KEY_S,"west":KEY_F}},base)
	check(collided.bindings == base.bindings,"Collision with default restores entire map")
	collided = Validation.sanitize({"bindings":{"north":KEY_UP,"south":KEY_UP,"west":KEY_F}},base)
	check(collided.bindings == base.bindings,"Collision between overrides restores entire map")
	var swapped: Dictionary = Validation.sanitize({"bindings":{"north":KEY_S,"south":KEY_W}},base)
	check(swapped.bindings.north == KEY_S and swapped.bindings.south == KEY_W,"Valid key swap is not treated as duplicate")
	var source: Dictionary = {"music":0.1,"bindings":{"north":KEY_UP},"unknown":{"nested":[1,2]}}
	var source_before: String = JSON.stringify(source)
	var base_before: String = JSON.stringify(base)
	var sanitized: Dictionary = Validation.sanitize(source,base)
	check(JSON.stringify(source) == source_before and JSON.stringify(base) == base_before,"Sanitization mutates neither input")
	sanitized.bindings.north = KEY_DOWN
	check(JSON.stringify(source) == source_before and JSON.stringify(base) == base_before,"Returned nested map shares no input storage")
	var stored: Dictionary = Validation.sanitize({"master":0.83,"music":0.4,"muted":true,"text_scale":1.2,"bindings":{"north":KEY_UP,"south":KEY_DOWN}},base)
	var decoded: Variant = JSON.parse_string(JSON.stringify(stored))
	check(decoded is Dictionary,"JSON persistence produces dictionary")
	var restored: Dictionary = Validation.sanitize(decoded,base)
	check(restored == stored,"Settings survive sanitized JSON persistence round trip")
	check(typeof(restored.bindings.north) == TYPE_INT,"Persisted keycode restored to integer")
	check(Validation.sanitize(restored,base) == restored,"Sanitization is idempotent")
	for failure: String in failures: push_error(failure)
	print("SETTINGS VALIDATION TEST: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
