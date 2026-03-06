@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _host: Node = null


func tool_name() -> String:
	return "run.prop_list"


func set_host(host: Node) -> void:
	_host = host


func execute(args: Dictionary) -> Dictionary:
	var service = _runtime_service()
	if service == null:
		return _result.error(_errors.EDITOR_STATE, "runtime bridge service is unavailable")
	if not service.has_method("execute_prop_list"):
		return _result.error(_errors.INTERNAL, "runtime bridge service execute_prop_list is unavailable")
	return service.call("execute_prop_list", args)


func _runtime_service() -> Variant:
	if _host == null:
		return null
	if not _host.has_method("get_runtime_bridge_service"):
		return null
	return _host.call("get_runtime_bridge_service")
