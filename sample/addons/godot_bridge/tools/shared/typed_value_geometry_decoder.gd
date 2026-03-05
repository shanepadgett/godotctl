@tool
extends RefCounted
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()

func decode_vector2(value: Dictionary) -> Dictionary:
	var x_result := _require_numeric_field(value, "x")
	if not bool(x_result.get("ok", false)):
		return x_result

	var y_result := _require_numeric_field(value, "y")
	if not bool(y_result.get("ok", false)):
		return y_result

	return {
		"ok": true,
		"value": Vector2(float(x_result.get("value", 0.0)), float(y_result.get("value", 0.0))),
	}

func decode_vector3(value: Dictionary) -> Dictionary:
	var x_result := _require_numeric_field(value, "x")
	if not bool(x_result.get("ok", false)):
		return x_result

	var y_result := _require_numeric_field(value, "y")
	if not bool(y_result.get("ok", false)):
		return y_result

	var z_result := _require_numeric_field(value, "z")
	if not bool(z_result.get("ok", false)):
		return z_result

	return {
		"ok": true,
		"value": Vector3(
			float(x_result.get("value", 0.0)),
			float(y_result.get("value", 0.0)),
			float(z_result.get("value", 0.0))
		),
	}

func decode_color(value: Dictionary) -> Dictionary:
	var r_result := _require_numeric_field(value, "r")
	if not bool(r_result.get("ok", false)):
		return r_result

	var g_result := _require_numeric_field(value, "g")
	if not bool(g_result.get("ok", false)):
		return g_result

	var b_result := _require_numeric_field(value, "b")
	if not bool(b_result.get("ok", false)):
		return b_result

	var alpha := 1.0
	if value.has("a"):
		var a_result := _require_numeric_field(value, "a")
		if not bool(a_result.get("ok", false)):
			return a_result
		alpha = float(a_result.get("value", 1.0))

	return {
		"ok": true,
		"value": Color(
			float(r_result.get("value", 0.0)),
			float(g_result.get("value", 0.0)),
			float(b_result.get("value", 0.0)),
			alpha
		),
	}

func decode_node_path(value: Dictionary) -> Dictionary:
	if not value.has("value"):
		return _result.error(_errors.INVALID_ARGS, "typed value NodePath requires field: value")

	var raw_path = value.get("value")
	if typeof(raw_path) != TYPE_STRING:
		return _result.error(_errors.INVALID_ARGS, "typed value NodePath field value must be a string")

	return {
		"ok": true,
		"value": NodePath(str(raw_path)),
	}

func _require_numeric_field(value: Dictionary, field_name: String) -> Dictionary:
	if not value.has(field_name):
		return _result.error(_errors.INVALID_ARGS, "typed value requires field: %s" % field_name)

	var raw_value = value.get(field_name)
	var value_type := typeof(raw_value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return _result.error(_errors.INVALID_ARGS, "typed value field %s must be numeric" % field_name)

	return {
		"ok": true,
		"value": float(raw_value),
	}
