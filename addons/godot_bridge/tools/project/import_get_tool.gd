@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const IMPORT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/import_settings_store.gd")
const SETTING_VALUE_SERIALIZER_SCRIPT := preload("res://addons/godot_bridge/tools/shared/setting_value_serializer.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _store = IMPORT_SETTINGS_STORE_SCRIPT.new()
var _serializer = SETTING_VALUE_SERIALIZER_SCRIPT.new()


func tool_name() -> String:
	return "project.import_get"


func set_host(host: Node) -> void:
	_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var requested_key := str(args.get("key", "")).strip_edges()
	var prefix := str(args.get("prefix", "")).strip_edges()
	var include_values := bool(args.get("include_values", false))
	var max_properties := int(args.get("max_properties", 200))
	if max_properties < 0:
		return _result.error(_errors.INVALID_ARGS, "max_properties must be >= 0")
	if requested_key != "" and prefix != "":
		return _result.error(_errors.INVALID_ARGS, "key and prefix cannot be used together")

	var load_result := _store.load_import_config(str(args.get("path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var config: ConfigFile = load_result.get("config", null)
	var rows := _collect_rows(config, include_values)
	if requested_key != "":
		rows = _filter_exact(rows, requested_key)
		if rows.is_empty():
			return _result.error(_errors.NOT_FOUND, "import property not found: %s" % requested_key)
	elif prefix != "":
		rows = _filter_prefix(rows, prefix)

	var total_count := rows.size()
	var truncated := false
	if max_properties > 0 and rows.size() > max_properties:
		rows = rows.slice(0, max_properties)
		truncated = true

	return _result.success("import metadata listed", {
		"source_path": str(load_result.get("source_path", "")),
		"import_path": str(load_result.get("import_path", "")),
		"requested_key": requested_key,
		"prefix": prefix,
		"include_values": include_values,
		"max_properties": max_properties,
		"properties": rows,
		"count": total_count,
		"returned_count": rows.size(),
		"truncated": truncated,
	})


func _collect_rows(config: ConfigFile, include_values: bool) -> Array:
	var rows: Array = []
	var sections := config.get_sections()
	sections.sort()
	for raw_section in sections:
		var section := str(raw_section).strip_edges()
		if section.is_empty():
			continue
		var keys := config.get_section_keys(section)
		keys.sort()
		for raw_key in keys:
			var key := str(raw_key).strip_edges()
			if key.is_empty():
				continue
			var value = config.get_value(section, key, null)
			var row := {
				"key": "%s/%s" % [section, key],
				"value_type": type_string(typeof(value)),
			}
			if include_values:
				var serialized := _serializer.serialize(value)
				row["value"] = serialized.get("value", null)
				row["value_text"] = str(serialized.get("text", ""))
				row["value_type"] = str(serialized.get("type", ""))
			rows.append(row)
	return rows


func _filter_exact(rows: Array, target_key: String) -> Array:
	var filtered: Array = []
	for row in rows:
		if str(row.get("key", "")) == target_key:
			filtered.append(row)
	return filtered


func _filter_prefix(rows: Array, prefix: String) -> Array:
	var filtered: Array = []
	for row in rows:
		var key := str(row.get("key", ""))
		if key == prefix or key.begins_with("%s/" % prefix):
			filtered.append(row)
	return filtered
