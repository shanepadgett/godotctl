@tool
extends RefCounted

const AUTOLOAD_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/autoload_store.gd")

var _store = AUTOLOAD_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.autoload_remove"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	return _store.remove_autoload(str(args.get("name", "")))
