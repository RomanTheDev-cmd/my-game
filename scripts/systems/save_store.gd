extends RefCounted
const City = preload("res://scripts/quests/city_rules.gd")
const Forest = preload("res://scripts/quests/forest_rules.gd")
const Campaign = preload("res://scripts/quests/campaign_rules.gd")
const Field = preload("res://scripts/magic/field_rules.gd")
const Community = preload("res://scripts/factions/community_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Trial = preload("res://scripts/quests/trial_rules.gd")

const WorldState = preload("res://scripts/world/living/world_state.gd")
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Skills = preload("res://scripts/progression/skill_rules.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const VERSION := 9
const DEFAULT_PATH := "user://save.json"

static func migrate(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var upgraded: Dictionary = data.duplicate(true)
	if upgraded.get("version") == 1:
		upgraded["version"] = 2
		upgraded["region"] = "crossing"
		upgraded["vitals"] = {"health": 100.0, "stamina": 100.0, "mana": 100.0}
	if upgraded.get("version") == 2:
		if not upgraded.get("defeated") is Array:
			return {}
		upgraded["version"] = 3
		upgraded["xp"] = mini(100000, upgraded.defeated.size() * 20 + (40 if upgraded.get("quest") == 3 else 0))
		upgraded["skills"] = {}
		upgraded["aid_quest"] = 0
	if upgraded.get("version") == 3:
		if not upgraded.get("inventory") is Dictionary or not upgraded.get("defeated") is Array:
			return {}
		var coins = upgraded.inventory.get("coin", 0)
		if not (coins is int or coins is float) or coins < 0 or coins > 999 or floorf(coins) != coins:
			return {}
		upgraded["version"] = 4
		upgraded["gear_owned"] = Gear.DEFAULT_OWNED.duplicate()
		upgraded["equipped"] = Gear.DEFAULT_EQUIPPED.duplicate()
		upgraded["opened"] = []
		upgraded.inventory["coin"] = mini(999, int(coins) + upgraded.defeated.size() * 3)
	if upgraded.get("version") == 4:
		upgraded["version"] = 5
		upgraded["world_state"] = WorldState.defaults()
		upgraded.world_state.reputation = {"roadfolk": 0}
		upgraded.world_state.erase("commission")
	if upgraded.get("version") == 5:
		var world = upgraded.get("world_state")
		if not world is Dictionary or not world.get("reputation") is Dictionary or world.has("commission"):
			return {}
		if world.reputation.size() != 1 or not WorldState.number(world.reputation.get("roadfolk"), -10, 10, true):
			return {}
		upgraded["version"] = 6
		world.reputation["wardens"] = 0
		world.reputation["tenders"] = 0
		world["commission"] = WorldState.Commission.defaults()
	if upgraded.get("version") == 6:
		if upgraded.has("nature"): return {}
		upgraded["version"] = 7
		upgraded["nature"] = Nature.defaults()
		upgraded.nature.erase("resolve")
		upgraded.nature.erase("landing")
	if upgraded.get("version") == 7:
		var old_nature = upgraded.get("nature")
		if not old_nature is Dictionary or old_nature.has("resolve") or old_nature.get("kind") not in ["human", "vampire"]: return {}
		if old_nature.get("gift") not in ["", "oath", "blood", "scar"] or old_nature.get("form") not in ["human", "battle"] or old_nature.get("history") not in [[], ["vampire"]]: return {}
		old_nature["resolve"] = 100.0
		var check_nature: Dictionary = old_nature.duplicate(true)
		check_nature["landing"] = {}
		if not Nature.valid(check_nature): return {}
		upgraded["version"] = 8
	if upgraded.get("version") == 8:
		var old_nature = upgraded.get("nature")
		if not old_nature is Dictionary or old_nature.has("landing") or old_nature.get("form") in ["bat", "mist"] or old_nature.get("gift") in ["blood_bat", "blood_mist"]: return {}
		old_nature["landing"] = {}
		if not Nature.valid(old_nature): return {}
		upgraded["version"] = VERSION
	return upgraded

static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	if not Nature.valid(data.get("nature")): return false
	if not WorldState.valid(data.get("world_state")):
		return false
	if not Gear.valid(data.get("gear_owned"), data.get("equipped")) or not data.get("opened") is Array:
		return false
	for id in data.opened:
		if not id is String:
			return false
	if not Skills.valid(data.get("xp"), data.get("skills")):
		return false
	var aid = data.get("aid_quest")
	if not (aid is int or aid is float) or aid < 0 or aid > 2 or floorf(aid) != aid:
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
	if data.world_state.commission.stage > 0 and data.quest != 3:
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
	if not Dialogue.valid(data.gathered): return false
	if not data.nature.landing.is_empty() and data.nature.landing.region != data.region: return false
	if not Nature.quest_valid(data.nature, data.gathered, data.opened): return false
	if not Community.valid(data.nature, data.gathered, data.opened): return false
	if not City.valid(data.nature, data.gathered, data.opened): return false
	if data.defeated.any(func(flag): return flag.begins_with("city:") or flag.begins_with("city_") or flag == City.SUPPLIES): return false
	if not Forest.valid(data.nature, data.gathered, data.opened): return false
	if data.defeated.any(func(flag): return flag.begins_with("forest:") or flag.begins_with("forest_")): return false
	if not Campaign.valid(data.nature, int(data.quest), data.gathered, data.opened, data.inventory): return false
	if data.defeated.any(func(flag): return flag.begins_with("story:") or flag.begins_with("story_")): return false
	if not Field.valid(data.gathered, data.opened): return false
	if data.defeated.any(func(flag): return flag.begins_with("field:") or flag.begins_with("field_")): return false
	if not Trial.valid(data.gathered, data.defeated, data.opened, int(data.world_state.commission.stage)):
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
