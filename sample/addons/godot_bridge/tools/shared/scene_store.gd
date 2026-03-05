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


func load_root(scene_path_raw: String, field_name: String = "scene_path") -> Dictionary:
	var path_result := _validate_scene_path(scene_path_raw, field_name)
	if not bool(path_result.get("ok", false)):
		return path_result

	var scene_path := str(path_result.get("scene_path", ""))
	if not ResourceLoader.exists(scene_path):
		return _result.error(_errors.NOT_FOUND, "scene not found: %s" % scene_path)

	var resource := ResourceLoader.load(scene_path)
	if resource == null:
		return _result.error(_errors.IO_ERROR, "failed to load scene: %s" % scene_path)
	if not (resource is PackedScene):
		return _result.error(_errors.TYPE_MISMATCH, "resource is not a PackedScene: %s" % scene_path)

	var packed: PackedScene = resource
	var instance: Variant = packed.instantiate()
	if instance == null:
		return _result.error(_errors.INTERNAL, "failed to instantiate scene: %s" % scene_path)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _result.error(_errors.TYPE_MISMATCH, "scene root is not a Node: %s" % scene_path)

	return {
		"ok": true,
		"scene_path": scene_path,
		"root": instance,
	}


func save_root(scene_path: String, root: Node) -> Dictionary:
	if root == null:
		return _result.error(_errors.INTERNAL, "scene root is unavailable")

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to pack scene: %s" % error_string(pack_err))

	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to save scene: %s" % error_string(save_err))

	var filesystem_refreshed := _filesystem.refresh_filesystem(scene_path)
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "scene saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	}


func finalize(root: Node, response: Dictionary) -> Dictionary:
	if root != null:
		root.free()
	return response


func _validate_scene_path(scene_path_raw: String, field_name: String) -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "scene_path"

	var raw_path := str(scene_path_raw).strip_edges()
	if raw_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)

	var scene_path := _paths.normalize_res_path(raw_path)
	if not _paths.has_tscn_extension(scene_path):
		return _result.error(_errors.INVALID_ARGS, "%s must end with .tscn" % normalized_field)

	return {
		"ok": true,
		"scene_path": scene_path,
	}
