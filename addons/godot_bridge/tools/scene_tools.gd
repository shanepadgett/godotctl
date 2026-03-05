@tool
extends RefCounted

const TOOL_UTILS_SCRIPT := preload("res://addons/godot_bridge/tools/tool_utils.gd")

var _utils = TOOL_UTILS_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host


func list_tools() -> Array[String]:
	var tools: Array[String] = [
		"scene.create",
		"scene.add_node",
		"scene.remove_node",
		"scene.set_prop",
		"scene.tree",
	]
	return _utils.sort_strings(tools)


func execute(tool: String, args: Dictionary) -> Dictionary:
	var tool_name := str(tool).strip_edges()
	if tool_name == "scene.create":
		return _scene_create(args)
	if tool_name == "scene.add_node":
		return _scene_add_node(args)
	if tool_name == "scene.remove_node":
		return _scene_remove_node(args)
	if tool_name == "scene.set_prop":
		return _scene_set_prop(args)
	if tool_name == "scene.tree":
		return _scene_tree(args)
	return _utils.make_error(_utils.ERROR_NOT_FOUND, "unknown tool: %s" % tool_name)


func _scene_create(args: Dictionary) -> Dictionary:
	var scene_path_raw := str(args.get("scene_path", "")).strip_edges()
	if scene_path_raw.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path is required")

	var scene_path := _utils.normalize_res_path(scene_path_raw)
	if not _utils.has_tscn_extension(scene_path):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path must end with .tscn")

	var root_type := str(args.get("root_type", "")).strip_edges()
	var class_validation := _utils.validate_node_class(root_type, "root_type")
	if not bool(class_validation.get("ok", false)):
		return class_validation

	var root_name := str(args.get("root_name", "")).strip_edges()
	if root_name.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "root_name is required")

	var overwrite := bool(args.get("overwrite", false))
	var open_in_editor := bool(args.get("open_in_editor", false))

	if ResourceLoader.exists(scene_path) and not overwrite:
		return _utils.make_error(_utils.ERROR_ALREADY_EXISTS, "scene already exists: %s" % scene_path)

	var parent_dir_result := _ensure_parent_directory(scene_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var instance: Variant = ClassDB.instantiate(root_type)
	if instance == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "could not instantiate root_type: %s" % root_type)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "root_type is not a Node: %s" % root_type)

	var root: Node = instance
	root.name = root_name

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to pack scene: %s" % error_string(pack_err))

	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to save scene: %s" % error_string(save_err))

	var filesystem_refreshed := _refresh_filesystem(scene_path)
	if not filesystem_refreshed:
		return _utils.make_error(_utils.ERROR_EDITOR_STATE, "scene saved but filesystem refresh failed")

	var opened := false
	if open_in_editor:
		opened = _open_scene(scene_path)
		if not opened:
			return _utils.make_error(_utils.ERROR_EDITOR_STATE, "scene saved but failed to open in editor")

	return _utils.make_success("scene created: %s" % scene_path, {
		"scene_path": scene_path,
		"root_type": root_type,
		"root_name": root_name,
		"saved": true,
		"opened": opened,
		"filesystem_refreshed": filesystem_refreshed,
	})


