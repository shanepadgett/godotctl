@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const INPUT_MAP_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_map_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = INPUT_MAP_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_deadzone_set"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var action_name := str(args.get("action", "")).strip_edges()
	var deadzone := float(args.get("value", -1.0))
	if action_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")
	if deadzone < 0.0:
		return _result.error(_errors.INVALID_ARGS, "value must be >= 0")

	var action_result := _store.get_action(action_name)
	if not bool(action_result.get("ok", false)):
		return action_result

	var save_result := _store.set_action(action_name, deadzone, action_result.get("events", []))
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("input deadzone set: %s" % action_name, {
		"action": action_name,
		"deadzone": deadzone,
		"changed": bool(save_result.get("changed", false)),
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
