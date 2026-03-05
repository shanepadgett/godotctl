@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "project.settings_get"


func execute(args: Dictionary) -> Dictionary:
	var requested_key := str(args.get("key", "")).strip_edges()
	if not requested_key.is_empty():
		return _execute_single(requested_key)

	return _execute_list()


func _execute_single(key: String) -> Dictionary:
	if not ProjectSettings.has_setting(key):
		return _result.error(_errors.NOT_FOUND, "project setting not found: %s" % key)

	var setting_value = ProjectSettings.get_setting(key)
	return _result.success("project setting retrieved: %s" % key, {
		"requested_key": key,
		"settings": [_build_setting_entry(key, setting_value)],
		"count": 1,
	})


func _execute_list() -> Dictionary:
	var keys_result := _collect_public_setting_keys()
	if not bool(keys_result.get("ok", false)):
		return keys_result

	var settings: Array = []
	for key in keys_result.get("keys", []):
		var setting_key := str(key).strip_edges()
		if setting_key.is_empty():
			continue
		if not ProjectSettings.has_setting(setting_key):
			continue

		settings.append(_build_setting_entry(setting_key, ProjectSettings.get_setting(setting_key)))

	settings.sort_custom(Callable(self, "_compare_settings"))

	return _result.success("project settings listed", {
		"requested_key": "",
		"settings": settings,
		"count": settings.size(),
	})


func _collect_public_setting_keys() -> Dictionary:
	var config := ConfigFile.new()
	var load_err := config.load("res://project.godot")
	if load_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to read project settings: %s" % error_string(load_err))

	var keys: Array = []
	var seen := {}
	var sections := config.get_sections()
	sections.sort()

	for section_value in sections:
		var section := str(section_value).strip_edges()
		if section.is_empty():
			continue

		var section_keys := config.get_section_keys(section)
		section_keys.sort()
		for key_value in section_keys:
			var key_part := str(key_value).strip_edges()
			if key_part.is_empty():
				continue

			var setting_key := "%s/%s" % [section, key_part]
			if not _is_public_key(setting_key):
				continue
			if seen.has(setting_key):
				continue

			seen[setting_key] = true
			keys.append(setting_key)

	keys.sort()
	return {
		"ok": true,
		"keys": keys,
	}


func _is_public_key(key: String) -> bool:
	var normalized_key := str(key).strip_edges()
	if normalized_key.is_empty():
		return false
	if normalized_key.begins_with("_"):
		return false
	if normalized_key.find("/") == -1:
		return false
	if normalized_key.begins_with("input/"):
		return false

	var parts := normalized_key.split("/", false)
	if parts.is_empty():
		return false
	if str(parts[0]).strip_edges().begins_with("_"):
		return false

	return true


func _build_setting_entry(key: String, value: Variant) -> Dictionary:
	var serialized := _serializer.serialize(value)
	return {
		"key": key,
		"value": serialized.get("value", null),
		"value_text": str(serialized.get("text", "")),
		"value_type": str(serialized.get("type", "")),
	}


func _compare_settings(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("key", "")) < str(b.get("key", ""))
