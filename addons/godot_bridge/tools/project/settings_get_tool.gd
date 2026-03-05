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
	var prefix := _normalize_prefix(str(args.get("prefix", "")))
	var include_settings := bool(args.get("include_settings", true))
	var include_values := bool(args.get("include_values", false))
	var max_settings := int(args.get("max_settings", 200))

	if max_settings < 0:
		return _result.error(_errors.INVALID_ARGS, "max_settings must be >= 0")
	if include_values and not include_settings:
		return _result.error(_errors.INVALID_ARGS, "include_values requires include_settings=true")
	if not requested_key.is_empty() and not prefix.is_empty():
		return _result.error(_errors.INVALID_ARGS, "key and prefix cannot be used together")

	if not requested_key.is_empty():
		return _execute_single(requested_key, include_settings, include_values)

	return _execute_list(prefix, include_settings, include_values, max_settings)


func _execute_single(key: String, include_settings: bool, include_values: bool) -> Dictionary:
	if not ProjectSettings.has_setting(key):
		return _result.error(_errors.NOT_FOUND, "project setting not found: %s" % key)

	var settings: Array = []
	if include_settings:
		settings.append(_build_setting_entry(key, ProjectSettings.get_setting(key), include_values))

	return _result.success("project setting retrieved: %s" % key, {
		"requested_key": key,
		"prefix": "",
		"include_settings": include_settings,
		"include_values": include_values,
		"max_settings": 1,
		"settings": settings,
		"count": 1,
		"returned_count": settings.size(),
		"truncated": false,
	})


func _execute_list(prefix: String, include_settings: bool, include_values: bool, max_settings: int) -> Dictionary:
	var keys_result := _collect_public_setting_keys()
	if not bool(keys_result.get("ok", false)):
		return keys_result

	var keys: Array = []
	for key in keys_result.get("keys", []):
		var setting_key := str(key).strip_edges()
		if setting_key.is_empty():
			continue
		if not _matches_prefix(setting_key, prefix):
			continue
		if not ProjectSettings.has_setting(setting_key):
			continue

		keys.append(setting_key)

	var settings: Array = []
	var truncated := false
	if include_settings:
		var selected_keys := keys
		if max_settings > 0 and selected_keys.size() > max_settings:
			selected_keys = selected_keys.slice(0, max_settings)
			truncated = true

		for setting_key in selected_keys:
			settings.append(_build_setting_entry(setting_key, ProjectSettings.get_setting(setting_key), include_values))

		settings.sort_custom(Callable(self, "_compare_settings"))

	var total_count := keys.size()

	return _result.success("project settings listed", {
		"requested_key": "",
		"prefix": prefix,
		"include_settings": include_settings,
		"include_values": include_values,
		"max_settings": max_settings,
		"settings": settings,
		"count": total_count,
		"returned_count": settings.size(),
		"truncated": truncated,
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


func _build_setting_entry(key: String, value: Variant, include_values: bool) -> Dictionary:
	var entry := {
		"key": key,
		"value_type": type_string(typeof(value)),
	}

	if include_values:
		var serialized := _serializer.serialize(value)
		entry["value"] = serialized.get("value", null)
		entry["value_text"] = str(serialized.get("text", ""))
		entry["value_type"] = str(serialized.get("type", ""))

	return entry


func _normalize_prefix(raw_prefix: String) -> String:
	var prefix := str(raw_prefix).strip_edges()
	while prefix.ends_with("/"):
		prefix = prefix.left(prefix.length() - 1)

	return prefix


func _matches_prefix(setting_key: String, prefix: String) -> bool:
	if prefix.is_empty():
		return true

	if setting_key == prefix:
		return true

	return setting_key.begins_with("%s/" % prefix)


func _compare_settings(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("key", "")) < str(b.get("key", ""))
