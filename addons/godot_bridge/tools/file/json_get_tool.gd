@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const JSON_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/json_document_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _store = JSON_DOCUMENT_STORE_SCRIPT.new()


func tool_name() -> String:
	return "file.json_get"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var pointer := str(args.get("pointer", ""))
	var load_result := _store.load_document(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var value_result := _store.get_value(load_result.get("document", null), pointer)
	if not bool(value_result.get("ok", false)):
		return value_result

	var value = value_result.get("value", null)
	return _result.success("JSON value read", {
		"path": str(load_result.get("path", "")),
		"pointer": pointer,
		"value": value,
		"value_text": JSON.stringify(value),
		"value_type": type_string(typeof(value)),
	})
