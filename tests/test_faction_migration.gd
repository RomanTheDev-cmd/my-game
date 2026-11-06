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
	var legacy: Dictionary = session.snapshot(Vector2(410, 490), {"health": 71, "stamina": 52, "mana": 38})
	legacy.version = 5
	legacy.world_state = {"minutes": 2489.5, "seed": 712, "npcs": {"crossing:merchant": [310, 450]},
		"reputation": {"roadfolk": 4}, "seen": ["lost_pack"], "next_event": 2610,
		"active": {"id": "shelter", "region": "crossing", "position": [650, 600]}}
	legacy.inventory = {"coin": 17, "herb": 2, "potion": 1}
	legacy.xp = 120
	legacy.skills = {"sword": 1, "ward": 1}
	legacy.quest = 3
	legacy.defeated = ["road_1"]
	legacy.opened = ["ruins_supplies"]
	legacy.gear_owned.append("iron_sword")
	legacy.equipped.weapon = "iron_sword"
	var upgraded := Store.migrate(legacy)
	check(upgraded.get("version") == 6 and upgraded.get("world_state", {}).get("reputation", {}).has("wardens"), "old world gains new relationships through migration")
	check(upgraded.get("world_state", {}).get("commission", {}).get("stage") == 0, "old hero receives unstarted new quest line")
	check(Store.validate(upgraded), "migrated profile satisfies complete current save schema")
	check(upgraded.world_state.minutes == 2489.5 and upgraded.world_state.seed == 712 and upgraded.world_state.next_event == 2610, "migration retains clock, weather seed and event deadline")
	check(upgraded.world_state.reputation.roadfolk == 4 and upgraded.world_state.seen == ["lost_pack"] and upgraded.world_state.active.id == "shelter", "migration preserves previous trust and pending/remembered events")
	check(upgraded.world_state.npcs["crossing:merchant"] == [310, 450] and upgraded.vitals.health == 71, "migration retains in-transit NPC and wounded hero")
	check(upgraded.inventory.coin == 17 and upgraded.xp == 120 and upgraded.skills.ward == 1 and upgraded.equipped.weapon == "iron_sword", "migration never repeats old rewards or discards trained equipment")
	check(legacy.version == 5 and legacy.world_state.reputation.size() == 1 and not legacy.world_state.has("commission"), "migration leaves original v5 data untouched")
	check(Store.write_game(legacy, "user://factions-migration.json") == OK, "legacy profile writes through normal migration path")
	var loaded := Store.load_game("user://factions-migration.json")
	check(loaded.version == 6 and loaded.world_state.minutes == 2489.5 and loaded.inventory.coin == 17, "current disk reload retains migrated state without rerunning rewards")
	var bad := upgraded.duplicate(true)
	bad.world_state.reputation.erase("tenders")
	check(not Store.validate(bad), "missing group rejected instead of resetting all relationships")
	bad = upgraded.duplicate(true)
	bad.world_state.commission.stage = 6
	check(not Store.validate(bad), "forged final quest stage rejected")
	bad = upgraded.duplicate(true)
	bad.quest = 0
	bad.world_state.commission.stage = 1
	check(not Store.validate(bad), "new line cannot be loaded before required introductory progress")
	session.apply(upgraded)
	var vitals := {"health": 71.0, "stamina": 52.0, "mana": 38.0}
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.commission_event("accept", Vector2(410, 490), vitals) and session.world_state.commission.stage == 0, "failed initial write does not accept quest")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.commission_event("accept", Vector2(410, 490), vitals) and session.load_saved() and session.world_state.commission.stage == 1, "accepted phase survives actual reload")
	session.world_state.commission = {"stage": 3, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "", "settlement": ""}
	session.inventory.coin = 8
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.commission_event("supply_purchase", Vector2(410, 490), vitals) and session.inventory.coin == 8 and session.world_state.commission.stage == 3, "failed supply write keeps money and phase unchanged")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.commission_event("supply_purchase", Vector2(410, 490), vitals) and session.inventory.coin == 0 and session.world_state.commission.stage == 4, "paid supply consumes exactly the price after saving")
	check(not session.commission_event("supply_purchase", Vector2(410, 490), vitals) and session.inventory.coin == 0, "same supply cannot be paid for twice")
	check(session.commission_event("restore_shared", Vector2(410, 490), vitals) and session.world_state.reputation.wardens == 2, "saved settlement applies relationship consequences")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.commission_event("report", Vector2(410, 490), vitals) and session.xp == 120 and session.inventory.coin == 0 and session.world_state.commission.stage == 5, "failed final write grants neither XP nor money")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.commission_event("report", Vector2(410, 490), vitals) and session.xp == 200 and session.inventory.coin == 16, "final reward applies once after disk commit")
	check(session.load_saved() and session.world_state.commission.stage == 6 and not session.commission_event("report", Vector2(410, 490), vitals) and session.xp == 200, "reloading completed line cannot repeat the reward")
	print("Faction migration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
