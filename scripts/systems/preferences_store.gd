extends RefCounted
const PATH := "user://preferences.json"
const DEFAULTS := {"version": 1, "difficulty": 1, "fullscreen": false, "audio": {"master": 0.8, "effects": 0.8, "ambience": 0.5}}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("fullscreen") is bool:
		return false
	if data.has("audio"):
		if not data.audio is Dictionary or data.audio.size() != 3:
			return false
		for key in ["master", "effects", "ambience"]:
			var value = data.audio.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 1:
				return false
	var difficulty = data.get("difficulty")
	return (difficulty is int or difficulty is float) and difficulty >= 0 and difficulty <= 2 and floorf(difficulty) == difficulty

static func read(path: String = PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and valid(parser.data):
			var result := DEFAULTS.duplicate(true)
			result.merge(parser.data, true)
			return result
	return DEFAULTS.duplicate(true)

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
