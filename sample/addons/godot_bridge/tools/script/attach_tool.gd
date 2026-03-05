@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")
const SCRIPT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/script_store.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()
var _scripts = SCRIPT_STORE_SCRIPT.new()


func tool_name() -> String:
	return "script.attach"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var scene_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(scene_result.get("ok", false)):
		return scene_result

	var scene_path := str(scene_result.get("scene_path", ""))
	var root: Node = scene_result.get("root", null)

	var node_result := _nodes.resolve_node(root, str(args.get("node_path", "")), "node_path")
	if not bool(node_result.get("ok", false)):
		return _finish(root, node_result)

	var node: Node = node_result.get("node", null)
	var canonical_node_path := str(node_result.get("path", ""))

	var script_result := _scripts.load_script_resource(str(args.get("script_path", "")))
	if not bool(script_result.get("ok", false)):
		return _finish(root, script_result)

	var script_path := str(script_result.get("script_path", ""))
	var script: Script = script_result.get("script", null)
	var overwrite := bool(args.get("overwrite", false))
	var had_script := node.get_script() != null

	if had_script and not overwrite:
		return _finish(root, _result.error(_errors.ALREADY_EXISTS, "node already has a script: %s" % canonical_node_path))

	var base_type := str(script.get_instance_base_type()).strip_edges()
	if base_type.is_empty() or not node.is_class(base_type):
		return _finish(root, _result.error(_errors.TYPE_MISMATCH, "script base type %s is incompatible with node type %s" % [base_type, node.get_class()]))

	node.set_script(script)
	if node.get_script() == null:
		return _finish(root, _result.error(_errors.TYPE_MISMATCH, "failed to attach script: %s" % script_path))

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("script attached: %s" % canonical_node_path, {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"script_path": script_path,
		"overwrote": had_script,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
