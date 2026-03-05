@tool
extends RefCounted


func serialize(value: Variant) -> Dictionary:
	var normalized_value := _to_json_value(value)
	return {
		"value": normalized_value,
		"text": _to_text(normalized_value),
		"type": type_string(typeof(value)),
	}


func _to_json_value(value: Variant) -> Variant:
	var value_type := typeof(value)
	if value_type == TYPE_NIL or value_type == TYPE_BOOL or value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_STRING:
		return value

	if value is StringName or value is NodePath:
		return str(value)

	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_to_json_value(item))
		return normalized_array

	if value is Dictionary:
		return _normalize_dictionary(value)

	if value is PackedByteArray:
		var bytes: Array = []
		for item in value:
			bytes.append(int(item))
		return bytes

	if value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedStringArray:
		var packed_values: Array = []
		for item in value:
			packed_values.append(_to_json_value(item))
		return packed_values

	if value is PackedVector2Array or value is PackedVector3Array or value is PackedVector4Array or value is PackedColorArray:
		var vector_values: Array = []
		for item in value:
			vector_values.append(str(item))
		return vector_values

	if value is Object:
		return _normalize_object(value)

	return str(value)


func _normalize_dictionary(source: Dictionary) -> Dictionary:
	var keys := source.keys()
	keys.sort_custom(Callable(self, "_compare_keys"))

	var normalized := {}
	for key in keys:
		normalized[str(key)] = _to_json_value(source.get(key))

	return normalized


func _normalize_object(value: Object) -> Variant:
	if value is Resource:
		var resource: Resource = value
		var resource_path := str(resource.resource_path).strip_edges()
		if not resource_path.is_empty():
			return {
				"type": resource.get_class(),
				"resource_path": resource_path,
			}

	return str(value)


func _to_text(value: Variant) -> String:
	var value_type := typeof(value)
	if value_type == TYPE_ARRAY or value_type == TYPE_DICTIONARY:
		return JSON.stringify(value)

	return str(value)


func _compare_keys(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)
