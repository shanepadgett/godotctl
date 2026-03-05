@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")
const SCENE_SIGNAL_IDENTITY_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_signal_identity.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()
var _identity = SCENE_SIGNAL_IDENTITY_SCRIPT.new()

const _CONNECT_PERSIST := 2


func tool_name() -> String:
	return "scene.signal_connect"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var from_result := _nodes.resolve_node(root, str(args.get("from_node", "")), "from_node")
	if not bool(from_result.get("ok", false)):
		return _finish(root, from_result)

	var to_result := _nodes.resolve_node(root, str(args.get("to_target", "")), "to_target")
	if not bool(to_result.get("ok", false)):
		return _finish(root, to_result)

	var source: Node = from_result.get("node", null)
	var source_path := str(from_result.get("path", ""))
	var target: Node = to_result.get("node", null)
	var target_path := str(to_result.get("path", ""))

	var signal_name := str(args.get("signal", "")).strip_edges()
	if signal_name.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "signal is required"))
	if not source.has_signal(StringName(signal_name)):
		return _finish(root, _result.error(_errors.NOT_FOUND, "signal not found: %s" % signal_name))

	var method_name := str(args.get("method", "")).strip_edges()
	if method_name.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "method is required"))
	if not target.has_method(method_name):
		return _finish(root, _result.error(_errors.NOT_FOUND, "method not found on to_target: %s" % method_name))

	var requested_flags := int(args.get("flags", 0))
	if requested_flags < 0:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "flags must be >= 0"))
	var effective_flags := requested_flags | _CONNECT_PERSIST

	var rows := _identity.collect(root, scene_path, _nodes)
	if _identity.has_exact(rows, scene_path, source_path, signal_name, target_path, method_name, effective_flags):
		return _finish(root, _result.success("signal connected: %s.%s" % [source_path, signal_name], {
			"scene_path": scene_path,
			"from_node": source_path,
			"signal": signal_name,
			"to_target": target_path,
			"method": method_name,
			"flags": effective_flags,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		}))

	var callable := Callable(target, method_name)
	var connect_err := source.connect(signal_name, callable, effective_flags)
	if connect_err != OK:
		if source.is_connected(signal_name, callable):
			var refreshed_rows := _identity.collect(root, scene_path, _nodes)
			var existing := _identity.find_match(refreshed_rows, scene_path, source_path, signal_name, target_path, method_name)
			var existing_flags := effective_flags
			if not existing.is_empty():
				existing_flags = int(existing.get("flags", effective_flags))
			return _finish(root, _result.success("signal connected: %s.%s" % [source_path, signal_name], {
				"scene_path": scene_path,
				"from_node": source_path,
				"signal": signal_name,
				"to_target": target_path,
				"method": method_name,
				"flags": existing_flags,
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			}))
		return _finish(root, _result.error(_errors.INTERNAL, "failed to connect signal: %s" % error_string(connect_err)))

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("signal connected: %s.%s" % [source_path, signal_name], {
		"scene_path": scene_path,
		"from_node": source_path,
		"signal": signal_name,
		"to_target": target_path,
		"method": method_name,
		"flags": effective_flags,
		"changed": true,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
