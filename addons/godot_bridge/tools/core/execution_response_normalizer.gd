@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func normalize(response: Variant) -> Dictionary:
	if typeof(response) != TYPE_DICTIONARY:
		return _result.error(_errors.INTERNAL, "tool handler returned invalid response")

	var payload: Dictionary = response
	if typeof(payload.get("ok", null)) != TYPE_BOOL:
		return _result.error(_errors.INTERNAL, "tool handler response is missing ok")

	if bool(payload.get("ok", false)):
		var result_value = payload.get("result", {})
		if typeof(result_value) != TYPE_DICTIONARY:
			return _result.error(_errors.INTERNAL, "tool handler response is missing result")

		var result: Dictionary = result_value
		var message := str(result.get("message", "")).strip_edges()
		if message.is_empty():
			message = "operation completed"

		var data = result.get("data", {})
		if typeof(data) != TYPE_DICTIONARY:
			data = {}

		var diagnostics = result.get("diagnostics", [])
		if typeof(diagnostics) != TYPE_ARRAY:
			diagnostics = []

		return {
			"ok": true,
			"result": {
				"code": "OK",
				"message": message,
				"data": data,
				"diagnostics": diagnostics,
			},
		}

	var error_message := str(payload.get("error", "")).strip_edges()
	if error_message.is_empty():
		error_message = "tool call failed"

	return {
		"ok": false,
		"error": error_message,
		"error_code": _errors.normalize(str(payload.get("error_code", ""))),
	}
