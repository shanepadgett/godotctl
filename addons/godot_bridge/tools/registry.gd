@tool
extends RefCounted

const PING_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/misc/ping_tool.gd")
const TOOLS_DESCRIBE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/misc/describe_tool.gd")
const CLASS_DESCRIBE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/class/describe_tool.gd")
const SCENE_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/create_tool.gd")
const SCENE_ADD_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/add_node_tool.gd")
const SCENE_RENAME_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/rename_node_tool.gd")
const SCENE_REPARENT_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/reparent_node_tool.gd")
const SCENE_DUPLICATE_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/duplicate_node_tool.gd")
const SCENE_INSTANCE_SCENE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/instance_scene_tool.gd")
const SCENE_REMOVE_NODE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/remove_node_tool.gd")
const SCENE_SIGNAL_CONNECT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/signal_connect_tool.gd")
const SCENE_SIGNAL_DISCONNECT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/signal_disconnect_tool.gd")
const SCENE_SIGNAL_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/signal_list_tool.gd")
const SCENE_GROUP_ADD_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/group_add_tool.gd")
const SCENE_GROUP_REMOVE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/group_remove_tool.gd")
const SCENE_GROUP_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/group_list_tool.gd")
const SCENE_SET_PROP_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/set_prop_tool.gd")
const SCENE_TRANSFORM_APPLY_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/transform_apply_tool.gd")
const SCENE_NODE_CONFIGURE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/node_configure_tool.gd")
const SCENE_TREE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/tree_tool.gd")
const SCENE_INSPECT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/scene/inspect_tool.gd")
const SCRIPT_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/create_tool.gd")
const SCRIPT_EDIT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/edit_tool.gd")
const SCRIPT_VALIDATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/validate_tool.gd")
const SCRIPT_ATTACH_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/script/attach_tool.gd")
const PROJECT_SETTINGS_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/settings_get_tool.gd")
const PROJECT_SETTINGS_SET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/settings_set_tool.gd")
const PROJECT_INPUT_MAP_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_get_tool.gd")
const PROJECT_INPUT_MAP_ACTION_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_action_create_tool.gd")
const PROJECT_INPUT_MAP_ACTION_DELETE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_action_delete_tool.gd")
const PROJECT_INPUT_MAP_EVENT_ADD_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_event_add_tool.gd")
const PROJECT_INPUT_MAP_EVENT_REMOVE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_event_remove_tool.gd")
const PROJECT_INPUT_MAP_DEADZONE_SET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/input_map_deadzone_set_tool.gd")
const PROJECT_AUTOLOAD_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/autoload_list_tool.gd")
const PROJECT_AUTOLOAD_ADD_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/autoload_add_tool.gd")
const PROJECT_AUTOLOAD_REMOVE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/autoload_remove_tool.gd")
const PROJECT_IMPORT_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/import_get_tool.gd")
const PROJECT_IMPORT_SET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/import_set_tool.gd")
const PROJECT_IMPORT_REIMPORT_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/import_reimport_tool.gd")
const PROJECT_GRAPH_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/project/graph_tool.gd")
const FILE_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/list_tool.gd")
const FILE_READ_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/read_tool.gd")
const FILE_JSON_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/json_get_tool.gd")
const FILE_JSON_SET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/json_set_tool.gd")
const FILE_JSON_REMOVE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/json_remove_tool.gd")
const FILE_CFG_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/cfg_get_tool.gd")
const FILE_CFG_SET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/cfg_set_tool.gd")
const FILE_CFG_REMOVE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/file/cfg_remove_tool.gd")
const RESOURCE_CREATE_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/resource/create_tool.gd")
const RESOURCE_GET_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/resource/get_tool.gd")
const RESOURCE_SET_PROP_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/resource/set_prop_tool.gd")
const RESOURCE_LIST_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/resource/list_tool.gd")
const RESOURCE_REFS_TOOL_SCRIPT := preload("res://addons/godot_bridge/tools/resource/refs_tool.gd")


