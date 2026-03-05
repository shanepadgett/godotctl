@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "scene.instance_scene"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var source_scene_path := _paths.normalize_res_path(str(args.get("source_scene_path", "")).strip_edges())
	if source_scene_path.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "source_scene_path is required"))
	if not _paths.has_tscn_extension(source_scene_path):
		return _finish(root, _result.error(_errors.INVALID_ARGS, "source_scene_path must end with .tscn"))
	if not ResourceLoader.exists(source_scene_path):
		return _finish(root, _result.error(_errors.NOT_FOUND, "scene not found: %s" % source_scene_path))

	var parent_result := _nodes.resolve_node(root, str(args.get("parent_path", "")), "parent_path")
	if not bool(parent_result.get("ok", false)):
		return _finish(root, parent_result)

	var parent: Node = parent_result.get("node", null)
	var parent_path := str(parent_result.get("path", ""))

	var requested_name := str(args.get("name", "")).strip_edges()
	if not requested_name.is_empty() and requested_name.find("/") != -1:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "name must not contain '/'"))

	var source_resource := ResourceLoader.load(source_scene_path)
	if source_resource == null:
		return _finish(root, _result.error(_errors.IO_ERROR, "failed to load scene: %s" % source_scene_path))
	if not (source_resource is PackedScene):
		return _finish(root, _result.error(_errors.TYPE_MISMATCH, "resource is not a PackedScene: %s" % source_scene_path))

	var packed: PackedScene = source_resource
	var instance_value: Variant = packed.instantiate()
	if instance_value == null or not (instance_value is Node):
		return _finish(root, _result.error(_errors.TYPE_MISMATCH, "instantiated scene root is not a Node: %s" % source_scene_path))

	var child: Node = instance_value
	var default_name := requested_name
	if default_name.is_empty():
		default_name = str(child.name)

	var name_result := _resolve_name(parent, default_name)
	child.name = str(name_result.get("name", ""))
	var name_collision := bool(name_result.get("collision", false))

	parent.add_child(child)
	_nodes.assign_owner_recursive(child, root)

	var created_path := _nodes.canonical_node_path(root, child)
	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("scene instanced: %s" % created_path, {
		"scene_path": scene_path,
		"source_scene_path": source_scene_path,
		"parent_path": parent_path,
		"node_path": created_path,
		"name": str(child.name),
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
