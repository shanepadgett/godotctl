@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESOURCE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/resource_store.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = RESOURCE_STORE_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "resource.list"


func execute(args: Dictionary) -> Dictionary:
	var include_values := bool(args.get("include_values", false))
	var max_properties := int(args.get("max_properties", 200))
	if max_properties < 0:
		return _result.error(_errors.INVALID_ARGS, "max_properties must be >= 0")

	var load_result := _store.load_resource(str(args.get("path", "")), "path")
	if not bool(load_result.get("ok", false)):
		return load_result

	var resource_path := str(load_result.get("resource_path", ""))
	var resource: Resource = load_result.get("resource", null)

	var rows := _collect_properties(resource, include_values)
	var count := rows.size()
	var truncated := false
	if max_properties > 0 and rows.size() > max_properties:
		rows = rows.slice(0, max_properties)
		truncated = true

	return _result.success("resource properties listed: %s" % resource_path, {
		"resource_path": resource_path,
		"include_values": include_values,
		"max_properties": max_properties,
		"properties": rows,
		"count": count,
		"returned_count": rows.size(),
		"truncated": truncated,
	})


func _collect_properties(resource: Resource, include_values: bool) -> Array:
	var rows: Array = []
	if resource == null:
		return rows

	for item in resource.get_property_list():
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var property_info: Dictionary = item
		var property_name := str(property_info.get("name", "")).strip_edges()
		if property_name.is_empty() or property_name.begins_with("_"):
			continue

		var usage := int(property_info.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue

		var type_id := int(property_info.get("type", TYPE_NIL))
		var row := {
			"name": property_name,
			"type": type_string(type_id),
			"type_id": type_id,
		}

		if include_values:
			var serialized := _serializer.serialize(resource.get(property_name))
			row["value"] = serialized.get("value", null)
			row["value_text"] = str(serialized.get("text", ""))
			row["value_type"] = str(serialized.get("type", ""))

		rows.append(row)

	rows.sort_custom(Callable(self, "_compare_properties"))
	return rows


func _compare_properties(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("name", ""))
	var b_name := str(b.get("name", ""))
	if a_name != b_name:
		return a_name < b_name

	return int(a.get("type_id", TYPE_NIL)) < int(b.get("type_id", TYPE_NIL))
