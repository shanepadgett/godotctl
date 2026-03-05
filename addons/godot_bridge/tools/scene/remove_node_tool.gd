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
	return "scene.remove_node"


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
	var canonical_target_path := str(node_result.get("path", ""))
	if canonical_target_path == ".":
		return _finish(root, _result.error(_errors.INVALID_ARGS, "node_path cannot target root"))

	var parent := target.get_parent()
	if parent is Node:
		parent.remove_child(target)
	target.free()

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("node removed: %s" % canonical_target_path, {
		"scene_path": scene_path,
		"removed_path": canonical_target_path,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
