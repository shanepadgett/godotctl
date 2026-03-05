@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const IMPORT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/import_settings_store.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = IMPORT_SETTINGS_STORE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "project.import_set"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var key := str(args.get("key", "")).strip_edges()
	if key.is_empty():
		return _result.error(_errors.INVALID_ARGS, "key is required")

	var key_parts := key.split("/", false, 1)
	if key_parts.size() != 2:
		return _result.error(_errors.INVALID_ARGS, "key must be in section/name form")

	var decode_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(decode_result.get("ok", false)):
		return decode_result

	var load_result := _store.load_import_config(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var config: ConfigFile = load_result.get("config", null)
	var section := str(key_parts[0]).strip_edges()
	var field_name := str(key_parts[1]).strip_edges()
	var next_value = decode_result.get("value", null)
	var existing = config.get_value(section, field_name, null)
	var changed: bool = (existing != next_value)
	if changed:
		config.set_value(section, field_name, next_value)
		var save_result := _store.save_import_config(str(load_result.get("source_path", "")), str(load_result.get("import_path", "")), config)
		if not bool(save_result.get("ok", false)):
			return save_result
		return _result.success("import property set: %s" % key, {
			"source_path": str(load_result.get("source_path", "")),
			"import_path": str(load_result.get("import_path", "")),
			"key": key,
			"changed": true,
			"reimport_required": true,
			"saved": true,
			"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
		})

	return _result.success("import property set: %s" % key, {
		"source_path": str(load_result.get("source_path", "")),
		"import_path": str(load_result.get("import_path", "")),
		"key": key,
		"changed": false,
		"reimport_required": false,
		"saved": false,
		"filesystem_refreshed": false,
	})
