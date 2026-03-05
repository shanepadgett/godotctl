@tool
extends RefCounted

const PING_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/misc/ping_tool.gd")
const SCENE_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/create_tool.gd")
const SCENE_ADD_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/add_node_tool.gd")
const SCENE_REMOVE_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/remove_node_tool.gd")
const SCENE_SET_PROP_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/set_prop_tool.gd")
const SCENE_TREE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/tree_tool.gd")
const SCRIPT_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/create_tool.gd")
const SCRIPT_EDIT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/edit_tool.gd")
const SCRIPT_VALIDATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/validate_tool.gd")
const SCRIPT_ATTACH_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/attach_tool.gd")
const PROJECT_SETTINGS_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/settings_get_tool.gd")
const PROJECT_INPUT_MAP_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_get_tool.gd")
const FILE_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/list_tool.gd")
const FILE_READ_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/read_tool.gd")


func instantiate_tools() -> Array[RefCounted]:
	return [
		PING_TOOL_SCRIPT.new(),
		SCENE_CREATE_TOOL_SCRIPT.new(),
		SCENE_ADD_NODE_TOOL_SCRIPT.new(),
		SCENE_REMOVE_NODE_TOOL_SCRIPT.new(),
		SCENE_SET_PROP_TOOL_SCRIPT.new(),
		SCENE_TREE_TOOL_SCRIPT.new(),
		SCRIPT_CREATE_TOOL_SCRIPT.new(),
		SCRIPT_EDIT_TOOL_SCRIPT.new(),
		SCRIPT_VALIDATE_TOOL_SCRIPT.new(),
		SCRIPT_ATTACH_TOOL_SCRIPT.new(),
		PROJECT_SETTINGS_GET_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_GET_TOOL_SCRIPT.new(),
		FILE_LIST_TOOL_SCRIPT.new(),
		FILE_READ_TOOL_SCRIPT.new(),
	]
