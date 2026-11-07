extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/city_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "ordinary city combat fixture starts with a valid main commitment")
	session.region = "velshof"
	session.arrival = Vector2(240, 650)
	game._build_world()
	game.resume()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for entry in game.world.definition.enemies:
		var enemy: CharacterBody2D
		for child in game.world.get_children():
			if child is CharacterBody2D and child.get("id") == entry[0]: enemy = child
		check(enemy != null, "optional city combat uses an actual authored enemy")
		enemy.receive_damage(999, Vector2.RIGHT)
		check(entry[0] in session.defeated and session.Store.validate(session.snapshot(game.world.player.position, game.world.player_vitals())), "actual defeated signal preserves save validity for each new enemy")
		check(session.save_at(game.world.player.position, game.world.player_vitals()), "ordinary save remains writable after each actual city victory")
	var ids: Array = session.defeated.duplicate()
	check(session.load_saved() and ids.all(func(id): return id in session.defeated) and session.region == "velshof", "both city victories reload from real disk")
	game._build_world()
	game.resume()
	check(game.world.get_children().all(func(child): return not (child is CharacterBody2D and child.get("id") in ids)), "rebuilt scene does not resurrect committed city enemies")
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for herb in game.world.herbs:
		game.world.player.position = herb.position
		game.world.interact()
		check(herb.get_meta("id") in session.gathered and session.Store.validate(session.snapshot(game.world.player.position, game.world.player_vitals())), "actual authored herb pickup preserves save validity")
		check(session.save_at(game.world.player.position, game.world.player_vitals()), "save remains writable after each actual herb pickup")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "workshop" and ids.all(func(id): return id in session.defeated), "actual travel remains writable after both city victories")
	print("City combat save checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
