extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const OUTSIDE := [Vector2(45, 650), Vector2(45, 120), Vector2(960, 100), Vector2(1880, 700), Vector2(960, 1265)]
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func route_clear(world: Node, start: Vector2, finish: Vector2) -> bool:
	var route: PackedVector2Array = world.navigation.find_path(start, finish)
	if route.is_empty(): return false
	var previous := start
	for point in route:
		if not world.navigation.segment_clear(previous, point): return false
		previous = point
	return true
func build(game: Node, session: Node, region: String, arrival: Vector2) -> Node:
	session.region = region
	session.arrival = arrival
	game._build_world()
	game.world.set_process(false)
	for child in game.world.get_children():
		if child is CharacterBody2D: child.set_physics_process(false)
	game.resume()
	await process_frame
	await physics_frame
	await physics_frame
	return game.world
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	# Rotunda, the hall below it and the waterworks share the old frame; the crypt follows it too.
	for region in ["rotunda", "underhall", "waterworks", "undercroft"]:
		var definition := Regions.get_region(region)
		var world: Node = await build(game, session, region, definition.camp)
		for outside in OUTSIDE:
			check(world.navigation.find_path(definition.camp, outside).is_empty(), "%s: no route leads beyond the hall walls to %s" % [region, outside])
		for portal in Regions.exits(region):
			check(route_clear(world, definition.camp, portal.point), "%s: ordinary route to exit %s stays clear" % [region, portal.label])
		for key in ["mentor", "steward", "witness", "crafter"]:
			if definition.has(key): check(route_clear(world, definition.camp, definition[key]), "%s: ordinary route to %s stays clear" % [region, key])
		for herb in definition.herbs: check(route_clear(world, definition.camp, herb), "%s: herb remains reachable" % region)
		# Real keyboard movement through the west exit gap stops beside the door.
		world.player.position = Vector2(175, 650)
		world.player.set_physics_process(true)
		Input.action_press("move_left")
		for i in 90: await physics_frame
		Input.action_release("move_left")
		Input.action_press("move_up")
		for i in 90: await physics_frame
		Input.action_release("move_up")
		world.player.set_physics_process(false)
		var exit_point: Vector2 = definition.exit
		check(world.player.position.x > 90 and world.player.position.y > 540 and world.player.position.distance_to(exit_point) < 120, "%s: keyboard movement stays in the exit alcove: %s" % [region, world.player.position])
		world.player.position = Vector2(160, 650)
		check(world.nearby_key() == definition.exit_label, "%s: exit is still usable from the alcove" % region)
	# An old save positioned in the former void arrives safely at the camp.
	for region in ["rotunda", "underhall", "waterworks"]:
		session.fresh()
		var data: Dictionary = session.snapshot(Vector2(45, 120))
		data.region = region
		check(session.Store.write_game(data) == OK and session.load_saved() and session.arrival == Vector2(45, 120), "%s: old v9 save in the former void still loads" % region)
		game._build_world()
		game.resume()
		await physics_frame
		game.world.player.sync_form_geometry()
		check(game.world.player.position == Regions.get_region(region).camp, "%s: arrival inside rock is moved to the camp without healing" % region)
	print("Indoor bounds checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
