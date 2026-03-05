@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const RESOURCE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/resource_store.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _store = RESOURCE_STORE_SCRIPT.new()


func tool_name() -> String:
	return "resource.create"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var path_result := _store.validate_resource_path(str(args.get("path", "")), "path")
	if not bool(path_result.get("ok", false)):
		return path_result

	var resource_path := str(path_result.get("resource_path", ""))
	var resource_type := str(args.get("type", "")).strip_edges()
	if resource_type.is_empty():
		return _result.error(_errors.INVALID_ARGS, "type is required")

	if not ClassDB.class_exists(resource_type):
		return _result.error(_errors.NOT_FOUND, "class does not exist: %s" % resource_type)

	var overwrite := bool(args.get("overwrite", false))
	if FileAccess.file_exists(resource_path) and not overwrite:
		return _result.error(_errors.ALREADY_EXISTS, "resource already exists: %s" % resource_path)

	var parent_dir_result := _store.ensure_parent_directory(resource_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var instance: Variant = ClassDB.instantiate(resource_type)
	if instance == null:
		return _result.error(_errors.TYPE_MISMATCH, "resource type is not instantiable: %s" % resource_type)
	if not (instance is Resource):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _result.error(_errors.TYPE_MISMATCH, "type is not a Resource: %s" % resource_type)

	var resource: Resource = instance
	resource.take_over_path(resource_path)

	var save_result := _store.save_resource(resource_path, resource)
	if not bool(save_result.get("ok", false)):
		return save_result

	return _result.success("resource created: %s" % resource_path, {
		"resource_path": resource_path,
		"type": resource_type,
		"changed": true,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	})
