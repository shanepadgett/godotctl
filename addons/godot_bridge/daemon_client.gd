@tool
extends Node

signal connected_to_daemon(project_name: String)

const DAEMON_URL := "ws://127.0.0.1:6505/ws"
const RECONNECT_DELAY_MIN_MSEC := 2000
const RECONNECT_DELAY_MAX_MSEC := 30000
const AUTO_START_COOLDOWN_MSEC := 15000
const CONNECT_WATCHDOG_MSEC := 300
const MAX_TOOL_RESULT_JSON_BYTES := 60000
const TOOL_EXECUTOR_SCRIPT := preload("res://addons/godot_bridge/tool_executor.gd")

var _socket := WebSocketPeer.new()
var _hello_sent := false
var _connecting := false
var _project_name := ""
var _next_retry_at_msec := 0
var _retry_delay_msec := RECONNECT_DELAY_MIN_MSEC
var _connect_attempt_count := 0
var _next_auto_start_at_msec := 0
var _auto_start_enabled := true
var _owner_token := ""
var _owns_daemon := false
var _connect_started_at_msec := 0
var _auto_start_attempted_this_connect := false
var _tool_executor: RefCounted = TOOL_EXECUTOR_SCRIPT.new()
var _runtime_bridge_service: RefCounted = null


func start(auto_start_enabled: bool = true) -> void:
	_project_name = str(ProjectSettings.get_setting("application/config/name", ""))
	_auto_start_enabled = auto_start_enabled
	if _tool_executor == null:
		_tool_executor = TOOL_EXECUTOR_SCRIPT.new()
	if _tool_executor.has_method("set_host"):
		_tool_executor.call("set_host", self)
	if _runtime_bridge_service != null and _runtime_bridge_service.has_method("set_host"):
		_runtime_bridge_service.call("set_host", self)
	print("godot_bridge: daemon client starting")
	set_process(true)
	_connect()


func stop() -> void:
	print("godot_bridge: daemon client stopping")
	_maybe_stop_owned_daemon()
	set_process(false)
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_hello_sent = false
	_connecting = false
	_connect_attempt_count = 0
	_retry_delay_msec = RECONNECT_DELAY_MIN_MSEC
	_owns_daemon = false
	_connect_started_at_msec = 0
	_auto_start_attempted_this_connect = false
	if _runtime_bridge_service != null and _runtime_bridge_service.has_method("set_running_hint"):
		_runtime_bridge_service.call("set_running_hint", false)


func set_runtime_bridge_service(service: RefCounted) -> void:
	_runtime_bridge_service = service
	if _runtime_bridge_service != null and _runtime_bridge_service.has_method("set_host"):
		_runtime_bridge_service.call("set_host", self)


func get_runtime_bridge_service() -> Variant:
	return _runtime_bridge_service


func _process(_delta: float) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING or _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.poll()

	match _socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_maybe_watchdog_start_daemon()
		WebSocketPeer.STATE_OPEN:
			if not _hello_sent:
				_send_hello()
			_read_messages()
		WebSocketPeer.STATE_CLOSED:
			if _connecting:
				_on_connect_failed("connection closed")
			if Time.get_ticks_msec() >= _next_retry_at_msec:
				_connect()


func _connect() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_socket = WebSocketPeer.new()

	_connecting = true
	_hello_sent = false
	_connect_attempt_count += 1
	_connect_started_at_msec = Time.get_ticks_msec()
	_auto_start_attempted_this_connect = false
	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		print("godot_bridge: attempting daemon connection (attempt %d)" % _connect_attempt_count)

	var err := _socket.connect_to_url(DAEMON_URL)
	if err != OK:
		_on_connect_failed("connect_to_url failed: %s" % error_string(err))


func _send_hello() -> void:
	var tools: Array[String] = []
	if _tool_executor != null and _tool_executor.has_method("list_tools"):
		var listed_tools = _tool_executor.call("list_tools")
		if typeof(listed_tools) == TYPE_ARRAY:
			for item in listed_tools:
				if typeof(item) != TYPE_STRING:
					continue
				var tool_name := str(item).strip_edges()
				if tool_name.is_empty():
					continue
				tools.append(tool_name)

	var payload := {
		"type": "hello",
		"project": _project_name,
		"tools": tools,
	}
	var validation_error := _validate_hello_message(payload)
	if not validation_error.is_empty():
		push_warning("godot_bridge: invalid hello payload: %s" % validation_error)
		return
	var send_err := _socket.send_text(JSON.stringify(payload))
	if send_err != OK:
		if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_socket.close()
		_hello_sent = false
		_on_connect_failed("hello send failed: %s" % error_string(send_err))
		return
	_hello_sent = true
	_connecting = false


