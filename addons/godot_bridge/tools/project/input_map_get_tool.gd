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
	if not requested_action.is_empty():
		return _execute_single(requested_action)

	return _execute_list()


func _execute_single(action_name: String) -> Dictionary:
	if not InputMap.has_action(action_name):
		return _result.error(_errors.NOT_FOUND, "input action not found: %s" % action_name)

	var action_row := _build_action_row(action_name)
	var event_count := int(action_row.get("event_count", 0))

	return _result.success("input action retrieved: %s" % action_name, {
		"requested_action": action_name,
		"actions": [action_row],
		"count": 1,
		"total_event_count": event_count,
	})


func _execute_list() -> Dictionary:
	var action_names := _collect_action_names()
	var rows: Array = []
	var total_event_count := 0

	for action_name in action_names:
		var row := _build_action_row(action_name)
		rows.append(row)
		total_event_count += int(row.get("event_count", 0))

	return _result.success("input map listed", {
		"requested_action": "",
		"actions": rows,
		"count": rows.size(),
		"total_event_count": total_event_count,
	})


func _collect_action_names() -> Array:
	var names: Array = []
	var seen := {}

	for raw_name in InputMap.get_actions():
		var action_name := str(raw_name).strip_edges()
		if action_name.is_empty():
			continue
		if seen.has(action_name):
			continue
		seen[action_name] = true
		names.append(action_name)

	names.sort()
	return names


func _build_action_row(action_name: String) -> Dictionary:
	var events: Array = []
	for raw_event in InputMap.action_get_events(action_name):
		if not (raw_event is InputEvent):
			continue
		var event: InputEvent = raw_event
		events.append(_summarizer.summarize(event))

	events.sort_custom(Callable(self, "_compare_events"))

	return {
		"name": action_name,
		"deadzone": float(InputMap.action_get_deadzone(action_name)),
		"events": events,
		"event_count": events.size(),
	}


func _compare_events(a: Dictionary, b: Dictionary) -> bool:
	var a_summary := str(a.get("summary", ""))
	var b_summary := str(b.get("summary", ""))
	if a_summary == b_summary:
		return str(a.get("type", "")) < str(b.get("type", ""))

	return a_summary < b_summary
