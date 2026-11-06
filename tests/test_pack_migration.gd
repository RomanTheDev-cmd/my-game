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
	session.nature.form = "battle"
	session.nature.blood = 31.5
	session.gathered.append("dialogue:keeper:vampire:honest")
	var old: Dictionary = session.snapshot(Vector2(520, 490), {"health": 64.0, "stamina": 52.0, "mana": 31.0})
	old.version = 7
	old.nature.erase("resolve")
	var original := old.duplicate(true)
	var upgraded: Dictionary = session.Store.migrate(old)
	check(upgraded.get("version") == 8 and upgraded.get("nature", {}).get("resolve") == 100, "v7 gains independent shape stamina through explicit migration")
	check(upgraded.nature.kind == "vampire" and upgraded.nature.form == "battle" and upgraded.nature.blood == 31.5, "migration preserves old vampire nature shape and hunger")
	check(upgraded.world_state == old.world_state and upgraded.gathered == old.gathered and upgraded.vitals.health == 64 and old == original, "migration retains full world conversation memory wounds and immutable source")
	check(session.Store.validate(upgraded) and session.Store.write_game(old, "user://v7-pack.json") == OK, "legacy profile migrates and writes to actual disk")
	check(session.Store.load_game("user://v7-pack.json").nature.blood == 31.5, "migration roundtrip does not refill vampire blood")
	Fixture.completed_episode(session)
	var pos := Vector2(450, 600)
	var vitals := {"health": 64.0, "stamina": 52.0, "mana": 70.0}
	check(session.pack_event("invite", pos, vitals) and session.nature.kind == "human", "offer commits while preserving human start")
	for event in ["trail_0", "trail_1", "trail_2", "hear"]:
		check(session.pack_event(event, pos, vitals), "distinct preparation writes once")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.pack_event("accept", pos, vitals) and session.nature.kind == "human" and session.xp == 180, "failed acceptance write does not transform or grant reward")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.pack_event("accept", pos, vitals) and session.nature.kind == "werewolf" and session.xp == 220, "explicit prepared acceptance persists wolf nature exactly once")
	var corrupt: Dictionary = session.snapshot(pos, vitals)
	corrupt.nature.cure = 1
	corrupt.gathered.append_array(["pack:return_started", "pack:release_den", "pack:release_word"])
	check(not session.Store.validate(corrupt), "full save validator rejects a return state that would dead-end")
	check(session.load_saved() and session.nature.history == ["werewolf"] and session.vitals.health == 64, "new nature reloads without healing or losing history")
	check(not session.pack_event("accept", pos, vitals), "accepted path cannot farm reward")
	session.nature.form = "wolf"
	session.nature.resolve = 8
	check(session.save_at(pos, vitals) and session.load_saved() and session.nature.form == "wolf" and session.nature.resolve == 8, "saved shape and reserve survive actual reload")
	session.advance_world(20)
	check(session.nature.form == "human" and is_equal_approx(session.nature.resolve, 8), "normal clock depletes then recovers in human shape")
	check(session.pack_event("return_start", pos, vitals), "return starts its own procedure")
	check(not session.pack_event("return_finish", pos, vitals), "return cannot skip preparation")
	check(session.pack_event("release_den", pos, vitals) and session.pack_event("release_word", pos, vitals), "return requires two independent actions")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.pack_event("return_finish", pos, vitals) and session.nature.kind == "werewolf", "failed return write retains supernatural nature")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.pack_event("return_finish", pos, vitals) and session.nature.kind == "human" and session.nature.gift == "wild_scar" and session.vitals.mana == 40, "return spends real mana and retains distinct human aftermath")
	check(session.load_saved() and session.nature.history == ["werewolf"] and not session.pack_event("accept", pos, vitals), "returned history persists and prevents free recapture")
	print("Pack migration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
