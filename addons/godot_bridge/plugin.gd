@tool
extends EditorPlugin

const DAEMON_CLIENT_SCRIPT := preload("res://addons/godot_bridge/daemon_client.gd")
const RUNTIME_BRIDGE_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/runtime_bridge_service.gd")
const RUNTIME_DEBUGGER_CAPTURE_SCRIPT := preload("res://addons/godot_bridge/runtime_debugger_capture.gd")
const AUTO_START_DAEMON := true

var _daemon_client: Node
var _runtime_bridge_service: RefCounted
var _runtime_debugger_capture: EditorDebuggerPlugin


func _enter_tree() -> void:
	print("godot_bridge: plugin entering tree")
	_runtime_bridge_service = RUNTIME_BRIDGE_SERVICE_SCRIPT.new()
	_runtime_debugger_capture = RUNTIME_DEBUGGER_CAPTURE_SCRIPT.new()
	if _runtime_debugger_capture != null and _runtime_debugger_capture.has_method("set_runtime_bridge_service"):
		_runtime_debugger_capture.call("set_runtime_bridge_service", _runtime_bridge_service)
	if _runtime_debugger_capture != null:
		add_debugger_plugin(_runtime_debugger_capture)

	_daemon_client = DAEMON_CLIENT_SCRIPT.new()
	if _daemon_client != null and _daemon_client.has_method("set_runtime_bridge_service"):
		_daemon_client.call("set_runtime_bridge_service", _runtime_bridge_service)
	_daemon_client.connected_to_daemon.connect(_on_daemon_connected)
	add_child(_daemon_client)
	_daemon_client.start(AUTO_START_DAEMON)


func _exit_tree() -> void:
	print("godot_bridge: plugin exiting tree")
	if _daemon_client != null:
		_daemon_client.stop()
		_daemon_client.queue_free()
		_daemon_client = null
	if _runtime_debugger_capture != null:
		remove_debugger_plugin(_runtime_debugger_capture)
		_runtime_debugger_capture = null
	_runtime_bridge_service = null


func _on_daemon_connected(project_name: String) -> void:
	if project_name.is_empty():
		print("godot_bridge: connected to daemon")
		return

	print("godot_bridge: connected to daemon for project '%s'" % project_name)
