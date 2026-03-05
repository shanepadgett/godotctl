@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "project.settings_set"


func set_host(host: Node) -> void:
	_settings.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var key_result := _settings.validate_setting_key(str(args.get("key", "")), "key")
	if not bool(key_result.get("ok", false)):
		return key_result

	var value_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(value_result.get("ok", false)):
		return value_result

	var setting_key := str(key_result.get("key", ""))
	var next_value = value_result.get("value", null)
	var changed := true
	if _settings.has_setting(setting_key):
		changed = _settings.get_setting(setting_key) != next_value
	elif next_value == null:
		changed = false

	if not changed:
		return _result.success("project setting set: %s" % setting_key, {
			"key": setting_key,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	_settings.set_setting(setting_key, next_value)
	var save_result := _settings.save()
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("project setting set: %s" % setting_key, {
		"key": setting_key,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
