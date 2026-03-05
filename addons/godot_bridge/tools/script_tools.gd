@tool
extends RefCounted

const TOOL_UTILS_SCRIPT := preload("res://addons/godot_bridge/tools/tool_utils.gd")

var _utils = TOOL_UTILS_SCRIPT.new()
var _host: Node = null


func set_host(host: Node) -> void:
	_host = host


func list_tools() -> Array[String]:
	var tools: Array[String] = [
		"script.create",
		"script.edit",
		"script.validate",
		"script.attach",
	]
	return _utils.sort_strings(tools)


func execute(tool: String, args: Dictionary) -> Dictionary:
	var tool_name := str(tool).strip_edges()
	if tool_name == "script.create":
		return _script_create(args)
	if tool_name == "script.edit":
		return _script_edit(args)
	if tool_name == "script.validate":
		return _script_validate(args)
	if tool_name == "script.attach":
		return _script_attach(args)
	return _utils.make_error(_utils.ERROR_NOT_FOUND, "unknown tool: %s" % tool_name)


func _script_create(args: Dictionary) -> Dictionary:
	var script_path_result := _validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	var base_class_result := _validate_identifier(str(args.get("base_class", "")), "base_class")
	if not bool(base_class_result.get("ok", false)):
		return base_class_result

	var base_class := str(base_class_result.get("value", ""))
	var script_class_name := str(args.get("class_name", "")).strip_edges()
	if not script_class_name.is_empty():
		var class_name_result := _validate_identifier(script_class_name, "class_name")
		if not bool(class_name_result.get("ok", false)):
			return class_name_result
		script_class_name = str(class_name_result.get("value", ""))

	var overwrite := bool(args.get("overwrite", false))
	var existed := FileAccess.file_exists(script_path)
	if existed and not overwrite:
		return _utils.make_error(_utils.ERROR_ALREADY_EXISTS, "script already exists: %s" % script_path)

	var parent_dir_result := _ensure_parent_directory(script_path)
	if not bool(parent_dir_result.get("ok", false)):
		return parent_dir_result

	var template_source := _build_template_source(base_class, script_class_name)
	var write_result := _write_text_file(script_path, template_source)
	if not bool(write_result.get("ok", false)):
		return write_result

	var filesystem_refreshed := _refresh_filesystem(script_path)
	if not filesystem_refreshed:
		return _utils.make_error(_utils.ERROR_EDITOR_STATE, "script saved but filesystem refresh failed")

	return _utils.make_success("script created: %s" % script_path, {
		"script_path": script_path,
		"base_class": base_class,
		"class_name": script_class_name,
		"overwrote": existed,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	})


func _script_edit(args: Dictionary) -> Dictionary:
	var script_path_result := _validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "script not found: %s" % script_path)

	if not args.has("find_text"):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "find_text is required")
	var find_text := str(args.get("find_text", ""))
	if find_text.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "find_text is required")

	if not args.has("replace_text"):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "replace_text is required")
	var replace_text := str(args.get("replace_text", ""))

	var read_result := _read_text_file(script_path)
	if not bool(read_result.get("ok", false)):
		return read_result

	var source_text := str(read_result.get("text", ""))
	var match_count := _count_literal_matches(source_text, find_text)
	var replaced_text := source_text.replace(find_text, replace_text)

	var write_result := _write_text_file(script_path, replaced_text)
	if not bool(write_result.get("ok", false)):
		return write_result

	var filesystem_refreshed := _refresh_filesystem(script_path)
	if not filesystem_refreshed:
		return _utils.make_error(_utils.ERROR_EDITOR_STATE, "script saved but filesystem refresh failed")

	return _utils.make_success("script edited: %s" % script_path, {
		"script_path": script_path,
		"match_count": match_count,
		"replaced_count": match_count,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	})


func _script_validate(args: Dictionary) -> Dictionary:
	var script_path_result := _validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "script not found: %s" % script_path)

	var read_result := _read_text_file(script_path)
	if not bool(read_result.get("ok", false)):
		return read_result

	var source_text := str(read_result.get("text", ""))
	var transient_script := GDScript.new()
	transient_script.source_code = source_text
	var reload_err := transient_script.reload()

	var diagnostics: Array = []
	var valid := reload_err == OK
	if not valid:
		diagnostics.append({
			"severity": "error",
			"code": "SCRIPT_COMPILE_FAILED",
			"message": "script failed to parse/compile (%s)" % error_string(reload_err),
		})

	var message := "script valid: %s" % script_path
	if not valid:
		message = "script invalid: %s" % script_path

	return _utils.make_success(message, {
		"script_path": script_path,
		"valid": valid,
		"diagnostics": diagnostics,
	})


