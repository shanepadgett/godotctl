@tool
extends RefCounted

const ERROR_CODES_SCRIPT := preload("res://addons/godot_bridge/tools/core/error_codes.gd")
const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCRIPT_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/script_store.gd")
const FILESYSTEM_SERVICE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/filesystem_service.gd")

var _errors = ERROR_CODES_SCRIPT.new()
var _result = RESULT_FACTORY_SCRIPT.new()
var _scripts = SCRIPT_STORE_SCRIPT.new()
var _filesystem = FILESYSTEM_SERVICE_SCRIPT.new()


func tool_name() -> String:
	return "script.edit"


func set_host(host: Node) -> void:
	_filesystem.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var script_path_result := _scripts.validate_script_path(str(args.get("script_path", "")), "script_path")
	if not bool(script_path_result.get("ok", false)):
		return script_path_result

	var script_path := str(script_path_result.get("script_path", ""))
	if not FileAccess.file_exists(script_path):
		return _result.error(_errors.NOT_FOUND, "script not found: %s" % script_path)

	if not args.has("find_text"):
		return _result.error(_errors.INVALID_ARGS, "find_text is required")
	var find_text := str(args.get("find_text", ""))
	if find_text.is_empty():
		return _result.error(_errors.INVALID_ARGS, "find_text is required")

	if not args.has("replace_text"):
		return _result.error(_errors.INVALID_ARGS, "replace_text is required")
	var replace_text := str(args.get("replace_text", ""))

	var read_result := _scripts.read_text_file(script_path)
	if not bool(read_result.get("ok", false)):
		return read_result

	var source_text := str(read_result.get("text", ""))
	var match_count := _count_literal_matches(source_text, find_text)
	var replaced_text := source_text.replace(find_text, replace_text)

	var write_result := _scripts.write_text_file(script_path, replaced_text)
	if not bool(write_result.get("ok", false)):
		return write_result

	var filesystem_refreshed := _filesystem.refresh_filesystem(script_path)
	if not filesystem_refreshed:
		return _result.error(_errors.EDITOR_STATE, "script saved but filesystem refresh failed")

	return _result.success("script edited: %s" % script_path, {
		"script_path": script_path,
		"match_count": match_count,
		"replaced_count": match_count,
		"saved": true,
		"filesystem_refreshed": filesystem_refreshed,
	})


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
