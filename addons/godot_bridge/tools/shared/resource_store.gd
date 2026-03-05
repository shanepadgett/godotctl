@tool
extends RefCounted

const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")

var _paths = PATH_RULES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()


func set_host(host: Node) -> void:
	_filesystem.set_host(host)


func validate_resource_path(raw_path: String, field_name: String = "path") -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "path"

	var path_raw := str(raw_path).strip_edges()
	if path_raw.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)

	var resource_path := _paths.normalize_res_path(path_raw)
	if resource_path == "res://":
		return _result.error(_errors.INVALID_ARGS, "%s must target a project file" % normalized_field)

	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return _result.error(_errors.TYPE_MISMATCH, "path is not a file: %s" % resource_path)

	return {
		"ok": true,
		"resource_path": resource_path,
	}


func load_resource(raw_path: String, field_name: String = "path") -> Dictionary:
	var path_result := validate_resource_path(raw_path, field_name)
	if not bool(path_result.get("ok", false)):
		return path_result

	var resource_path := str(path_result.get("resource_path", ""))
	if not FileAccess.file_exists(resource_path):
		return _result.error(_errors.NOT_FOUND, "resource not found: %s" % resource_path)

	var resource := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return _result.error(_errors.IO_ERROR, "failed to load resource: %s" % resource_path)

	return {
		"ok": true,
		"resource_path": resource_path,
		"resource": resource,
	}


func save_resource(resource_path: String, resource: Resource) -> Dictionary:
	if resource == null:
		return _result.error(_errors.INTERNAL, "resource is unavailable")

	var save_err := ResourceSaver.save(resource, resource_path)
	if save_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to save resource: %s" % error_string(save_err))

	var filesystem_refreshed := _filesystem.refresh_filesystem(resource_path)
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "resource saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	}


func ensure_parent_directory(resource_path: String) -> Dictionary:
	return _filesystem.ensure_parent_directory(resource_path)
