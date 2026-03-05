@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func validate_node_class(node_class_name: String, field_name: String = "node_class") -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "node_class"

	var normalized_class := str(node_class_name).strip_edges()
	if normalized_class.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)
	if not ClassDB.class_exists(normalized_class):
		return _result.error(_errors.NOT_FOUND, "class does not exist: %s" % normalized_class)

	var instance: Variant = ClassDB.instantiate(normalized_class)
	if instance == null:
		return _result.error(_errors.INVALID_ARGS, "class cannot be instantiated: %s" % normalized_class)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _result.error(_errors.TYPE_MISMATCH, "class is not a Node: %s" % normalized_class)

	instance.free()
	return _result.success("validated node class", {
		"class_name": normalized_class,
	})
