@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")

const MAX_LOG_ROWS := 2000

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()

var _host: Node = null
var _log_rows: Array = []
var _next_log_cursor := 1
var _debug_sessions := {}
var _bridge_attached := false
var _bridge_session_id := -1
var _bridge_info := {}
var _running_hint := false
var _requested_scene_path := ""
var _snapshot := {
	"captured_at_msec": 0,
	"frame": 0,
	"nodes": [],
	"count": 0,
	"truncated": false,
	"node_lookup": {},
}


func set_host(host: Node) -> void:
	_host = host


func set_running_hint(running: bool) -> void:
	_running_hint = running
	if not running:
		_bridge_attached = false
		_bridge_session_id = -1


func register_debug_session(session_id: int, session: Variant = null) -> void:
	_debug_sessions[session_id] = session


func unregister_debug_session(session_id: int) -> void:
	_debug_sessions.erase(session_id)
	if _bridge_session_id == session_id:
		_bridge_attached = false
		_bridge_session_id = -1


func capture_message(message: String, data: Array, session_id: int) -> bool:
	var kind := str(message).strip_edges()
	if kind == "runtime_event":
		kind = "godot_bridge:runtime_event"
	if kind == "runtime_log":
		kind = "godot_bridge:runtime_log"
	if kind.begins_with("godot_bridge:"):
		if kind != "godot_bridge:runtime_event" and kind != "godot_bridge:runtime_log":
			return false
		for item in data:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			_handle_runtime_event(item, session_id)
		return true

	if kind == "stdout" or kind == "stderr" or kind == "output":
		_capture_log_payload(kind, data, session_id)
		return true

	return false


func execute_start(args: Dictionary) -> Dictionary:
	var editor = _get_editor_interface()
	if editor == null:
		return _result.error(_errors.EDITOR_STATE, "editor interface is unavailable")

	var running := _is_running(editor)
	var requested_scene_path := str(args.get("scene_path", "")).strip_edges()
	if running:
		_running_hint = true
		if not requested_scene_path.is_empty():
			_requested_scene_path = requested_scene_path
		return _result.success("run already active", _status_payload(editor, _requested_scene_path, false, true))

	var scene_path := ""
	if not requested_scene_path.is_empty():
		var scene_path_result := _validate_scene_path(requested_scene_path)
		if not bool(scene_path_result.get("ok", false)):
			return scene_path_result
		scene_path = str(scene_path_result.get("scene_path", ""))

	var play_result: Variant = null
	if scene_path.is_empty():
		if not editor.has_method("play_main_scene"):
			return _result.error(_errors.EDITOR_STATE, "play_main_scene is unavailable")
		play_result = editor.call("play_main_scene")
	else:
		if not editor.has_method("play_custom_scene"):
			return _result.error(_errors.EDITOR_STATE, "play_custom_scene is unavailable")
		play_result = editor.call("play_custom_scene", scene_path)

	if typeof(play_result) == TYPE_INT and int(play_result) != OK:
		return _result.error(_errors.EDITOR_STATE, "failed to start run: %s" % error_string(int(play_result)))

	_running_hint = true
	_requested_scene_path = scene_path
	_bridge_attached = false
	_bridge_session_id = -1
	_bridge_info = {}
	_snapshot = {
		"captured_at_msec": 0,
		"frame": 0,
		"nodes": [],
		"count": 0,
		"truncated": false,
		"node_lookup": {},
	}
	_append_log("info", "run started", "editor", -1)

	return _result.success("run started", _status_payload(editor, scene_path, true, true))