func _scene_add_node(args: Dictionary) -> Dictionary:
	var load_result := _load_scene_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var node_name := str(args.get("node_name", "")).strip_edges()
	if node_name.is_empty():
		return _finalize_response(root, _utils.make_error(_utils.ERROR_INVALID_ARGS, "node_name is required"))
	if node_name.find("/") != -1:
		return _finalize_response(root, _utils.make_error(_utils.ERROR_INVALID_ARGS, "node_name must not contain '/'"))

	var node_type := str(args.get("node_type", "")).strip_edges()
	var class_validation := _utils.validate_node_class(node_type, "node_type")
	if not bool(class_validation.get("ok", false)):
		return _finalize_response(root, class_validation)

	var parent_result := _resolve_node(root, str(args.get("parent_path", "")), "parent_path")
	if not bool(parent_result.get("ok", false)):
		return _finalize_response(root, parent_result)

	var parent: Node = parent_result.get("node", null)
	var canonical_parent_path := str(parent_result.get("path", ""))
	if _has_child_named(parent, node_name):
		return _finalize_response(root, _utils.make_error(_utils.ERROR_ALREADY_EXISTS, "child already exists under %s: %s" % [canonical_parent_path, node_name]))

	var instance: Variant = ClassDB.instantiate(node_type)
	if instance == null:
		return _finalize_response(root, _utils.make_error(_utils.ERROR_INTERNAL, "could not instantiate node_type: %s" % node_type))
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _finalize_response(root, _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "node_type is not a Node: %s" % node_type))

	var child: Node = instance
	child.name = node_name
	parent.add_child(child)
	_assign_owner_recursive(child, root)

	var canonical_node_path := _canonical_node_path(root, child)
	var save_result := _save_scene_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finalize_response(root, save_result)

	return _finalize_response(root, _utils.make_success("node added: %s" % canonical_node_path, {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"parent_path": canonical_parent_path,
		"node_type": node_type,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _scene_remove_node(args: Dictionary) -> Dictionary:
	var load_result := _load_scene_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var node_result := _resolve_node(root, str(args.get("node_path", "")), "node_path")
	if not bool(node_result.get("ok", false)):
		return _finalize_response(root, node_result)

	var target: Node = node_result.get("node", null)
	var canonical_target_path := str(node_result.get("path", ""))
	if canonical_target_path == ".":
		return _finalize_response(root, _utils.make_error(_utils.ERROR_INVALID_ARGS, "node_path cannot target root"))

	var parent := target.get_parent()
	if parent is Node:
		parent.remove_child(target)
	target.free()

	var save_result := _save_scene_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finalize_response(root, save_result)

	return _finalize_response(root, _utils.make_success("node removed: %s" % canonical_target_path, {
		"scene_path": scene_path,
		"removed_path": canonical_target_path,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _scene_set_prop(args: Dictionary) -> Dictionary:
	var load_result := _load_scene_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var node_result := _resolve_node(root, str(args.get("node_path", "")), "node_path")
	if not bool(node_result.get("ok", false)):
		return _finalize_response(root, node_result)

	var node: Node = node_result.get("node", null)
	var canonical_node_path := str(node_result.get("path", ""))

	var property_name := str(args.get("property", "")).strip_edges()
	if property_name.is_empty():
		return _finalize_response(root, _utils.make_error(_utils.ERROR_INVALID_ARGS, "property is required"))

	var value_result := _parse_value_json(str(args.get("value_json", "")))
	if not bool(value_result.get("ok", false)):
		return _finalize_response(root, value_result)

	var value = value_result.get("value", null)
	var property_validation := _utils.validate_property_assignment(node, property_name, value)
	if not bool(property_validation.get("ok", false)):
		return _finalize_response(root, property_validation)

	node.set(property_name, value)

	var save_result := _save_scene_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finalize_response(root, save_result)

	return _finalize_response(root, _utils.make_success("property set: %s.%s" % [canonical_node_path, property_name], {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"property": property_name,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _scene_tree(args: Dictionary) -> Dictionary:
	var load_result := _load_scene_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var nodes: Array = []
	_collect_scene_nodes(root, root, nodes)
	nodes.sort_custom(Callable(self, "_compare_tree_nodes"))

	return _finalize_response(root, _utils.make_success("scene tree: %s" % scene_path, {
		"scene_path": scene_path,
		"nodes": nodes,
	}))


func _load_scene_root(scene_path_raw: String) -> Dictionary:
	var raw_path := str(scene_path_raw).strip_edges()
	if raw_path.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path is required")

	var scene_path := _utils.normalize_res_path(raw_path)
	if not _utils.has_tscn_extension(scene_path):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "scene_path must end with .tscn")
	if not ResourceLoader.exists(scene_path):
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "scene not found: %s" % scene_path)

	var resource := ResourceLoader.load(scene_path)
	if resource == null:
		return _utils.make_error(_utils.ERROR_IO, "failed to load scene: %s" % scene_path)
	if not (resource is PackedScene):
		return _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "resource is not a PackedScene: %s" % scene_path)

	var packed: PackedScene = resource
	var instance: Variant = packed.instantiate()
	if instance == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "failed to instantiate scene: %s" % scene_path)
	if not (instance is Node):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		return _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "scene root is not a Node: %s" % scene_path)

	return {
		"ok": true,
		"scene_path": scene_path,
		"root": instance,
	}


func _save_scene_root(scene_path: String, root: Node) -> Dictionary:
	if root == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "scene root is unavailable")

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to pack scene: %s" % error_string(pack_err))

	var save_err := ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return _utils.make_error(_utils.ERROR_IO, "failed to save scene: %s" % error_string(save_err))

	var filesystem_refreshed := _refresh_filesystem(scene_path)
	if not filesystem_refreshed:
		return _utils.make_error(_utils.ERROR_EDITOR_STATE, "scene saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	}


func _resolve_node(root: Node, raw_path: String, field_name: String) -> Dictionary:
	if root == null:
		return _utils.make_error(_utils.ERROR_INTERNAL, "scene root is unavailable")

	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "node_path"

	var normalized_path := _normalize_node_path(raw_path)
	if normalized_path.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "%s is required" % normalized_field)
	if normalized_path == ".":
		return {
			"ok": true,
			"node": root,
			"path": ".",
		}

	var node := root.get_node_or_null(NodePath(normalized_path))
	if node == null:
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "node not found: %s" % normalized_path)

	return {
		"ok": true,
		"node": node,
		"path": _canonical_node_path(root, node),
	}


func _normalize_node_path(raw_path: String) -> String:
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


func _canonical_node_path(root: Node, node: Node) -> String:
	if root == null or node == null:
		return ""
	if root == node:
		return "."

	var relative := str(root.get_path_to(node))
	return _normalize_node_path(relative)


func _has_child_named(parent: Node, node_name: String) -> bool:
	if parent == null:
		return false

	for child in parent.get_children():
		if not (child is Node):
			continue
		if str(child.name) == node_name:
			return true

	return false


func _assign_owner_recursive(node: Node, owner: Node) -> void:
	if node == null:
		return

	node.owner = owner
	for child in node.get_children():
		if child is Node:
			_assign_owner_recursive(child, owner)


func _parse_value_json(raw_value_json: String) -> Dictionary:
	var value_json := str(raw_value_json).strip_edges()
	if value_json.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "value_json is required")

	var parser := JSON.new()
	var parse_err := parser.parse(value_json)
	if parse_err != OK:
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "value_json is invalid JSON: %s" % parser.get_error_message())

	var decode_result := _decode_typed_value(parser.data)
	if not bool(decode_result.get("ok", false)):
		return decode_result

	return {
		"ok": true,
		"value": decode_result.get("value", null),
	}


