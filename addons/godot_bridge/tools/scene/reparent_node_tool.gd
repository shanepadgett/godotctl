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
	return "scene.reparent_node"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var node_result := _nodes.resolve_node(root, str(args.get("node_path", "")), "node_path")
	if not bool(node_result.get("ok", false)):
		return _finish(root, node_result)

	var parent_result := _nodes.resolve_node(root, str(args.get("parent_path", "")), "parent_path")
	if not bool(parent_result.get("ok", false)):
		return _finish(root, parent_result)

	var target: Node = node_result.get("node", null)
	var target_path := str(node_result.get("path", ""))
	if target_path == ".":
		return _finish(root, _result.error(_errors.INVALID_ARGS, "node_path cannot target root"))

	var new_parent: Node = parent_result.get("node", null)
	var parent_path := str(parent_result.get("path", ""))
	if target == new_parent or target.is_ancestor_of(new_parent):
		return _finish(root, _result.error(_errors.INVALID_ARGS, "parent_path cannot be within node_path subtree"))

	var has_index := args.has("index")
	var requested_index := int(args.get("index", -1))
	if has_index and requested_index < 0:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "index must be >= 0"))

	var current_parent := target.get_parent()
	if current_parent == null or not (current_parent is Node):
		return _finish(root, _result.error(_errors.INTERNAL, "node parent is unavailable"))
	if current_parent != new_parent and _nodes.has_child_named(new_parent, str(target.name)):
		return _finish(root, _result.error(_errors.ALREADY_EXISTS, "child already exists under %s: %s" % [parent_path, str(target.name)]))

	if has_index:
		var max_index := int(new_parent.get_child_count())
		if requested_index > max_index:
			return _finish(root, _result.error(_errors.INVALID_ARGS, "index is out of range"))

	if current_parent == new_parent:
		if not has_index:
			return _finish(root, _result.success("node reparented: %s" % target_path, {
				"scene_path": scene_path,
				"node_path": target_path,
				"parent_path": parent_path,
				"index": target.get_index(),
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			}))

		var normalized_index := _normalize_index(requested_index, new_parent.get_child_count())
		if target.get_index() == normalized_index:
			return _finish(root, _result.success("node reparented: %s" % target_path, {
				"scene_path": scene_path,
				"node_path": target_path,
				"parent_path": parent_path,
				"index": normalized_index,
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			}))

		new_parent.move_child(target, normalized_index)
	else:
		current_parent.remove_child(target)
		new_parent.add_child(target)
		_nodes.assign_owner_recursive(target, root)
		if has_index:
			new_parent.move_child(target, _normalize_index(requested_index, new_parent.get_child_count()))

	var final_path := _nodes.canonical_node_path(root, target)
	var final_index := target.get_index()

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("node reparented: %s" % final_path, {
		"scene_path": scene_path,
		"node_path": final_path,
		"parent_path": parent_path,
		"index": final_index,
		"changed": true,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _normalize_index(index: int, child_count: int) -> int:
	if child_count <= 0:
		return 0
	if index >= child_count:
		return child_count - 1
	return index


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
