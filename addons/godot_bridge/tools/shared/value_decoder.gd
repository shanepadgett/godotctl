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
	if value_type == TYPE_ARRAY:
		var decoded_array: Array = []
		for item in value:
			var item_result := decode(item)
			if not bool(item_result.get("ok", false)):
				return item_result
			decoded_array.append(item_result.get("value", null))
		return {"ok": true, "value": decoded_array}
	if value_type == TYPE_DICTIONARY:
		if value.has("type"):
			var type_name := str(value.get("type", "")).strip_edges()
			if type_name == "Vector2" or type_name == "Vector3" or type_name == "Color" or type_name == "NodePath":
				return _typed_decoder.decode(value)

		var decoded_dictionary := {}
		var keys: Array = value.keys()
		keys.sort_custom(Callable(self , "_compare_keys"))
		for key in keys:
			var entry_result := decode(value.get(key))
			if not bool(entry_result.get("ok", false)):
				return entry_result
			decoded_dictionary[str(key)] = entry_result.get("value", null)
		return {"ok": true, "value": decoded_dictionary}

	return _result.error(_errors.INVALID_ARGS, "value_json must be a primitive or typed object")


func _compare_keys(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)
