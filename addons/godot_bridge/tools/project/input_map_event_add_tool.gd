@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const INPUT_MAP_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_map_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = INPUT_MAP_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_event_add"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var action_name := str(args.get("action", "")).strip_edges()
	if action_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	var action_result := _store.get_action(action_name)
	if not bool(action_result.get("ok", false)):
		return action_result

	var decode_result := _store.decode_event_json(str(args.get("event_json", "")))
	if not bool(decode_result.get("ok", false)):
		return decode_result

	var target_key := str(decode_result.get("event_key", ""))
	var events: Array = action_result.get("events", [])
	for raw_event in events:
		if not (raw_event is InputEvent):
			continue
		var event_rows := _store.encode_event_rows([raw_event], true, 0).get("events", [])
		if not event_rows.is_empty() and str(event_rows[0].get("event_key", "")) == target_key:
			return _result.success("input event added: %s" % action_name, {
				"action": action_name,
				"event_key": target_key,
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			})

	events.append(decode_result.get("event", null))
	var save_result := _store.set_action(action_name, float(action_result.get("deadzone", 0.5)), events)
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("input event added: %s" % action_name, {
		"action": action_name,
		"event_key": target_key,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
