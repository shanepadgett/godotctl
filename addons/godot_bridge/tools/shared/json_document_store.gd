@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const SCRIPT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/script_store.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")
const PROJECT_SETTINGS_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/project_settings_store.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _errors = ERROR_CODES_SCRIPT.new()
var _scripts = SCRIPT_STORE_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()
var _settings = PROJECT_SETTINGS_STORE_SCRIPT.new()


func set_host(host: Node) -> void:
	_filesystem.set_host(host)
	_settings.set_host(host)


func load_document(raw_path: String, create_missing: bool = false) -> Dictionary:
	var path_result := _validate_json_path(raw_path)
	if not bool(path_result.get("ok", false)):
		return path_result

	var document_path := str(path_result.get("path", ""))
	if not FileAccess.file_exists(document_path):
		if create_missing:
			return {
				"ok": true,
				"path": document_path,
				"document": {},
				"text": "{}",
				"created": true,
			}
		return _result.error(_errors.NOT_FOUND, "file not found: %s" % document_path)

	var read_result := _scripts.read_text_file(document_path)
	if not bool(read_result.get("ok", false)):
		return read_result

	var text := str(read_result.get("text", "")).strip_edges()
	if text.is_empty():
		text = "{}"

	var parser := JSON.new()
	var parse_err := parser.parse(text)
	if parse_err != OK:
		return _result.error(_errors.IO_ERROR, "failed to parse JSON file: %s" % parser.get_error_message())

	return {
		"ok": true,
		"path": document_path,
		"document": parser.data,
		"text": text,
		"created": false,
	}


func save_document(path: String, document: Variant) -> Dictionary:
	var normalized := normalize_value(document)
	var text := JSON.stringify(normalized, "\t")
	var write_result := _scripts.write_text_file(path, "%s\n" % text)
	if not bool(write_result.get("ok", false)):
		return write_result

	var refreshed := _filesystem.refresh_filesystem(path)
	if not refreshed:
		return _result.error(_errors.EDITOR_STATE, "JSON file saved but filesystem refresh failed")

	return {
		"ok": true,
		"saved": true,
		"filesystem_refreshed": refreshed,
		"text": text,
	}


func normalize_value(value: Variant) -> Variant:
	var value_type := typeof(value)
	if value_type == TYPE_NIL or value_type == TYPE_BOOL or value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_STRING:
		return value

	if value_type == TYPE_ARRAY:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(normalize_value(item))
		return normalized_array

	if value_type == TYPE_DICTIONARY:
		var keys: Array = value.keys()
		keys.sort_custom(Callable(self , "_compare_values"))

		var normalized := {}
		for key in keys:
			normalized[str(key)] = normalize_value(value.get(key))
		return normalized

	return str(value)


func pointer_tokens(pointer: String) -> Dictionary:
	var normalized := str(pointer)
	if normalized.is_empty():
		return {
			"ok": true,
			"tokens": [],
		}
	if not normalized.begins_with("/"):
		return _result.error(_errors.INVALID_ARGS, "pointer must be empty or start with /")

	var raw_tokens := normalized.substr(1).split("/", false)
	var tokens: Array = []
	for raw_token in raw_tokens:
		tokens.append(str(raw_token).replace("~1", "/").replace("~0", "~"))

	return {
		"ok": true,
		"tokens": tokens,
	}


func get_value(document: Variant, pointer: String) -> Dictionary:
	var token_result := pointer_tokens(pointer)
	if not bool(token_result.get("ok", false)):
		return token_result

	var current = document
	for token in token_result.get("tokens", []):
		if typeof(current) != TYPE_DICTIONARY:
			return _result.error(_errors.NOT_FOUND, "pointer not found: %s" % pointer)
		if not current.has(token):
			return _result.error(_errors.NOT_FOUND, "pointer not found: %s" % pointer)
		current = current.get(token)

	return {
		"ok": true,
		"value": normalize_value(current),
	}


func set_value(document: Variant, pointer: String, value: Variant) -> Dictionary:
	var normalized_value := normalize_value(value)
	if pointer.is_empty():
		return {
			"ok": true,
			"document": normalized_value,
			"changed": normalize_value(document) != normalized_value,
		}

	var token_result := pointer_tokens(pointer)
	if not bool(token_result.get("ok", false)):
		return token_result

	if typeof(document) != TYPE_DICTIONARY:
		return _result.error(_errors.INVALID_ARGS, "JSON document root must be an object for pointer writes")

	var tokens: Array = token_result.get("tokens", [])
	var root := normalize_value(document)
	var parent = root
	for index in range(tokens.size() - 1):
		var token := str(tokens[index])
		if parent.has(token):
			var next_value = parent.get(token)
			if typeof(next_value) != TYPE_DICTIONARY:
				return _result.error(_errors.INVALID_ARGS, "pointer traverses a non-object value")
			parent = next_value
			continue

		parent[token] = {}
		parent = parent.get(token)

	var leaf := str(tokens[tokens.size() - 1])
	var changed: bool = not parent.has(leaf) or normalize_value(parent.get(leaf)) != normalized_value
	parent[leaf] = normalized_value

	return {
		"ok": true,
		"document": root,
		"changed": changed,
	}


func remove_value(document: Variant, pointer: String) -> Dictionary:
	if pointer.is_empty():
		return _result.error(_errors.INVALID_ARGS, "pointer is required")

	var token_result := pointer_tokens(pointer)
	if not bool(token_result.get("ok", false)):
		return token_result
	if typeof(document) != TYPE_DICTIONARY:
		return {
			"ok": true,
			"document": normalize_value(document),
			"changed": false,
		}

	var tokens: Array = token_result.get("tokens", [])
	var root := normalize_value(document)
	var parent = root
	for index in range(tokens.size() - 1):
		var token := str(tokens[index])
		if typeof(parent) != TYPE_DICTIONARY or not parent.has(token):
			return {
				"ok": true,
				"document": root,
				"changed": false,
			}

		var next_value = parent.get(token)
		if typeof(next_value) != TYPE_DICTIONARY:
			return {
				"ok": true,
				"document": root,
				"changed": false,
			}

		parent = next_value

	var leaf := str(tokens[tokens.size() - 1])
	if not parent.has(leaf):
		return {
			"ok": true,
			"document": root,
			"changed": false,
		}

	parent.erase(leaf)
	return {
		"ok": true,
		"document": root,
		"changed": true,
	}


func _validate_json_path(raw_path: String) -> Dictionary:
	var path_result := _settings.validate_project_file_path(raw_path, "path")
	if not bool(path_result.get("ok", false)):
		return path_result

	var document_path := str(path_result.get("path", ""))
	if not document_path.to_lower().ends_with(".json"):
		return _result.error(_errors.TYPE_MISMATCH, "path must end with .json")

	return {
		"ok": true,
		"path": document_path,
	}


func _compare_values(a: Variant, b: Variant) -> bool:
	return str(a) < str(b)
