@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const CFG_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/cfg_document_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = CFG_DOCUMENT_STORE_SCRIPT.new()


func tool_name() -> String:
	return "file.cfg_remove"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var section := str(args.get("section", "")).strip_edges()
	var key := str(args.get("key", "")).strip_edges()
	if section.is_empty():
		return _result.error(_errors.INVALID_ARGS, "section is required")

	var load_result := _store.load_config(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var config: ConfigFile = load_result.get("config", null)
	var changed := false
	if key == "":
		if config.has_section(section):
			config.erase_section(section)
			changed = true
	else:
		if config.has_section_key(section, key):
			config.erase_section_key(section, key)
			changed = true

	if not changed:
		return _result.success("config value removed", {
			"path": str(load_result.get("path", "")),
			"section": section,
			"key": key,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	var save_result := _store.save_config(str(load_result.get("path", "")), config)
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("config value removed", {
		"path": str(load_result.get("path", "")),
		"section": section,
		"key": key,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
