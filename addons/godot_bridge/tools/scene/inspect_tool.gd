@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _nodes = NODE_PATH_SERVICE_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "scene.inspect"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var include_properties := bool(args.get("include_properties", false))
	var include_property_values := bool(args.get("include_property_values", false))
	var include_connections := bool(args.get("include_connections", false))
	var include_signal_names := bool(args.get("include_signal_names", false))
	var max_properties := int(args.get("max_properties", 16))
	var requested_node_path := str(args.get("node_path", "")).strip_edges()
	if max_properties < 0:
		return _result.error(_errors.INVALID_ARGS, "max_properties must be >= 0")
	if include_property_values and not include_properties:
		return _result.error(_errors.INVALID_ARGS, "include_property_values requires include_properties=true")

	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)
	var start_node := root
	var resolved_node_path := "."
	if not requested_node_path.is_empty():
		var node_result := _nodes.resolve_node(root, requested_node_path, "node_path")
		if not bool(node_result.get("ok", false)):
			return _scene_store.finalize(root, node_result)

		start_node = node_result.get("node", root)
		resolved_node_path = str(node_result.get("path", "."))

	var node_rows: Array = []
	var connections: Array = []
	var stats := {
		"nodes_with_truncated_properties": 0,
	}
	_collect_node_rows(root, start_node, node_rows, connections, include_properties, include_property_values, include_connections, include_signal_names, max_properties, stats)

	node_rows.sort_custom(Callable(self, "_compare_node_rows"))
	connections.sort_custom(Callable(self, "_compare_connections"))

	return _scene_store.finalize(root, _result.success("scene inspect: %s" % scene_path, {
		"scene_path": scene_path,
		"requested_node_path": requested_node_path,
		"resolved_node_path": resolved_node_path,
		"include_properties": include_properties,
		"include_property_values": include_property_values,
		"include_connections": include_connections,
		"include_signal_names": include_signal_names,
		"max_properties": max_properties,
		"nodes": node_rows,
		"connections": connections,
		"node_count": node_rows.size(),
		"connection_count": connections.size(),
		"nodes_with_truncated_properties": int(stats.get("nodes_with_truncated_properties", 0)),
	}))


func _collect_node_rows(root: Node, current: Node, node_rows: Array, connections: Array, include_properties: bool, include_property_values: bool, include_connections: bool, include_signal_names: bool, max_properties: int, stats: Dictionary) -> void:
	if current == null:
		return

	var canonical_path := _nodes.canonical_node_path(root, current)
	var signal_names: Array = []
	if include_connections or include_signal_names:
		signal_names = _collect_signal_names(current)

	if include_connections:
		for signal_name in signal_names:
			var signal_connections := current.get_signal_connection_list(signal_name)
			for connection in signal_connections:
				if typeof(connection) != TYPE_DICTIONARY:
					continue
				var normalized := _normalize_connection(root, canonical_path, signal_name, connection)
				if normalized.is_empty():
					continue
				connections.append(normalized)

	var exposed_signal_names: Array = []
	if include_signal_names:
		exposed_signal_names = signal_names

	var property_snapshot := _collect_properties(current, include_properties, include_property_values, max_properties)
	if bool(property_snapshot.get("truncated", false)):
		stats["nodes_with_truncated_properties"] = int(stats.get("nodes_with_truncated_properties", 0)) + 1

	node_rows.append({
		"path": canonical_path,
		"name": str(current.name),
		"type": current.get_class(),
		"child_count": current.get_child_count(),
		"groups": _collect_groups(current),
		"properties": property_snapshot.get("properties", []),
		"property_count": int(property_snapshot.get("property_count", 0)),
		"properties_truncated": bool(property_snapshot.get("truncated", false)),
		"signal_names": exposed_signal_names,
	})

	for child in current.get_children():
		if child is Node:
			_collect_node_rows(root, child, node_rows, connections, include_properties, include_property_values, include_connections, include_signal_names, max_properties, stats)


