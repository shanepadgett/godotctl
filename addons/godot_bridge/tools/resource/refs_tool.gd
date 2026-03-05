@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")
const PROJECT_DEPENDENCY_GRAPH_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_dependency_graph.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()
var _graph = PROJECT_DEPENDENCY_GRAPH_SCRIPT.new()


func tool_name() -> String:
	return "resource.refs"


func execute(args: Dictionary) -> Dictionary:
	var raw_path := str(args.get("path", "")).strip_edges()
	if raw_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "path is required")

	var from_prefix := _normalize_from_prefix(str(args.get("from_prefix", "")))
	var include_references := bool(args.get("include_references", true))
	var max_refs := int(args.get("max_refs", 200))
	if max_refs < 0:
		return _result.error(_errors.INVALID_ARGS, "max_refs must be >= 0")

	var resource_path := _paths.normalize_res_path(raw_path)
	if resource_path == "res://":
		return _result.error(_errors.INVALID_ARGS, "path must target a project file")

	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if DirAccess.dir_exists_absolute(absolute_path):
		return _result.error(_errors.TYPE_MISMATCH, "path is not a file: %s" % resource_path)
	if not FileAccess.file_exists(resource_path):
		return _result.error(_errors.NOT_FOUND, "path not found: %s" % resource_path)

	var graph_result := _graph.build_graph("res://", {
		"include_nodes": false,
		"include_edges": true,
	})
	if not bool(graph_result.get("ok", false)):
		return graph_result

	var references: Array = []
	for item in graph_result.get("edges", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = item
		if str(edge.get("to", "")) != resource_path:
			continue

		var from_path := str(edge.get("from", ""))
		if not from_prefix.is_empty() and not _matches_prefix(from_path, from_prefix):
			continue

		references.append({
			"from": from_path,
			"uid": str(edge.get("uid", "")),
		})

	references.sort_custom(Callable(self, "_compare_references"))

	var total_count := references.size()
	var returned_references: Array = []
	var truncated := false

	if include_references:
		returned_references = references
		if max_refs > 0 and returned_references.size() > max_refs:
			returned_references = returned_references.slice(0, max_refs)
			truncated = true

	return _result.success("resource references listed: %s" % resource_path, {
		"resource_path": resource_path,
		"from_prefix": from_prefix,
		"include_references": include_references,
		"max_refs": max_refs,
		"references": returned_references,
		"count": total_count,
		"returned_count": returned_references.size(),
		"truncated": truncated,
		"graph_node_count": int(graph_result.get("node_count", 0)),
		"graph_edge_count": int(graph_result.get("edge_count", 0)),
	})


func _compare_references(a: Dictionary, b: Dictionary) -> bool:
	var a_from := str(a.get("from", ""))
	var b_from := str(b.get("from", ""))
	if a_from != b_from:
		return a_from < b_from

	return str(a.get("uid", "")) < str(b.get("uid", ""))


func _normalize_from_prefix(raw_prefix: String) -> String:
	var trimmed := str(raw_prefix).strip_edges()
	if trimmed.is_empty():
		return ""

	return _paths.normalize_res_path(trimmed)


func _matches_prefix(path: String, prefix: String) -> bool:
	if prefix.is_empty():
		return true

	var value := str(path)
	if value == prefix:
		return true

	if prefix == "res://":
		return value.begins_with("res://")

	if value.begins_with("%s." % prefix):
		return true

	return value.begins_with("%s/" % prefix)
