@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func validate(target: Object, property_name: String, value: Variant) -> Dictionary:
	if target == null:
		return _result.error(_errors.INVALID_ARGS, "target is required")

	var normalized_name := str(property_name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "property name is required")

	var property_info := _property_info(target, normalized_name)
	if property_info.is_empty():
		return _result.error(_errors.NOT_FOUND, "property does not exist: %s" % normalized_name)

	var expected_type := int(property_info.get("type", TYPE_NIL))
	var incoming_type := typeof(value)
	if not _is_assignable_type(expected_type, incoming_type):
		return _result.error(
			_errors.TYPE_MISMATCH,
			"property %s expects %s but got %s" % [
				normalized_name,
				type_string(expected_type),
				type_string(incoming_type),
			]
		)

	return _result.success("validated property assignment", {
		"property": normalized_name,
	})


func _property_info(target: Object, property_name: String) -> Dictionary:
	for entry in target.get_property_list():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("name", "")) == property_name:
			return entry
	return {}


func _is_assignable_type(expected_type: int, incoming_type: int) -> bool:
	if expected_type == TYPE_NIL:
		return true
	if incoming_type == TYPE_NIL:
		return true
	if expected_type == incoming_type:
		return true

	if expected_type == TYPE_FLOAT and incoming_type == TYPE_INT:
		return true
	if expected_type == TYPE_STRING_NAME and incoming_type == TYPE_STRING:
		return true
	if expected_type == TYPE_NODE_PATH and incoming_type == TYPE_STRING:
		return true

	return false
