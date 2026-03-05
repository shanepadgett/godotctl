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
	return "scene.duplicate_node"


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

	var source: Node = node_result.get("node", null)
	var source_path := str(node_result.get("path", ""))
	var parent: Node = parent_result.get("node", null)
	var parent_path := str(parent_result.get("path", ""))

	var requested_name := str(args.get("name", "")).strip_edges()
	if not requested_name.is_empty() and requested_name.find("/") != -1:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "name must not contain '/'"))

	var duplicate_instance: Variant = source.duplicate()
	if duplicate_instance == null or not (duplicate_instance is Node):
		return _finish(root, _result.error(_errors.INTERNAL, "failed to duplicate node: %s" % source_path))

	var clone: Node = duplicate_instance
	var base_name := requested_name
	if base_name.is_empty():
		base_name = str(source.name)

	var name_result := _resolve_name(parent, base_name)
	clone.name = str(name_result.get("name", ""))
	var name_collision := bool(name_result.get("collision", false))

	parent.add_child(clone)
	_nodes.assign_owner_recursive(clone, root)

	var created_path := _nodes.canonical_node_path(root, clone)
	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("node duplicated: %s" % created_path, {
		"scene_path": scene_path,
		"source_path": source_path,
		"parent_path": parent_path,
		"node_path": created_path,
		"name": str(clone.name),
		"name_collision": name_collision,
		"changed": true,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _resolve_name(parent: Node, base_name_raw: String) -> Dictionary:
	var base_name := str(base_name_raw).strip_edges()
	if base_name.is_empty():
		base_name = "Node"

	if not _nodes.has_child_named(parent, base_name):
		return {
			"name": base_name,
			"collision": false,
		}

	var suffix := 2
	while true:
		var candidate := "%s_%d" % [base_name, suffix]
		if not _nodes.has_child_named(parent, candidate):
			return {
				"name": candidate,
				"collision": true,
			}
		suffix += 1

	return {
		"name": base_name,
		"collision": true,
	}


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
