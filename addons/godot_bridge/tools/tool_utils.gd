@tool
extends RefCounted

const ERROR_INVALID_ARGS := "INVALID_ARGS"
const ERROR_NOT_FOUND := "NOT_FOUND"
const ERROR_ALREADY_EXISTS := "ALREADY_EXISTS"
const ERROR_TYPE_MISMATCH := "TYPE_MISMATCH"
const ERROR_IO := "IO_ERROR"
const ERROR_EDITOR_STATE := "EDITOR_STATE"
const ERROR_INTERNAL := "INTERNAL"

const _VALID_ERROR_CODES := [
	ERROR_INVALID_ARGS,
	ERROR_NOT_FOUND,
	ERROR_ALREADY_EXISTS,
	ERROR_TYPE_MISMATCH,
	ERROR_IO,
	ERROR_EDITOR_STATE,
	ERROR_INTERNAL,
]


func make_success(message: String, data: Dictionary = {}, diagnostics: Array = []) -> Dictionary:
	return {
		"ok": true,
		"result": {
			"code": "OK",
			"message": str(message).strip_edges(),
			"data": data,
			"diagnostics": _normalize_diagnostics(diagnostics),
		},
	}


func make_error(code: String, message: String) -> Dictionary:
	var error_message := str(message).strip_edges()
	if error_message.is_empty():
		error_message = "tool call failed"

	return {
		"ok": false,
		"error": error_message,
		"error_code": normalize_error_code(code),
	}


func normalize_error_code(code: String) -> String:
	var normalized := str(code).strip_edges()
	if normalized.is_empty():
		return ERROR_INTERNAL
	if _VALID_ERROR_CODES.has(normalized):
		return normalized
	return ERROR_INTERNAL


func normalize_res_path(raw_path: String) -> String:
	var path := str(raw_path).strip_edges().replace("\\", "/")
	if path.is_empty():
		return ""

	if path.begins_with("res://"):
		path = path.substr(6)
	elif path.begins_with("res:/"):
		path = path.substr(5)
	elif path.begins_with("./"):
		path = path.substr(2)
	elif path.begins_with("/"):
		path = path.substr(1)

	while path.find("//") != -1:
		path = path.replace("//", "/")

	while path.begins_with("/"):
		path = path.substr(1)

	if path.is_empty():
		return "res://"

	return "res://%s" % path


func ensure_tscn_extension(path: String) -> String:
	var normalized_path := normalize_res_path(path)
	if normalized_path.to_lower().ends_with(".tscn"):
		return normalized_path
	return "%s.tscn" % normalized_path


func has_tscn_extension(path: String) -> bool:
	return normalize_res_path(path).to_lower().ends_with(".tscn")


func sort_strings(values: Array[String]) -> Array[String]:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted


func validate_node_class(node_class_name: String, field_name: String = "node_class") -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "node_class"

	var normalized_class := str(node_class_name).strip_edges()
	if normalized_class.is_empty():
		return make_error(ERROR_INVALID_ARGS, "%s is required" % normalized_field)
	if not ClassDB.class_exists(normalized_class):
		return make_error(ERROR_NOT_FOUND, "class does not exist: %s" % normalized_class)

	var instance: Variant = ClassDB.instantiate(normalized_class)
	if instance == null:
		return make_error(ERROR_INVALID_ARGS, "class cannot be instantiated: %s" % normalized_class)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return make_error(ERROR_TYPE_MISMATCH, "class is not a Node: %s" % normalized_class)

	instance.free()
	return make_success("validated node class", {
		"class_name": normalized_class,
	})


func validate_property_assignment(target: Object, property_name: String, value: Variant) -> Dictionary:
	if target == null:
		return make_error(ERROR_INVALID_ARGS, "target is required")

	var normalized_name := str(property_name).strip_edges()
	if normalized_name.is_empty():
		return make_error(ERROR_INVALID_ARGS, "property name is required")

	var property_info := _property_info(target, normalized_name)
	if property_info.is_empty():
		return make_error(ERROR_NOT_FOUND, "property does not exist: %s" % normalized_name)

	var expected_type := int(property_info.get("type", TYPE_NIL))
	var incoming_type := typeof(value)
	if not _is_assignable_type(expected_type, incoming_type):
		return make_error(
			ERROR_TYPE_MISMATCH,
			"property %s expects %s but got %s" % [
				normalized_name,
				type_string(expected_type),
				type_string(incoming_type),
			]
		)

	return make_success("validated property assignment", {
		"property": normalized_name,
	})


func _normalize_diagnostics(diagnostics: Array) -> Array:
	if typeof(diagnostics) != TYPE_ARRAY:
		return []
	return diagnostics.duplicate(true)


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
