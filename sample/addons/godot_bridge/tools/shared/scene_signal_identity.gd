@tool
extends RefCounted


func collect(root: Node, scene_path: String, nodes_service: RefCounted) -> Array:
	var rows: Array = []
	_collect_from_node(root, root, scene_path, nodes_service, rows)
	rows.sort_custom(Callable(self, "_compare_rows"))
	return rows


func matches_filters(row: Dictionary, from_node: String, signal_name: String, to_target: String, method_name: String) -> bool:
	if not from_node.is_empty() and str(row.get("from_node", "")) != from_node:
		return false
	if not signal_name.is_empty() and str(row.get("signal", "")) != signal_name:
		return false
	if not to_target.is_empty() and str(row.get("to_target", "")) != to_target:
		return false
	if not method_name.is_empty() and str(row.get("method", "")) != method_name:
		return false
	return true


func has_exact(rows: Array, scene_path: String, from_node: String, signal_name: String, to_target: String, method_name: String, flags: int = -1) -> bool:
	return not find_match(rows, scene_path, from_node, signal_name, to_target, method_name, flags).is_empty()


func find_match(rows: Array, scene_path: String, from_node: String, signal_name: String, to_target: String, method_name: String, flags: int = -1) -> Dictionary:
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("scene_path", "")) != scene_path:
			continue
		if str(row.get("from_node", "")) != from_node:
			continue
		if str(row.get("signal", "")) != signal_name:
			continue
		if str(row.get("to_target", "")) != to_target:
			continue
		if str(row.get("method", "")) != method_name:
			continue
		if flags >= 0 and int(row.get("flags", 0)) != flags:
			continue
		return row

	return {}


func _collect_from_node(root: Node, current: Node, scene_path: String, nodes_service: RefCounted, rows: Array) -> void:
	if current == null:
		return

	var from_path: String = str(nodes_service.canonical_node_path(root, current))
	var signal_names: Array = []
	var seen_signal_names := {}
	for signal_item in current.get_signal_list():
		if typeof(signal_item) != TYPE_DICTIONARY:
			continue
		var candidate := str(signal_item.get("name", "")).strip_edges()
		if candidate.is_empty():
			continue
		if seen_signal_names.has(candidate):
			continue
		seen_signal_names[candidate] = true
		signal_names.append(candidate)

	signal_names.sort()

	for signal_name in signal_names:
		for connection_item in current.get_signal_connection_list(signal_name):
			if typeof(connection_item) != TYPE_DICTIONARY:
				continue
			var connection: Dictionary = connection_item
			if not connection.has("callable"):
				continue
			var callable_value = connection.get("callable")
			if typeof(callable_value) != TYPE_CALLABLE:
				continue

			var callable: Callable = callable_value
			var target = callable.get_object()
			var method_name := str(callable.get_method()).strip_edges()
			if method_name.is_empty():
				continue
			var to_target := _target_ref(root, target, nodes_service)
			if to_target.is_empty():
				continue

			rows.append({
				"scene_path": scene_path,
				"from_node": from_path,
				"signal": signal_name,
				"to_target": to_target,
				"method": method_name,
				"flags": _normalize_flags(int(connection.get("flags", 0))),
			})

	for child in current.get_children():
		if child is Node:
			_collect_from_node(root, child, scene_path, nodes_service, rows)


func _target_ref(root: Node, target_object: Variant, nodes_service: RefCounted) -> String:
	if target_object == null:
		return ""

	if target_object is Node:
		var target_node: Node = target_object
		if target_node == root or root.is_ancestor_of(target_node):
			return nodes_service.canonical_node_path(root, target_node)
		return ""

	return ""


func _normalize_flags(flags: int) -> int:
	return flags & 15


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_scene := str(a.get("scene_path", ""))
	var b_scene := str(b.get("scene_path", ""))
	if a_scene != b_scene:
		return a_scene < b_scene

	var a_from := str(a.get("from_node", ""))
	var b_from := str(b.get("from_node", ""))
	if a_from != b_from:
		return a_from < b_from

	var a_signal := str(a.get("signal", ""))
	var b_signal := str(b.get("signal", ""))
	if a_signal != b_signal:
		return a_signal < b_signal

	var a_to := str(a.get("to_target", ""))
	var b_to := str(b.get("to_target", ""))
	if a_to != b_to:
		return a_to < b_to

	var a_method := str(a.get("method", ""))
	var b_method := str(b.get("method", ""))
	if a_method != b_method:
		return a_method < b_method

	return int(a.get("flags", 0)) < int(b.get("flags", 0))
