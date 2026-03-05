@tool
extends RefCounted

const AUTOLOAD_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/autoload_store.gd")

var _store = AUTOLOAD_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.autoload_add"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	return _store.add_autoload(
		str(args.get("name", "")),
		str(args.get("path", "")),
		bool(args.get("singleton", true)),
		int(args.get("index", -1))
	)
