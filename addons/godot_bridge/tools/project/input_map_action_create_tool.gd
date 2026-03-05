@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const INPUT_MAP_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_map_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = INPUT_MAP_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_action_create"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var action_name := str(args.get("action", "")).strip_edges()
	var deadzone := float(args.get("deadzone", 0.5))
	if action_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	if _store.action_exists(action_name):
		var action_result := _store.get_action(action_name)
		if not bool(action_result.get("ok", false)):
			return action_result
		var existing_events: Array = action_result.get("events", [])
		var existing_deadzone := float(action_result.get("deadzone", 0.5))
		if existing_events.is_empty() and existing_deadzone == deadzone:
			return _result.success("input action created: %s" % action_name, {
				"action": action_name,
				"deadzone": deadzone,
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			})
		return _result.error(_errors.ALREADY_EXISTS, "input action already exists: %s" % action_name)

	var save_result := _store.set_action(action_name, deadzone, [])
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("input action created: %s" % action_name, {
		"action": action_name,
		"deadzone": deadzone,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
