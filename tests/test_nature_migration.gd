extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	session.fresh()
	var old: Dictionary = session.snapshot(Vector2(410, 490), {"health": 62.0, "stamina": 41.0, "mana": 27.0})
	old.version = 6
	old.erase("nature")
	old.inventory = {"coin": 17, "herb": 4}
	old.world_state.minutes = 2345.5
	var original := old.duplicate(true)
	var upgraded: Dictionary = session.Store.migrate(old)
	check(upgraded.get("version") == 7 and upgraded.get("nature", {}).get("kind") == "human", "v6 gains a human nature without retroactive transformation")
	check(old == original, "migration never mutates its caller's old save")
	check(upgraded.world_state == old.world_state and upgraded.inventory == old.inventory and upgraded.vitals.health == 62, "nature migration preserves whole world inventory and wounds")
	check(session.Store.validate(upgraded), "migrated v6 satisfies complete current schema")
	check(session.Store.write_game(old, "user://nature-migrate.json") == OK, "legacy data can be written through migration")
	check(session.Store.load_game("user://nature-migrate.json").nature.kind == "human", "migrated nature survives real disk reload")
	for field in ["kind", "form", "blood", "history", "stage", "cure", "gift"]:
		var bad := upgraded.duplicate(true)
		bad.nature.erase(field)
		check(not session.Store.validate(bad), "missing nature field rejects damaged save")
	var bad := upgraded.duplicate(true)
	bad.nature.kind = "werewolf"
	check(not session.Store.validate(bad), "unsupported nature is not silently accepted as an implemented path")
	bad = upgraded.duplicate(true)
	bad.nature.blood = INF
	check(not session.Store.validate(bad), "nonfinite resource is rejected")
	Fixture.completed_episode(session)
	var position := Vector2(480, 620)
	var vitals := {"health": 62.0, "stamina": 41.0, "mana": 77.0}
	check(session.nature_event("invite", position, vitals), "invitation writes without changing nature")
	check(session.nature.kind == "human" and session.nature_event("water", position, vitals) and session.nature_event("garden", position, vitals), "preparation commits both observations while hero stays human")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.nature_event("vampire", position, vitals) and session.nature.kind == "human" and session.xp == 180, "failed acceptance write does not transform or grant reward")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.nature_event("vampire", position, vitals) and session.nature.kind == "vampire" and session.xp == 220 and session.world_state.reputation.roadfolk == -1, "explicit nature change commits power history reward and relation together")
	check(session.load_saved() and session.nature.history == ["vampire"] and session.vitals.health == 62, "reload preserves transformed nature without free healing")
	check(not session.nature_event("human", position, vitals) and session.nature.kind == "vampire", "initial choice cannot undo permanent nature freely")
	session.nature.blood = 30
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.nature_event("supply", position, vitals) and session.nature.blood == 30 and session.inventory.coin == 24, "failed supply write retains both blood and money")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.nature_event("supply", position, vitals) and session.nature.blood == 70 and session.inventory.coin == 18, "voluntary supply spends actual currency for bounded blood")
	check(session.nature_event("cure_start", position, vitals) and session.nature.cure == 1, "return begins its own persistent procedure")
	check(not session.nature_event("cure_finish", position, vitals), "return cannot skip its separate preparation")
	check(session.nature_event("release_garden", position, vitals) and session.nature_event("release_water", position, vitals) and session.nature.cure == 2, "two return actions prepare final ritual")
	check(not session.nature_event("cure_finish", position, {"health": 62.0, "stamina": 41.0, "mana": 29.0}), "ritual requires its actual mana price")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.nature_event("cure_finish", position, vitals) and session.nature.kind == "vampire" and session.vitals.mana == 77, "failed ritual write keeps former nature and resources")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.nature_event("cure_finish", position, vitals) and session.nature.kind == "human" and session.nature.gift == "scar" and session.vitals.mana == 47 and session.xp == 260, "return spends mana and replaces powers without erasing history")
	check(session.load_saved() and session.nature.history == ["vampire"] and session.nature.cure == 3, "returned human remains distinct on disk")
	check(not session.nature_event("vampire", position, vitals) and not session.nature_event("cure_finish", position, vitals), "completed return forbids free recapture and repeated rewards")
	Fixture.vampire(session)
	session.nature.blood = 30
	var time_before: float = session.world_state.minutes
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.wait_minutes(1440, position) and session.nature.blood == 30 and session.world_state.minutes == time_before, "failed wait write preserves both blood and clock")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.wait_minutes(1440, position) and session.nature.blood == 0 and session.nature.form == "human" and session.world_state.minutes == time_before + 1440, "waiting applies the same hunger cost as normal elapsed world time")
	check(session.load_saved() and session.nature.blood == 0, "spent blood from waiting survives disk reload")
	var nature_before: Dictionary = session.nature.duplicate(true)
	time_before = session.world_state.minutes
	for invalid_delta in [-1.0, NAN, INF]:
		session.advance_world(invalid_delta)
		check(session.nature == nature_before and session.world_state.minutes == time_before, "invalid world delta cannot destroy nature or alter time")
	print("Nature migration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
