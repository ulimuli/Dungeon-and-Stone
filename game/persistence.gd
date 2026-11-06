class_name SaveStore
extends RefCounted

const SCHEMA_VERSION: int = 1
const SAVE_DIRECTORY: String = "user://saves"

static func _path(slot: int) -> String:
	return SAVE_DIRECTORY.path_join("slot_%02d.json" % slot)

static func save_slot(slot: int, state: Dictionary) -> String:
	if slot < 0 or slot > 99:
		return "Save slot must be between 0 and 99."
	var directory_error := DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return "Cannot create save directory: %s" % error_string(directory_error)
	var payload := JSON.stringify(state)
	var envelope := {"schema": SCHEMA_VERSION, "payload": payload, "checksum": payload.sha256_text(), "saved_at": Time.get_datetime_string_from_system(true)}
	var path := _path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Cannot write save: %s" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "Save write failed: %s" % error_string(write_error)
	# Validate the flushed temporary file before replacing the last good save.
	if not bool(_read(temporary).get("ok", false)):
		return "Save validation failed; existing save preserved."
	if FileAccess.file_exists(path):
		# A corrupted primary must never replace a healthy backup.
		var prior: Dictionary = _read(path)
		var campaign: bool = state.has("hero") and state.has("version")
		var structurally_valid: bool = not campaign or (prior.get("ok", false) and preload("res://game/save_validation.gd").validate(prior.state).is_empty())
		if bool(prior.get("ok", false)) and structurally_valid:
			var copy_error := DirAccess.copy_absolute(path, path + ".bak")
			if copy_error != OK:
				return "Cannot preserve save backup: %s" % error_string(copy_error)
	var rename_error := DirAccess.rename_absolute(temporary, path)
	if rename_error != OK:
		return "Cannot commit save: %s" % error_string(rename_error)
	return ""

static func save_campaign_slot(slot: int, state: Dictionary) -> String:
	var errors: Array[String] = preload("res://game/save_validation.gd").validate(state)
	if not errors.is_empty(): return "Cannot save invalid campaign: " + errors[0]
	return save_slot(slot, state)

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "state": {}, "warning": "No save exists in this slot."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "state": {}, "warning": "Save cannot be read."}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return {"ok": false, "state": {}, "warning": "Save JSON is corrupt."}
	var envelope: Dictionary = parser.data
	var schema: int = int(envelope.get("schema", 0))
	if schema > SCHEMA_VERSION or schema < 0:
		return {"ok": false, "state": {}, "warning": "Save belongs to an unsupported version."}
	if schema == 0:
		var old_state: Variant = envelope.get("state", envelope)
		if old_state is Dictionary and not old_state.is_empty():
			return {"ok": true, "state": old_state, "warning": "Legacy save imported; save again to upgrade."}
		return {"ok": false, "state": {}, "warning": "Legacy save has no campaign state."}
	var payload: String = str(envelope.get("payload", ""))
	if payload.sha256_text() != str(envelope.get("checksum", "")):
		return {"ok": false, "state": {}, "warning": "Save checksum failed."}
	var state_parser := JSON.new()
	if state_parser.parse(payload) != OK or not state_parser.data is Dictionary or state_parser.data.is_empty():
		return {"ok": false, "state": {}, "warning": "Save has no campaign state."}
	return {"ok": true, "state": state_parser.data, "warning": "", "saved_at": envelope.get("saved_at", "")}

static func load_slot(slot: int) -> Dictionary:
	if slot < 0 or slot > 99:
		return {"ok": false, "state": {}, "warning": "Invalid save slot."}
	var primary := _read(_path(slot))
	if bool(primary["ok"]):
		return primary
	var backup := _read(_path(slot) + ".bak")
	if bool(backup["ok"]):
		backup["warning"] = "Recovered previous save from backup. " + str(primary["warning"])
		return backup
	return primary

static func slots() -> Array:
	var result: Array = []
	for slot in range(1, 4):
		var loaded := load_slot(slot)
		result.append({"slot": slot, "ok": loaded["ok"], "exists": FileAccess.file_exists(_path(slot)), "warning": loaded["warning"], "saved_at": loaded.get("saved_at", ""), "state": loaded.get("state", {})})
	return result

static func load_campaign_slot(slot: int) -> Dictionary:
	if slot < 0 or slot > 99: return {"ok": false, "state": {}, "warning": "Invalid save slot."}
	var primary: Dictionary = _read(_path(slot))
	if primary.ok:
		var errors: Array[String] = preload("res://game/save_validation.gd").validate(primary.state)
		if errors.is_empty(): return primary
		primary = {"ok": false, "state": {}, "warning": "Invalid campaign: " + errors[0]}
	var backup: Dictionary = _read(_path(slot) + ".bak")
	if backup.ok and preload("res://game/save_validation.gd").validate(backup.state).is_empty():
		backup.warning = "Recovered previous campaign from backup. " + str(primary.warning)
		return backup
	return primary

static func save_settings(data: Dictionary) -> void:
	var file := FileAccess.open("user://settings.json.tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Cannot persist settings")
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var result := DirAccess.rename_absolute("user://settings.json.tmp", "user://settings.json")
	if result != OK:
		push_warning("Cannot commit settings: " + error_string(result))

static func load_settings() -> Dictionary:
	if not FileAccess.file_exists("user://settings.json"):
		return {}
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	return parser.data if parse_error == OK and parser.data is Dictionary else {}
