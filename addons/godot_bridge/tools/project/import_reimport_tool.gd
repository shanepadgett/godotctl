@tool
extends RefCounted

const IMPORT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/import_settings_store.gd")

var _store = IMPORT_SETTINGS_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.import_reimport"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var resolve_result := _store.resolve_source_path(str(args.get("path", "")))
	if not bool(resolve_result.get("ok", false)):
		return resolve_result
	return _store.reimport_source(str(resolve_result.get("source_path", "")))