func _read_messages() -> void:
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(packet)
		if typeof(data) != TYPE_DICTIONARY:
			continue

		var msg_type := str(data.get("type", "")).strip_edges()
		if msg_type.is_empty():
			push_warning("godot_bridge: received message without type")
			continue

		if msg_type == "welcome":
			_on_connected(data)
			connected_to_daemon.emit(_project_name)
		elif msg_type == "tool_invoke":
			_handle_tool_invoke(data)
		elif msg_type == "ping":
			_socket.send_text(JSON.stringify({"type": "pong"}))
		elif msg_type == "pong":
			pass
		else:
			push_warning("godot_bridge: ignoring unknown message type: %s" % msg_type)


func _handle_tool_invoke(data: Dictionary) -> void:
	var validation_error := _validate_tool_invoke_message(data)
	if not validation_error.is_empty():
		push_warning("godot_bridge: invalid tool_invoke payload: %s" % validation_error)
		var invalid_request_id := str(data.get("id", ""))
		if not invalid_request_id.is_empty():
			_send_tool_result(invalid_request_id, {
				"ok": false,
				"error": "invalid tool_invoke: %s" % validation_error,
				"error_code": "INVALID_ARGS",
			})
		return

	var request_id := str(data.get("id", ""))
	var tool := str(data.get("tool", ""))
	var args = data.get("args", {})

	if request_id.is_empty():
		return
	if typeof(args) != TYPE_DICTIONARY:
		_send_tool_result(request_id, {
			"ok": false,
			"error": "invalid tool_invoke: args must be a dictionary",
			"error_code": "INVALID_ARGS",
		})
		return

	if _tool_executor == null or not _tool_executor.has_method("execute"):
		_send_tool_result(request_id, {
			"ok": false,
			"error": "tool executor unavailable",
			"error_code": "INTERNAL",
		})
		return

	var execution = _tool_executor.call("execute", tool, args)
	if typeof(execution) != TYPE_DICTIONARY:
		_send_tool_result(request_id, {
			"ok": false,
			"error": "tool executor returned invalid response",
			"error_code": "INTERNAL",
		})
		return

	_send_tool_result(request_id, execution)


func _send_tool_result(request_id: String, execution: Dictionary) -> void:
	var normalized := execution
	if typeof(normalized.get("ok", null)) != TYPE_BOOL:
		normalized = {
			"ok": false,
			"error": "invalid tool response: ok must be a bool",
			"error_code": "INTERNAL",
		}

	var ok := bool(normalized.get("ok", false))
	var payload := {
		"type": "tool_result",
		"id": request_id,
		"ok": ok,
	}

	if ok:
		payload["result"] = normalized.get("result", {})
	else:
		var error_message := str(normalized.get("error", "tool call failed")).strip_edges()
		if error_message.is_empty():
			error_message = "tool call failed"
		payload["error"] = error_message
		var error_code := str(normalized.get("error_code", "")).strip_edges()
		if not error_code.is_empty():
			payload["error_code"] = error_code

	var validation_error := _validate_tool_result_message(payload)
	if not validation_error.is_empty():
		push_warning("godot_bridge: invalid tool_result payload: %s" % validation_error)
		return

	var payload_text := JSON.stringify(payload)
	var payload_size := payload_text.to_utf8_buffer().size()
	if payload_size > MAX_TOOL_RESULT_JSON_BYTES:
		payload_text = _tool_error_payload_json(request_id, "tool result payload too large: %d bytes (limit %d)" % [payload_size, MAX_TOOL_RESULT_JSON_BYTES], "INTERNAL")

	var send_err := _socket.send_text(payload_text)
	if send_err == OK:
		return

	var fallback_text := _tool_error_payload_json(request_id, "failed to send tool result: %s" % error_string(send_err), "INTERNAL")
	var fallback_err := _socket.send_text(fallback_text)
	if fallback_err != OK:
		push_warning("godot_bridge: failed to send tool result fallback: %s" % error_string(fallback_err))


