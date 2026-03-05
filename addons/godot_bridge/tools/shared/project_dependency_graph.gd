@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const PATH_RULES_SCRIPT := preload("res://addons/godot_bridge/tools/core/path_rules.gd")

const _INDEXED_EXTENSIONS := [
	".gd",
	".gdshader",
	".gdshaderinc",
	".material",
	".res",
	".scn",
	".shader",
	".tscn",
	".tres",
]

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _paths = PATH_RULES_SCRIPT.new()


func build_graph(root_path_raw: String = "res://", options: Dictionary = {}) -> Dictionary:
	var root_path := _paths.normalize_res_path(root_path_raw)
	if root_path.is_empty():
		root_path = "res://"

	var include_nodes := bool(options.get("include_nodes", true))
	var include_edges := bool(options.get("include_edges", true))
	var path_prefix := _normalize_prefix(str(options.get("path_prefix", "")))
	var max_nodes := int(options.get("max_nodes", 0))
	var max_edges := int(options.get("max_edges", 0))
	if max_nodes < 0:
		return _result.error(_errors.INVALID_ARGS, "max_nodes must be >= 0")
	if max_edges < 0:
		return _result.error(_errors.INVALID_ARGS, "max_edges must be >= 0")

	var absolute_root := ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return _result.error(_errors.NOT_FOUND, "path not found: %s" % root_path)

	var files: Array = []
	var collect_result := _collect_files(root_path, files)
	if not bool(collect_result.get("ok", false)):
		return collect_result

	files.sort()

	var node_set := {}
	for file_path in files:
		node_set[str(file_path)] = true

	var all_edge_rows: Array = []
	var edge_set := {}
	for file_path in files:
		var normalized_source := str(file_path)
		var dependencies := ResourceLoader.get_dependencies(normalized_source)
		for dependency in dependencies:
			var parsed := _parse_dependency_entry(str(dependency))
			var target_path := str(parsed.get("path", ""))
			var uid := str(parsed.get("uid", ""))

			if target_path.is_empty():
				if uid.is_empty():
					continue
				target_path = uid
			else:
				target_path = _paths.normalize_res_path(target_path)

			var edge_key := "%s|%s|%s" % [normalized_source, target_path, uid]
			if edge_set.has(edge_key):
				continue

			edge_set[edge_key] = true
			node_set[target_path] = true
			all_edge_rows.append({
				"from": normalized_source,
				"to": target_path,
				"uid": uid,
			})

	all_edge_rows.sort_custom(Callable(self, "_compare_edges"))

	var node_paths: Array = []
	for key in node_set.keys():
		node_paths.append(str(key))
	node_paths.sort()

	var filtered_node_paths := _filter_node_paths(node_paths, path_prefix)
	var filtered_edge_rows := _filter_edges(all_edge_rows, path_prefix)

	var returned_nodes: Array = []
	var returned_edges: Array = []
	var nodes_truncated := false
	var edges_truncated := false

	if include_nodes:
		var limited_node_paths := filtered_node_paths
		if max_nodes > 0 and limited_node_paths.size() > max_nodes:
			limited_node_paths = limited_node_paths.slice(0, max_nodes)
			nodes_truncated = true

		for node_path in limited_node_paths:
			returned_nodes.append({
				"path": node_path,
			})

	if include_edges:
		var limited_edge_rows := filtered_edge_rows
		if max_edges > 0 and limited_edge_rows.size() > max_edges:
			limited_edge_rows = limited_edge_rows.slice(0, max_edges)
			edges_truncated = true

		returned_edges = limited_edge_rows

	return {
		"ok": true,
		"root_path": root_path,
		"path_prefix": path_prefix,
		"include_nodes": include_nodes,
		"include_edges": include_edges,
		"max_nodes": max_nodes,
		"max_edges": max_edges,
		"scanned_file_count": files.size(),
		"scanned_node_count": node_paths.size(),
		"scanned_edge_count": all_edge_rows.size(),
		"node_count": filtered_node_paths.size(),
		"edge_count": filtered_edge_rows.size(),
		"returned_node_count": returned_nodes.size(),
		"returned_edge_count": returned_edges.size(),
		"nodes_truncated": nodes_truncated,
		"edges_truncated": edges_truncated,
		"nodes": returned_nodes,
		"edges": returned_edges,
	}


