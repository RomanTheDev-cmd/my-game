extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Store = preload("res://scripts/systems/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := root.get_node("Session")
	session.fresh()
	var state: Dictionary = session.snapshot(Vector2(410, 490))
	state.version = 5
	state.erase("nature")
	state["world_state"] = {"minutes": 1445.0, "seed": 43119, "npcs": {}, "reputation": {"roadfolk": 0}, "seen": [], "next_event": 1500.0, "active": {}}
	check(Store.write_game(state, "user://world-time-test.json") == OK, "world time can be saved with game state")
	var loaded := Store.load_game("user://world-time-test.json")
	check(loaded.get("world_state", {}).get("minutes") == 1445, "elapsed time survives reload")
	var legacy: Dictionary = session.snapshot(Vector2(410, 490), {"health": 73.0, "stamina": 60.0, "mana": 40.0})
	legacy.version = 4
	legacy.erase("nature")
	legacy.erase("world_state")
	legacy.inventory = {"coin": 17, "potion": 2}
	legacy.defeated = ["road_1"]
	legacy.xp = 60
	legacy.skills = {"sword": 1}
	legacy.opened = ["crossing_cache"]
	var upgraded := Store.migrate(legacy)
	check(Store.validate(upgraded) and upgraded.version == 7 and upgraded.world_state.minutes == 1020, "v4 gains valid initial clock without resetting the hero")
	check(upgraded.inventory == legacy.inventory and upgraded.skills == legacy.skills and upgraded.xp == 60, "clock migration preserves money, supplies and training without retroactive rewards")
	check(upgraded.vitals.health == 73 and upgraded.defeated == legacy.defeated and upgraded.opened == legacy.opened and upgraded.equipped == legacy.equipped, "clock migration retains wounds, world memory and equipment")
	check(legacy.version == 4 and not legacy.has("world_state"), "clock migration leaves original data untouched")
	check(Store.write_game(upgraded, "user://world-time-test.json") == OK and Store.load_game("user://world-time-test.json").inventory.coin == 17, "v4 migration survives disk reload without repeated reward")
	state.world_state.active = {"id": "shelter", "region": "crossing", "position": [650, 600]}
	check(Store.write_game(state, "user://world-time-test.json") == OK, "pending encounter writes before any choice")
	loaded = Store.load_game("user://world-time-test.json")
	var active: Dictionary = loaded.world_state.active
	check(active.id == "shelter" and active.region == "crossing" and Vector2(active.position[0], active.position[1]) == Vector2(650, 600) and loaded.world_state.seen.is_empty(), "pending encounter retains identity, location and unresolved status after reload")
	DirAccess.remove_absolute("user://world-time-test.json")
	print("World time checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
