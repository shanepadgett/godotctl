@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const AUTOLOAD_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/autoload_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = AUTOLOAD_STORE_SCRIPT.new()


func tool_name() -> String:
	return "project.autoload_list"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var name_filter := str(args.get("name", "")).strip_edges()
	var max_rows := int(args.get("max", 200))
	if max_rows < 0:
		return _result.error(_errors.INVALID_ARGS, "max must be >= 0")

	var rows: Array = []
	for row in _store.list_autoloads():
		if name_filter != "" and str(row.get("name", "")) != name_filter:
			continue
		rows.append(row)

	var total_count := rows.size()
	var truncated := false
	if max_rows > 0 and rows.size() > max_rows:
		rows = rows.slice(0, max_rows)
		truncated = true

	return _result.success("autoloads listed", {
		"name": name_filter,
		"max": max_rows,
		"autoloads": rows,
		"count": total_count,
		"returned_count": rows.size(),
		"truncated": truncated,
	})
