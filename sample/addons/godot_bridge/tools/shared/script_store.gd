@tool
extends RefCounted

const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")

var _paths = PATH_RULES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()


func validate_script_path(raw_path: String, field_name: String = "script_path") -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "script_path"

	var path_raw := str(raw_path).strip_edges()
	if path_raw.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)

	var script_path := _paths.normalize_res_path(path_raw)
	if not _paths.has_gd_extension(script_path):
		return _result.error(_errors.INVALID_ARGS, "%s must end with .gd" % normalized_field)

	return {
		"ok": true,
		"script_path": script_path,
	}


func load_script_resource(script_path_raw: String) -> Dictionary:
	var script_path_result := validate_script_path(script_path_raw, "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _result.error(_errors.NOT_FOUND, "script not found: %s" % script_path)

	var resource = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return _result.error(_errors.INVALID_ARGS, "failed to load script: %s" % script_path)
	if not (resource is Script):
		return _result.error(_errors.TYPE_MISMATCH, "resource is not a Script: %s" % script_path)

	return {
		"ok": true,
		"script_path": script_path,
		"script": resource,
	}


func read_text_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var read_err := FileAccess.get_open_error()
		return _result.error(_errors.IO_ERROR, "failed to read file: %s" % error_string(read_err))

	return {
		"ok": true,
		"text": file.get_as_text(),
	}


func write_text_file(path: String, content: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var write_err := FileAccess.get_open_error()
		return _result.error(_errors.IO_ERROR, "failed to write file: %s" % error_string(write_err))

	file.store_string(content)
	return {
		"ok": true,
	}
