@tool
extends RefCounted

const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")

var _paths = PATH_RULES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host


func ensure_parent_directory(path: String) -> Dictionary:
	var base_dir := _paths.normalize_res_path(str(path).get_base_dir())
	if base_dir.is_empty() or base_dir == "res://":
		return _result.success("parent directory available")

	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return _result.success("parent directory available")

	var mkdir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_err != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return _result.error(_errors.IO_ERROR, "failed to create directory: %s" % error_string(mkdir_err))

	return _result.success("parent directory available")


func refresh_filesystem(path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("get_resource_filesystem"):
		return false

	var filesystem = editor.call("get_resource_filesystem")
	if filesystem == null:
		return false

	if filesystem.has_method("update_file"):
		filesystem.call("update_file", path)
		return true

	if filesystem.has_method("scan"):
		filesystem.call("scan")
		return true

	return false


func open_scene(scene_path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("open_scene_from_path"):
		return false

	editor.call("open_scene_from_path", scene_path)
	return true


func _get_editor_interface() -> Variant:
	if _host == null:
		return null

	var plugin := _host.get_parent()
	if plugin == null:
		return null
	if not plugin.has_method("get_editor_interface"):
		return null

	return plugin.call("get_editor_interface")
