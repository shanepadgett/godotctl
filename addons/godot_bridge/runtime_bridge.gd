extends Node

const SNAPSHOT_INTERVAL_MSEC := 400
const MAX_NODES := 96
const MAX_PROPERTIES_PER_NODE := 12

var _last_snapshot_at_msec := 0


func _ready() -> void:
	_register_message_capture()
	set_process(true)
	_send_runtime_event("bridge_attached", {
		"bridge_version": "1",
		"scene_path": _current_scene_path(),
	})
	_send_snapshot()


func _exit_tree() -> void:
	_send_runtime_event("bridge_detached", {})


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_snapshot_at_msec >= SNAPSHOT_INTERVAL_MSEC:
		_send_snapshot()


func _register_message_capture() -> void:
	if not EngineDebugger.has_method("register_message_capture"):
		return
	EngineDebugger.register_message_capture("godot_bridge", Callable(self, "_on_debugger_message"))


func _on_debugger_message(message: String, data: Array) -> bool:
	var kind := str(message).strip_edges()
	if kind != "runtime_command" and kind != "godot_bridge:runtime_command":
		return false

	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_apply_command(item)

	return true


func _apply_command(command: Dictionary) -> void:
	var op := str(command.get("op", "")).strip_edges()
	var payload = command.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}

	if op == "input_action_press":
		var action := str(payload.get("action", "")).strip_edges()
		if action.is_empty():
			return
		var strength := float(payload.get("strength", 1.0))
		Input.action_press(action, strength)
		return

	if op == "input_action_release":
		var release_action := str(payload.get("action", "")).strip_edges()
		if release_action.is_empty():
			return
		Input.action_release(release_action)
		return

	if op == "input_event":
		var decoded_event := _decode_input_event(payload.get("event", null))
		if decoded_event != null:
			Input.parse_input_event(decoded_event)
		return

	if op == "step":
		var frames := int(payload.get("frames", 1))
		if frames < 1:
			frames = 1
		_call_step_async(frames)
		return


func _send_snapshot() -> void:
	if not EngineDebugger.is_active():
		return

	_last_snapshot_at_msec = Time.get_ticks_msec()
	var snapshot := _collect_snapshot()
	_send_runtime_event("snapshot", snapshot)


func _collect_snapshot() -> Dictionary:
	var rows: Array = []
	var queue: Array = []
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		return {
			"nodes": rows,
			"count": 0,
			"truncated": false,
			"frame": int(Engine.get_frames_drawn()),
		}

	queue.append(root)
	var count := 0
	var truncated := false

	while queue.size() > 0:
		var node_value = queue.pop_front()
		if not (node_value is Node):
			continue
		var node: Node = node_value

		count += 1
		if rows.size() < MAX_NODES:
			var property_snapshot := _collect_properties(node)
			rows.append({
				"path": str(node.get_path()),
				"name": str(node.name),
				"type": node.get_class(),
				"properties": property_snapshot.get("properties", []),
				"property_count": int(property_snapshot.get("property_count", 0)),
				"properties_truncated": bool(property_snapshot.get("truncated", false)),
			})
		else:
			truncated = true

		for child in node.get_children():
			if child is Node:
				queue.append(child)

	rows.sort_custom(Callable(self, "_compare_nodes"))

	return {
		"nodes": rows,
		"count": count,
		"truncated": truncated,
		"frame": int(Engine.get_frames_drawn()),
	}


