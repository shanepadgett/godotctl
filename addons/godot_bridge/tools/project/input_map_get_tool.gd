@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const INPUT_MAP_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_map_store.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _store = INPUT_MAP_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_get"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var requested_action := str(args.get("action", "")).strip_edges()
	var prefix := _normalize_prefix(str(args.get("prefix", "")))
	var include_actions := bool(args.get("include_actions", true))
	var include_events := bool(args.get("include_events", false))
	var max_actions := int(args.get("max_actions", 200))
	var max_events := int(args.get("max_events", 200))

	if max_actions < 0:
		return _result.error(_errors.INVALID_ARGS, "max_actions must be >= 0")
	if max_events < 0:
		return _result.error(_errors.INVALID_ARGS, "max_events must be >= 0")
	if include_events and not include_actions:
		return _result.error(_errors.INVALID_ARGS, "include_events requires include_actions=true")
	if not requested_action.is_empty() and not prefix.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action and prefix cannot be used together")

	if not requested_action.is_empty():
		return _execute_single(requested_action, include_actions, include_events, max_events)

	return _execute_list(prefix, include_actions, include_events, max_actions, max_events)


func _execute_single(action_name: String, include_actions: bool, include_events: bool, max_events: int) -> Dictionary:
	var action_result := _store.get_action(action_name)
	if not bool(action_result.get("ok", false)):
		return action_result

	var total_event_count := int(action_result.get("events", []).size())
	var actions: Array = []
	var returned_event_count := 0
	var actions_with_truncated_events := 0

	if include_actions:
		var action_row := _build_action_row(action_name, float(action_result.get("deadzone", 0.5)), action_result.get("events", []), include_events, max_events)
		actions = [action_row]
		returned_event_count = int(action_row.get("returned_event_count", 0))
		if bool(action_row.get("events_truncated", false)):
			actions_with_truncated_events = 1

	return _result.success("input action retrieved: %s" % action_name, {
		"requested_action": action_name,
		"prefix": "",
		"include_actions": include_actions,
		"include_events": include_events,
		"max_actions": 1,
		"max_events": max_events,
		"actions": actions,
		"count": 1,
		"returned_count": actions.size(),
		"truncated": false,
		"total_event_count": total_event_count,
		"returned_event_count": returned_event_count,
		"actions_with_truncated_events": actions_with_truncated_events,
	})


func _execute_list(prefix: String, include_actions: bool, include_events: bool, max_actions: int, max_events: int) -> Dictionary:
	var action_names := _store.list_action_names(prefix)
	var total_count := action_names.size()
	var total_event_count := 0
	for action_name in action_names:
		var action_result := _store.get_action(action_name)
		if bool(action_result.get("ok", false)):
			total_event_count += int(action_result.get("events", []).size())

	var rows: Array = []
	var returned_event_count := 0
	var actions_with_truncated_events := 0
	var truncated := false

	if include_actions:
		var selected_action_names := action_names
		if max_actions > 0 and selected_action_names.size() > max_actions:
			selected_action_names = selected_action_names.slice(0, max_actions)
			truncated = true

		for action_name in selected_action_names:
			var action_result := _store.get_action(action_name)
			if not bool(action_result.get("ok", false)):
				continue
			var row := _build_action_row(action_name, float(action_result.get("deadzone", 0.5)), action_result.get("events", []), include_events, max_events)
			rows.append(row)
			returned_event_count += int(row.get("returned_event_count", 0))
			if bool(row.get("events_truncated", false)):
				actions_with_truncated_events += 1

	var returned_count := rows.size()

	return _result.success("input map listed", {
		"requested_action": "",
		"prefix": prefix,
		"include_actions": include_actions,
		"include_events": include_events,
		"max_actions": max_actions,
		"max_events": max_events,
		"actions": rows,
		"count": total_count,
		"returned_count": returned_count,
		"truncated": truncated,
		"total_event_count": total_event_count,
		"returned_event_count": returned_event_count,
		"actions_with_truncated_events": actions_with_truncated_events,
	})


func _build_action_row(action_name: String, deadzone: float, events: Array, include_events: bool, max_events: int) -> Dictionary:
	var event_rows := _store.encode_event_rows(events, include_events, max_events)
	return {
		"name": action_name,
		"deadzone": deadzone,
		"events": event_rows.get("events", []),
		"event_count": int(event_rows.get("event_count", 0)),
		"returned_event_count": int(event_rows.get("returned_event_count", 0)),
		"events_truncated": bool(event_rows.get("events_truncated", false)),
	}


func _normalize_prefix(raw_prefix: String) -> String:
	return str(raw_prefix).strip_edges()
