@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const IDENTIFIER_VALIDATOR_SCRIPT := preload("res://addons/godot_bridge/tools/core/identifier_validator.gd")
const SCRIPT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/script_store.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _identifiers = IDENTIFIER_VALIDATOR_SCRIPT.new()
var _scripts = SCRIPT_STORE_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "script.create"


func set_host(host: Node) -> void:
	_filesystem.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var script_path_result := _scripts.validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	var base_class_result := _identifiers.validate_identifier(str(args.get("base_class", "")), "base_class")
	if not bool(base_class_result.get("ok", false)):
		return base_class_result

	var base_class := str(base_class_result.get("value", ""))
	var script_class_name := str(args.get("class_name", "")).strip_edges()
	if not script_class_name.is_empty():
		var class_name_result := _identifiers.validate_identifier(script_class_name, "class_name")
		if not bool(class_name_result.get("ok", false)):
			return class_name_result
		script_class_name = str(class_name_result.get("value", ""))

	var overwrite := bool(args.get("overwrite", false))
	var existed := FileAccess.file_exists(script_path)
	if existed and not overwrite:
		return _result.error(_errors.ALREADY_EXISTS, "script already exists: %s" % script_path)

	var parent_dir_result := _filesystem.ensure_parent_directory(script_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var template_source := _build_template_source(base_class, script_class_name)
	var write_result := _scripts.write_text_file(script_path, template_source)
	if not bool(write_result.get("ok", false)):
		return write_result

	var filesystem_refreshed := _filesystem.refresh_filesystem(script_path)
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "script saved but filesystem refresh failed")

	return _result.success("script created: %s" % script_path, {
		"script_path": script_path,
		"base_class": base_class,
		"class_name": script_class_name,
		"overwrote": existed,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	})


func _build_template_source(base_class: String, script_class_name: String) -> String:
	var source := "extends %s\n" % base_class
	if not script_class_name.is_empty():
		source += "class_name %s\n" % script_class_name
	source += "\n"
	source += "func _ready() -> void:\n"
	source += "\tpass\n"
	return source
