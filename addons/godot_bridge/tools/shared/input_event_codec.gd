@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const INPUT_EVENT_SUMMARIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/input_event_summarizer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _summarizer = INPUT_EVENT_SUMMARIZER_SCRIPT.new()


func decode_event_json(raw_event_json: String) -> Dictionary:
	var event_json := str(raw_event_json).strip_edges()
	if event_json.is_empty():
		return _result.error(_errors.INVALID_ARGS, "event_json is required")

	var parser := JSON.new()
	var parse_err := parser.parse(event_json)
	if parse_err != OK:
		return _result.error(_errors.INVALID_ARGS, "event_json is invalid JSON: %s" % parser.get_error_message())

	if typeof(parser.data) != TYPE_DICTIONARY:
		return _result.error(_errors.INVALID_ARGS, "event_json must be a JSON object")

	return decode_event_payload(parser.data)


func decode_event_payload(payload: Dictionary) -> Dictionary:
	if not payload.has("type"):
		return _result.error(_errors.INVALID_ARGS, "event payload requires field: type")

	var type_name := str(payload.get("type", "")).strip_edges().to_lower()
	if type_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "event payload type must be non-empty")

	if type_name == "key":
		return _decode_key_event(payload)
	if type_name == "mouse_button":
		return _decode_mouse_button_event(payload)
	if type_name == "joypad_button":
		return _decode_joypad_button_event(payload)
	if type_name == "joypad_motion":
		return _decode_joypad_motion_event(payload)

	return _result.error(_errors.INVALID_ARGS, "unsupported input event type: %s" % type_name)


func encode_event(event: InputEvent) -> Dictionary:
	if event == null:
		return {}

	var encoded := _encode_event_payload(event)
	var summary := _summarizer.summarize(event)
	return {
		"type": str(summary.get("type", "")),
		"summary": str(summary.get("summary", "")),
		"event_key": build_event_key(encoded),
		"event": encoded,
	}


func build_event_key(payload: Dictionary) -> String:
	var normalized := _normalize_payload(payload)
	if normalized.is_empty():
		return ""

	return JSON.stringify(normalized)


func compare_event_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_key := str(a.get("event_key", ""))
	var b_key := str(b.get("event_key", ""))
	if a_key == b_key:
		return str(a.get("type", "")) < str(b.get("type", ""))

	return a_key < b_key


func _decode_key_event(payload: Dictionary) -> Dictionary:
	var keycode_result := _require_int(payload, "keycode")
	if not bool(keycode_result.get("ok", false)):
		return keycode_result

	var event := InputEventKey.new()
	event.device = int(payload.get("device", 0))
	event.keycode = int(keycode_result.get("value", 0))
	event.physical_keycode = int(payload.get("physical_keycode", 0))
	event.unicode = int(payload.get("unicode", 0))
	event.ctrl_pressed = bool(payload.get("ctrl", false))
	event.alt_pressed = bool(payload.get("alt", false))
	event.shift_pressed = bool(payload.get("shift", false))
	event.meta_pressed = bool(payload.get("meta", false))

	return {
		"ok": true,
		"event": event,
		"event_key": build_event_key(_encode_event_payload(event)),
	}


func _decode_mouse_button_event(payload: Dictionary) -> Dictionary:
	var button_result := _require_int(payload, "button_index")
	if not bool(button_result.get("ok", false)):
		return button_result

	var event := InputEventMouseButton.new()
	event.device = int(payload.get("device", 0))
	event.button_index = int(button_result.get("value", 0))
	event.double_click = bool(payload.get("double_click", false))
	event.ctrl_pressed = bool(payload.get("ctrl", false))
	event.alt_pressed = bool(payload.get("alt", false))
	event.shift_pressed = bool(payload.get("shift", false))
	event.meta_pressed = bool(payload.get("meta", false))

	return {
		"ok": true,
		"event": event,
		"event_key": build_event_key(_encode_event_payload(event)),
	}


func _decode_joypad_button_event(payload: Dictionary) -> Dictionary:
	var button_result := _require_int(payload, "button_index")
	if not bool(button_result.get("ok", false)):
		return button_result

	var event := InputEventJoypadButton.new()
	event.device = int(payload.get("device", 0))
	event.button_index = int(button_result.get("value", 0))

	return {
		"ok": true,
		"event": event,
		"event_key": build_event_key(_encode_event_payload(event)),
	}


func _decode_joypad_motion_event(payload: Dictionary) -> Dictionary:
	var axis_result := _require_int(payload, "axis")
	if not bool(axis_result.get("ok", false)):
		return axis_result

	var value_result := _require_numeric(payload, "axis_value")
	if not bool(value_result.get("ok", false)):
		return value_result

	var event := InputEventJoypadMotion.new()
	event.device = int(payload.get("device", 0))
	event.axis = int(axis_result.get("value", 0))
	event.axis_value = float(value_result.get("value", 0.0))

	return {
		"ok": true,
		"event": event,
		"event_key": build_event_key(_encode_event_payload(event)),
	}


func _encode_event_payload(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return {
			"type": "key",
			"device": int(key_event.device),
			"keycode": int(key_event.keycode),
			"physical_keycode": int(key_event.physical_keycode),
			"unicode": int(key_event.unicode),
			"ctrl": bool(key_event.ctrl_pressed),
			"alt": bool(key_event.alt_pressed),
			"shift": bool(key_event.shift_pressed),
			"meta": bool(key_event.meta_pressed),
		}

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		return {
			"type": "mouse_button",
			"device": int(mouse_button.device),
			"button_index": int(mouse_button.button_index),
			"double_click": bool(mouse_button.double_click),
			"ctrl": bool(mouse_button.ctrl_pressed),
			"alt": bool(mouse_button.alt_pressed),
			"shift": bool(mouse_button.shift_pressed),
			"meta": bool(mouse_button.meta_pressed),
		}

	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event
		return {
			"type": "joypad_button",
			"device": int(joy_button.device),
			"button_index": int(joy_button.button_index),
		}

	if event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event
		return {
			"type": "joypad_motion",
			"device": int(joy_motion.device),
			"axis": int(joy_motion.axis),
			"axis_value": snapped(float(joy_motion.axis_value), 0.000001),
		}

	return {}


func _normalize_payload(payload: Dictionary) -> Dictionary:
	var keys := payload.keys()
	keys.sort_custom(Callable(self, "_compare_values"))

	var normalized := {}
	for key in keys:
		var key_name := str(key).strip_edges()
		if key_name.is_empty():
			continue
		normalized[key_name] = payload.get(key)

	return normalized


func _require_int(payload: Dictionary, field_name: String) -> Dictionary:
	if not payload.has(field_name):
		return _result.error(_errors.INVALID_ARGS, "event payload requires field: %s" % field_name)

	var raw_value = payload.get(field_name)
	var value_type := typeof(raw_value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return _result.error(_errors.INVALID_ARGS, "event payload field %s must be numeric" % field_name)

	return {
		"ok": true,
		"value": int(raw_value),
	}


func _require_numeric(payload: Dictionary, field_name: String) -> Dictionary:
	if not payload.has(field_name):
		return _result.error(_errors.INVALID_ARGS, "event payload requires field: %s" % field_name)

	var raw_value = payload.get(field_name)
	var value_type := typeof(raw_value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return _result.error(_errors.INVALID_ARGS, "event payload field %s must be numeric" % field_name)

	return {
		"ok": true,
		"value": float(raw_value),
	}


func _compare_values(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)
