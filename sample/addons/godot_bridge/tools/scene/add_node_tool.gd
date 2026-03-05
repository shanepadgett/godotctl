@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const NODE_CLASS_VALIDATOR_SCRIPT := preload("res://addons/godot_bridge/tools/core/node_class_validator.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _class_validator = NODE_CLASS_VALIDATOR_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "scene.add_node"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var node_name := str(args.get("node_name", "")).strip_edges()
	if node_name.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "node_name is required"))
	if node_name.find("/") != -1:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "node_name must not contain '/'"))

	var node_type := str(args.get("node_type", "")).strip_edges()
	var class_validation := _class_validator.validate_node_class(node_type, "node_type")
	if not bool(class_validation.get("ok", false)):
		return _finish(root, class_validation)

	var parent_result := _nodes.resolve_node(root, str(args.get("parent_path", "")), "parent_path")
	if not bool(parent_result.get("ok", false)):
		return _finish(root, parent_result)

	var parent: Node = parent_result.get("node", null)
	var canonical_parent_path := str(parent_result.get("path", ""))
	if _nodes.has_child_named(parent, node_name):
		return _finish(root, _result.error(_errors.ALREADY_EXISTS, "child already exists under %s: %s" % [canonical_parent_path, node_name]))

	var instance: Variant = ClassDB.instantiate(node_type)
	if instance == null:
		return _finish(root, _result.error(_errors.INTERNAL, "could not instantiate node_type: %s" % node_type))
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _finish(root, _result.error(_errors.TYPE_MISMATCH, "node_type is not a Node: %s" % node_type))

	var child: Node = instance
	child.name = node_name
	parent.add_child(child)
	_nodes.assign_owner_recursive(child, root)

	var canonical_node_path := _nodes.canonical_node_path(root, child)
	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("node added: %s" % canonical_node_path, {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"parent_path": canonical_parent_path,
		"node_type": node_type,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
