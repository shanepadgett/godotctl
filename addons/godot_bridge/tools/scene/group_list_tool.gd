@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "scene.group_list"


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

	var scope_path := ""
	var scope_node := root
	var requested_node_path := str(args.get("node_path", "")).strip_edges()
	if not requested_node_path.is_empty():
		var node_result := _nodes.resolve_node(root, requested_node_path, "node_path")
		if not bool(node_result.get("ok", false)):
			return _finish(root, node_result)
		scope_node = node_result.get("node", root)
		scope_path = str(node_result.get("path", ""))

	var rows: Array = []
	_collect_rows(root, scope_node, rows)
	rows.sort_custom(Callable(self, "_compare_rows"))

	var count := rows.size()
	var truncated := false
	if max_rows > 0 and rows.size() > max_rows:
		rows = rows.slice(0, max_rows)
		truncated = true

	return _finish(root, _result.success("group list: %s" % scene_path, {
		"scene_path": scene_path,
		"node_path": scope_path,
		"max": max_rows,
		"groups": rows,
		"count": count,
		"returned_count": rows.size(),
		"truncated": truncated,
	}))


func _collect_rows(root: Node, current: Node, rows: Array) -> void:
	if current == null:
		return

	var node_path := _nodes.canonical_node_path(root, current)
	var seen := {}
	for raw_group in current.get_groups():
		var group_name := str(raw_group).strip_edges()
		if group_name.is_empty():
			continue
		if seen.has(group_name):
			continue
		seen[group_name] = true
		rows.append({
			"node_path": node_path,
			"group": group_name,
		})

	for child in current.get_children():
		if child is Node:
			_collect_rows(root, child, rows)


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("node_path", ""))
	var b_path := str(b.get("node_path", ""))
	if a_path != b_path:
		return a_path < b_path

	return str(a.get("group", "")) < str(b.get("group", ""))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
