@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")
const INPUT_EVENT_CODEC_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_event_codec.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()
var _codec = INPUT_EVENT_CODEC_SCRIPT.new()


func set_host(host: Node) -> void:
	_settings.set_host(host)


func action_exists(action_name: String) -> bool:
	return _settings.has_setting(_setting_name(action_name))


func list_action_names(prefix: String = "") -> Array:
	var rows: Array = []
	var normalized_prefix := str(prefix).strip_edges()
	for setting_name in _settings.list_setting_names("input/"):
		var action_name := str(setting_name).substr("input/".length())
		if action_name.is_empty():
			continue
		if normalized_prefix != "" and not action_name.begins_with(normalized_prefix):
			continue
		var action_result := get_action(action_name)
		if not bool(action_result.get("ok", false)):
			continue
		rows.append(action_name)

	rows.sort()
	return rows


func get_action(action_name: String) -> Dictionary:
	var normalized_name := str(action_name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	var setting_name := _setting_name(normalized_name)
	if not _settings.has_setting(setting_name):
		return _result.error(_errors.NOT_FOUND, "input action not found: %s" % normalized_name)

	var raw_value = _settings.get_setting(setting_name, {})
	if typeof(raw_value) != TYPE_DICTIONARY:
		return _result.error(_errors.TYPE_MISMATCH, "input action is not stored as a dictionary: %s" % normalized_name)

	var deadzone := float(raw_value.get("deadzone", 0.5))
	var events: Array = []
	for raw_event in raw_value.get("events", []):
		if raw_event is InputEvent:
			events.append(raw_event)

	return {
		"ok": true,
		"action": normalized_name,
		"deadzone": deadzone,
		"events": events,
	}


func set_action(action_name: String, deadzone: float, events: Array) -> Dictionary:
	var normalized_name := str(action_name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")
	if deadzone < 0.0:
		return _result.error(_errors.INVALID_ARGS, "deadzone must be >= 0")

	var normalized_events: Array = []
	for raw_event in events:
		if raw_event is InputEvent:
			normalized_events.append(raw_event)

	var setting_name := _setting_name(normalized_name)
	var changed := true
	if _settings.has_setting(setting_name):
		var existing_result := get_action(normalized_name)
		if not bool(existing_result.get("ok", false)):
			return existing_result
		changed = _events_changed(existing_result.get("events", []), normalized_events) or float(existing_result.get("deadzone", 0.5)) != deadzone

	if not changed:
		return {
			"ok": true,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		}

	_settings.set_setting(setting_name, {
		"deadzone": deadzone,
		"events": normalized_events,
	})

	var save_result := _settings.save()
	if not bool(save_result.get("ok", false)):
		return save_result
	if not InputMap.has_method("load_from_project_settings"):
		return _result.error(_errors.EDITOR_STATE, "InputMap.load_from_project_settings is unavailable")

	InputMap.load_from_project_settings()
	return {
		"ok": true,
		"changed": changed,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}


func remove_action(action_name: String) -> Dictionary:
	var normalized_name := str(action_name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	var setting_name := _setting_name(normalized_name)
	if not _settings.has_setting(setting_name):
		return {
			"ok": true,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		}

	_settings.set_setting(setting_name, null)
	var save_result := _settings.save()
	if not bool(save_result.get("ok", false)):
		return save_result
	if not InputMap.has_method("load_from_project_settings"):
		return _result.error(_errors.EDITOR_STATE, "InputMap.load_from_project_settings is unavailable")
	InputMap.load_from_project_settings()

	return {
		"ok": true,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}


func encode_event_rows(events: Array, include_events: bool, max_events: int) -> Dictionary:
	var rows: Array = []
	for raw_event in events:
		if raw_event is InputEvent:
			rows.append(_codec.encode_event(raw_event))

	rows.sort_custom(Callable(_codec, "compare_event_rows"))

	var returned_rows: Array = []
	var truncated := false
	if include_events:
		returned_rows = rows
		if max_events > 0 and returned_rows.size() > max_events:
			returned_rows = returned_rows.slice(0, max_events)
			truncated = true

	return {
		"events": returned_rows,
		"event_count": rows.size(),
		"returned_event_count": returned_rows.size(),
		"events_truncated": truncated,
	}


func decode_event_json(raw_event_json: String) -> Dictionary:
	return _codec.decode_event_json(raw_event_json)


func _events_changed(existing_events: Array, next_events: Array) -> bool:
	var existing_rows := []
	for raw_event in existing_events:
		if raw_event is InputEvent:
			existing_rows.append(_codec.build_event_key(_codec.encode_event(raw_event).get("event", {})))

	var next_rows := []
	for raw_event in next_events:
		if raw_event is InputEvent:
			next_rows.append(_codec.build_event_key(_codec.encode_event(raw_event).get("event", {})))

	existing_rows.sort()
	next_rows.sort()
	return existing_rows != next_rows


func _setting_name(action_name: String) -> String:
	return "input/%s" % str(action_name).strip_edges()
