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
	return "scene.rename_node"


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

	var target: Node = node_result.get("node", null)
	var canonical_node_path := str(node_result.get("path", ""))
	if canonical_node_path == ".":
		return _finish(root, _result.error(_errors.INVALID_ARGS, "node_path cannot target root"))
	var new_name := str(args.get("name", "")).strip_edges()
	if new_name.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "name is required"))
	if new_name.find("/") != -1:
		return _finish(root, _result.error(_errors.INVALID_ARGS, "name must not contain '/'"))

	if str(target.name) == new_name:
		return _finish(root, _result.success("node renamed: %s" % canonical_node_path, {
			"scene_path": scene_path,
			"node_path": canonical_node_path,
			"name": new_name,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		}))

	var parent := target.get_parent()
	if parent is Node and _nodes.has_child_named(parent, new_name):
		return _finish(root, _result.error(_errors.ALREADY_EXISTS, "child already exists under %s: %s" % [_nodes.canonical_node_path(root, parent), new_name]))

	target.name = new_name
	var renamed_path := _nodes.canonical_node_path(root, target)

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("node renamed: %s" % renamed_path, {
		"scene_path": scene_path,
		"node_path": renamed_path,
		"name": new_name,
		"changed": true,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
