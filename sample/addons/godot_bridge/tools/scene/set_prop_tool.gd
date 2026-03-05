@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PROPERTY_ASSIGNMENT_VALIDATOR_SCRIPT := preload("res://addons/godot_bridge/tools/core/property_assignment_validator.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _property_validator = PROPERTY_ASSIGNMENT_VALIDATOR_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "scene.set_prop"


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

	var node: Node = node_result.get("node", null)
	var canonical_node_path := str(node_result.get("path", ""))

	var property_name := str(args.get("property", "")).strip_edges()
	if property_name.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "property is required"))

	var value_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(value_result.get("ok", false)):
		return _finish(root, value_result)

	var value = value_result.get("value", null)
	var property_validation := _property_validator.validate(node, property_name, value)
	if not bool(property_validation.get("ok", false)):
		return _finish(root, property_validation)

	node.set(property_name, value)

	var save_result := _scene_store.save_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finish(root, save_result)

	return _finish(root, _result.success("property set: %s.%s" % [canonical_node_path, property_name], {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"property": property_name,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
