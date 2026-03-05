@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host
	_filesystem.set_host(host)
	_settings.set_host(host)


func resolve_source_path(raw_path: String) -> Dictionary:
	var path_result := _settings.validate_project_file_path(raw_path, "path")
	if not bool(path_result.get("ok", false)):
		return path_result

	var source_path := str(path_result.get("path", ""))
	if source_path.ends_with(".import"):
		return _result.error(_errors.INVALID_ARGS, "path must target the source asset, not the .import file")
	if _is_native_resource(source_path):
		return _result.error(_errors.TYPE_MISMATCH, "native Godot resources do not use import metadata: %s" % source_path)
	if not FileAccess.file_exists(source_path):
		return _result.error(_errors.NOT_FOUND, "asset not found: %s" % source_path)

	var import_path := "%s.import" % source_path
	return {
		"ok": true,
		"source_path": source_path,
		"import_path": import_path,
	}


func load_import_config(raw_path: String, create_missing: bool = false) -> Dictionary:
	var resolve_result := resolve_source_path(raw_path)
	if not bool(resolve_result.get("ok", false)):
		return resolve_result

	var source_path := str(resolve_result.get("source_path", ""))
	var import_path := str(resolve_result.get("import_path", ""))
	if not FileAccess.file_exists(import_path):
		if create_missing:
			return {
				"ok": true,
				"source_path": source_path,
				"import_path": import_path,
				"config": ConfigFile.new(),
				"created": true,
			}
		return _result.error(_errors.NOT_FOUND, "import metadata not found: %s" % import_path)

	var config := ConfigFile.new()
	var load_err := config.load(import_path)
	if load_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to load import metadata: %s" % error_string(load_err))

	return {
		"ok": true,
		"source_path": source_path,
		"import_path": import_path,
		"config": config,
		"created": false,
	}


func save_import_config(source_path: String, import_path: String, config: ConfigFile) -> Dictionary:
	var save_err := config.save(import_path)
	if save_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to save import metadata: %s" % error_string(save_err))

	var filesystem_refreshed := _filesystem.refresh_filesystem(import_path)
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "import metadata saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
		"source_path": source_path,
		"import_path": import_path,
	}


func reimport_source(source_path: String) -> Dictionary:
	var plugin := _get_plugin()
	if plugin == null or not plugin.has_method("get_editor_interface"):
		return _result.error(_errors.EDITOR_STATE, "editor interface unavailable for reimport")

	var editor = plugin.call("get_editor_interface")
	if editor == null or not editor.has_method("get_resource_filesystem"):
		return _result.error(_errors.EDITOR_STATE, "resource filesystem unavailable for reimport")

	var filesystem = editor.call("get_resource_filesystem")
	if filesystem == null:
		return _result.error(_errors.EDITOR_STATE, "resource filesystem unavailable for reimport")
	if filesystem.has_method("is_scanning") and bool(filesystem.call("is_scanning")):
		return _result.error(_errors.EDITOR_STATE, "cannot reimport while filesystem scan is in progress")

	if filesystem.has_method("update_file"):
		filesystem.call("update_file", source_path)
	if not filesystem.has_method("reimport_files"):
		return _result.error(_errors.EDITOR_STATE, "resource filesystem does not support reimport_files")

	filesystem.call("reimport_files", PackedStringArray([source_path]))
	return _result.success("asset reimported: %s" % source_path, {
		"source_path": source_path,
		"changed": true,
		"saved": false,
		"filesystem_refreshed": true,
	})


func _is_native_resource(path: String) -> bool:
	var lowered := path.to_lower()
	return lowered.ends_with(".tscn") or lowered.ends_with(".scn") or lowered.ends_with(".tres") or lowered.ends_with(".res")


func _get_plugin() -> Variant:
	if _host == null:
		return null
	return _host.get_parent()
