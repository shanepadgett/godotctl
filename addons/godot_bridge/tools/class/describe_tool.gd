@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()


func tool_name() -> String:
	return "class.describe"


func execute(args: Dictionary) -> Dictionary:
	var target_class := str(args.get("name", "")).strip_edges()
	if target_class.is_empty():
		return _result.error(_errors.INVALID_ARGS, "name is required")

	var include_properties := bool(args.get("include_properties", false))
	var include_methods := bool(args.get("include_methods", false))
	var include_signals := bool(args.get("include_signals", false))
	var include_inheritors := bool(args.get("include_inheritors", false))

	if not ClassDB.class_exists(target_class):
		return _result.error(_errors.NOT_FOUND, "class does not exist: %s" % target_class)

	var properties: Array = []
	var methods: Array = []
	var signals: Array = []
	var inheritors: Array = []

	var property_count := 0
	var method_count := 0
	var signal_count := 0
	var inheritor_count := 0

	if include_properties:
		properties = _collect_properties(target_class)
		property_count = properties.size()
	else:
		property_count = ClassDB.class_get_property_list(target_class, true).size()

	if include_methods:
		methods = _collect_methods(target_class)
		method_count = methods.size()
	else:
		method_count = ClassDB.class_get_method_list(target_class, true).size()

	if include_signals:
		signals = _collect_signals(target_class)
		signal_count = signals.size()
	else:
		signal_count = ClassDB.class_get_signal_list(target_class, true).size()

	if include_inheritors:
		inheritors = _collect_inheritors(target_class)
		inheritor_count = inheritors.size()
	else:
		inheritor_count = ClassDB.get_inheriters_from_class(target_class).size()

	var inheritance := _collect_inheritance(target_class)

	return _result.success("class metadata retrieved: %s" % target_class, {
		"class_name": target_class,
		"parent_class": str(ClassDB.get_parent_class(target_class)),
		"inheritance": inheritance,
		"include_properties": include_properties,
		"include_methods": include_methods,
		"include_signals": include_signals,
		"include_inheritors": include_inheritors,
		"inheritors": inheritors,
		"inheritor_count": inheritor_count,
		"instantiable": _can_instantiate(target_class),
		"properties": properties,
		"methods": methods,
		"signals": signals,
		"property_count": property_count,
		"method_count": method_count,
		"signal_count": signal_count,
	})


func _collect_properties(target_class: String) -> Array:
	var rows: Array = []
	for item in ClassDB.class_get_property_list(target_class, true):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = item
		var name := str(entry.get("name", "")).strip_edges()
		if name.is_empty():
			continue

		var type_id := int(entry.get("type", TYPE_NIL))
		var declared_class := str(entry.get("class_name", ""))
		rows.append({
			"name": name,
			"type": type_string(type_id),
			"type_id": type_id,
			"class_name": declared_class,
			"hint": int(entry.get("hint", 0)),
			"hint_string": str(entry.get("hint_string", "")),
			"usage": int(entry.get("usage", 0)),
		})

	rows.sort_custom(Callable(self, "_compare_properties"))
	return rows


func _collect_methods(target_class: String) -> Array:
	var rows: Array = []
	for item in ClassDB.class_get_method_list(target_class, true):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = item
		var name := str(entry.get("name", "")).strip_edges()
		if name.is_empty():
			continue

		rows.append({
			"name": name,
			"id": int(entry.get("id", -1)),
			"flags": int(entry.get("flags", 0)),
			"arguments": _normalize_argument_list(entry.get("args", [])),
			"default_argument_count": _default_argument_count(entry.get("default_args", [])),
			"return": _normalize_argument_info(entry.get("return", {})),
		})

	rows.sort_custom(Callable(self, "_compare_methods"))
	return rows


func _collect_signals(target_class: String) -> Array:
	var rows: Array = []
	for item in ClassDB.class_get_signal_list(target_class, true):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = item
		var name := str(entry.get("name", "")).strip_edges()
		if name.is_empty():
			continue

		rows.append({
			"name": name,
			"arguments": _normalize_argument_list(entry.get("args", [])),
		})

	rows.sort_custom(Callable(self, "_compare_signals"))
	return rows


func _normalize_argument_list(raw_args: Variant) -> Array:
	if typeof(raw_args) != TYPE_ARRAY:
		return []

	var rows: Array = []
	for index in range(raw_args.size()):
		if typeof(raw_args[index]) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_argument_info(raw_args[index])
		normalized["index"] = index
		rows.append(normalized)

	return rows


func _normalize_argument_info(raw_arg: Variant) -> Dictionary:
	if typeof(raw_arg) != TYPE_DICTIONARY:
		return {
			"name": "",
			"type": type_string(TYPE_NIL),
			"type_id": TYPE_NIL,
			"class_name": "",
			"hint": 0,
			"hint_string": "",
			"usage": 0,
		}

	var entry: Dictionary = raw_arg
	var type_id := int(entry.get("type", TYPE_NIL))
	return {
		"name": str(entry.get("name", "")),
		"type": type_string(type_id),
		"type_id": type_id,
		"class_name": str(entry.get("class_name", "")),
		"hint": int(entry.get("hint", 0)),
		"hint_string": str(entry.get("hint_string", "")),
		"usage": int(entry.get("usage", 0)),
	}


func _default_argument_count(raw_defaults: Variant) -> int:
	if typeof(raw_defaults) != TYPE_ARRAY:
		return 0
	return raw_defaults.size()


func _collect_inheritance(target_class: String) -> Array:
	var chain: Array = []
	var seen := {}
	var current := target_class

	while not current.is_empty() and not seen.has(current):
		seen[current] = true
		chain.append(current)
		current = str(ClassDB.get_parent_class(current)).strip_edges()

	return chain


func _collect_inheritors(target_class: String) -> Array:
	var rows: Array = []
	for item in ClassDB.get_inheriters_from_class(target_class):
		var inheritor := str(item).strip_edges()
		if inheritor.is_empty():
			continue
		rows.append(inheritor)

	rows.sort()
	return rows


func _can_instantiate(target_class: String) -> bool:
	var instance: Variant = ClassDB.instantiate(target_class)
	if instance == null:
		return false

	if instance is Object and not (instance is RefCounted):
		instance.free()

	return true


func _compare_properties(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("name", ""))
	var b_name := str(b.get("name", ""))
	if a_name != b_name:
		return a_name < b_name

	return int(a.get("type_id", TYPE_NIL)) < int(b.get("type_id", TYPE_NIL))


func _compare_methods(a: Dictionary, b: Dictionary) -> bool:
	var a_name := str(a.get("name", ""))
	var b_name := str(b.get("name", ""))
	if a_name != b_name:
		return a_name < b_name

	return int(a.get("id", -1)) < int(b.get("id", -1))


func _compare_signals(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))
