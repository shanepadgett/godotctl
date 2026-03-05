@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const NODE_CLASS_VALIDATOR_SCRIPT := preload("res://addons/godot_bridge/tools/core/node_class_validator.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()
var _class_validator = NODE_CLASS_VALIDATOR_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "scene.create"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)
	_filesystem.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var scene_path_raw := str(args.get("scene_path", "")).strip_edges()
	if scene_path_raw.is_empty():
		return _result.error(_errors.INVALID_ARGS, "scene_path is required")

	var scene_path := _paths.normalize_res_path(scene_path_raw)
	if not _paths.has_tscn_extension(scene_path):
		return _result.error(_errors.INVALID_ARGS, "scene_path must end with .tscn")

	var root_type := str(args.get("root_type", "")).strip_edges()
	var class_validation := _class_validator.validate_node_class(root_type, "root_type")
	if not bool(class_validation.get("ok", false)):
		return class_validation

	var root_name := str(args.get("root_name", "")).strip_edges()
	if root_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "root_name is required")

	var overwrite := bool(args.get("overwrite", false))
	var open_in_editor := bool(args.get("open_in_editor", false))
	if ResourceLoader.exists(scene_path) and not overwrite:
		return _result.error(_errors.ALREADY_EXISTS, "scene already exists: %s" % scene_path)

	var parent_dir_result := _filesystem.ensure_parent_directory(scene_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var instance: Variant = ClassDB.instantiate(root_type)
	if instance == null:
		return _result.error(_errors.INTERNAL, "could not instantiate root_type: %s" % root_type)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _result.error(_errors.TYPE_MISMATCH, "root_type is not a Node: %s" % root_type)

	var root: Node = instance
	root.name = root_name
	var save_result := _scene_store.save_root(scene_path, root)
	root.free()
	if not bool(save_result.get("ok", false)):
		return save_result

	var opened := false
	if open_in_editor:
		opened = _filesystem.open_scene(scene_path)
		if not opened:
			return _result.error(_errors.EDITOR_STATE, "scene saved but failed to open in editor")

	return _result.success("scene created: %s" % scene_path, {
		"scene_path": scene_path,
		"root_type": root_type,
		"root_name": root_name,
		"saved": true,
		"opened": opened,
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
