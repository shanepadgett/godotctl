@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const INPUT_MAP_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_map_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _store = INPUT_MAP_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_action_delete"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var action_name := str(args.get("action", "")).strip_edges()
	var delete_result := _store.remove_action(action_name)
	if not bool(delete_result.get("ok", false)):
		return delete_result

	return _result.success("input action deleted: %s" % action_name, {
		"action": action_name,
		"changed": bool(delete_result.get("changed", false)),
		"saved": bool(delete_result.get("saved", false)),
		"filesystem_refreshed": bool(delete_result.get("filesystem_refreshed", false)),
	})
