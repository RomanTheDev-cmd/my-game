extends RefCounted
const PATH := "user://preferences.json"
const DEFAULTS := {"version": 1, "difficulty": 1, "fullscreen": false}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("fullscreen") is bool:
		return false
	var difficulty = data.get("difficulty")
	return (difficulty is int or difficulty is float) and difficulty >= 0 and difficulty <= 2 and floorf(difficulty) == difficulty

static func read(path: String = PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and valid(parser.data):
			return parser.data
	return DEFAULTS.duplicate()

static func write(data: Dictionary, path: String = PATH) -> Error:
	if not valid(data):
		return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)