func _collect_properties(node: Node) -> Dictionary:
	var rows: Array = []
	var property_count := 0
	for property_info in node.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue
		var name := str(property_info.get("name", "")).strip_edges()
		if name.is_empty() or name.begins_with("_"):
			continue
		var usage := int(property_info.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue

		property_count += 1

		if rows.size() < MAX_PROPERTIES_PER_NODE:
			var serialized := _serialize_value(node.get(name))
			rows.append({
				"name": name,
				"value": serialized.get("value", null),
				"value_text": str(serialized.get("value_text", "")),
				"value_type": str(serialized.get("value_type", "")),
			})

	rows.sort_custom(Callable(self, "_compare_properties"))
	return {
		"properties": rows,
		"property_count": property_count,
		"truncated": property_count > rows.size(),
	}


func _call_step_async(frames: int) -> void:
	_step_async(frames)


func _step_async(frames: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var was_paused := tree.paused
	if was_paused:
		tree.paused = false

	for _i in range(frames):
		await tree.process_frame

	if was_paused:
		tree.paused = true

	_send_runtime_event("log", {
		"level": "info",
		"message": "step advanced %d frame(s)" % frames,
	})
	_send_snapshot()


func _serialize_value(value: Variant) -> Dictionary:
	var value_type := typeof(value)
	if value_type == TYPE_NIL:
		return {"value": null, "value_text": "null", "value_type": "Nil"}
	if value_type == TYPE_BOOL:
		return {"value": bool(value), "value_text": "true" if bool(value) else "false", "value_type": "bool"}
	if value_type == TYPE_INT:
		return {"value": int(value), "value_text": str(int(value)), "value_type": "int"}
	if value_type == TYPE_FLOAT:
		return {"value": float(value), "value_text": str(float(value)), "value_type": "float"}
	if value_type == TYPE_STRING:
		return {"value": str(value), "value_text": str(value), "value_type": "String"}
	return {"value": null, "value_text": str(value), "value_type": type_string(value_type)}


func _decode_input_event(raw_event: Variant) -> InputEvent:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return null

	var data: Dictionary = raw_event
	var event_type := str(data.get("type", "")).strip_edges()
	if event_type == "key":
		event_type = "InputEventKey"
	if event_type == "mouse_button":
		event_type = "InputEventMouseButton"
	if event_type == "action":
		event_type = "InputEventAction"
	if event_type == "InputEventAction":
		var action := str(data.get("action", "")).strip_edges()
		if action.is_empty():
			return null
		var action_event := InputEventAction.new()
		action_event.action = action
		action_event.pressed = bool(data.get("pressed", true))
		action_event.strength = float(data.get("strength", 1.0))
		return action_event

	if event_type == "InputEventKey":
		var keycode_value = data.get("keycode", data.get("physical_keycode", null))
		if typeof(keycode_value) != TYPE_INT:
			return null
		var key_event := InputEventKey.new()
		key_event.keycode = int(keycode_value)
		key_event.pressed = bool(data.get("pressed", true))
		key_event.shift_pressed = bool(data.get("shift", false))
		key_event.alt_pressed = bool(data.get("alt", false))
		key_event.ctrl_pressed = bool(data.get("ctrl", false))
		key_event.meta_pressed = bool(data.get("meta", false))
		return key_event

	if event_type == "InputEventMouseButton":
		if typeof(data.get("button_index", null)) != TYPE_INT:
			return null
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(data.get("button_index", 0))
		mouse_event.pressed = bool(data.get("pressed", true))
		mouse_event.double_click = bool(data.get("double_click", false))
		mouse_event.shift_pressed = bool(data.get("shift", false))
		mouse_event.alt_pressed = bool(data.get("alt", false))
		mouse_event.ctrl_pressed = bool(data.get("ctrl", false))
		mouse_event.meta_pressed = bool(data.get("meta", false))
		return mouse_event

	return null


func _send_runtime_event(event_name: String, payload: Dictionary) -> void:
	if not EngineDebugger.is_active():
		return

	var body := {
		"event": event_name,
		"captured_at_msec": Time.get_ticks_msec(),
	}
	for key in payload.keys():
		body[key] = payload[key]

	EngineDebugger.send_message("godot_bridge:runtime_event", [body])


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	if current == null:
		return ""
	var scene_file := str(current.scene_file_path).strip_edges()
	if scene_file.is_empty():
		return str(current.get_path())
	return scene_file


func _compare_nodes(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))


func _compare_properties(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))
