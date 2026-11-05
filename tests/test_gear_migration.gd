extends SceneTree
const Store = preload("res://scripts/systems/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var old := {"version": 3, "xp": 60, "skills": {"sword": 1}, "quest": 3, "aid_quest": 0,
		"position": [410, 490], "region": "crossing", "difficulty": 1,
		"inventory": {"coin": 12, "potion": 1, "herb": 2}, "defeated": ["road_1", "lake_2"], "gathered": [],
		"vitals": {"health": 75, "stamina": 60, "mana": 30}}
	var upgraded := Store.migrate(old)
	check(Store.validate(upgraded), "v3 migrates into valid equipped v4 state")
	check(upgraded.gear_owned.size() == 3 and upgraded.equipped.weapon == "road_sword", "migration supplies previous implicit starter gear")
	check(upgraded.inventory.coin == 18 and upgraded.inventory.potion == 1, "migration retains consumables and credits old encounter drops once")
	check(upgraded.xp == 60 and upgraded.skills.get("sword") == 1 and upgraded.vitals.health == 75, "migration preserves trained and wounded hero")
	check(old.version == 3 and old.inventory.coin == 12, "migration never mutates source data")
	check(Store.write_game(upgraded, "user://gear-migration.json") == OK, "upgraded state writes")
	var restored := Store.load_game("user://gear-migration.json")
	check(restored.inventory.coin == 18, "v4 reload cannot repeat retroactive rewards")
	var bad := upgraded.duplicate(true)
	bad.equipped.weapon = "iron_sword"
	check(not Store.validate(bad), "save cannot equip unowned gear")
	bad = upgraded.duplicate(true)
	bad.gear_owned.append("road_sword")
	check(not Store.validate(bad), "duplicated unique gear rejected")
	bad = upgraded.duplicate(true)
	bad.opened = [4]
	check(not Store.validate(bad), "malformed opened-cache identifiers rejected")
	DirAccess.remove_absolute("user://gear-migration.json")
	print("Gear migration checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
