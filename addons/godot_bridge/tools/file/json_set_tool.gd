@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const JSON_DOCUMENT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/json_document_store.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _store = JSON_DOCUMENT_STORE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "file.json_set"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var pointer := str(args.get("pointer", ""))
	var create_missing := bool(args.get("create", false))
	var decode_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(decode_result.get("ok", false)):
		return decode_result

	var load_result := _store.load_document(str(args.get("path", "")), create_missing)
	if not bool(load_result.get("ok", false)):
		return load_result

	var set_result := _store.set_value(load_result.get("document", null), pointer, decode_result.get("value", null))
	if not bool(set_result.get("ok", false)):
		return set_result

	if not bool(set_result.get("changed", false)):
		return _result.success("JSON value set", {
			"path": str(load_result.get("path", "")),
			"pointer": pointer,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	var save_result := _store.save_document(str(load_result.get("path", "")), set_result.get("document", null))
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("JSON value set", {
		"path": str(load_result.get("path", "")),
		"pointer": pointer,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
