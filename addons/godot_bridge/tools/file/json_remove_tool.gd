@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const JSON_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/json_document_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _store = JSON_DOCUMENT_STORE_SCRIPT.new()


func tool_name() -> String:
	return "file.json_remove"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var pointer := str(args.get("pointer", ""))
	var load_result := _store.load_document(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var remove_result := _store.remove_value(load_result.get("document", null), pointer)
	if not bool(remove_result.get("ok", false)):
		return remove_result

	if not bool(remove_result.get("changed", false)):
		return _result.success("JSON value removed", {
			"path": str(load_result.get("path", "")),
			"pointer": pointer,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	var save_result := _store.save_document(str(load_result.get("path", "")), remove_result.get("document", null))
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("JSON value removed", {
		"path": str(load_result.get("path", "")),
		"pointer": pointer,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
