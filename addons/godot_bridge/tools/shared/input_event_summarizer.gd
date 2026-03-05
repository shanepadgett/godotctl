@tool
extends RefCounted


func summarize(event: InputEvent) -> Dictionary:
	if event == null:
		return {
			"type": "InputEvent",
			"summary": "null",
		}

	return {
		"type": event.get_class(),
		"summary": _summary(event),
	}


func _summary(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return "key(device=%d,keycode=%d,physical=%d,unicode=%d,ctrl=%d,alt=%d,shift=%d,meta=%d)" % [
			int(key_event.device),
			int(key_event.keycode),
			int(key_event.physical_keycode),
			int(key_event.unicode),
			int(key_event.ctrl_pressed),
			int(key_event.alt_pressed),
			int(key_event.shift_pressed),
			int(key_event.meta_pressed),
		]

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		return "mouse_button(device=%d,button=%d,double=%d,ctrl=%d,alt=%d,shift=%d,meta=%d)" % [
			int(mouse_button.device),
			int(mouse_button.button_index),
			int(mouse_button.double_click),
			int(mouse_button.ctrl_pressed),
			int(mouse_button.alt_pressed),
			int(mouse_button.shift_pressed),
			int(mouse_button.meta_pressed),
		]

	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event
		return "joy_button(device=%d,button=%d)" % [
			int(joy_button.device),
			int(joy_button.button_index),
		]

	if event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event
		return "joy_motion(device=%d,axis=%d,value=%s)" % [
			int(joy_motion.device),
			int(joy_motion.axis),
			_format_float(joy_motion.axis_value),
		]

	if event is InputEventAction:
		var action_event: InputEventAction = event
		return "action(name=%s,strength=%s)" % [
			str(action_event.action),
			_format_float(action_event.strength),
		]

	var text := str(event.as_text()).strip_edges()
	if text.is_empty():
		text = event.get_class()

	return text


func _format_float(value: float) -> String:
	return "%.6f" % value
