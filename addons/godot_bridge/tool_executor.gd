@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const EXECUTION_NORMALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/core/execution_response_normalizer.gd")
const TOOL_REGISTRY_SCRIPT := preload("res://addons/godot_bridge/tools/registry.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _normalizer = EXECUTION_NORMALIZER_SCRIPT.new()
var _tool_handlers: Dictionary = {}
var _handlers: Array = []
var _host: Node = null


func _init() -> void:
	var registry = TOOL_REGISTRY_SCRIPT.new()
	if not registry.has_method("instantiate_tools"):
		return

	var listed_tools = registry.call("instantiate_tools")
	if typeof(listed_tools) != TYPE_ARRAY:
		return

	for handler in listed_tools:
		if typeof(handler) != TYPE_OBJECT:
			continue
		_register_handler(handler)


func set_host(host: Node) -> void:
	_host = host
	for handler in _handlers:
		if handler == null:
			continue
		if handler.has_method("set_host"):
			handler.call("set_host", _host)


func list_tools() -> Array[String]:
	var tool_names: Array[String] = []
	for key in _tool_handlers.keys():
		tool_names.append(str(key))
	tool_names.sort()
	return tool_names


func execute(tool: String, args: Dictionary) -> Dictionary:
	var tool_name := str(tool).strip_edges()
	if tool_name.is_empty():
		return _result.error(_errors.INVALID_ARGS, "tool is required")

	var call_args := args
	if typeof(call_args) != TYPE_DICTIONARY:
		call_args = {}

	if not _tool_handlers.has(tool_name):
		return _result.error(_errors.NOT_FOUND, "unknown tool: %s" % tool_name)

	var handler = _tool_handlers[tool_name]
	if handler == null:
		return _result.error(_errors.INTERNAL, "tool handler is unavailable")
	if not handler.has_method("execute"):
		return _result.error(_errors.INTERNAL, "tool handler execute method missing")

	var response = handler.call("execute", call_args)
	return _normalizer.normalize(response)


func _register_handler(handler: RefCounted) -> void:
	if handler == null:
		return
	if not handler.has_method("tool_name"):
		return
	if not handler.has_method("execute"):
		return

	_handlers.append(handler)
	if _host != null and handler.has_method("set_host"):
		handler.call("set_host", _host)

	var tool_name := str(handler.call("tool_name")).strip_edges()
	if tool_name.is_empty():
		return
	_register_tool(tool_name, handler)


func _register_tool(tool: String, handler: RefCounted) -> void:
	var tool_name := str(tool).strip_edges()
	if tool_name.is_empty():
		return
	if handler == null:
		return
	if _tool_handlers.has(tool_name):
		push_warning("godot_bridge: duplicate tool handler ignored for %s" % tool_name)
		return

	_tool_handlers[tool_name] = handler
