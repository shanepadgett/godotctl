@tool
extends Node

signal connected_to_daemon(project_name: String)

const DAEMON_URL := "ws://127.0.0.1:6505/ws"
const RECONNECT_DELAY_MIN_MSEC := 2000
const RECONNECT_DELAY_MAX_MSEC := 30000
const AUTO_START_COOLDOWN_MSEC := 15000

var _socket := WebSocketPeer.new()
var _hello_sent := false
var _connecting := false
var _project_name := ""
var _next_retry_at_msec := 0
var _retry_delay_msec := RECONNECT_DELAY_MIN_MSEC
var _connect_attempt_count := 0
var _next_auto_start_at_msec := 0
var _auto_start_enabled := true


func start(auto_start_enabled: bool = true) -> void:
	_project_name = str(ProjectSettings.get_setting("application/config/name", ""))
	_auto_start_enabled = auto_start_enabled
	print("godot_bridge: daemon client starting")
	set_process(true)
	_connect()


func stop() -> void:
	print("godot_bridge: daemon client stopping")
	set_process(false)
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_hello_sent = false
	_connecting = false
	_connect_attempt_count = 0
	_retry_delay_msec = RECONNECT_DELAY_MIN_MSEC


func _process(_delta: float) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING or _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.poll()

	match _socket.get_ready_state():
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
	_socket.send_text(JSON.stringify(payload))
	_hello_sent = true
	_connecting = false


func _read_messages() -> void:
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(packet)
		if typeof(data) != TYPE_DICTIONARY:
			continue

		if data.get("type", "") == "welcome":
			_on_connected()
			connected_to_daemon.emit(_project_name)
		elif data.get("type", "") == "tool_invoke":
			_handle_tool_invoke(data)


func _handle_tool_invoke(data: Dictionary) -> void:
	var request_id := str(data.get("id", ""))
	var tool := str(data.get("tool", ""))

	if request_id.is_empty():
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

	_socket.send_text(JSON.stringify(payload))


func _on_connected() -> void:
	_connect_attempt_count = 0
	_retry_delay_msec = RECONNECT_DELAY_MIN_MSEC
	_next_retry_at_msec = 0


func _on_connect_failed(reason: String) -> void:
	_connecting = false
	_next_retry_at_msec = Time.get_ticks_msec() + _retry_delay_msec
	_retry_delay_msec = min(_retry_delay_msec * 2, RECONNECT_DELAY_MAX_MSEC)

	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		push_warning("godot_bridge: daemon unavailable (%s)" % reason)

	_maybe_start_daemon()


func _maybe_start_daemon() -> void:
	if not _auto_start_enabled:
		return

	var now := Time.get_ticks_msec()
	if now < _next_auto_start_at_msec:
		return

	_next_auto_start_at_msec = now + AUTO_START_COOLDOWN_MSEC

	for executable in _daemon_candidates():
		var pid := OS.create_process(executable, ["daemon", "start"], false)
		if pid != -1:
			print("godot_bridge: launched daemon via %s (pid=%d)" % [executable, pid])
			return

	if _connect_attempt_count == 1 or _connect_attempt_count % 5 == 0:
		push_warning("godot_bridge: could not launch daemon automatically")


func _daemon_candidates() -> Array[String]:
	var plugin_binary := ProjectSettings.globalize_path("res://addons/godot_bridge/bin/godotctl.exe")
	return [plugin_binary, "godotctl.exe", "godotctl"]
