@tool
extends RefCounted


func normalize_res_path(raw_path: String) -> String:
	var path := str(raw_path).strip_edges().replace("\\", "/")
	if path.is_empty():
		return ""

	if path.begins_with("res://"):
		path = path.substr(6)
	elif path.begins_with("res:/"):
		path = path.substr(5)
	elif path.begins_with("./"):
		path = path.substr(2)
	elif path.begins_with("/"):
		path = path.substr(1)

	while path.find("//") != -1:
		path = path.replace("//", "/")

	while path.begins_with("/"):
		path = path.substr(1)

	if path.is_empty():
		return "res://"

	return "res://%s" % path


func has_tscn_extension(path: String) -> bool:
	return normalize_res_path(path).to_lower().ends_with(".tscn")


func has_gd_extension(path: String) -> bool:
	return normalize_res_path(path).to_lower().ends_with(".gd")
