@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const CFG_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/cfg_document_store.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = CFG_DOCUMENT_STORE_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "file.cfg_get"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var section := str(args.get("section", "")).strip_edges()
	var key := str(args.get("key", "")).strip_edges()
	if key != "" and section == "":
		return _result.error(_errors.INVALID_ARGS, "section is required when key is set")

	var load_result := _store.load_config(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var config: ConfigFile = load_result.get("config", null)
	var entries := _collect_entries(config, section, key)
	if key != "" and entries.is_empty():
		return _result.error(_errors.NOT_FOUND, "config key not found: %s/%s" % [section, key])

	return _result.success("config values listed", {
		"path": str(load_result.get("path", "")),
		"section": section,
		"key": key,
		"entries": entries,
		"count": entries.size(),
		"returned_count": entries.size(),
		"truncated": false,
	})


func _collect_entries(config: ConfigFile, section: String, key: String) -> Array:
	var rows: Array = []
	var sections := config.get_sections()
	sections.sort()
	for raw_section in sections:
		var section_name := str(raw_section).strip_edges()
		if section != "" and section_name != section:
			continue
		var keys := config.get_section_keys(section_name)
		keys.sort()
		for raw_key in keys:
			var key_name := str(raw_key).strip_edges()
			if key != "" and key_name != key:
				continue
			var value = config.get_value(section_name, key_name, null)
			var serialized := _serializer.serialize(value)
			rows.append({
				"section": section_name,
				"key": key_name,
				"value": serialized.get("value", null),
				"value_text": str(serialized.get("text", "")),
				"value_type": str(serialized.get("type", "")),
			})
	return rows
