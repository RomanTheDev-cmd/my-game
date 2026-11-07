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
	session.region = "lake"
	session.arrival = Vector2(240, 1000)
	game._build_world()
	game.resume()
	game.world.player.health = 61
	game.world.player.position = Vector2(135, 1000)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "haven" and game.world.player.health == 61 and game.world.safe_to_rest(), "new physical portal preserves wounds and arrives safely")
	var points: Array = game.world.definition.community_sites.values() + game.world.definition.herbs + [game.world.definition.camp, game.world.definition.exit, game.world.definition.host, Vector2(470, 780)]
	for point in points:
		var path: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		check(not path.is_empty(), "ordinary body has a route to each new objective day or night")
		var previous := Vector2(240, 650)
		var clear := true
		for step in path:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "new routes clear the actual banks and structures")
	check(game.world.npcs.host.visible and Schedule.destination("haven", "host", 1380, 0) == Vector2(470, 780), "new essential NPC has a real safe night destination")
	game.show_map()
	check(game.current_screen == "map", "new region renders through normal map screen")
	game.resume()
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "lake" and game.world.player.health == 61 and game.world.safe_to_rest(), "new region has a working return without free healing")
	print("Haven navigation checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
