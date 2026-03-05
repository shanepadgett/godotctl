@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _result = RESULT_FACTORY_SCRIPT.new()


func tool_name() -> String:
	return "ping"


func execute(_args: Dictionary) -> Dictionary:
	return _result.success("pong from godot_bridge", {
		"message": "pong from godot_bridge",
	})
