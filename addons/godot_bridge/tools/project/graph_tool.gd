@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PROJECT_DEPENDENCY_GRAPH_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_dependency_graph.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _graph = PROJECT_DEPENDENCY_GRAPH_SCRIPT.new()


func tool_name() -> String:
	return "project.graph"


func execute(args: Dictionary) -> Dictionary:
	var root_path := str(args.get("root_path", "res://")).strip_edges()
	if root_path.is_empty():
		root_path = "res://"

	var options := {
		"path_prefix": str(args.get("path_prefix", "")).strip_edges(),
		"include_nodes": bool(args.get("include_nodes", false)),
		"include_edges": bool(args.get("include_edges", false)),
		"max_nodes": int(args.get("max_nodes", 200)),
		"max_edges": int(args.get("max_edges", 200)),
	}

	if int(options.get("max_nodes", 0)) < 0:
		return _result.error(_errors.INVALID_ARGS, "max_nodes must be >= 0")
	if int(options.get("max_edges", 0)) < 0:
		return _result.error(_errors.INVALID_ARGS, "max_edges must be >= 0")

	var graph_result := _graph.build_graph(root_path, options)
	if not bool(graph_result.get("ok", false)):
		return graph_result

	return _result.success("project graph built", {
		"root_path": str(graph_result.get("root_path", "res://")),
		"path_prefix": str(graph_result.get("path_prefix", "")),
		"include_nodes": bool(graph_result.get("include_nodes", false)),
		"include_edges": bool(graph_result.get("include_edges", false)),
		"max_nodes": int(graph_result.get("max_nodes", 0)),
		"max_edges": int(graph_result.get("max_edges", 0)),
		"scanned_file_count": int(graph_result.get("scanned_file_count", 0)),
		"scanned_node_count": int(graph_result.get("scanned_node_count", 0)),
		"scanned_edge_count": int(graph_result.get("scanned_edge_count", 0)),
		"nodes": graph_result.get("nodes", []),
		"edges": graph_result.get("edges", []),
		"node_count": int(graph_result.get("node_count", 0)),
		"edge_count": int(graph_result.get("edge_count", 0)),
		"returned_node_count": int(graph_result.get("returned_node_count", 0)),
		"returned_edge_count": int(graph_result.get("returned_edge_count", 0)),
		"nodes_truncated": bool(graph_result.get("nodes_truncated", false)),
		"edges_truncated": bool(graph_result.get("edges_truncated", false)),
	})
