@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func tool_name() -> String:
	return "tools.describe"


func execute(args: Dictionary) -> Dictionary:
	var requested_tool := str(args.get("tool", "")).strip_edges()
	var definitions := _build_definitions()
	definitions.sort_custom(Callable(self, "_compare_definitions"))

	if requested_tool.is_empty():
		return _result.success("tool schemas listed", {
			"schema_version": "godotctl.tool-schema.v1",
			"requested_tool": "",
			"tools": definitions,
			"count": definitions.size(),
		})

	for definition in definitions:
		if str(definition.get("name", "")) == requested_tool:
			return _result.success("tool schema retrieved: %s" % requested_tool, {
				"schema_version": "godotctl.tool-schema.v1",
				"requested_tool": requested_tool,
				"tools": [definition],
				"count": 1,
			})

	return _result.error(_errors.NOT_FOUND, "tool not found: %s" % requested_tool)


func _build_definitions() -> Array:
	return [
		_tool_definition(
			"class.describe",
			"Describe Godot class metadata",
			_args_schema(["name"], {
				"name": _schema("string", "Godot class name"),
				"include_properties": _schema("bool", "Include detailed property metadata (defaults to false)"),
				"include_methods": _schema("bool", "Include detailed method metadata (defaults to false)"),
				"include_signals": _schema("bool", "Include detailed signal metadata (defaults to false)"),
				"include_inheritors": _schema("bool", "Include direct inheritor class names (defaults to false)"),
			}),
			_result_schema({
				"class_name": _schema("string", "Resolved class name"),
				"parent_class": _schema("string", "Immediate parent class name"),
				"inheritance": _schema("array<string>", "Class to root inheritance chain"),
				"include_properties": _schema("bool", "Whether detailed properties are included"),
				"include_methods": _schema("bool", "Whether detailed methods are included"),
				"include_signals": _schema("bool", "Whether detailed signals are included"),
				"include_inheritors": _schema("bool", "Whether direct inheritors are included"),
				"inheritors": _schema("array<string>", "Direct inheritor class names"),
				"inheritor_count": _schema("int", "Direct inheritor count"),
				"instantiable": _schema("bool", "Whether ClassDB.instantiate succeeds"),
				"properties": _schema("array<object>", "Sorted property metadata rows"),
				"methods": _schema("array<object>", "Sorted method metadata rows"),
				"signals": _schema("array<object>", "Sorted signal metadata rows"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "INTERNAL"])
		),
		_tool_definition(
			"file.list",
			"List project files and directories",
			_args_schema(["path"], {
				"path": _schema("string", "Project-relative directory path"),
				"recursive": _schema("bool", "Recursively include nested entries"),
			}),
			_result_schema({
				"path": _schema("string", "Resolved directory path"),
				"recursive": _schema("bool", "Recursive mode"),
				"entries": _schema("array<object>", "Sorted file and directory entries"),
				"count": _schema("int", "Entry count"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"file.read",
			"Read a project file as text",
			_args_schema(["path"], {
				"path": _schema("string", "Project-relative file path"),
			}),
			_result_schema({
				"path": _schema("string", "Resolved file path"),
				"text": _schema("string", "File text content"),
				"byte_count": _schema("int", "File size in bytes"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"ping",
			"Round-trip plugin reachability check",
			_args_schema([], {}),
			_result_schema({
				"message": _schema("string", "Ping response message"),
			}),
			_error_schema(["INTERNAL"])
		),
		_tool_definition(
			"project.graph",
			"Build deterministic project dependency graph",
			_args_schema([], {
				"root_path": _schema("string", "Optional graph root path (defaults to res://)"),
				"path_prefix": _schema("string", "Optional path prefix filter for nodes and edges"),
				"include_nodes": _schema("bool", "Include node rows in result payload (defaults to false)"),
				"include_edges": _schema("bool", "Include edge rows in result payload (defaults to false)"),
				"max_nodes": _schema("int", "Max returned nodes (0 means no limit, default 200)"),
				"max_edges": _schema("int", "Max returned edges (0 means no limit, default 200)"),
			}),
			_result_schema({
				"root_path": _schema("string", "Graph root path"),
				"path_prefix": _schema("string", "Applied path prefix filter"),
				"include_nodes": _schema("bool", "Whether nodes were included"),
				"include_edges": _schema("bool", "Whether edges were included"),
				"max_nodes": _schema("int", "Requested max nodes"),
				"max_edges": _schema("int", "Requested max edges"),
				"scanned_file_count": _schema("int", "Indexed file count under root"),
				"scanned_node_count": _schema("int", "Node count before filtering"),
				"scanned_edge_count": _schema("int", "Edge count before filtering"),
				"nodes": _schema("array<object>", "Sorted graph nodes with path"),
				"edges": _schema("array<object>", "Sorted dependency edges"),
				"node_count": _schema("int", "Node count"),
				"edge_count": _schema("int", "Edge count"),
				"returned_node_count": _schema("int", "Returned node row count"),
				"returned_edge_count": _schema("int", "Returned edge row count"),
				"nodes_truncated": _schema("bool", "Whether node rows were truncated by limit"),
				"edges_truncated": _schema("bool", "Whether edge rows were truncated by limit"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"project.input_map_get",
			"Inspect project input map actions",
			_args_schema([], {
				"action": _schema("string", "Optional action name"),
				"prefix": _schema("string", "Optional action name prefix filter"),
				"include_actions": _schema("bool", "Include action rows in result payload (defaults to true)"),
				"include_events": _schema("bool", "Include summarized events in action rows (defaults to false)"),
				"max_actions": _schema("int", "Max returned action rows (0 means no limit, default 200)"),
				"max_events": _schema("int", "Max returned events per action (0 means no limit, default 200)"),
			}),
			_result_schema({
				"requested_action": _schema("string", "Requested action name, empty when listing"),
				"prefix": _schema("string", "Applied action name prefix filter"),
				"include_actions": _schema("bool", "Whether action rows were included"),
				"include_events": _schema("bool", "Whether event rows were included"),
				"max_actions": _schema("int", "Requested max actions"),
				"max_events": _schema("int", "Requested max events per action"),
				"actions": _schema("array<object>", "Sorted input actions"),
				"count": _schema("int", "Action count"),
				"returned_count": _schema("int", "Returned action row count"),
				"truncated": _schema("bool", "Whether action rows were truncated by limit"),
				"total_event_count": _schema("int", "Total event count"),
				"returned_event_count": _schema("int", "Returned event row count"),
				"actions_with_truncated_events": _schema("int", "Action rows where events were truncated by limit"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "INTERNAL"])
		),
		_tool_definition(
			"project.settings_get",
			"Inspect project settings",
			_args_schema([], {
				"key": _schema("string", "Optional project setting key"),
				"prefix": _schema("string", "Optional setting key prefix filter"),
				"include_settings": _schema("bool", "Include setting rows in result payload (defaults to true)"),
				"include_values": _schema("bool", "Include serialized setting values (defaults to false)"),
				"max_settings": _schema("int", "Max returned setting rows (0 means no limit, default 200)"),
			}),
			_result_schema({
				"requested_key": _schema("string", "Requested key, empty when listing"),
				"prefix": _schema("string", "Applied setting key prefix filter"),
				"include_settings": _schema("bool", "Whether setting rows were included"),
				"include_values": _schema("bool", "Whether setting values were included"),
				"max_settings": _schema("int", "Requested max settings"),
				"settings": _schema("array<object>", "Sorted project setting rows"),
				"count": _schema("int", "Setting count"),
				"returned_count": _schema("int", "Returned setting row count"),
				"truncated": _schema("bool", "Whether setting rows were truncated by limit"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"resource.create",
			"Create a project resource",
			_args_schema(["path", "type"], {
				"path": _schema("string", "Project-relative resource path"),
				"type": _schema("string", "Resource class name"),
				"overwrite": _schema("bool", "Overwrite existing resource"),
			}),
			_result_schema({
				"resource_path": _schema("string", "Resolved resource path"),
				"type": _schema("string", "Created resource class"),
				"changed": _schema("bool", "Whether resource content changed"),
				"saved": _schema("bool", "Whether resource save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"resource.get",
			"Get one resource property",
			_args_schema(["path", "prop"], {
				"path": _schema("string", "Project-relative resource path"),
				"prop": _schema("string", "Property name"),
			}),
			_result_schema({
				"resource_path": _schema("string", "Resolved resource path"),
				"property": _schema("string", "Requested property name"),
				"value": _schema("any", "Property value payload"),
				"value_text": _schema("string", "Property value text form"),
				"value_type": _schema("string", "Property value variant type"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"resource.list",
			"List deterministic resource properties",
			_args_schema(["path"], {
				"path": _schema("string", "Project-relative resource path"),
				"include_values": _schema("bool", "Include serialized property values (defaults to false)"),
				"max_properties": _schema("int", "Max returned property rows (0 means no limit, default 200)"),
			}),
			_result_schema({
				"resource_path": _schema("string", "Resolved resource path"),
				"include_values": _schema("bool", "Whether value payloads were included"),
				"max_properties": _schema("int", "Requested max properties"),
				"properties": _schema("array<object>", "Sorted resource property rows"),
				"count": _schema("int", "Property count"),
				"returned_count": _schema("int", "Returned property row count"),
				"truncated": _schema("bool", "Whether property rows were truncated by limit"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"resource.set_prop",
			"Set one resource property",
			_args_schema(["path", "prop", "value_json"], {
				"path": _schema("string", "Project-relative resource path"),
				"prop": _schema("string", "Property name"),
				"value_json": _schema("string", "JSON primitive or typed object payload"),
			}),
			_result_schema({
				"resource_path": _schema("string", "Resolved resource path"),
				"property": _schema("string", "Updated property name"),
				"changed": _schema("bool", "Whether property value changed"),
				"saved": _schema("bool", "Whether resource save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"resource.refs",
			"List reverse references to one resource",
			_args_schema(["path"], {
				"path": _schema("string", "Target project resource path"),
				"from_prefix": _schema("string", "Optional source path prefix filter"),
				"include_references": _schema("bool", "Include reference rows in result payload (defaults to true)"),
				"max_refs": _schema("int", "Max returned reference rows (0 means no limit, default 200)"),
			}),
			_result_schema({
				"resource_path": _schema("string", "Resolved target resource path"),
				"from_prefix": _schema("string", "Applied source path prefix filter"),
				"include_references": _schema("bool", "Whether reference rows were included"),
				"max_refs": _schema("int", "Requested max references"),
				"references": _schema("array<object>", "Sorted reverse reference rows"),
				"count": _schema("int", "Reference count"),
				"returned_count": _schema("int", "Returned reference row count"),
				"truncated": _schema("bool", "Whether reference rows were truncated by limit"),
				"graph_node_count": _schema("int", "Node count in scanned graph"),
				"graph_edge_count": _schema("int", "Edge count in scanned graph"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"scene.add_node",
			"Add a child node and save scene",
			_args_schema(["scene_path", "node_name", "node_type", "parent_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_name": _schema("string", "Child node name"),
				"node_type": _schema("string", "Node class name"),
				"parent_path": _schema("string", "Parent node path"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical new node path"),
				"parent_path": _schema("string", "Canonical parent path"),
				"node_type": _schema("string", "Instantiated node type"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.duplicate_node",
			"Duplicate one node under a parent",
			_args_schema(["scene_path", "node_path", "parent_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Source node path"),
				"parent_path": _schema("string", "Parent node path for the duplicate"),
				"name": _schema("string", "Optional duplicate node name override"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"source_path": _schema("string", "Canonical source node path"),
				"parent_path": _schema("string", "Canonical parent node path"),
				"node_path": _schema("string", "Canonical created node path"),
				"name": _schema("string", "Created node name"),
				"name_collision": _schema("bool", "Whether name was auto-adjusted to avoid collision"),
				"changed": _schema("bool", "Whether scene content changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.group_add",
			"Add node membership to one group",
			_args_schema(["scene_path", "node_path", "group"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"group": _schema("string", "Group name"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"group": _schema("string", "Group name"),
				"changed": _schema("bool", "Whether group membership changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.group_list",
			"List deterministic group memberships",
			_args_schema(["scene_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Optional node path scope"),
				"max": _schema("int", "Max returned rows (0 means no limit, default 0)"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Applied node path scope"),
				"max": _schema("int", "Requested max rows"),
				"groups": _schema("array<object>", "Sorted group membership rows"),
				"count": _schema("int", "Total matching row count"),
				"returned_count": _schema("int", "Returned row count"),
				"truncated": _schema("bool", "Whether rows were truncated by max"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"scene.group_remove",
			"Remove node membership from one group",
			_args_schema(["scene_path", "node_path", "group"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"group": _schema("string", "Group name"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"group": _schema("string", "Group name"),
				"changed": _schema("bool", "Whether group membership changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.create",
			"Create a scene with root node",
			_args_schema(["scene_path", "root_type", "root_name"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"root_type": _schema("string", "Root node class"),
				"root_name": _schema("string", "Root node name"),
				"overwrite": _schema("bool", "Overwrite existing scene"),
				"open_in_editor": _schema("bool", "Open scene in editor after save"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"root_type": _schema("string", "Root node class"),
				"root_name": _schema("string", "Root node name"),
				"saved": _schema("bool", "Whether scene save completed"),
				"opened": _schema("bool", "Whether scene was opened in editor"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.inspect",
			"Inspect deterministic scene snapshots",
			_args_schema(["scene_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Optional node path to inspect only one subtree"),
				"include_properties": _schema("bool", "Include per-node property snapshots (defaults to false)"),
				"include_property_values": _schema("bool", "Include property value payloads when properties are included"),
				"include_connections": _schema("bool", "Include signal connection rows (defaults to false)"),
				"include_signal_names": _schema("bool", "Include per-node signal name lists (defaults to false)"),
				"max_properties": _schema("int", "Max properties per node (0 means no limit, defaults to 16)"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"requested_node_path": _schema("string", "Requested node scope path"),
				"resolved_node_path": _schema("string", "Resolved canonical node scope path"),
				"include_properties": _schema("bool", "Whether properties were included"),
				"include_property_values": _schema("bool", "Whether property values were included"),
				"include_connections": _schema("bool", "Whether signal connections were included"),
				"include_signal_names": _schema("bool", "Whether per-node signal names were included"),
				"max_properties": _schema("int", "Max properties requested per node"),
				"nodes": _schema("array<object>", "Sorted node snapshots"),
				"connections": _schema("array<object>", "Sorted signal connection snapshots"),
				"node_count": _schema("int", "Node count"),
				"connection_count": _schema("int", "Connection count"),
				"nodes_with_truncated_properties": _schema("int", "Nodes where property lists were truncated"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"scene.instance_scene",
			"Instance another scene as a child node",
			_args_schema(["scene_path", "source_scene_path", "parent_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"source_scene_path": _schema("string", "Source scene .tscn path to instance"),
				"parent_path": _schema("string", "Parent node path for the instance"),
				"name": _schema("string", "Optional created node name override"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"source_scene_path": _schema("string", "Resolved source scene path"),
				"parent_path": _schema("string", "Canonical parent node path"),
				"node_path": _schema("string", "Canonical created node path"),
				"name": _schema("string", "Created node name"),
				"name_collision": _schema("bool", "Whether name was auto-adjusted to avoid collision"),
				"changed": _schema("bool", "Whether scene content changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.node_configure",
			"Apply deterministic multi-property node config",
			_args_schema(["scene_path", "node_path", "config_json"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"config_json": _schema("string", "JSON object mapping property names to values"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"properties": _schema("array<object>", "Sorted property update rows"),
				"changed": _schema("bool", "Whether any property changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.rename_node",
			"Rename one scene node",
			_args_schema(["scene_path", "node_path", "name"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"name": _schema("string", "New node name"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path after rename"),
				"name": _schema("string", "New node name"),
				"changed": _schema("bool", "Whether node name changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.reparent_node",
			"Move one node under a different parent",
			_args_schema(["scene_path", "node_path", "parent_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path to move"),
				"parent_path": _schema("string", "New parent node path"),
				"index": _schema("int", "Optional destination child index"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical moved node path"),
				"parent_path": _schema("string", "Canonical parent node path"),
				"index": _schema("int", "Final child index under parent"),
				"changed": _schema("bool", "Whether node parent/index changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.remove_node",
			"Remove a node and save scene",
			_args_schema(["scene_path", "node_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path to remove"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"removed_path": _schema("string", "Canonical removed node path"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.signal_connect",
			"Connect one in-scene signal target",
			_args_schema(["scene_path", "from_node", "signal", "to_target", "method"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"from_node": _schema("string", "Canonical source node path"),
				"signal": _schema("string", "Signal name"),
				"to_target": _schema("string", "Canonical in-scene target node path"),
				"method": _schema("string", "Target method name"),
				"flags": _schema("int", "Optional connection flags filter"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"from_node": _schema("string", "Canonical source node path"),
				"signal": _schema("string", "Signal name"),
				"to_target": _schema("string", "Canonical target node path"),
				"method": _schema("string", "Target method name"),
				"flags": _schema("int", "Connection flags"),
				"changed": _schema("bool", "Whether connection changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.signal_disconnect",
			"Disconnect one in-scene signal target",
			_args_schema(["scene_path", "from_node", "signal", "to_target", "method"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"from_node": _schema("string", "Canonical source node path"),
				"signal": _schema("string", "Signal name"),
				"to_target": _schema("string", "Canonical in-scene target node path"),
				"method": _schema("string", "Target method name"),
				"flags": _schema("int", "Connection flags (defaults to 0)"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"from_node": _schema("string", "Canonical source node path"),
				"signal": _schema("string", "Signal name"),
				"to_target": _schema("string", "Canonical target node path"),
				"method": _schema("string", "Target method name"),
				"flags": _schema("int", "Connection flags"),
				"changed": _schema("bool", "Whether connection changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.signal_list",
			"List deterministic signal connections",
			_args_schema(["scene_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"from_node": _schema("string", "Optional source node path filter"),
				"signal": _schema("string", "Optional signal name filter"),
				"to_target": _schema("string", "Optional target node path filter"),
				"method": _schema("string", "Optional method name filter"),
				"max": _schema("int", "Max returned rows (0 means no limit, default 0)"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"from_node": _schema("string", "Applied source node filter"),
				"signal": _schema("string", "Applied signal filter"),
				"to_target": _schema("string", "Applied target node filter"),
				"method": _schema("string", "Applied method filter"),
				"max": _schema("int", "Requested max rows"),
				"connections": _schema("array<object>", "Sorted signal connection rows"),
				"count": _schema("int", "Total matching row count"),
				"returned_count": _schema("int", "Returned row count"),
				"truncated": _schema("bool", "Whether rows were truncated by max"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"scene.set_prop",
			"Set one node property and save scene",
			_args_schema(["scene_path", "node_path", "property", "value_json"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"property": _schema("string", "Property name"),
				"value_json": _schema("string", "JSON primitive or typed object payload"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"property": _schema("string", "Updated property name"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.transform_apply",
			"Apply minimal transform properties to node",
			_args_schema(["scene_path", "node_path", "value_json"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"value_json": _schema("string", "JSON object with transform property values"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"properties": _schema("array<object>", "Sorted transform property update rows"),
				"changed": _schema("bool", "Whether any property changed"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"scene.tree",
			"List deterministic scene node paths",
			_args_schema(["scene_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"nodes": _schema("array<object>", "Sorted node rows"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "TYPE_MISMATCH", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"script.attach",
			"Attach script to scene node",
			_args_schema(["scene_path", "node_path", "script_path"], {
				"scene_path": _schema("string", "Scene .tscn path"),
				"node_path": _schema("string", "Node path"),
				"script_path": _schema("string", "Script .gd path"),
				"overwrite": _schema("bool", "Overwrite existing attached script"),
			}),
			_result_schema({
				"scene_path": _schema("string", "Resolved scene path"),
				"node_path": _schema("string", "Canonical node path"),
				"script_path": _schema("string", "Resolved script path"),
				"overwrote": _schema("bool", "Whether existing script was replaced"),
				"saved": _schema("bool", "Whether scene save completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "ALREADY_EXISTS", "TYPE_MISMATCH", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"script.create",
			"Create script from deterministic template",
			_args_schema(["script_path", "base_class"], {
				"script_path": _schema("string", "Script .gd path"),
				"base_class": _schema("string", "Base class name"),
				"class_name": _schema("string", "Optional class_name declaration"),
				"overwrite": _schema("bool", "Overwrite existing script"),
			}),
			_result_schema({
				"script_path": _schema("string", "Resolved script path"),
				"base_class": _schema("string", "Template base class"),
				"class_name": _schema("string", "Template class_name"),
				"overwrote": _schema("bool", "Whether existing file was replaced"),
				"saved": _schema("bool", "Whether write completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "ALREADY_EXISTS", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"script.edit",
			"Apply literal replace-all edit to script",
			_args_schema(["script_path", "find_text", "replace_text"], {
				"script_path": _schema("string", "Script .gd path"),
				"find_text": _schema("string", "Literal text to find"),
				"replace_text": _schema("string", "Replacement text"),
			}),
			_result_schema({
				"script_path": _schema("string", "Resolved script path"),
				"match_count": _schema("int", "Literal matches found"),
				"replaced_count": _schema("int", "Literal replacements applied"),
				"saved": _schema("bool", "Whether write completed"),
				"filesystem_refreshed": _schema("bool", "Whether filesystem refresh completed"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "IO_ERROR", "EDITOR_STATE", "INTERNAL"])
		),
		_tool_definition(
			"script.validate",
			"Validate script parse and compile",
			_args_schema(["script_path"], {
				"script_path": _schema("string", "Script .gd path"),
			}),
			_result_schema({
				"script_path": _schema("string", "Resolved script path"),
				"valid": _schema("bool", "Whether script compiles"),
				"diagnostics": _schema("array<object>", "Validation diagnostics"),
			}),
			_error_schema(["INVALID_ARGS", "NOT_FOUND", "IO_ERROR", "INTERNAL"])
		),
		_tool_definition(
			"tools.describe",
			"Describe tool argument/result/error schemas",
			_args_schema([], {
				"tool": _schema("string", "Optional tool name to filter one schema"),
			}),
			_result_schema({
				"schema_version": _schema("string", "Schema format version"),
				"requested_tool": _schema("string", "Requested tool name"),
				"tools": _schema("array<object>", "Sorted tool schema entries"),
				"count": _schema("int", "Returned tool schema count"),
			}),
			_error_schema(["NOT_FOUND", "INTERNAL"])
		),
	]


func _tool_definition(name: String, summary: String, args_schema: Dictionary, result_schema: Dictionary, error_schema: Dictionary) -> Dictionary:
	return {
		"name": name,
		"summary": summary,
		"args_schema": args_schema,
		"result_schema": result_schema,
		"error_schema": error_schema,
	}


func _args_schema(required: Array, properties: Dictionary) -> Dictionary:
	return {
		"type": "object",
		"required": _sorted_strings(required),
		"properties": properties,
	}


func _result_schema(properties: Dictionary) -> Dictionary:
	return {
		"type": "object",
		"properties": properties,
	}


func _error_schema(tool_codes: Array) -> Dictionary:
	return {
		"tool_codes": _sorted_strings(tool_codes),
	}


func _schema(value_type: String, description: String) -> Dictionary:
	return {
		"type": value_type,
		"description": description,
	}


func _sorted_strings(values: Array) -> Array:
	var rows: Array = []
	for value in values:
		var text := str(value).strip_edges()
		if text.is_empty():
			continue
		rows.append(text)

	rows.sort()
	return rows


func _compare_definitions(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))
