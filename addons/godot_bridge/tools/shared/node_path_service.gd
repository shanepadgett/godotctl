@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()


func resolve_node(root: Node, raw_path: String, field_name: String) -> Dictionary:
	if root == null:
		return _result.error(_errors.INTERNAL, "scene root is unavailable")

	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "node_path"

	var normalized_path := normalize_node_path(raw_path)
	if normalized_path.is_empty():
		return _result.error(_errors.INVALID_ARGS, "%s is required" % normalized_field)
	if normalized_path == ".":
		return {
			"ok": true,
			"node": root,
			"path": ".",
		}

	var node := root.get_node_or_null(NodePath(normalized_path))
	if node == null:
		return _result.error(_errors.NOT_FOUND, "node not found: %s" % normalized_path)

	return {
		"ok": true,
		"node": node,
		"path": canonical_node_path(root, node),
	}


func normalize_node_path(raw_path: String) -> String:
	var path := str(raw_path).strip_edges().replace("\\", "/")
	if path.is_empty():
		return ""
	if path == ".":
		return "."

	if path.begins_with("./"):
		path = path.substr(2)

	while path.find("//") != -1:
		path = path.replace("//", "/")
	while path.begins_with("/"):
		path = path.substr(1)
	while path.ends_with("/"):
		path = path.substr(0, path.length() - 1)

	if path.is_empty():
		return "."

	return path


func canonical_node_path(root: Node, node: Node) -> String:
	if root == null or node == null:
		return ""
	if root == node:
		return "."

	var relative := str(root.get_path_to(node))
	return normalize_node_path(relative)


func has_child_named(parent: Node, node_name: String) -> bool:
	if parent == null:
		return false

	for child in parent.get_children():
		if not (child is Node):
			continue
		if str(child.name) == node_name:
			return true

	return false


func assign_owner_recursive(node: Node, owner: Node) -> void:
	if node == null:
		return

	node.owner = owner
	for child in node.get_children():
		if child is Node:
			assign_owner_recursive(child, owner)
