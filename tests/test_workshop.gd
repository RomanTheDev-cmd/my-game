extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Schedule = preload("res://scripts/world/living/npc_schedule.gd")
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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.region = "workshop"
	session.arrival = Vector2(240, 650)
	game._build_world()
	game.resume()
	await physics_frame
	var definition := Regions.get_region("workshop")
	var points: Array = definition.commission_sites.values() + [definition.camp, definition.exit]
	for kind in ["warden", "wright", "tender"]:
		points.append(definition[kind])
	for entry in definition.salvage:
		points.append(entry.point)
	for point in points:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		check(not route.is_empty(), "authored objective has a reachable route")
		var previous := Vector2(240, 650)
		var clear := true
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "objective route clears actual solid geometry")
	check(not game.world.navigation.segment_clear(Vector2(960, 600), Vector2(1230, 600)), "unrepaired passage remains physically blocked")
	var detour: PackedVector2Array = game.world.navigation.find_path(Vector2(960, 600), Vector2(1230, 600))
	check(detour.size() > 2, "blocked direct passage still has an alternative route")
	for kind in ["warden", "wright", "tender"]:
		var destination := Schedule.destination("workshop", kind, 1380, 0)
		check(game.world.npcs[kind].visible and not game.world.navigation.find_path(game.world.npcs[kind].position, destination).is_empty(), "essential NPC has a reachable night destination")
	game.world.player.health = 71
	game.world.player.position = definition.exit
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "lake" and game.world.player.health == 71, "real return portal keeps wounded hero and changes region")
	check(game.world.safe_to_rest(), "authored return arrival avoids enemy aggro")
	game.world.player.position = Vector2(1750, 1120)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "workshop", "actual new branch portal returns to courtyard")
	print("Workshop navigation checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
