extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
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
	Fixture.ready(session)
	session.region = "lake"
	session.arrival = Vector2(1680, 340)
	game._build_world()
	game.resume()
	game.world.player.health = 63
	game.world.player.position = Vector2(1750, 340)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "terrace" and game.world.player.health == 63 and game.world.safe_to_rest(), "new exploration portal preserves wounds and has a safe arrival")
	var points: Array = game.world.definition.story_sites.values() + game.world.definition.herbs + [game.world.definition.camp, game.world.definition.exit, game.world.definition.witness, Vector2(460, 790)]
	for entry in game.world.definition.chests: points.append(entry.point)
	for point in points:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		check(not route.is_empty(), "ordinary body can reach each story point and optional resource")
		var previous := Vector2(240, 650)
		var clear := true
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "each actual route segment clears authored water and buildings")
	check(Schedule.destination("terrace", "witness", 1380, 0) == Vector2(460, 790), "new essential witness remains reachable at night")
	game.show_map()
	check(game.current_screen == "map", "new geography uses the normal world map")
	game.resume()
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "lake" and game.world.player.health == 63 and game.world.safe_to_rest(), "new area has a working safe return without healing")
	session.region = "workshop"
	session.arrival = Vector2(240, 650)
	game._build_world()
	game.resume()
	for point in [game.world.definition.mentor, Vector2(740, 760)]:
		check(not game.world.navigation.find_path(Vector2(240, 650), point).is_empty(), "new mentor is reachable before optional commission gate opens")
	check(Schedule.destination("workshop", "mentor", 1380, 0) == Vector2(740, 760), "new mentor has his own normal night destination")
	print("Terrace navigation checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
