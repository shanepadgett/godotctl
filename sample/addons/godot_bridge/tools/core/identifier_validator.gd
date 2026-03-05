@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func validate_identifier(raw_name: String, field_name: String) -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "identifier"

	var name := str(raw_name).strip_edges()
	if name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)
	if not _is_valid_identifier(name):
		return _result.error(_errors.INVALID_ARGS, "%s must be a valid identifier" % normalized_field)

	return {
		"ok": true,
		"value": name,
	}


func _is_valid_identifier(name: String) -> bool:
	if name.is_empty():
		return false

	var first_code := name.unicode_at(0)
	if not (_is_ascii_letter(first_code) or first_code == 95):
		return false

	for i in range(1, name.length()):
		var code := name.unicode_at(i)
		if not (_is_ascii_letter(code) or _is_ascii_digit(code) or code == 95):
			return false

	return true


func _is_ascii_letter(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _is_ascii_digit(code: int) -> bool:
	return code >= 48 and code <= 57