func _collect_files(path: String, out_files: Array) -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null:
		var open_err := DirAccess.get_open_error()
		return _result.error(_errors.IO_ERROR, "failed to open directory: %s" % error_string(open_err))

	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		if _should_skip_entry(name):
			continue

		var child_path := _join_res_path(path, name)
		if directory.current_is_dir():
			var nested := _collect_files(child_path, out_files)
			if not bool(nested.get("ok", false)):
				directory.list_dir_end()
				return nested
			continue

		if _is_indexed_file(child_path):
			out_files.append(child_path)

	directory.list_dir_end()
	return {
		"ok": true,
	}


func _should_skip_entry(name: String) -> bool:
	var normalized := str(name).strip_edges()
	if normalized.is_empty():
		return true
	if normalized.begins_with("."):
		return true
	if normalized == ".godot":
		return true

	return false


func _is_indexed_file(path: String) -> bool:
	var lower := str(path).to_lower()
	for extension in _INDEXED_EXTENSIONS:
		if lower.ends_with(extension):
			return true

	return false


func _join_res_path(parent_path: String, child_name: String) -> String:
	if parent_path == "res://":
		return "res://%s" % child_name

	return "%s/%s" % [parent_path, child_name]


func _parse_dependency_entry(raw_entry: String) -> Dictionary:
	var value := str(raw_entry).strip_edges()
	if value.is_empty():
		return {
			"uid": "",
			"path": "",
		}

	var sections := value.split("::", false)
	if sections.size() == 1:
		if value.begins_with("uid://"):
			return {
				"uid": _normalize_uid(value),
				"path": "",
			}
		return {
			"uid": "",
			"path": value,
		}

	var uid := _normalize_uid(str(sections[0]))
	var path := ""
	if sections.size() >= 3:
		path = str(sections[2]).strip_edges()
	else:
		path = str(sections[sections.size() - 1]).strip_edges()

	return {
		"uid": uid,
		"path": path,
	}


func _normalize_uid(raw_uid: String) -> String:
	var uid := str(raw_uid).strip_edges()
	if uid.is_empty():
		return ""
	if uid.begins_with("uid://"):
		return uid

	return "uid://%s" % uid


func _normalize_prefix(raw_prefix: String) -> String:
	var trimmed := str(raw_prefix).strip_edges()
	if trimmed.is_empty():
		return ""

	return _paths.normalize_res_path(trimmed)


func _filter_node_paths(node_paths: Array, path_prefix: String) -> Array:
	if path_prefix.is_empty():
		return node_paths

	var filtered: Array = []
	for node_path in node_paths:
		if _matches_prefix(str(node_path), path_prefix):
			filtered.append(node_path)

	return filtered


func _filter_edges(edge_rows: Array, path_prefix: String) -> Array:
	if path_prefix.is_empty():
		return edge_rows

	var filtered: Array = []
	for item in edge_rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = item
		var from_path := str(edge.get("from", ""))
		var to_path := str(edge.get("to", ""))
		if _matches_prefix(from_path, path_prefix) or _matches_prefix(to_path, path_prefix):
			filtered.append(edge)

	return filtered


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


func _compare_edges(a: Dictionary, b: Dictionary) -> bool:
	var a_from := str(a.get("from", ""))
	var b_from := str(b.get("from", ""))
	if a_from != b_from:
		return a_from < b_from

	var a_to := str(a.get("to", ""))
	var b_to := str(b.get("to", ""))
	if a_to != b_to:
		return a_to < b_to

	return str(a.get("uid", "")) < str(b.get("uid", ""))
