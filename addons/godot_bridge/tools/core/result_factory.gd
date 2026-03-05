@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")

var _errors = ERROR_CODES_SCRIPT.new()


func success(message: String, data: Dictionary = {}, diagnostics: Array = []) -> Dictionary:
	var payload_data = data
	if typeof(payload_data) != TYPE_DICTIONARY:
		payload_data = {}

	return {
		"ok": true,
		"result": {
			"code": "OK",
			"message": str(message).strip_edges(),
			"data": payload_data,
			"diagnostics": _normalize_diagnostics(diagnostics),
		},
	}


func error(code: String, message: String) -> Dictionary:
	var error_message := str(message).strip_edges()
	if error_message.is_empty():
		error_message = "tool call failed"

	return {
		"ok": false,
		"error": error_message,
		"error_code": _errors.normalize(code),
	}


func _normalize_diagnostics(diagnostics: Array) -> Array:
	if typeof(diagnostics) != TYPE_ARRAY:
		return []
	return diagnostics.duplicate(true)
