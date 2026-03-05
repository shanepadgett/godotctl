@tool
extends RefCounted

const TOOL_UTILS_SCRIPT := preload("res://addons/godot_bridge/tools/tool_utils.gd")

var _utils = TOOL_UTILS_SCRIPT.new()


func list_tools() -> Array[String]:
	var tools: Array[String] = []
	return _utils.sort_strings(tools)


func execute(tool: String, _args: Dictionary) -> Dictionary:
	return _utils.make_error(_utils.ERROR_NOT_FOUND, "unknown tool: %s" % tool)
