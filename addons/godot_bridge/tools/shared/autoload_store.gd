@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host
	_settings.set_host(host)


func list_autoloads() -> Array:
	var rows: Array = []
	for setting_name in _settings.list_setting_names("autoload/"):
		var autoload_name := str(setting_name).substr("autoload/".length())
		if autoload_name.is_empty():
			continue

		var parsed := _parse_setting_value(autoload_name, _settings.get_setting(setting_name))
		if parsed.is_empty():
			continue

		parsed["index"] = _settings.get_order(setting_name)
		rows.append(parsed)

	rows.sort_custom(Callable(self, "_compare_rows"))
	return rows


func add_autoload(name: String, path: String, singleton: bool, index: int) -> Dictionary:
	var normalized_name := str(name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "name is required")

	var path_result := _validate_autoload_path(path)
	if not bool(path_result.get("ok", false)):
		return path_result

	var autoload_path := str(path_result.get("path", ""))
	var existing_rows := list_autoloads()
	var setting_name := "autoload/%s" % normalized_name
	var setting_value := _encode_setting_value(autoload_path, singleton)
	var existing := _find_by_name(existing_rows, normalized_name)
	if existing != null:
		if str(existing.get("path", "")) == autoload_path and bool(existing.get("singleton", false)) == singleton:
			if index >= 0:
				var changed := int(existing.get("index", 0)) != index
				if changed:
					_settings.set_order(setting_name, index)
					var save_result := _settings.save()
					if not bool(save_result.get("ok", false)):
						return save_result
					return _result.success("autoload added: %s" % normalized_name, {
						"name": normalized_name,
						"path": autoload_path,
						"singleton": singleton,
						"enabled": true,
						"index": index,
						"changed": true,
						"saved": true,
						"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
					})

				return _result.success("autoload added: %s" % normalized_name, {
					"name": normalized_name,
					"path": autoload_path,
					"singleton": singleton,
					"enabled": true,
					"index": index,
					"changed": false,
					"saved": false,
					"filesystem_refreshed": false,
				})

			return _result.success("autoload already present: %s" % normalized_name, {
				"name": normalized_name,
				"path": autoload_path,
				"singleton": singleton,
				"enabled": true,
				"index": int(existing.get("index", 0)),
				"changed": false,
				"saved": false,
				"filesystem_refreshed": false,
			})

		return _result.error(_errors.ALREADY_EXISTS, "autoload already exists with different configuration: %s" % normalized_name)

	var plugin := _get_plugin()
	if singleton and plugin != null and plugin.has_method("add_autoload_singleton"):
		plugin.call("add_autoload_singleton", normalized_name, autoload_path)
	else:
		_settings.set_setting(setting_name, setting_value)

	if index >= 0:
		_settings.set_order(setting_name, index)

	var save_result := _settings.save()
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("autoload added: %s" % normalized_name, {
		"name": normalized_name,
		"path": autoload_path,
		"singleton": singleton,
		"enabled": true,
		"index": _settings.get_order(setting_name),
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})


func remove_autoload(name: String) -> Dictionary:
	var normalized_name := str(name).strip_edges()
	if normalized_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "name is required")

	var setting_name := "autoload/%s" % normalized_name
	if not _settings.has_setting(setting_name):
		return _result.success("autoload removed: %s" % normalized_name, {
			"name": normalized_name,
			"changed": false,
			"saved": false,
			"filesystem_refreshed": false,
		})

	var plugin := _get_plugin()
	if plugin != null and plugin.has_method("remove_autoload_singleton"):
		plugin.call("remove_autoload_singleton", normalized_name)
	else:
		_settings.set_setting(setting_name, null)

	var save_result := _settings.save()
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("autoload removed: %s" % normalized_name, {
		"name": normalized_name,
		"changed": true,
		"saved": true,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})


func _validate_autoload_path(raw_path: String) -> Dictionary:
	var normalized_path := _paths.normalize_res_path(raw_path)
	if normalized_path == "" or normalized_path == "res://":
		return _result.error(_errors.INVALID_ARGS, "path is required")
	if not normalized_path.ends_with(".gd") and not normalized_path.ends_with(".tscn"):
		return _result.error(_errors.TYPE_MISMATCH, "autoload path must end with .gd or .tscn")
	if not FileAccess.file_exists(normalized_path):
		return _result.error(_errors.NOT_FOUND, "autoload target not found: %s" % normalized_path)

	return {
		"ok": true,
		"path": normalized_path,
	}


func _parse_setting_value(name: String, raw_value: Variant) -> Dictionary:
	var value := str(raw_value).strip_edges()
	if value.is_empty():
		return {}

	var enabled := true
	var singleton := false
	var path := value
	if path.begins_with("*"):
		enabled = true
		singleton = true
		path = path.substr(1)

	return {
		"name": name,
		"path": path,
		"singleton": singleton,
		"enabled": enabled,
	}


func _encode_setting_value(path: String, singleton: bool) -> String:
	if singleton:
		return "*%s" % path
	return path


func _find_by_name(rows: Array, name: String) -> Variant:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("name", "")) == name:
			return row

	return null


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_index := int(a.get("index", 0))
	var b_index := int(b.get("index", 0))
	if a_index == b_index:
		return str(a.get("name", "")) < str(b.get("name", ""))

	return a_index < b_index


func _get_plugin() -> Variant:
	if _host == null:
		return null
	return _host.get_parent()
