@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()


func tool_name() -> String:
	return "file.read"


func execute(args: Dictionary) -> Dictionary:
	var raw_path := str(args.get("path", "")).strip_edges()
	if raw_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "path is required")

	var file_path := _normalize_path(raw_path)
	var validation := _validate_file_path(file_path)
	if not bool(validation.get("ok", false)):
		return validation

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var read_err := FileAccess.get_open_error()
		return _result.error(_errors.IO_ERROR, "failed to read file: %s" % error_string(read_err))

	var byte_count := int(file.get_length())
	var text := file.get_as_text()

	return _result.success("file read: %s" % file_path, {
		"path": file_path,
		"text": text,
		"byte_count": byte_count,
	})


func _normalize_path(raw_path: String) -> String:
	var normalized := _paths.normalize_res_path(raw_path)
	if normalized == "res://":
		return normalized

	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)

	return normalized


func _validate_file_path(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return {"ok": true}

	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return _result.error(_errors.TYPE_MISMATCH, "path is not a file: %s" % path)

	return _result.error(_errors.NOT_FOUND, "path not found: %s" % path)
