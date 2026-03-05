@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const GEOMETRY_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/typed_value_geometry_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _geometry = GEOMETRY_DECODER_SCRIPT.new()


func decode(value: Dictionary) -> Dictionary:
	if not value.has("type"):
		return _result.error(_errors.INVALID_ARGS, "typed value object requires field: type")

	var type_name := str(value.get("type", "")).strip_edges()
	if type_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "typed value object type must be non-empty")

	if type_name == "Vector2":
		return _geometry.decode_vector2(value)
	if type_name == "Vector3":
		return _geometry.decode_vector3(value)
	if type_name == "Color":
		return _geometry.decode_color(value)
	if type_name == "NodePath":
		return _geometry.decode_node_path(value)

	return _result.error(_errors.INVALID_ARGS, "unsupported typed value: %s" % type_name)
