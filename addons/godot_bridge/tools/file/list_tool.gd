@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()


func tool_name() -> String:
	return "file.list"


func execute(args: Dictionary) -> Dictionary:
	var raw_path := str(args.get("path", "")).strip_edges()
	if raw_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "path is required")

	var list_path := _normalize_path(raw_path)
	var recursive := bool(args.get("recursive", false))

	var validation := _validate_directory_path(list_path)
	if not bool(validation.get("ok", false)):
		return validation

	var entries: Array = []
	var collect_result := _collect_directory_entries(list_path, recursive, entries)
	if not bool(collect_result.get("ok", false)):
		return collect_result

	entries.sort_custom(Callable(self, "_compare_entries"))

	return _result.success("file list: %s" % list_path, {
		"path": list_path,
		"recursive": recursive,
		"entries": entries,
		"count": entries.size(),
	})


func _normalize_path(raw_path: String) -> String:
	var normalized := _paths.normalize_res_path(raw_path)
	if normalized == "res://":
		return normalized

	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)

	return normalized


func _validate_directory_path(path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return {"ok": true}

	if FileAccess.file_exists(path):
		return _result.error(_errors.TYPE_MISMATCH, "path is not a directory: %s" % path)

	return _result.error(_errors.NOT_FOUND, "path not found: %s" % path)


func _collect_directory_entries(path: String, recursive: bool, entries: Array) -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null:
		var open_err := DirAccess.get_open_error()
		return _result.error(_errors.IO_ERROR, "failed to open directory: %s" % error_string(open_err))

	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue

		var is_directory := directory.current_is_dir()
		var child_path := _join_res_path(path, name)

		entries.append({
			"path": child_path,
			"name": name,
			"kind": "dir" if is_directory else "file",
		})

		if recursive and is_directory:
			var nested_result := _collect_directory_entries(child_path, true, entries)
			if not bool(nested_result.get("ok", false)):
				directory.list_dir_end()
				return nested_result

	directory.list_dir_end()
	return {"ok": true}


func _join_res_path(parent_path: String, child_name: String) -> String:
	if parent_path == "res://":
		return "res://%s" % child_name

	return "%s/%s" % [parent_path, child_name]


func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))