func _script_attach(args: Dictionary) -> Dictionary:
	var scene_result := _load_scene_root(str(args.get("scene_path", "")))
	if not bool(scene_result.get("ok", false)):
		return scene_result

	var scene_path := str(scene_result.get("scene_path", ""))
	var root: Node = scene_result.get("root", null)

	var node_result := _resolve_node(root, str(args.get("node_path", "")), "node_path")
	if not bool(node_result.get("ok", false)):
		return _finalize_scene_response(root, node_result)

	var node: Node = node_result.get("node", null)
	var canonical_node_path := str(node_result.get("path", ""))

	var script_result := _load_script_resource(str(args.get("script_path", "")))
	if not bool(script_result.get("ok", false)):
		return _finalize_scene_response(root, script_result)

	var script_path := str(script_result.get("script_path", ""))
	var script: Script = script_result.get("script", null)
	var overwrite := bool(args.get("overwrite", false))
	var had_script := node.get_script() != null

	if had_script and not overwrite:
		return _finalize_scene_response(root, _utils.make_error(_utils.ERROR_ALREADY_EXISTS, "node already has a script: %s" % canonical_node_path))

	var base_type := str(script.get_instance_base_type()).strip_edges()
	if base_type.is_empty() or not node.is_class(base_type):
		return _finalize_scene_response(root, _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "script base type %s is incompatible with node type %s" % [base_type, node.get_class()]))

	node.set_script(script)
	if node.get_script() == null:
		return _finalize_scene_response(root, _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "failed to attach script: %s" % script_path))

	var save_result := _save_scene_root(scene_path, root)
	if not bool(save_result.get("ok", false)):
		return _finalize_scene_response(root, save_result)

	return _finalize_scene_response(root, _utils.make_success("script attached: %s" % canonical_node_path, {
		"scene_path": scene_path,
		"node_path": canonical_node_path,
		"script_path": script_path,
		"overwrote": had_script,
		"saved": bool(save_result.get("saved", false)),
		"filesystem_refreshed": bool(save_result.get("filesystem_refreshed", false)),
	}))


func _validate_script_path(raw_path: String, field_name: String) -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "script_path"

	var path_raw := str(raw_path).strip_edges()
	if path_raw.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "%s is required" % normalized_field)

	var script_path := _utils.normalize_res_path(path_raw)
	if not _has_gd_extension(script_path):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "%s must end with .gd" % normalized_field)

	return {
		"ok": true,
		"script_path": script_path,
	}


func _validate_identifier(raw_name: String, field_name: String) -> Dictionary:
	var normalized_field := str(field_name).strip_edges()
	if normalized_field.is_empty():
		normalized_field = "identifier"

	var name := str(raw_name).strip_edges()
	if name.is_empty():
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "%s is required" % normalized_field)
	if not _is_valid_identifier(name):
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "%s must be a valid identifier" % normalized_field)

	return {
		"ok": true,
		"value": name,
	}


func _is_valid_identifier(name: String) -> bool:
	if name.is_empty():
		return false

	var first_code := name.unicode_at(0)
	if not (_is_ascii_letter(first_code) or first_code == 95):
		return false

	for i in range(1, name.length()):
		var code := name.unicode_at(i)
		if not (_is_ascii_letter(code) or _is_ascii_digit(code) or code == 95):
			return false

	return true


func _is_ascii_letter(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _is_ascii_digit(code: int) -> bool:
	return code >= 48 and code <= 57


func _has_gd_extension(path: String) -> bool:
	return str(path).to_lower().ends_with(".gd")


func _build_template_source(base_class: String, script_class_name: String) -> String:
	var source := "extends %s\n" % base_class
	if not script_class_name.is_empty():
		source += "class_name %s\n" % script_class_name
	source += "\n"
	source += "func _ready() -> void:\n"
	source += "\tpass\n"
	return source


func _count_literal_matches(text: String, needle: String) -> int:
	if needle.is_empty():
		return 0

	var count := 0
	var start := 0
	while true:
		var index := text.find(needle, start)
		if index == -1:
			break
		count += 1
		start = index + needle.length()

	return count


func _read_text_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var read_err := FileAccess.get_open_error()
		return _utils.make_error(_utils.ERROR_IO, "failed to read file: %s" % error_string(read_err))

	return {
		"ok": true,
		"text": file.get_as_text(),
	}


func _write_text_file(path: String, content: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var write_err := FileAccess.get_open_error()
		return _utils.make_error(_utils.ERROR_IO, "failed to write file: %s" % error_string(write_err))

	file.store_string(content)
	return {
		"ok": true,
	}


func _load_script_resource(script_path_raw: String) -> Dictionary:
	var script_path_result := _validate_script_path(script_path_raw, "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _utils.make_error(_utils.ERROR_NOT_FOUND, "script not found: %s" % script_path)

	var resource = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return _utils.make_error(_utils.ERROR_INVALID_ARGS, "failed to load script: %s" % script_path)
	if not (resource is Script):
		return _utils.make_error(_utils.ERROR_TYPE_MISMATCH, "resource is not a Script: %s" % script_path)

	return {
		"ok": true,
		"script_path": script_path,
		"script": resource,
	}


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


func _finalize_scene_response(root: Node, response: Dictionary) -> Dictionary:
	if root != null:
		root.free()
	return response


func _ensure_parent_directory(path: String) -> Dictionary:
	var base_dir := _utils.normalize_res_path(path.get_base_dir())
	if base_dir.is_empty() or base_dir == "res://":
		return _utils.make_success("parent directory available")

	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_success("parent directory available")

	var mkdir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_err != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		return _utils.make_error(_utils.ERROR_IO, "failed to create directory: %s" % error_string(mkdir_err))

	return _utils.make_success("parent directory available")


func _refresh_filesystem(path: String) -> bool:
	var editor := _get_editor_interface()
	if editor == null:
		return false
	if not editor.has_method("get_resource_filesystem"):
		return false

	var filesystem = editor.call("get_resource_filesystem")
	if filesystem == null:
		return false

	if filesystem.has_method("update_file"):
		filesystem.call("update_file", path)
		return true

	if filesystem.has_method("scan"):
		filesystem.call("scan")
		return true

	return false


func _get_editor_interface() -> Variant:
	if _host == null:
		return null

	var plugin := _host.get_parent()
	if plugin == null:
		return null
	if not plugin.has_method("get_editor_interface"):
		return null

	return plugin.call("get_editor_interface")
