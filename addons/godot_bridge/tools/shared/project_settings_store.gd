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


func validate_setting_key(raw_key: String, field_name: String = "key") -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "key"

	var key := str(raw_key).strip_edges()
	if key.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)
	if key.find("/") == -1:
		return _result.error(_errors.INVALID_ARGS, "%s must contain a section path" % normalized_field)

	return {
		"ok": true,
		"key": key,
	}


func list_setting_names(prefix: String = "") -> Array:
	var rows: Array = []
	var seen := {}
	var normalized_prefix := str(prefix).strip_edges()

	for property_info in ProjectSettings.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue

		var name := str(property_info.get("name", "")).strip_edges()
		if name.is_empty():
			continue
		if normalized_prefix != "" and not name.begins_with(normalized_prefix):
			continue
		if seen.has(name):
			continue

		seen[name] = true
		rows.append(name)

	rows.sort()
	return rows


func has_setting(name: String) -> bool:
	return ProjectSettings.has_setting(str(name).strip_edges())


func get_setting(name: String, default_value: Variant = null) -> Variant:
	return ProjectSettings.get_setting(str(name).strip_edges(), default_value)


func get_order(name: String) -> int:
	return int(ProjectSettings.get_order(str(name).strip_edges()))


func set_setting(name: String, value: Variant) -> void:
	ProjectSettings.set_setting(str(name).strip_edges(), value)


func set_order(name: String, order: int) -> void:
	ProjectSettings.set_order(str(name).strip_edges(), order)


func save() -> Dictionary:
	var save_err := ProjectSettings.save()
	if save_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to save project settings: %s" % error_string(save_err))

	var filesystem_refreshed := _filesystem.refresh_filesystem("res://project.godot")
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "project settings saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	}


func validate_project_file_path(raw_path: String, field_name: String = "path") -> Dictionary:
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
		"path": resource_path,
	}
