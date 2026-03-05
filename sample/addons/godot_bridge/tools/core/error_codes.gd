@tool
extends RefCounted

const INVALID_ARGS := "INVALID_ARGS"
const NOT_FOUND := "NOT_FOUND"
const ALREADY_EXISTS := "ALREADY_EXISTS"
const TYPE_MISMATCH := "TYPE_MISMATCH"
const IO_ERROR := "IO_ERROR"
const EDITOR_STATE := "EDITOR_STATE"
const INTERNAL := "INTERNAL"

const _VALID_CODES := [
	INVALID_ARGS,
	NOT_FOUND,
	ALREADY_EXISTS,
	TYPE_MISMATCH,
	IO_ERROR,
	EDITOR_STATE,
	INTERNAL,
]


func normalize(code: String) -> String:
	var value := str(code).strip_edges()
	if value.is_empty():
		return INTERNAL
	if _VALID_CODES.has(value):
		return value
	return INTERNAL
