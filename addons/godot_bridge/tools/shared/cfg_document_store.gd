@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()


func set_host(host: Node) -> void:
	_settings.set_host(host)
	_filesystem.set_host(host)


func load_config(raw_path: String, create_missing: bool = false) -> Dictionary:
	var path_result := _settings.validate_project_file_path(raw_path, "path")
	if not bool(path_result.get("ok", false)):
		return path_result

	var config_path := str(path_result.get("path", ""))
	var lowered := config_path.to_lower()
	if not lowered.ends_with(".cfg") and not lowered.ends_with(".import"):
		return _result.error(_errors.TYPE_MISMATCH, "path must end with .cfg or .import")

	var config := ConfigFile.new()
	if not FileAccess.file_exists(config_path):
		if create_missing:
			return {
				"ok": true,
				"path": config_path,
				"config": config,
				"created": true,
			}
		return _result.error(_errors.NOT_FOUND, "file not found: %s" % config_path)

	var load_err := config.load(config_path)
	if load_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to load config file: %s" % error_string(load_err))

	return {
		"ok": true,
		"path": config_path,
		"config": config,
		"created": false,
	}


func save_config(path: String, config: ConfigFile) -> Dictionary:
	var save_err := config.save(path)
	if save_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to save config file: %s" % error_string(save_err))

	var refreshed := _filesystem.refresh_filesystem(path)
	if not refreshed:
		return _result.error(_errors.EDITOR_STATE, "config file saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": refreshed,
	}
