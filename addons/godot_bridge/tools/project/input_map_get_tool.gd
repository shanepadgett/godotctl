@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const INPUT_EVENT_SUMMARIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_event_summarizer.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _summarizer = INPUT_EVENT_SUMMARIZER_SCRIPT.new()


func tool_name() -> String:
	return "project.input_map_get"


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
	if not InputMap.has_action(action_name):
		return _result.error(_errors.NOT_FOUND, "input action not found: %s" % action_name)

	var total_event_count := _event_count_for_action(action_name)
	var actions: Array = []
	var returned_event_count := 0
	var actions_with_truncated_events := 0

	if include_actions:
		var action_row := _build_action_row(action_name, include_events, max_events)
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
	var action_names := _collect_action_names(prefix)
	var total_count := action_names.size()
	var total_event_count := 0
	for action_name in action_names:
		total_event_count += _event_count_for_action(action_name)

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
			var row := _build_action_row(action_name, include_events, max_events)
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


func _collect_action_names(prefix: String) -> Array:
	var names: Array = []
	var seen := {}

	for raw_name in InputMap.get_actions():
		var action_name := str(raw_name).strip_edges()
		if action_name.is_empty():
			continue
		if not _matches_prefix(action_name, prefix):
			continue
		if seen.has(action_name):
			continue
		seen[action_name] = true
		names.append(action_name)

	names.sort()
	return names


func _build_action_row(action_name: String, include_events: bool, max_events: int) -> Dictionary:
	var events: Array = []
	for raw_event in _collect_action_events(action_name):
		if not (raw_event is InputEvent):
			continue
		var event: InputEvent = raw_event
		events.append(_summarizer.summarize(event))

	events.sort_custom(Callable(self, "_compare_events"))

	var event_count := events.size()
	var returned_events: Array = []
	var events_truncated := false
	if include_events:
		returned_events = events
		if max_events > 0 and returned_events.size() > max_events:
			returned_events = returned_events.slice(0, max_events)
			events_truncated = true

	var returned_event_count := returned_events.size()

	return {
		"name": action_name,
		"deadzone": float(InputMap.action_get_deadzone(action_name)),
		"events": returned_events,
		"event_count": event_count,
		"returned_event_count": returned_event_count,
		"events_truncated": events_truncated,
	}


func _compare_events(a: Dictionary, b: Dictionary) -> bool:
	var a_summary := str(a.get("summary", ""))
	var b_summary := str(b.get("summary", ""))
	if a_summary == b_summary:
		return str(a.get("type", "")) < str(b.get("type", ""))

	return a_summary < b_summary


func _collect_action_events(action_name: String) -> Array:
	var events: Array = []
	for raw_event in InputMap.action_get_events(action_name):
		if raw_event is InputEvent:
			events.append(raw_event)

	return events


func _event_count_for_action(action_name: String) -> int:
	return _collect_action_events(action_name).size()


func _normalize_prefix(raw_prefix: String) -> String:
	return str(raw_prefix).strip_edges()


func _matches_prefix(action_name: String, prefix: String) -> bool:
	if prefix.is_empty():
		return true

	if action_name == prefix:
		return true

	return action_name.begins_with(prefix)