func instantiate_tools() -> Array[RefCounted]:
	return [
		PING_TOOL_SCRIPT.new(),
		TOOLS_DESCRIBE_TOOL_SCRIPT.new(),
		CLASS_DESCRIBE_TOOL_SCRIPT.new(),
		SCENE_CREATE_TOOL_SCRIPT.new(),
		SCENE_ADD_NODE_TOOL_SCRIPT.new(),
		SCENE_RENAME_NODE_TOOL_SCRIPT.new(),
		SCENE_REPARENT_NODE_TOOL_SCRIPT.new(),
		SCENE_DUPLICATE_NODE_TOOL_SCRIPT.new(),
		SCENE_INSTANCE_SCENE_TOOL_SCRIPT.new(),
		SCENE_REMOVE_NODE_TOOL_SCRIPT.new(),
		SCENE_SIGNAL_CONNECT_TOOL_SCRIPT.new(),
		SCENE_SIGNAL_DISCONNECT_TOOL_SCRIPT.new(),
		SCENE_SIGNAL_LIST_TOOL_SCRIPT.new(),
		SCENE_GROUP_ADD_TOOL_SCRIPT.new(),
		SCENE_GROUP_REMOVE_TOOL_SCRIPT.new(),
		SCENE_GROUP_LIST_TOOL_SCRIPT.new(),
		SCENE_SET_PROP_TOOL_SCRIPT.new(),
		SCENE_TRANSFORM_APPLY_TOOL_SCRIPT.new(),
		SCENE_NODE_CONFIGURE_TOOL_SCRIPT.new(),
		SCENE_TREE_TOOL_SCRIPT.new(),
		SCENE_INSPECT_TOOL_SCRIPT.new(),
		SCRIPT_CREATE_TOOL_SCRIPT.new(),
		SCRIPT_EDIT_TOOL_SCRIPT.new(),
		SCRIPT_VALIDATE_TOOL_SCRIPT.new(),
		SCRIPT_ATTACH_TOOL_SCRIPT.new(),
		PROJECT_SETTINGS_GET_TOOL_SCRIPT.new(),
		PROJECT_SETTINGS_SET_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_GET_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_ACTION_CREATE_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_ACTION_DELETE_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_EVENT_ADD_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_EVENT_REMOVE_TOOL_SCRIPT.new(),
		PROJECT_INPUT_MAP_DEADZONE_SET_TOOL_SCRIPT.new(),
		PROJECT_AUTOLOAD_LIST_TOOL_SCRIPT.new(),
		PROJECT_AUTOLOAD_ADD_TOOL_SCRIPT.new(),
		PROJECT_AUTOLOAD_REMOVE_TOOL_SCRIPT.new(),
		PROJECT_IMPORT_GET_TOOL_SCRIPT.new(),
		PROJECT_IMPORT_SET_TOOL_SCRIPT.new(),
		PROJECT_IMPORT_REIMPORT_TOOL_SCRIPT.new(),
		PROJECT_GRAPH_TOOL_SCRIPT.new(),
		FILE_LIST_TOOL_SCRIPT.new(),
		FILE_READ_TOOL_SCRIPT.new(),
		FILE_JSON_GET_TOOL_SCRIPT.new(),
		FILE_JSON_SET_TOOL_SCRIPT.new(),
		FILE_JSON_REMOVE_TOOL_SCRIPT.new(),
		FILE_CFG_GET_TOOL_SCRIPT.new(),
		FILE_CFG_SET_TOOL_SCRIPT.new(),
		FILE_CFG_REMOVE_TOOL_SCRIPT.new(),
		RESOURCE_CREATE_TOOL_SCRIPT.new(),
		RESOURCE_GET_TOOL_SCRIPT.new(),
		RESOURCE_SET_PROP_TOOL_SCRIPT.new(),
		RESOURCE_LIST_TOOL_SCRIPT.new(),
		RESOURCE_REFS_TOOL_SCRIPT.new(),
	]