func execute_stop(_args: Dictionary) -> Dictionary:
	var editor = _get_editor_interface()
	if editor == null:
		return _result.error(_errors.EDITOR_STATE, "editor interface is unavailable")

	if not _is_running(editor):
		_running_hint = false
		_requested_scene_path = ""
		return _result.success("run already stopped", _status_payload(editor, "", false, false))

	if not editor.has_method("stop_playing_scene"):
		return _result.error(_errors.EDITOR_STATE, "stop_playing_scene is unavailable")

	var stop_result: Variant = editor.call("stop_playing_scene")
	if typeof(stop_result) == TYPE_INT and int(stop_result) != OK:
		return _result.error(_errors.EDITOR_STATE, "failed to stop run: %s" % error_string(int(stop_result)))

	_running_hint = false
	_requested_scene_path = ""
	_bridge_attached = false
	_bridge_session_id = -1
	_append_log("info", "run stopped", "editor", -1)

	return _result.success("run stopped", _status_payload(editor, "", true, false))


func execute_status(_args: Dictionary) -> Dictionary:
	var editor = _get_editor_interface()
	return _result.success("run status", _status_payload(editor, "", false, _safe_running(editor)))


func execute_logs(args: Dictionary) -> Dictionary:
	var cursor := int(args.get("cursor", 0))
	var max_rows := int(args.get("max", 200))
	var level_filter := str(args.get("level", "")).strip_edges().to_lower()
	var contains_filter := str(args.get("contains", ""))
	var follow_window_msec := int(args.get("follow_window_msec", 0))

	if cursor < 0:
		return _result.error(_errors.INVALID_ARGS, "cursor must be >= 0")
	if max_rows < 0:
		return _result.error(_errors.INVALID_ARGS, "max must be >= 0")
	if follow_window_msec < 0:
		return _result.error(_errors.INVALID_ARGS, "follow_window_msec must be >= 0")

	follow_window_msec = min(follow_window_msec, 5000)
	if follow_window_msec > 0:
		var now := Time.get_ticks_msec()
		var deadline := now + follow_window_msec
		while Time.get_ticks_msec() < deadline:
			var probe := _filtered_logs(cursor, level_filter, contains_filter)
			if int(probe.get("count", 0)) > 0:
				break
			OS.delay_msec(20)

	var filtered := _filtered_logs(cursor, level_filter, contains_filter)
	var rows: Array = filtered.get("rows", [])
	var count := int(filtered.get("count", 0))
	var returned_rows := rows
	var truncated := false
	if max_rows > 0 and returned_rows.size() > max_rows:
		returned_rows = returned_rows.slice(0, max_rows)
		truncated = true

	var next_cursor := cursor
	if returned_rows.size() > 0:
		next_cursor = int(returned_rows[returned_rows.size() - 1].get("cursor", cursor))

	return _result.success("run logs listed", {
		"cursor": cursor,
		"next_cursor": next_cursor,
		"max": max_rows,
		"level": level_filter,
		"contains": contains_filter,
		"follow_window_msec": follow_window_msec,
		"logs": returned_rows,
		"count": count,
		"returned_count": returned_rows.size(),
		"truncated": truncated,
	})


func execute_tree(args: Dictionary) -> Dictionary:
	var ensure := _ensure_bridge_attached()
	if not bool(ensure.get("ok", false)):
		return ensure

	var max_rows := int(args.get("max", 200))
	if max_rows < 0:
		return _result.error(_errors.INVALID_ARGS, "max must be >= 0")

	var nodes: Array = _snapshot.get("nodes", [])
	var count := int(_snapshot.get("count", nodes.size()))
	var returned_nodes := nodes
	var truncated := bool(_snapshot.get("truncated", false))
	if max_rows > 0 and returned_nodes.size() > max_rows:
		returned_nodes = returned_nodes.slice(0, max_rows)
		truncated = true

	return _result.success("runtime tree listed", {
		"max": max_rows,
		"nodes": returned_nodes,
		"count": count,
		"returned_count": returned_nodes.size(),
		"truncated": truncated,
		"captured_at_msec": int(_snapshot.get("captured_at_msec", 0)),
		"frame": int(_snapshot.get("frame", 0)),
	})


