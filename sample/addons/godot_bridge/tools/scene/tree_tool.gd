@tool
extends RefCounted

const RESULT_FACTORY_SCRIPT := preload("res://addons/godot_bridge/tools/core/result_factory.gd")
const SCENE_STORE_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_store.gd")
const SCENE_TREE_COLLECTOR_SCRIPT := preload("res://addons/godot_bridge/tools/shared/scene_tree_collector.gd")

var _result = RESULT_FACTORY_SCRIPT.new()
var _scene_store = SCENE_STORE_SCRIPT.new()
var _collector = SCENE_TREE_COLLECTOR_SCRIPT.new()


func tool_name() -> String:
	return "scene.tree"


func set_host(host: Node) -> void:
	_scene_store.set_host(host)


func execute(args: Dictionary) -> Dictionary:
	var load_result := _scene_store.load_root(str(args.get("scene_path", "")))
	if not bool(load_result.get("ok", false)):
		return load_result

	var scene_path := str(load_result.get("scene_path", ""))
	var root: Node = load_result.get("root", null)

	var nodes := _collector.collect(root)

	return _scene_store.finalize(root, _result.success("scene tree: %s" % scene_path, {
		"scene_path": scene_path,
		"nodes": nodes,
	}))
