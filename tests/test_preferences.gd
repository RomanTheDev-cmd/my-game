extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Preferences = preload("res://scripts/systems/preferences_store.gd")
var checks := 0
var failures := 0
const PATH := "user://test-preferences.json"

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	check(Preferences.read(PATH).get("difficulty") == 1, "missing preferences use adventure mode")
	check(Preferences.write({"version": 1, "difficulty": 2, "fullscreen": true}, PATH) == OK, "valid preferences save")
	var restored := Preferences.read(PATH)
	check(restored.get("difficulty") == 2 and restored.get("fullscreen") == true, "fullscreen and difficulty persist across read")
	check(Preferences.write({"version": 1, "difficulty": 9, "fullscreen": false}, PATH) == ERR_INVALID_DATA, "invalid difficulty rejected")
	check(Preferences.read(PATH).get("difficulty") == 2, "rejected preferences do not overwrite valid settings")
	check(not Preferences.valid({"version": 1, "difficulty": 1, "fullscreen": "true"}), "string boolean rejected")
	check(restored.get("audio", {}).get("master") == 0.8, "old preferences gain safe audio defaults without losing difficulty")
	check(not Preferences.valid({"version": 1, "difficulty": 1, "fullscreen": false, "audio": {"master": 1.5, "effects": 0.8, "ambience": 0.5}}), "out-of-range volume rejected at settings boundary")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(Preferences.read(PATH).get("fullscreen") == false, "corrupt preferences recover safe windowed defaults")
	DirAccess.remove_absolute(PATH)
	print("Preferences checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
