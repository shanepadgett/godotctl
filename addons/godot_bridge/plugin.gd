@tool
extends EditorPlugin

const DAEMON_CLIENT_SCRIPT := preload("res://addons/godot_bridge/daemon_client.gd")
const AUTO_START_DAEMON := true

var _daemon_client: Node


func _enter_tree() -> void:
	print("godot_bridge: plugin entering tree")
	_daemon_client = DAEMON_CLIENT_SCRIPT.new()
	_daemon_client.connected_to_daemon.connect(_on_daemon_connected)
	add_child(_daemon_client)
	_daemon_client.start(AUTO_START_DAEMON)


func _exit_tree() -> void:
	print("godot_bridge: plugin exiting tree")
	if _daemon_client != null:
		_daemon_client.stop()
		_daemon_client.queue_free()
		_daemon_client = null


func _on_daemon_connected(project_name: String) -> void:
	if project_name.is_empty():
		print("godot_bridge: connected to daemon")
		return

	print("godot_bridge: connected to daemon for project '%s'" % project_name)
