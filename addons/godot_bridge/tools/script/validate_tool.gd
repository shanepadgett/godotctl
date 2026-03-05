@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCRIPT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/script_store.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _scripts = SCRIPT_STORE_SCRIPT.new()


func tool_name() -> String:
	return "script.validate"


func execute(args: Dictionary) -> Dictionary:
	var script_path_result := _scripts.validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _result.error(_errors.NOT_FOUND, "script not found: %s" % script_path)

	var read_result := _scripts.read_text_file(script_path)
	if not bool(read_result.get("ok", false)):
		return read_result

	var source_text := str(read_result.get("text", ""))
	var transient_script := GDScript.new()
	transient_script.source_code = source_text
	var reload_err := transient_script.reload()

	var diagnostics: Array = []
	var valid := reload_err == OK
	if not valid:
		diagnostics.append({
			"severity": "error",
			"code": "SCRIPT_COMPILE_FAILED",
			"message": "script failed to parse/compile (%s)" % error_string(reload_err),
		})

	var message := "script valid: %s" % script_path
	if not valid:
		message = "script invalid: %s" % script_path

	return _result.success(message, {
		"script_path": script_path,
		"valid": valid,
		"diagnostics": diagnostics,
	})
