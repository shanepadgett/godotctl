@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const CFG_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/cfg_document_store.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = CFG_DOCUMENT_STORE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "file.cfg_set"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var section := str(args.get("section", "")).strip_edges()
	var key := str(args.get("key", "")).strip_edges()
	if section.is_empty():
		return _result.error(_errors.INVALID_ARGS, "section is required")
	if key.is_empty():
		return _result.error(_errors.INVALID_ARGS, "key is required")

	var decode_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(decode_result.get("ok", false)):
		return decode_result

	var load_result := _store.load_config(str(args.get("path", "")), bool(args.get("create", false)))
	if not bool(load_result.get("ok", false)):
		return load_result

	var config: ConfigFile = load_result.get("config", null)
	var next_value = decode_result.get("value", null)
	var changed: bool = (config.get_value(section, key, null) != next_value)
	if not changed:
		return _result.success("config value set", {
			"path": str(load_result.get("path", "")),
			"section": section,
			"key": key,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	config.set_value(section, key, next_value)
	var save_result := _store.save_config(str(load_result.get("path", "")), config)
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("config value set", {
		"path": str(load_result.get("path", "")),
		"section": section,
		"key": key,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
