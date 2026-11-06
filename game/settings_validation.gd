class_name SettingsValidation
extends RefCounted
## Settings loaded from disk are untrusted. Defaults provide the known schema;
## malformed fields retain their defaults. Neither input dictionary is mutated.

const MAX_KEYCODE: int = 0x1ffffff
const VOLUME_FIELDS: Array[String] = ["master", "music", "sfx"]
const BOOLEAN_FIELDS: Array[String] = ["muted", "reduced_motion", "shake", "fullscreen"]

static func sanitize(data: Dictionary, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for field: String in VOLUME_FIELDS:
		if defaults.has(field) and _finite_number(data.get(field)):
			result[field] = clampf(float(data[field]), 0.0, 1.0)
	for field: String in BOOLEAN_FIELDS:
		if defaults.has(field) and data.get(field) is bool:
			result[field] = data[field]
	if defaults.has("text_scale") and _finite_number(data.get("text_scale")):
		result.text_scale = clampf(float(data.text_scale), 1.0, 1.2)
	if defaults.get("bindings") is Dictionary:
		var fallback: Dictionary = defaults.bindings.duplicate(true)
		var bindings: Dictionary = fallback.duplicate(true)
		if data.get("bindings") is Dictionary:
			for action: Variant in data.bindings:
				if action is String and fallback.has(action) and _valid_keycode(data.bindings[action]):
					bindings[action] = int(data.bindings[action])
		var seen: Dictionary = {}
		var duplicate: bool = false
		for action: Variant in bindings:
			var keycode: int = int(bindings[action])
			if seen.has(keycode):
				duplicate = true
				break
			seen[keycode] = true
		result.bindings = fallback if duplicate else bindings
	return result

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_keycode(value: Variant) -> bool:
	if not _finite_number(value): return false
	var code: float = float(value)
	return code >= 1.0 and code <= float(MAX_KEYCODE) and floorf(code) == code