func _tool_error_payload_json(request_id: String, message: String, error_code: String) -> String:
	var payload := {
		"type": "tool_result",
		"id": request_id,
		"ok": false,
		"error": str(message).strip_edges(),
		"error_code": str(error_code).strip_edges(),
	}

	var validation_error := _validate_tool_result_message(payload)
	if validation_error.is_empty():
		return JSON.stringify(payload)

	return JSON.stringify({
		"type": "tool_result",
		"id": request_id,
		"ok": false,
		"error": "tool call failed",
		"error_code": "INTERNAL",
	})


func _validate_hello_message(data: Dictionary) -> String:
	if str(data.get("type", "")).strip_edges() != "hello":
		return "type must be 'hello'"

	if data.has("project") and typeof(data.get("project")) != TYPE_STRING:
		return "project must be a string"

	if data.has("tools"):
		if typeof(data.get("tools")) != TYPE_ARRAY:
			return "tools must be an array"
		for item in data.get("tools"):
			if typeof(item) != TYPE_STRING:
				return "tools entries must be strings"

	return ""


func _validate_tool_invoke_message(data: Dictionary) -> String:
	if str(data.get("type", "")).strip_edges() != "tool_invoke":
		return "type must be 'tool_invoke'"

	var request_id := str(data.get("id", "")).strip_edges()
	if request_id.is_empty():
		return "id is required"

	var tool := str(data.get("tool", "")).strip_edges()
	if tool.is_empty():
		return "tool is required"

	if data.has("args") and typeof(data.get("args")) != TYPE_DICTIONARY:
		return "args must be a dictionary"

	return ""


func _validate_tool_result_message(data: Dictionary) -> String:
	if str(data.get("type", "")).strip_edges() != "tool_result":
		return "type must be 'tool_result'"

	var request_id := str(data.get("id", "")).strip_edges()
	if request_id.is_empty():
		return "id is required"

	if typeof(data.get("ok", null)) != TYPE_BOOL:
		return "ok must be a bool"
	if data.has("error_code"):
		if typeof(data.get("error_code")) != TYPE_STRING:
			return "error_code must be a string"
		if str(data.get("error_code", "")).strip_edges().is_empty():
			return "error_code must be non-empty when provided"

	var ok := bool(data.get("ok", false))
	var has_result := data.has("result") and typeof(data.get("result")) == TYPE_DICTIONARY
	var has_error := str(data.get("error", "")).strip_edges() != ""
	var has_error_code := data.has("error_code")

	if ok:
		if not has_result:
			return "result is required when ok=true"
		if has_error:
			return "error must be empty when ok=true"
		if has_error_code:
			return "error_code must be empty when ok=true"
		return ""

	if not has_error:
		return "error is required when ok=false"
	if has_result:
		return "result must be empty when ok=false"

	return ""


func _on_connected(data: Dictionary) -> void:
	_connect_attempt_count = 0
	_retry_delay_msec = RECONNECT_DELAY_MIN_MSEC
	_next_retry_at_msec = 0

	var daemon_owner_token := str(data.get("owner_token", ""))
	_owns_daemon = not _owner_token.is_empty() and _owner_token == daemon_owner_token
	if _owns_daemon:
		print("godot_bridge: daemon ownership confirmed")


func _on_connect_failed(reason: String) -> void:
	_connecting = false
	_next_retry_at_msec = Time.get_ticks_msec() + _retry_delay_msec
	_retry_delay_msec = min(_retry_delay_msec * 2, RECONNECT_DELAY_MAX_MSEC)

	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		push_warning("godot_bridge: daemon unavailable (%s)" % reason)

	if not _auto_start_attempted_this_connect:
		_auto_start_attempted_this_connect = true
		_maybe_start_daemon()


func _maybe_start_daemon() -> void:
	if not _auto_start_enabled:
		return

	var now := Time.get_ticks_msec()
	if now < _next_auto_start_at_msec:
		return

	_next_auto_start_at_msec = now + AUTO_START_COOLDOWN_MSEC

	if _owner_token.is_empty():
		_owner_token = _generate_owner_token()

	var args := ["daemon", "start", "--owner-token", _owner_token]
	var candidates := _daemon_candidates()
	for executable in candidates:
		var pid := OS.create_process(executable, args, false)
		if pid != -1:
			print("godot_bridge: launched daemon via %s (pid=%d)" % [executable, pid])
			return

	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		push_warning("godot_bridge: could not launch daemon automatically; checked %s" % _describe_daemon_candidates(candidates))


