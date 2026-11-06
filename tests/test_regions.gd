extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Store = preload("res://scripts/systems/save_store.gd")
var checks := 0
var failures := 0
const PATH := "user://region-test.json"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var state := {"version": 6, "world_state": {"minutes": 1020.0, "seed": 43119, "npcs": {}, "commission": {"stage": 0, "survey": [], "heard": [], "supply": "", "settlement": ""}, "reputation": {"roadfolk": 0, "wardens": 0, "tenders": 0}, "seen": [], "next_event": 1050.0, "active": {}}, "gear_owned": ["road_sword", "cloth", "wood_shield"], "equipped": {"weapon": "road_sword", "armor": "cloth", "shield": "wood_shield"}, "opened": [], "aid_quest": 0, "xp": 0, "skills": {}, "region": "lake", "position": [250, 650], "difficulty": 1,
		"vitals": {"health": 60, "stamina": 50, "mana": 45}, "quest": 0, "inventory": {"herb": 1}, "defeated": ["lake_1"], "gathered": ["lake:herb_600_650"]}
	check(Store.write_game(state, PATH) == OK, "save accepts a known second region")
	var restored := Store.load_game(PATH)
	check(restored.get("region") == "lake", "load restores second region identity")
	check(restored.get("vitals", {}).get("health") == 60, "save preserves health across reload")
	check(Store.write_game(state, PATH) == OK, "second save creates a recoverable region backup")
	var legacy := {"version": 1, "position": [410, 490], "difficulty": 1,
		"quest": 0, "inventory": {"herb": 0}, "defeated": [], "gathered": []}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated := Store.load_game(PATH)
	check(migrated.get("version") == 6 and migrated.get("region") == "crossing", "v1 save migrates into original region")
	check(migrated.get("position", []).size() == 2 and Vector2(migrated.position[0], migrated.position[1]) == Vector2(410, 490), "migration retains player location")
	check(migrated.get("vitals", {}).get("health") == 100, "legacy saves receive safe default vitals")
	legacy.version = 99
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(Store.load_game(PATH).get("region") == "lake", "unsupported primary version falls back to valid backup")
	state.region = "missing_region"
	check(Store.write_game(state, PATH) == ERR_INVALID_DATA, "unknown region rejected")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	print("Region save checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
