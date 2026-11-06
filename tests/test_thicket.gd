extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Schedule = preload("res://scripts/world/living/npc_schedule.gd")
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
	session.region = "workshop"
	session.arrival = Vector2(1820, 1190)
	game._build_world()
	game.resume()
	check(game.world.safe_to_rest(), "new forest return arrival avoids old archer awareness")
	game.world.player.health = 63
	game.world.player.position = Vector2(1780, 1200)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "thicket" and game.world.player.health == 63, "actual new portal preserves wounded hero")
	var points: Array = game.world.definition.pack_sites.values() + [game.world.definition.camp, game.world.definition.exit, game.world.definition.tracker, Vector2(420, 790)]
	for entry in game.world.definition.chests: points.append(entry.point)
	for point in points:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		check(not route.is_empty(), "forest objective has an authored traversable route")
		var prior := Vector2(240, 650)
		var clear := true
		for step in route:
			clear = clear and game.world.navigation.segment_clear(prior, step)
			prior = step
		check(clear, "route clears real rocks and tree collisions")
	check(game.world.npcs.tracker.visible and Schedule.destination("thicket", "tracker", 1380, 0) == Vector2(420, 790), "new essential NPC has a reachable night schedule")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "workshop" and game.world.player.health == 63 and game.world.safe_to_rest(), "forest has a working safe return without free healing")
	print("Thicket navigation checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
