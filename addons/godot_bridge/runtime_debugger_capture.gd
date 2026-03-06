@tool
extends EditorDebuggerPlugin

var _runtime_bridge_service: RefCounted = null


func set_runtime_bridge_service(service: RefCounted) -> void:
	_runtime_bridge_service = service


func _has_capture(message: String) -> bool:
	var kind := str(message).strip_edges()
	if kind == "godot_bridge":
		return true
	if kind.begins_with("godot_bridge:"):
		return true
	if kind == "stdout" or kind == "stderr" or kind == "output":
		return true
	return false


func _setup_session(session_id: int) -> void:
	if _runtime_bridge_service == null:
		return
	if not _runtime_bridge_service.has_method("register_debug_session"):
		return

	var session: Variant = null
	if has_method("get_session"):
		session = call("get_session", session_id)
	if session != null and session.has_signal("stopped"):
		var stopped_callable := Callable(self, "_on_session_stopped").bind(session_id)
		if not session.is_connected("stopped", stopped_callable):
			session.connect("stopped", stopped_callable)
	_runtime_bridge_service.call("register_debug_session", session_id, session)


func _on_session_stopped(session_id: int) -> void:
	if _runtime_bridge_service == null:
		return
	if _runtime_bridge_service.has_method("unregister_debug_session"):
		_runtime_bridge_service.call("unregister_debug_session", session_id)


func _capture(message: String, data: Array, session_id: int) -> bool:
	if _runtime_bridge_service == null:
		return false
	if not _runtime_bridge_service.has_method("capture_message"):
		return false
	return bool(_runtime_bridge_service.call("capture_message", message, data, session_id))