func _maybe_watchdog_start_daemon() -> void:
	if _auto_start_attempted_this_connect:
		return

	if Time.get_ticks_msec() - _connect_started_at_msec < CONNECT_WATCHDOG_MSEC:
		return

	_auto_start_attempted_this_connect = true
	_maybe_start_daemon()


func _daemon_candidates() -> Array[String]:
	var candidates: Array[String] = []
	_append_resolved_command_candidate(candidates, "godotctl.exe")
	_append_resolved_command_candidate(candidates, "godotctl")
	_append_existing_command_candidate(candidates, ProjectSettings.globalize_path("res://bin/godotctl.exe"))
	_append_existing_command_candidate(candidates, ProjectSettings.globalize_path("res://bin/godotctl"))
	for executable in _common_daemon_install_paths():
		_append_existing_command_candidate(candidates, executable)
	return candidates


func _common_daemon_install_paths() -> Array[String]:
	var candidates: Array[String] = []
	if not OS.has_feature("windows"):
		var home := OS.get_environment("HOME").strip_edges()
		if not home.is_empty():
			candidates.append(home.path_join(".local/bin/godotctl"))
			candidates.append(home.path_join("bin/godotctl"))
		return candidates

	var user_profile := OS.get_environment("USERPROFILE").strip_edges()
	if not user_profile.is_empty():
		candidates.append(user_profile.path_join(".local/bin/godotctl.exe"))
		candidates.append(user_profile.path_join("bin/godotctl.exe"))

	var local_app_data := OS.get_environment("LOCALAPPDATA").strip_edges()
	if not local_app_data.is_empty():
		candidates.append(local_app_data.path_join("Microsoft/WinGet/Links/godotctl.exe"))

	return candidates


func _describe_daemon_candidates(candidates: Array[String]) -> String:
	if candidates.is_empty():
		return "<none>"
	return ", ".join(candidates)


func _append_resolved_command_candidate(candidates: Array[String], executable: String) -> void:
	var resolved := _resolve_command_from_path(executable)
	if resolved.is_empty():
		return
	_append_existing_command_candidate(candidates, resolved)


func _append_existing_command_candidate(candidates: Array[String], executable: String) -> void:
	if executable.is_empty():
		return
	if not FileAccess.file_exists(executable):
		return
	if candidates.has(executable):
		return
	candidates.append(executable)


func _resolve_command_from_path(executable: String) -> String:
	var path_env := OS.get_environment("PATH").strip_edges()
	if path_env.is_empty():
		return ""

	var path_separator := ":"
	if OS.has_feature("windows"):
		path_separator = ";"

	for directory in path_env.split(path_separator, false):
		var trimmed_directory := directory.strip_edges()
		if trimmed_directory.begins_with("\"") and trimmed_directory.ends_with("\"") and trimmed_directory.length() >= 2:
			trimmed_directory = trimmed_directory.substr(1, trimmed_directory.length() - 2)
		if trimmed_directory.is_empty():
			continue

		for lookup_name in _path_lookup_names(executable):
			var candidate := trimmed_directory.path_join(lookup_name)
			if FileAccess.file_exists(candidate):
				return candidate

	return ""


func _path_lookup_names(executable: String) -> Array[String]:
	var names: Array[String] = [executable]
	if not OS.has_feature("windows"):
		return names
	if executable.contains("."):
		return names

	var pathext_env := OS.get_environment("PATHEXT").strip_edges()
	if pathext_env.is_empty():
		pathext_env = ".COM;.EXE;.BAT;.CMD"

	for extension in pathext_env.split(";", false):
		var trimmed_extension := extension.strip_edges()
		if trimmed_extension.is_empty():
			continue
		var lookup_name := executable + trimmed_extension
		if names.has(lookup_name):
			continue
		names.append(lookup_name)

	return names


func _maybe_stop_owned_daemon() -> void:
	if not _owns_daemon:
		return
	if _owner_token.is_empty():
		return

	var args := ["daemon", "stop", "--owner-token", _owner_token]
	for executable in _daemon_candidates():
		var pid := OS.create_process(executable, args, false)
		if pid != -1:
			print("godot_bridge: requested daemon stop via %s (pid=%d)" % [executable, pid])
			return

	push_warning("godot_bridge: could not request owned daemon stop")


func _generate_owner_token() -> String:
	var time_part := Time.get_unix_time_from_system()
	var tick_part := Time.get_ticks_usec()
	return "%s-%s" % [str(time_part), str(tick_part)]