func execute_prop_list(args: Dictionary) -> Dictionary:
	var ensure := _ensure_bridge_attached()
	if not bool(ensure.get("ok", false)):
		return ensure

	var node_path := str(args.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "node_path is required")

	var max_rows := int(args.get("max", 200))
	if max_rows < 0:
		return _result.error(_errors.INVALID_ARGS, "max must be >= 0")

	var lookup: Dictionary = _snapshot.get("node_lookup", {})
	if not lookup.has(node_path):
		return _result.error(_errors.NOT_FOUND, "node not found in runtime snapshot: %s" % node_path)

	var row: Dictionary = lookup.get(node_path, {})
	var props: Array = row.get("properties", [])
	var count := props.size()
	var returned_props := props
	var truncated := false
	if max_rows > 0 and returned_props.size() > max_rows:
		returned_props = returned_props.slice(0, max_rows)
		truncated = true

	return _result.success("runtime properties listed", {
		"node_path": node_path,
		"max": max_rows,
		"properties": returned_props,
		"count": count,
		"returned_count": returned_props.size(),
		"truncated": truncated,
		"captured_at_msec": int(_snapshot.get("captured_at_msec", 0)),
		"frame": int(_snapshot.get("frame", 0)),
	})


func execute_prop_get(args: Dictionary) -> Dictionary:
	var ensure := _ensure_bridge_attached()
	if not bool(ensure.get("ok", false)):
		return ensure

	var node_path := str(args.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "node_path is required")

	var property_name := str(args.get("property", "")).strip_edges()
	if property_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "property is required")

	var lookup: Dictionary = _snapshot.get("node_lookup", {})
	if not lookup.has(node_path):
		return _result.error(_errors.NOT_FOUND, "node not found in runtime snapshot: %s" % node_path)

	var row: Dictionary = lookup.get(node_path, {})
	for prop in row.get("properties", []):
		if typeof(prop) != TYPE_DICTIONARY:
			continue
		if str(prop.get("name", "")) != property_name:
			continue
		return _result.success("runtime property retrieved", {
			"node_path": node_path,
			"property": property_name,
			"value": prop.get("value", null),
			"value_text": str(prop.get("value_text", "")),
			"value_type": str(prop.get("value_type", "")),
			"captured_at_msec": int(_snapshot.get("captured_at_msec", 0)),
			"frame": int(_snapshot.get("frame", 0)),
		})

	return _result.error(_errors.NOT_FOUND, "property not found in runtime snapshot: %s" % property_name)


func execute_input_event(args: Dictionary) -> Dictionary:
	var event_payload = args.get("event", null)
	if typeof(event_payload) != TYPE_DICTIONARY:
		return _result.error(_errors.INVALID_ARGS, "event must be an object")

	var send_result := _send_bridge_command("input_event", {"event": event_payload})
	if not bool(send_result.get("ok", false)):
		return send_result

	return _result.success("runtime input event dispatched", {
		"dispatched": true,
	})


