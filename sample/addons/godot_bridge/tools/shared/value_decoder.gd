@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const TYPED_VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/typed_value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _typed_decoder = TYPED_VALUE_DECODER_SCRIPT.new()


func parse_value_json(raw_value_json: String) -> Dictionary:
	var value_json := str(raw_value_json).strip_edges()
	if value_json.is_empty():
		return _result.error(_errors.INVALID_ARGS, "value_json is required")

	var parser := JSON.new()
	var parse_err := parser.parse(value_json)
	if parse_err != OK:
		return _result.error(_errors.INVALID_ARGS, "value_json is invalid JSON: %s" % parser.get_error_message())

	var decode_result := decode(parser.data)
	if not bool(decode_result.get("ok", false)):
		return decode_result

	return {
		"ok": true,
		"value": decode_result.get("value", null),
	}


func decode(value: Variant) -> Dictionary:
	var value_type := typeof(value)
	if value_type == TYPE_NIL:
		return {"ok": true, "value": null}
	if value_type == TYPE_BOOL:
		return {"ok": true, "value": bool(value)}
	if value_type == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if value_type == TYPE_FLOAT:
		return {"ok": true, "value": float(value)}
	if value_type == TYPE_STRING:
		return {"ok": true, "value": str(value)}
	if value_type == TYPE_DICTIONARY:
		return _typed_decoder.decode(value)

	return _result.error(_errors.INVALID_ARGS, "value_json must be a primitive or typed object")
