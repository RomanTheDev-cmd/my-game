extends SceneTree
const Store = preload("res://scripts/systems/save_store.gd")
var checks := 0
var failures := 0
const PATH := "user://test-save.json"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var valid := {"version": 2, "region": "crossing", "position": [410, 490], "difficulty": 1, "quest": 1,
		"vitals": {"health": 75, "stamina": 60, "mana": 40}, "defeated": ["road_1"], "inventory": {"herb": 2}, "gathered": ["herb_650_670"]}
	check(Store.load_game(PATH).is_empty(), "missing save is an explicit empty result")
	check(Store.write_game(valid, PATH) == OK, "valid state writes successfully")
	var first := Store.load_game(PATH)
	check(first.get("quest") == 1 and first.inventory.herb == 2 and first.defeated == ["road_1"], "roundtrip retains progress and world state")
	valid.quest = 2
	valid.inventory["lantern"] = 1
	check(Store.write_game(valid, PATH) == OK, "second write succeeds")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	check(Store.load_game(PATH).get("quest") == 1, "corrupt primary recovers previous valid backup")
	var malformed := valid.duplicate(true)
	malformed.position = ["bad", 0]
	check(Store.write_game(malformed, PATH) == ERR_INVALID_DATA, "malformed coordinates rejected")
	check(Store.load_game(PATH).get("quest") == 1, "rejected write preserves recoverable state")
	for field in ["version", "vitals", "region", "quest", "difficulty", "defeated", "inventory", "gathered"]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		check(not Store.validate(missing), "reject missing " + field)
	for value in [-1, 4, 1.5]:
		var bad := valid.duplicate(true)
		bad.quest = value
		check(not Store.validate(bad), "reject impossible quest stage")
	var bad := valid.duplicate(true)
	bad.position = [INF, 0]
	check(not Store.validate(bad), "nonfinite coordinates rejected")
	bad = valid.duplicate(true)
	bad.inventory.herb = -5
	check(not Store.validate(bad), "negative inventory rejected")
	bad = valid.duplicate(true)
	bad.position = [-100, 490]
	check(not Store.validate(bad), "reject spawn outside playable world")
	bad = valid.duplicate(true)
	bad.inventory.erase("lantern")
	check(not Store.validate(bad), "reject quest objective state without its item")
	for value in [-1, 0, 101, INF, "bad"]:
		bad = valid.duplicate(true)
		bad.vitals.health = value
		check(not Store.validate(bad), "reject invalid saved health")
	check(Store.write_game(valid, PATH) == OK, "can recover by saving after primary corruption")
	check(Store.read_valid(PATH + ".bak").get("quest") == 1, "corrupt primary does not overwrite good backup")
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(PATH + suffix)
	print("Save checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