func _decode_typed_value(value: Variant) -> Dictionary:
	var value_type := typeof(value)
	if value_type == TYPE_NIL:
		return {"ok": true, "value": null}
	if value_type == TYPE_BOOL:
		return {"ok": true, "value": bool(value)}
	if value_type == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if value_type == TYPE_FLOAT:
		return {"ok": true, "value": float(value)}
	if value_type == TYPE_STRING:
		return {"ok": true, "value": str(value)}
	if value_type == TYPE_DICTIONARY:
		return _decode_typed_value_dictionary(value)

	return _utils.make_error(_utils.ERROR_INVALID_ARGS, "value_json must be a primitive or typed object")


func _decode_typed_value_dictionary(value: Dictionary) -> Dictionary:
	if not value.has("type"):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value object requires field: type")

	var type_name := str(value.get("type", "")).strip_edges()
	if type_name.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value object type must be non-empty")

	if type_name == "Vector2":
		return _decode_vector2(value)
	if type_name == "Vector3":
		return _decode_vector3(value)
	if type_name == "Color":
		return _decode_color(value)
	if type_name == "NodePath":
		return _decode_node_path(value)

	return _utils.make_error(_utils.ERROR_INVALID_ARGS, "unsupported typed value: %s" % type_name)


func _decode_vector2(value: Dictionary) -> Dictionary:
	var x_result := _require_numeric_field(value, "x")
	if not bool(x_result.get("ok", false)):
		return x_result

	var y_result := _require_numeric_field(value, "y")
	if not bool(y_result.get("ok", false)):
		return y_result

	return {
		"ok": true,
		"value": Vector2(float(x_result.get("value", 0.0)), float(y_result.get("value", 0.0))),
	}


