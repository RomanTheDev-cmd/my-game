extends RefCounted

const Regions = preload("res://scripts/world/region_catalog.gd")
const VERSION := 2
const DEFAULT_PATH := "user://save.json"

static func migrate(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var upgraded: Dictionary = data.duplicate(true)
	if upgraded.get("version") == 1:
		upgraded["version"] = VERSION
		upgraded["region"] = "crossing"
		upgraded["vitals"] = {"health": 100.0, "stamina": 100.0, "mana": 100.0}
	return upgraded

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	if not data.get("region") is String or not Regions.valid(data.region):
		return false
	if not data.get("vitals") is Dictionary:
		return false
	for key in ["health", "stamina", "mana"]:
		var amount = data.vitals.get(key)
		if not (amount is float or amount is int) or not is_finite(float(amount)):
			return false
		if amount < 0 or amount > 100 or (key == "health" and amount == 0):
			return false
	if not data.get("position") is Array or data.position.size() != 2:
		return false
	for value in data.position:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if data.position[0] < 8 or data.position[0] > 1912 or data.position[1] < 8 or data.position[1] > 1272:
		return false
	if not data.get("difficulty") is float and not data.get("difficulty") is int:
		return false
	if data.difficulty < 0 or data.difficulty > 2 or floorf(data.difficulty) != data.difficulty:
		return false
	if not data.get("quest") is float and not data.get("quest") is int:
		return false
	if data.quest < 0 or data.quest > 3 or floorf(data.quest) != data.quest:
		return false
	if not data.get("defeated") is Array or not data.get("inventory") is Dictionary:
		return false
	if not data.get("gathered") is Array:
		return false
	for item in data.defeated + data.gathered:
		if not item is String:
			return false
	for key in data.inventory:
		if not key is String or not (data.inventory[key] is float or data.inventory[key] is int):
			return false
		if data.inventory[key] < 0 or data.inventory[key] > 999 or floorf(data.inventory[key]) != data.inventory[key]:
			return false
	if int(data.quest) == 2 and data.inventory.get("lantern", 0) != 1:
		return false
	if int(data.quest) != 2 and data.inventory.get("lantern", 0) != 0:
		return false
	return true

static func read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data := migrate(parser.data)
	return data if validate(data) else {}

static func load_game(path: String = DEFAULT_PATH) -> Dictionary:
	var data := read_valid(path)
	return read_valid(path + ".bak") if data.is_empty() else data

static func write_game(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	data = migrate(data)
	if not validate(data):
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
	# Preserve the last valid primary; a corrupt primary must not replace a good backup.
	if not read_valid(path).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(path + ".tmp", path)