func _collect_signal_names(node: Node) -> Array:
	var signal_names: Array = []
	var seen := {}

	for item in node.get_signal_list():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var signal_name := str(item.get("name", "")).strip_edges()
		if signal_name.is_empty():
			continue
		if seen.has(signal_name):
			continue
		seen[signal_name] = true
		signal_names.append(signal_name)

	signal_names.sort()
	return signal_names


func _collect_groups(node: Node) -> Array:
	var groups: Array = []
	var seen := {}

	for raw_group in node.get_groups():
		var group_name := str(raw_group).strip_edges()
		if group_name.is_empty():
			continue
		if seen.has(group_name):
			continue
		seen[group_name] = true
		groups.append(group_name)

	groups.sort()
	return groups


func _collect_properties(node: Node, include_properties: bool, include_values: bool, max_properties: int) -> Dictionary:
	if not include_properties:
		return {
			"properties": [],
			"property_count": 0,
			"truncated": false,
		}

	var rows: Array = []
	for item in node.get_property_list():
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var property_info: Dictionary = item
		var property_name := str(property_info.get("name", "")).strip_edges()
		if property_name.is_empty() or property_name.begins_with("_"):
			continue

		var usage := int(property_info.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue

		var row := {
			"name": property_name,
		}
		if include_values:
			var serialized := _serializer.serialize(node.get(property_name))
			row["value"] = serialized.get("value", null)
			row["value_text"] = str(serialized.get("text", ""))
			row["value_type"] = str(serialized.get("type", ""))

		rows.append(row)

	rows.sort_custom(Callable(self, "_compare_properties"))

	var property_count := rows.size()
	var truncated := false
	if max_properties > 0 and rows.size() > max_properties:
		rows = rows.slice(0, max_properties)
		truncated = true

	return {
		"properties": rows,
		"property_count": property_count,
		"truncated": truncated,
	}


func _normalize_connection(root: Node, source_path: String, signal_name: String, connection: Dictionary) -> Dictionary:
	if not connection.has("callable"):
		return {}

	var callable_value = connection.get("callable")
	if typeof(callable_value) != TYPE_CALLABLE:
		return {}

	var callable: Callable = callable_value
	var target_object = callable.get_object()
	var method_name := str(callable.get_method()).strip_edges()
	if method_name.is_empty():
		method_name = "<anonymous>"

	return {
		"from": source_path,
		"signal": signal_name,
		"to": _target_ref(root, target_object),
		"method": method_name,
		"flags": int(connection.get("flags", 0)),
	}


func _target_ref(root: Node, target_object: Variant) -> String:
	if target_object == null:
		return "null"

	if target_object is Node:
		var target_node: Node = target_object
		if target_node == root or root.is_ancestor_of(target_node):
			return _nodes.canonical_node_path(root, target_node)
		return "external_node:%s" % str(target_node.get_path())

	if target_object is Object:
		var target: Object = target_object
		return "object:%s#%d" % [target.get_class(), target.get_instance_id()]

	return str(target_object)


func _compare_node_rows(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))


func _compare_properties(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))


func _compare_connections(a: Dictionary, b: Dictionary) -> bool:
	var a_from := str(a.get("from", ""))
	var b_from := str(b.get("from", ""))
	if a_from != b_from:
		return a_from < b_from

	var a_signal := str(a.get("signal", ""))
	var b_signal := str(b.get("signal", ""))
	if a_signal != b_signal:
		return a_signal < b_signal

	var a_to := str(a.get("to", ""))
	var b_to := str(b.get("to", ""))
	if a_to != b_to:
		return a_to < b_to

	var a_method := str(a.get("method", ""))
	var b_method := str(b.get("method", ""))
	if a_method != b_method:
		return a_method < b_method

	return int(a.get("flags", 0)) < int(b.get("flags", 0))
