@tool
extends Node

signal connected_to_daemon(project_name: String)

const DAEMON_URL := "ws://127.0.0.1:6505/ws"
const RECONNECT_DELAY_MIN_MSEC := 2000
const RECONNECT_DELAY_MAX_MSEC := 30000
const AUTO_START_COOLDOWN_MSEC := 15000
const CONNECT_WATCHDOG_MSEC := 300

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


func start(auto_start_enabled: bool = true) -> void:
	_project_name = str(ProjectSettings.get_setting("application/config/name", ""))
	_auto_start_enabled = auto_start_enabled
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
	var payload := {
		"type": "hello",
		"project": _project_name,
	}
	var validation_error := _validate_hello_message(payload)
	if not validation_error.is_empty():
		push_warning("godot_bridge: invalid hello payload: %s" % validation_error)
		return
	_socket.send_text(JSON.stringify(payload))
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
			_send_tool_result(invalid_request_id, false, {}, "invalid tool_invoke: %s" % validation_error)
		return

	var request_id := str(data.get("id", ""))
	var tool := str(data.get("tool", ""))
	var args = data.get("args", {})

	if request_id.is_empty():
		return
	if typeof(args) != TYPE_DICTIONARY:
		_send_tool_result(request_id, false, {}, "invalid tool_invoke: args must be a dictionary")
		return

	if tool == "ping":
		print("godot_bridge: received tools.ping request")
		_send_tool_result(request_id, true, {"message": "pong from godot_bridge"}, "")
		return

	_send_tool_result(request_id, false, {}, "unknown tool: %s" % tool)


func _send_tool_result(request_id: String, ok: bool, result: Dictionary, error_message: String) -> void:
	var payload := {
		"type": "tool_result",
		"id": request_id,
		"ok": ok,
	}

	if ok:
		payload["result"] = result
	else:
		payload["error"] = error_message

	var validation_error := _validate_tool_result_message(payload)
	if not validation_error.is_empty():
		push_warning("godot_bridge: invalid tool_result payload: %s" % validation_error)
		return

	_socket.send_text(JSON.stringify(payload))


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

	var ok := bool(data.get("ok", false))
	var has_result := data.has("result") and typeof(data.get("result")) == TYPE_DICTIONARY
	var has_error := str(data.get("error", "")).strip_edges() != ""

	if ok:
		if not has_result:
			return "result is required when ok=true"
		if has_error:
			return "error must be empty when ok=true"
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

	for executable in _daemon_candidates():
		var pid := OS.create_process(executable, args, false)
		if pid != -1:
			print("godot_bridge: launched daemon via %s (pid=%d)" % [executable, pid])
			return

	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		push_warning("godot_bridge: could not launch daemon automatically")


func _maybe_watchdog_start_daemon() -> void:
	if _auto_start_attempted_this_connect:
		return

	if Time.get_ticks_msec() - _connect_started_at_msec < CONNECT_WATCHDOG_MSEC:
		return

	_auto_start_attempted_this_connect = true
	_maybe_start_daemon()


func _daemon_candidates() -> Array[String]:
	var plugin_binary := ProjectSettings.globalize_path("res://addons/godot_bridge/bin/godotctl.exe")
	return [plugin_binary, "godotctl.exe", "godotctl"]


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
