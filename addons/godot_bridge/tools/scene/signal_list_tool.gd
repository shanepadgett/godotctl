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


func tool_name() -> String:
	return "scene.signal_list"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var max_rows := int(args.get("max", 0))
	if max_rows < 0:
		return _result.error(_errors.INVALID_ARGS, "max must be >= 0")

	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var from_filter := str(args.get("from_node", "")).strip_edges()
	if not from_filter.is_empty():
		var from_result := _nodes.resolve_node(root, from_filter, "from_node")
		if not bool(from_result.get("ok", false)):
			return _finish(root, from_result)
		from_filter = str(from_result.get("path", ""))

	var to_filter := str(args.get("to_target", "")).strip_edges()
	if not to_filter.is_empty():
		var to_result := _nodes.resolve_node(root, to_filter, "to_target")
		if not bool(to_result.get("ok", false)):
			return _finish(root, to_result)
		to_filter = str(to_result.get("path", ""))

	var signal_filter := str(args.get("signal", "")).strip_edges()
	var method_filter := str(args.get("method", "")).strip_edges()

	var rows: Array = []
	for row_item in _identity.collect(root, scene_path, _nodes):
		if typeof(row_item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_item
		if not _identity.matches_filters(row, from_filter, signal_filter, to_filter, method_filter):
			continue
		rows.append(row)

	var count := rows.size()
	var truncated := false
	if max_rows > 0 and rows.size() > max_rows:
		rows = rows.slice(0, max_rows)
		truncated = true

	return _finish(root, _result.success("signal connections listed: %s" % scene_path, {
		"scene_path": scene_path,
		"from_node": from_filter,
		"signal": signal_filter,
		"to_target": to_filter,
		"method": method_filter,
		"max": max_rows,
		"connections": rows,
		"count": count,
		"returned_count": rows.size(),
		"truncated": truncated,
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
