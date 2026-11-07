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
	Fixture.vampire(session)
	session.region = "waterworks"
	session.nature.form = "battle"
	var vitals := {"health": 54.0, "stamina": 37.0, "mana": 73.0}
	var old: Dictionary = session.snapshot(Vector2(1500, 430), vitals)
	old.version = 8
	old.nature.erase("landing")
	var original := old.duplicate(true)
	var migrated: Dictionary = session.Store.migrate(old)
	check(migrated.version == 9 and migrated.nature.landing.is_empty(), "v8 adds a safe landing field without forcing new lessons")
	check(old == original and migrated.nature.form == "battle" and migrated.nature.blood == 80, "migration preserves caller and former combat form")
	check(migrated.world_state == old.world_state and migrated.vitals == old.vitals and migrated.inventory == old.inventory and migrated.gathered == old.gathered, "whole world wounds resources and conversations survive")
	check(session.Store.write_game(old) == OK and session.load_saved() and session.nature.form == "battle", "real legacy disk roundtrip succeeds")
	for field in ["form", "gift"]:
		var bad := old.duplicate(true)
		bad.nature[field] = "bat" if field == "form" else "blood_bat"
		check(session.Store.migrate(bad).is_empty(), "old format cannot smuggle a newly unlocked ability")
	Fixture.vampire(session)
	session.region = "lake"
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.nature_event("learn_bat", Vector2(480, 620), vitals) and session.nature.gift == "blood" and session.xp == 180, "failed lesson write grants nothing and consumes nothing")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.nature_event("learn_bat", Vector2(480, 620), vitals) and session.vitals.mana == 53 and session.xp == 200, "successful lesson commits price progression and reward")
	check(session.load_saved() and session.nature.gift == "blood_bat" and "flight:bat" in session.gathered, "learned ability reloads from disk")
	session.region = "waterworks"
	session.nature = session.Nature.shift(session.nature, "bat", {"region": "waterworks", "position": [1500.0, 430.0]})
	check(session.save_at(Vector2(1640, 320), vitals) and session.load_saved() and session.nature.form == "bat" and session.nature.landing.position == [1500.0, 430.0], "mobile save keeps its safe external landing rather than the chamber location")
	var bad: Dictionary = session.snapshot(Vector2(1640, 320), vitals)
	bad.nature.landing.region = "lake"
	check(not session.Store.validate(bad), "save rejects an anchor in another region")
	bad = session.snapshot(Vector2(1640, 320), vitals)
	bad.nature.landing = {}
	check(not session.Store.validate(bad), "mobile save requires a landing anchor")
	var before: Dictionary = session.nature.duplicate(true)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.travel("workshop", Vector2(400, 650), vitals) and session.nature == before and session.region == "waterworks", "failed travel preserves mobile form and old region")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.travel("workshop", Vector2(400, 650), vitals) and session.nature.form == "human" and session.nature.landing.is_empty() and session.nature.blood == before.blood and session.vitals.health == 54, "travel lands in ordinary form without free blood or healing")
	print("Flight migration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
