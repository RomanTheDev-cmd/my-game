extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
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
	session.arrival = Vector2(1760, 420)
	game._build_world()
	game.resume()
	check(game.world.safe_to_rest(), "new return arrival avoids existing courtyard enemies")
	game.world.player.health = 67
	game.world.player.position = Vector2(1800, 420)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "waterworks" and game.world.player.health == 67, "actual new portal preserves wounds and enters fifth region")
	check(is_instance_valid(game.world.boss) and not game.world.boss.armed and game.world.safe_to_rest(), "unprepared guardian leaves exploration and saving available")
	await physics_frame
	var points: Array = game.world.definition.trial_sites.values() + [game.world.definition.camp, game.world.definition.exit, Vector2(1350, 650), Vector2(1660, 1020)]
	for point in points:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		check(not route.is_empty(), "authored objective has a traversable route")
		var previous := Vector2(240, 650)
		var clear := true
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "objective route clears all actual static obstacles")
	check(not game.world.navigation.segment_clear(Vector2(970, 420), Vector2(1100, 420)), "arena pillar is actual solid cover")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "workshop" and game.world.player.health == 67, "unaccepted optional branch always permits a real return")
	check(session.load_saved() and session.region == "workshop", "new exit location persists through real disk reload")
	print("Waterworks navigation checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
