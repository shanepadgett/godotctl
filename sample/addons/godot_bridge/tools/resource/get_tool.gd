@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESOURCE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/resource_store.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = RESOURCE_STORE_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "resource.get"


func execute(args: Dictionary) -> Dictionary:
	var load_result := _store.load_resource(str(args.get("path", "")), "path")
	if not bool(load_result.get("ok", false)):
		return load_result

	var resource_path := str(load_result.get("resource_path", ""))
	var resource: Resource = load_result.get("resource", null)

	var property_name := str(args.get("prop", "")).strip_edges()
	if property_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "prop is required")

	if _property_info(resource, property_name).is_empty():
		return _result.error(_errors.NOT_FOUND, "property does not exist: %s" % property_name)

	var value = resource.get(property_name)
	var serialized := _serializer.serialize(value)

	return _result.success("resource property retrieved: %s.%s" % [resource_path, property_name], {
		"resource_path": resource_path,
		"property": property_name,
		"value": serialized.get("value", null),
		"value_text": str(serialized.get("text", "")),
		"value_type": str(serialized.get("type", "")),
	})


func _property_info(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {}

	for entry in resource.get_property_list():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("name", "")) == property_name:
			return entry

	return {}
