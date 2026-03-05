@tool
extends RefCounted

const TOOL_UTILS_SCRIPT := preload("res://addons/godot_bridge/tools/tool_utils.gd")

var _utils = TOOL_UTILS_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host


func list_tools() -> Array[String]:
	var tools: Array[String] = ["scene.create"]
	return _utils.sort_strings(tools)


func execute(tool: String, args: Dictionary) -> Dictionary:
	var tool_name := str(tool).strip_edges()
	if tool_name == "scene.create":
		return _scene_create(args)
	return _utils.make_error(_utils.ERROR_NOT_FOUND, "unknown tool: %s" % tool_name)


func _scene_create(args: Dictionary) -> Dictionary:
	var scene_path_raw := str(args.get("scene_path", "")).strip_edges()
	if scene_path_raw.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path is required")

	var scene_path := _utils.normalize_res_path(scene_path_raw)
	if not _utils.has_tscn_extension(scene_path):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path must end with .tscn")

	var root_type := str(args.get("root_type", "")).strip_edges()
	var class_validation := _utils.validate_node_class(root_type)
	if not bool(class_validation.get("ok", false)):
		return class_validation

	var root_name := str(args.get("root_name", "")).strip_edges()
	if root_name.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "root_name is required")

	var overwrite := bool(args.get("overwrite", false))
	var open_in_editor := bool(args.get("open_in_editor", false))

	if ResourceLoader.exists(scene_path) and not overwrite:
		return _utils.make_error(_utils.ERROR_ALREADY_EXISTS, "scene already exists: %s" % scene_path)

	var parent_dir_result := _ensure_parent_directory(scene_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var instance: Variant = ClassDB.instantiate(root_type)
	if instance == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "could not instantiate root_type: %s" % root_type)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "root_type is not a Node: %s" % root_type)

	var root: Node = instance
	root.name = root_name

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to pack scene: %s" % error_string(pack_err))

	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to save scene: %s" % error_string(save_err))

	var filesystem_refreshed := _refresh_filesystem(scene_path)
	if not filesystem_refreshed:
		return _utils.make_error(_utils.ERROR_EDITOR_STATE, "scene saved but filesystem refresh failed")

	var opened := false
	if open_in_editor:
		opened = _open_scene(scene_path)
		if not opened:
			return _utils.make_error(_utils.ERROR_EDITOR_STATE, "scene saved but failed to open in editor")

	return _utils.make_success("scene created: %s" % scene_path, {
		"scene_path": scene_path,
		"root_type": root_type,
		"root_name": root_name,
		"saved": true,
		"opened": opened,
		"filesystem_refreshed": filesystem_refreshed,
	})


func _ensure_parent_directory(scene_path: String) -> Dictionary:
	var base_dir := _utils.normalize_res_path(scene_path.get_base_dir())
	if base_dir.is_empty() or base_dir == "res://":
		return _utils.make_success("parent directory available")

	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_success("parent directory available")

	var mkdir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_err != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_error(_utils.ERROR_IO, "failed to create directory: %s" % error_string(mkdir_err))

	return _utils.make_success("parent directory available")


func _refresh_filesystem(scene_path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("get_resource_filesystem"):
		return false

	var filesystem = editor.call("get_resource_filesystem")
	if filesystem == null:
		return false

	if filesystem.has_method("update_file"):
		filesystem.call("update_file", scene_path)
		return true

	if filesystem.has_method("scan"):
		filesystem.call("scan")
		return true

	return false


func _open_scene(scene_path: String) -> bool:
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
