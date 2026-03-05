@tool
extends RefCounted

const TOOL_UTILS_SCRIPT := preload("res://addons/godot_bridge/tools/tool_utils.gd")
const SCENE_TOOLS_SCRIPT := preload("res://addons/godot_bridge/tools/scene_tools.gd")
const SCRIPT_TOOLS_SCRIPT := preload("res://addons/godot_bridge/tools/script_tools.gd")
const PROJECT_TOOLS_SCRIPT := preload("res://addons/godot_bridge/tools/project_tools.gd")
const FILE_TOOLS_SCRIPT := preload("res://addons/godot_bridge/tools/file_tools.gd")

var _utils = TOOL_UTILS_SCRIPT.new()
var _tool_handlers: Dictionary = {}
var _domains: Array = []
var _host: Node = null


func _init() -> void:
	_register_tool("ping", Callable(self, "_execute_ping"))
	_register_domain(SCENE_TOOLS_SCRIPT.new())
	_register_domain(SCRIPT_TOOLS_SCRIPT.new())
	_register_domain(PROJECT_TOOLS_SCRIPT.new())
	_register_domain(FILE_TOOLS_SCRIPT.new())


func set_host(host: Node) -> void:
	_host = host
	for domain in _domains:
		if domain == null:
			continue
		if domain.has_method("set_host"):
			domain.call("set_host", _host)


func list_tools() -> Array[String]:
	var tool_names: Array[String] = []
	for key in _tool_handlers.keys():
		tool_names.append(str(key))
	return _utils.sort_strings(tool_names)


func execute(tool: String, args: Dictionary) -> Dictionary:
	var tool_name := str(tool).strip_edges()
	if tool_name.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "tool is required")

	var call_args := args
	if typeof(call_args) != TYPE_DICTIONARY:
		call_args = {}

	if not _tool_handlers.has(tool_name):
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "unknown tool: %s" % tool_name)

	var handler_callable: Callable = _tool_handlers[tool_name]
	var response = handler_callable.call(call_args)
	return _normalize_execution_response(response)


func _register_domain(handler: RefCounted) -> void:
	if handler == null:
		return
	if not handler.has_method("list_tools"):
		return
	if not handler.has_method("execute"):
		return
	_domains.append(handler)
	if _host != null and handler.has_method("set_host"):
		handler.call("set_host", _host)

	var listed_tools = handler.call("list_tools")
	if typeof(listed_tools) != TYPE_ARRAY:
		return

	for item in listed_tools:
		if typeof(item) != TYPE_STRING:
			continue
		var tool_name := str(item).strip_edges()
		if tool_name.is_empty():
			continue
		_register_tool(tool_name, Callable(self, "_execute_domain_tool").bind(handler, tool_name))


func _register_tool(tool: String, handler: Callable) -> void:
	var tool_name := str(tool).strip_edges()
	if tool_name.is_empty():
		return
	if not handler.is_valid():
		return
	if _tool_handlers.has(tool_name):
		push_warning("godot_bridge: duplicate tool handler ignored for %s" % tool_name)
		return

	_tool_handlers[tool_name] = handler


func _execute_ping(_args: Dictionary) -> Dictionary:
	return _utils.make_success("pong from godot_bridge", {
		"message": "pong from godot_bridge",
	})


func _execute_domain_tool(args: Dictionary, handler: RefCounted, tool: String) -> Dictionary:
	if handler == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "domain handler is unavailable")
	if not handler.has_method("execute"):
		return _utils.make_error(_utils.ERROR_INTERNAL, "domain handler execute method missing")
	var result = handler.call("execute", tool, args)
	if typeof(result) != TYPE_DICTIONARY:
		return _utils.make_error(_utils.ERROR_INTERNAL, "domain handler returned invalid response")
	return result


func _normalize_execution_response(response: Variant) -> Dictionary:
	if typeof(response) != TYPE_DICTIONARY:
		return _utils.make_error(_utils.ERROR_INTERNAL, "tool handler returned invalid response")

	var payload: Dictionary = response
	if typeof(payload.get("ok", null)) != TYPE_BOOL:
		return _utils.make_error(_utils.ERROR_INTERNAL, "tool handler response is missing ok")

	var ok := bool(payload.get("ok", false))
	if ok:
		var result_value = payload.get("result", {})
		if typeof(result_value) != TYPE_DICTIONARY:
			return _utils.make_error(_utils.ERROR_INTERNAL, "tool handler response is missing result")

		var result: Dictionary = result_value
		var message := str(result.get("message", "")).strip_edges()
		if message.is_empty():
			message = "operation completed"

		var data = result.get("data", {})
		if typeof(data) != TYPE_DICTIONARY:
			data = {}

		var diagnostics = result.get("diagnostics", [])
		if typeof(diagnostics) != TYPE_ARRAY:
			diagnostics = []

		return {
			"ok": true,
			"result": {
				"code": "OK",
				"message": message,
				"data": data,
				"diagnostics": diagnostics,
			},
		}

	var error_message := str(payload.get("error", "")).strip_edges()
	if error_message.is_empty():
		error_message = "tool call failed"

	return {
		"ok": false,
		"error": error_message,
		"error_code": _utils.normalize_error_code(str(payload.get("error_code", ""))),
	}
