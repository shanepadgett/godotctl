@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PROPERTY_ASSIGNMENT_VALIDATOR_SCRIPT := preload("res://addons/godot_bridge/tools/core/property_assignment_validator.gd")
const RESOURCE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/resource_store.gd")
const VALUE_DECODER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/value_decoder.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _property_validator = PROPERTY_ASSIGNMENT_VALIDATOR_SCRIPT.new()
var _store = RESOURCE_STORE_SCRIPT.new()
var _decoder = VALUE_DECODER_SCRIPT.new()


func tool_name() -> String:
	return "resource.set_prop"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _store.load_resource(str(args.get("path", "")), "path")
	if not bool(load_result.get("ok", false)):
		return load_result

	var resource_path := str(load_result.get("resource_path", ""))
	var resource: Resource = load_result.get("resource", null)

	var property_name := str(args.get("prop", "")).strip_edges()
	if property_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "prop is required")

	var value_result := _decoder.parse_value_json(str(args.get("value_json", "")))
	if not bool(value_result.get("ok", false)):
		return value_result

	var value = value_result.get("value", null)
	var property_validation := _property_validator.validate(resource, property_name, value)
	if not bool(property_validation.get("ok", false)):
		return property_validation

	var changed: bool = resource.get(property_name) != value
	var saved := false
	var filesystem_refreshed := false

	if changed:
		resource.set(property_name, value)
		var save_result := _store.save_resource(resource_path, resource)
		if not bool(save_result.get("ok", false)):
			return save_result

		saved = bool(save_result.get("saved", false))
		filesystem_refreshed = bool(save_result.get("filesystem_refreshed", false))

	return _result.success("resource property set: %s.%s" % [resource_path, property_name], {
		"resource_path": resource_path,
		"property": property_name,
		"changed": changed,
		"saved": saved,
		"filesystem_refreshed": filesystem_refreshed,
	})
