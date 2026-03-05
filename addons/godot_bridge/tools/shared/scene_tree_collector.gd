@tool
extends RefCounted

const NODE_PATH_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/node_path_service.gd")

var _nodes = NODE_PATH_SERVICE_SCRIPT.new()


func collect(root: Node) -> Array:
	var rows: Array = []
	_collect_recursive(root, root, rows)
	rows.sort_custom(Callable(self, "_compare_rows"))
	return rows


func _collect_recursive(root: Node, current: Node, rows: Array) -> void:
	if current == null:
		return

	rows.append({
		"path": _nodes.canonical_node_path(root, current),
		"name": str(current.name),
		"type": current.get_class(),
		"child_count": current.get_child_count(),
	})

	for child in current.get_children():
		if child is Node:
			_collect_recursive(root, child, rows)


func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))
