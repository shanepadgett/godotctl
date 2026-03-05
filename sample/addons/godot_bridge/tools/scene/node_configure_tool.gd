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
	return "scene.node_configure"


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
	var node_path := str(node_result.get("path", ""))
	var config_result := _parse_config(str(args.get("config_json", "")), "config_json")
	if not bool(config_result.get("ok", false)):
		return _finish(root, config_result)

	var raw_values: Dictionary = config_result.get("config", {})
	if raw_values.is_empty():
		return _finish(root, _result.error(_errors.INVALID_ARGS, "config_json must include at least one property"))

	var property_names := _sorted_property_names(raw_values)
	var decoded_values: Dictionary = {}
	for property_name in property_names:
		if property_name.is_empty():
			return _finish(root, _result.error(_errors.INVALID_ARGS, "config_json contains empty property name"))

		var decode_result := _decoder.decode(raw_values.get(property_name))
		if not bool(decode_result.get("ok", false)):
			return _finish(root, decode_result)

		var decoded_value = decode_result.get("value", null)
		var validation := _property_validator.validate(node, property_name, decoded_value)
		if not bool(validation.get("ok", false)):
			return _finish(root, validation)

		decoded_values[property_name] = decoded_value

	var rows: Array = []
	var changed := false
	for property_name in property_names:
		var current_value = node.get(property_name)
		var new_value = decoded_values.get(property_name)
		var prop_changed: bool = current_value != new_value
		if prop_changed:
			node.set(property_name, new_value)
			changed = true
		rows.append({
			"property": property_name,
			"changed": prop_changed,
		})

	rows.sort_custom(Callable(self, "_compare_rows"))

	var saved := false
	var filesystem_refreshed := false
	if changed:
		var save_result := _scene_store.save_root(scene_path, root)
		if not bool(save_result.get("ok", false)):
			return _finish(root, save_result)
		saved = bool(save_result.get("saved", false))
		filesystem_refreshed = bool(save_result.get("filesystem_refreshed", false))

	return _finish(root, _result.success("node configured: %s" % node_path, {
		"scene_path": scene_path,
		"node_path": node_path,
		"properties": rows,
		"changed": changed,
		"saved": saved,
		"filesystem_refreshed": filesystem_refreshed,
	}))


func _parse_config(raw_json: String, field_name: String) -> Dictionary:
	var normalized := str(raw_json).strip_edges()
	if normalized.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % field_name)

	var parser := JSON.new()
	var parse_err := parser.parse(normalized)
	if parse_err != OK:
		return _result.error(_errors.INVALID_ARGS, "%s is invalid JSON: %s" % [field_name, parser.get_error_message()])

	if typeof(parser.data) != TYPE_DICTIONARY:
		return _result.error(_errors.INVALID_ARGS, "%s must be a JSON object" % field_name)

	return {
		"ok": true,
		"config": parser.data,
	}


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("property", "")) < str(b.get("property", ""))


func _sorted_property_names(raw_values: Dictionary) -> Array:
	var names: Array = []
	for key in raw_values.keys():
		names.append(str(key).strip_edges())
	names.sort()
	return names


func _finish(root: Node, response: Dictionary) -> Dictionary:
	return _scene_store.finalize(root, response)