func execute_input_action_press(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	if action.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	var strength := float(args.get("strength", 1.0))
	if strength < 0.0:
		return _result.error(_errors.INVALID_ARGS, "strength must be >= 0")

	var send_result := _send_bridge_command("input_action_press", {
		"action": action,
		"strength": strength,
	})
	if not bool(send_result.get("ok", false)):
		return send_result

	return _result.success("runtime input action pressed", {
		"action": action,
		"strength": strength,
		"dispatched": true,
	})


func execute_input_action_release(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	if action.is_empty():
		return _result.error(_errors.INVALID_ARGS, "action is required")

	var send_result := _send_bridge_command("input_action_release", {
		"action": action,
	})
	if not bool(send_result.get("ok", false)):
		return send_result

	return _result.success("runtime input action released", {
		"action": action,
		"dispatched": true,
	})


func execute_step(args: Dictionary) -> Dictionary:
	var frames := int(args.get("frames", 1))
	if frames <= 0:
		return _result.error(_errors.INVALID_ARGS, "frames must be >= 1")
	if frames > 120:
		return _result.error(_errors.INVALID_ARGS, "frames must be <= 120")

	var send_result := _send_bridge_command("step", {
		"frames": frames,
	})
	if not bool(send_result.get("ok", false)):
		return send_result

	return _result.success("runtime step dispatched", {
		"frames": frames,
		"dispatched": true,
	})


func _status_payload(editor: Variant, requested_scene_path: String, changed: bool, running: bool) -> Dictionary:
	var scene_path := requested_scene_path
	if scene_path.is_empty():
		scene_path = _requested_scene_path
	if scene_path.is_empty():
		scene_path = str(_bridge_info.get("scene_path", ""))

	var state := "stopped"
	if running:
		state = "running"
		if not _bridge_attached:
			state = "starting"

	return {
		"state": state,
		"running": running,
		"changed": changed,
		"requested_scene_path": scene_path,
		"bridge_attached": _bridge_attached,
		"bridge_session_id": _bridge_session_id,
		"bridge_version": str(_bridge_info.get("bridge_version", "")),
		"debug_session_count": _debug_sessions.size(),
		"log_count": _log_rows.size(),
		"last_log_cursor": _next_log_cursor - 1,
		"snapshot_captured_at_msec": int(_snapshot.get("captured_at_msec", 0)),
		"snapshot_frame": int(_snapshot.get("frame", 0)),
		"editor_available": editor != null,
	}


func _validate_scene_path(raw_scene_path: String) -> Dictionary:
	var scene_path := _paths.normalize_res_path(raw_scene_path)
	if scene_path == "res://":
		return _result.error(_errors.INVALID_ARGS, "scene_path must target a .tscn file")
	if not _paths.has_tscn_extension(scene_path):
		return _result.error(_errors.INVALID_ARGS, "scene_path must end with .tscn")
	if not ResourceLoader.exists(scene_path):
		return _result.error(_errors.NOT_FOUND, "scene not found: %s" % scene_path)
	return {
		"ok": true,
		"scene_path": scene_path,
	}


func _get_editor_interface() -> Variant:
	if _host == null:
		return null
	var plugin := _host.get_parent()
	if plugin == null:
		return null
	if not plugin.has_method("get_editor_interface"):
		return null
	return plugin.call("get_editor_interface")


func _safe_running(editor: Variant) -> bool:
	if editor == null:
		return _running_hint
	return _is_running(editor)


func _is_running(editor: Variant) -> bool:
	if editor == null:
		return _running_hint
	if editor.has_method("is_playing_scene"):
		return bool(editor.call("is_playing_scene"))
	return _running_hint


func _capture_log_payload(kind: String, data: Array, session_id: int) -> void:
	for item in data:
		var text := ""
		var level := "info"
		if typeof(item) == TYPE_STRING:
			text = str(item)
		elif typeof(item) == TYPE_DICTIONARY:
			text = str(item.get("message", item.get("text", "")))
			var item_level := str(item.get("level", "")).strip_edges().to_lower()
			if not item_level.is_empty():
				level = item_level
		if text.is_empty():
			continue
		if kind == "stderr":
			level = "error"
		_append_log(level, text, kind, session_id)


func _filtered_logs(cursor: int, level_filter: String, contains_filter: String) -> Dictionary:
	var rows: Array = []
	for row in _log_rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var row_cursor := int(row.get("cursor", 0))
		if row_cursor <= cursor:
			continue
		if not level_filter.is_empty() and str(row.get("level", "")).to_lower() != level_filter:
			continue
		if not contains_filter.is_empty() and str(row.get("message", "")).find(contains_filter) == -1:
			continue
		rows.append(row)

	return {
		"rows": rows,
		"count": rows.size(),
	}


func _handle_runtime_event(event: Dictionary, session_id: int) -> void:
	var event_name := str(event.get("event", "")).strip_edges()
	if event_name.is_empty():
		return

	if event_name == "bridge_attached":
		_bridge_attached = true
		_bridge_session_id = session_id
		_bridge_info = event.duplicate(true)
		_append_log("info", "runtime bridge attached", "runtime", session_id)
		return

	if event_name == "bridge_detached":
		_bridge_attached = false
		if _bridge_session_id == session_id:
			_bridge_session_id = -1
		_append_log("info", "runtime bridge detached", "runtime", session_id)
		return

	if event_name == "snapshot":
		_update_snapshot(event)
		return

	if event_name == "log":
		var level := str(event.get("level", "info")).strip_edges().to_lower()
		var message := str(event.get("message", "")).strip_edges()
		if not message.is_empty():
			_append_log(level, message, "runtime", session_id)


func _update_snapshot(event: Dictionary) -> void:
	var rows: Array = []
	var lookup := {}
	for item in event.get("nodes", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var path := str(item.get("path", "")).strip_edges()
		if path.is_empty():
			continue

		var props: Array = []
		for raw_prop in item.get("properties", []):
			if typeof(raw_prop) != TYPE_DICTIONARY:
				continue
			var prop_name := str(raw_prop.get("name", "")).strip_edges()
			if prop_name.is_empty():
				continue
			props.append({
				"name": prop_name,
				"value": raw_prop.get("value", null),
				"value_text": str(raw_prop.get("value_text", "")),
				"value_type": str(raw_prop.get("value_type", "")),
			})
		props.sort_custom(Callable(self, "_compare_props"))

		var row := {
			"path": path,
			"name": str(item.get("name", "")),
			"type": str(item.get("type", "")),
			"property_count": int(item.get("property_count", props.size())),
			"returned_property_count": props.size(),
			"properties_truncated": bool(item.get("properties_truncated", false)),
			"properties": props,
		}
		rows.append(row)
		lookup[path] = row

	rows.sort_custom(Callable(self, "_compare_nodes"))

	_snapshot = {
		"captured_at_msec": int(event.get("captured_at_msec", Time.get_ticks_msec())),
		"frame": int(event.get("frame", 0)),
		"nodes": rows,
		"count": int(event.get("count", rows.size())),
		"truncated": bool(event.get("truncated", false)),
		"node_lookup": lookup,
	}


func _append_log(level: String, message: String, source: String, session_id: int) -> void:
	var text := str(message).strip_edges()
	if text.is_empty():
		return

	var normalized_level := str(level).strip_edges().to_lower()
	if normalized_level.is_empty():
		normalized_level = "info"

	_log_rows.append({
		"cursor": _next_log_cursor,
		"timestamp_msec": Time.get_ticks_msec(),
		"level": normalized_level,
		"message": text,
		"source": str(source).strip_edges(),
		"session_id": session_id,
	})
	_next_log_cursor += 1

	if _log_rows.size() <= MAX_LOG_ROWS:
		return

	var overflow := _log_rows.size() - MAX_LOG_ROWS
	_log_rows = _log_rows.slice(overflow, _log_rows.size())


func _ensure_bridge_attached() -> Dictionary:
	if _bridge_attached:
		return {"ok": true}
	return _result.error(_errors.EDITOR_STATE, "runtime bridge is not attached; add runtime_bridge.gd as an autoload in the running project")


func _send_bridge_command(op: String, payload: Dictionary) -> Dictionary:
	var ensure := _ensure_bridge_attached()
	if not bool(ensure.get("ok", false)):
		return ensure

	if not _debug_sessions.has(_bridge_session_id):
		return _result.error(_errors.EDITOR_STATE, "runtime bridge session is unavailable")

	var session = _debug_sessions[_bridge_session_id]
	if session == null:
		return _result.error(_errors.EDITOR_STATE, "runtime bridge session is unavailable")
	if not session.has_method("send_message"):
		return _result.error(_errors.EDITOR_STATE, "runtime bridge session cannot send messages")

	var send_result = session.call("send_message", "godot_bridge:runtime_command", [{
		"op": op,
		"payload": payload,
	}])
	if typeof(send_result) == TYPE_INT and int(send_result) != OK:
		return _result.error(_errors.INTERNAL, "failed to dispatch runtime command: %s" % error_string(int(send_result)))

	return {"ok": true}


func _compare_nodes(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))


func _compare_props(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))