func _decode_vector3(value: Dictionary) -> Dictionary:
	var x_result := _require_numeric_field(value, "x")
	if not bool(x_result.get("ok", false)):
		return x_result

	var y_result := _require_numeric_field(value, "y")
	if not bool(y_result.get("ok", false)):
		return y_result

	var z_result := _require_numeric_field(value, "z")
	if not bool(z_result.get("ok", false)):
		return z_result

	return {
		"ok": true,
		"value": Vector3(
			float(x_result.get("value", 0.0)),
			float(y_result.get("value", 0.0)),
			float(z_result.get("value", 0.0))
		),
	}


func _decode_color(value: Dictionary) -> Dictionary:
	var r_result := _require_numeric_field(value, "r")
	if not bool(r_result.get("ok", false)):
		return r_result

	var g_result := _require_numeric_field(value, "g")
	if not bool(g_result.get("ok", false)):
		return g_result

	var b_result := _require_numeric_field(value, "b")
	if not bool(b_result.get("ok", false)):
		return b_result

	var alpha := 1.0
	if value.has("a"):
		var a_result := _require_numeric_field(value, "a")
		if not bool(a_result.get("ok", false)):
			return a_result
		alpha = float(a_result.get("value", 1.0))

	return {
		"ok": true,
		"value": Color(
			float(r_result.get("value", 0.0)),
			float(g_result.get("value", 0.0)),
			float(b_result.get("value", 0.0)),
			alpha
		),
	}


func _decode_node_path(value: Dictionary) -> Dictionary:
	if not value.has("value"):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value NodePath requires field: value")

	var raw_path = value.get("value")
	if typeof(raw_path) != TYPE_STRING:
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value NodePath field value must be a string")

	return {
		"ok": true,
		"value": NodePath(str(raw_path)),
	}


func _require_numeric_field(value: Dictionary, field_name: String) -> Dictionary:
	if not value.has(field_name):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value requires field: %s" % field_name)

	var raw_value = value.get(field_name)
	var value_type := typeof(raw_value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "typed value field %s must be numeric" % field_name)

	return {
		"ok": true,
		"value": float(raw_value),
	}


func _collect_scene_nodes(root: Node, current: Node, nodes: Array) -> void:
	if current == null:
		return

	nodes.append({
		"path": _canonical_node_path(root, current),
		"name": str(current.name),
		"type": current.get_class(),
		"child_count": current.get_child_count(),
	})

	for child in current.get_children():
		if child is Node:
			_collect_scene_nodes(root, child, nodes)


func _compare_tree_nodes(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("path", "")) < str(b.get("path", ""))


func _finalize_response(root: Node, response: Dictionary) -> Dictionary:
	if root != null:
		root.free()
	return response


func _ensure_parent_directory(scene_path: String) -> Dictionary:
	var base_dir := _utils.normalize_res_path(scene_path.get_base_dir())
	if base_dir.is_empty() or base_dir == "res://":
		return _utils.make_success("parent directory available")

	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_success("parent directory available")

	var mkdir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_err != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_error(_utils.ERROR_IO, "failed to create directory: %s" % error_string(mkdir_err))

	return _utils.make_success("parent directory available")


func _refresh_filesystem(scene_path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("get_resource_filesystem"):
		return false

	var filesystem = editor.call("get_resource_filesystem")
	if filesystem == null:
		return false

	if filesystem.has_method("update_file"):
		filesystem.call("update_file", scene_path)
		return true

	if filesystem.has_method("scan"):
		filesystem.call("scan")
		return true

	return false


func _open_scene(scene_path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("open_scene_from_path"):
		return false

	editor.call("open_scene_from_path", scene_path)
	return true


func _get_editor_interface() -> Variant:
	if _host == null:
		return null

	var plugin := _host.get_parent()
	if plugin == null:
		return null
	if not plugin.has_method("get_editor_interface"):
		return null

	return plugin.call("get_editor_interface")
