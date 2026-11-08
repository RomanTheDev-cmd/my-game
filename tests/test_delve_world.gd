extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/delve_rules.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const OUTSIDE := [Vector2(50, 650), Vector2(960, 100), Vector2(1880, 650), Vector2(960, 1250)]
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
func cross(world: Node, rect: Rect2) -> bool:
	var vertical := rect.size.x < rect.size.y
	var start := rect.get_center() - (Vector2(60, 0) if vertical else Vector2(0, 60))
	var finish := rect.get_center() + (Vector2(60, 0) if vertical else Vector2(0, 60))
	world.player.position = start
	world.player.set_physics_process(true)
	var action := "move_right" if vertical else "move_down"
	Input.action_press(action)
	for i in 80:
		await physics_frame
		if world.player.position.distance_to(finish) < 8: break
	Input.action_release(action)
	world.player.set_physics_process(false)
	return world.player.position.distance_to(start) > 100
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	var warden_script: GDScript = load("res://scripts/actors/hollow_warden.gd")
	for seed_value in [17, 90210, 2024108]:
		NatureFixture.vampire(session)
		session.world_state["delve_seed"] = seed_value
		session.nature.gift = "blood_bat"
		session.gathered.append("flight:bat")
		session.opened.append_array(["delve_keystone_1", "delve_keystone_2"])
		for depth in [1, 2, 3]:
			var region := Rules.region(depth)
			var world: Node = await build(game, session, region, Vector2(250, 680))
			var layout: Dictionary = world.definition
			check(layout.depth == depth and world.landscape.get_script().resource_path.ends_with("hollow_landscape.gd"), "%s/%d: generated layout drives the real scene" % [region, seed_value])
			var spawned := world.get_children().filter(func(child): return child is CharacterBody2D and child != world.player and child.get("id") != null and child.id.begins_with("hollow_"))
			check(spawned.size() == layout.enemies.size(), "%s/%d: every generated enemy is spawned" % [region, seed_value])
			if depth == 3:
				var wardens := spawned.filter(func(enemy): return enemy.get_script() == warden_script)
				check(wardens.size() == 1 and wardens[0].max_health == 300, "%s/%d: elite warden guards the deepest keystone" % [region, seed_value])
				var warden = wardens[0]
				warden.target = world.player
				world.player.position = warden.position + Vector2(-30, 0)
				warden.awareness_time = 4
				warden._physics_process(1.0 / 60)
				var full: float = warden.timer if warden.state == "windup" else -1.0
				warden.state = "idle"
				warden.timer = 0
				warden.health = 100
				warden._physics_process(1.0 / 60)
				var hurt: float = warden.timer if warden.state == "windup" else -1.0
				check(is_equal_approx(full, 0.9) and is_equal_approx(hurt, 0.7), "%s/%d: the elite warden's real windup timer is faster than an ordinary heavy foe: %s/%s" % [region, seed_value, full, hurt])
			var targets: Array = [Vector2(230, 780), Vector2(175, 680), layout.note] + layout.herbs + layout.chests.map(func(chest): return chest.point) + layout.enemies.map(func(entry): return entry[1])
			if layout.has("stairs"): targets.append(layout.stairs)
			var reachable := targets.all(func(point): return route_clear(world, Vector2(250, 680), point))
			check(reachable, "%s/%d: ordinary body has a clear route to camp, exit, note, herbs, caches, enemies and stairs" % [region, seed_value])
			check(OUTSIDE.all(func(point): return world.navigation.find_path(Vector2(250, 680), point).is_empty()), "%s/%d: no route leads beyond the hollow walls" % [region, seed_value])
			var rubble: Rect2 = layout.rubble[0]
			var bodies := world.get_children().filter(func(child): return child is StaticBody2D and child.has_meta("rubble"))
			var across: Vector2 = Vector2(40, 0) if rubble.size.x < rubble.size.y else Vector2(0, 40)
			check(bodies.size() == 1 and bodies[0].collision_layer == 16 and not world.navigation.segment_clear(rubble.get_center() - across, rubble.get_center() + across), "%s/%d: rubble is a real low body that routes avoid" % [region, seed_value])
			if seed_value == 17:
				check(not await cross(world, rubble), "%s: ordinary body cannot climb the rubble" % region)
				world.player.position = rubble.get_center() - (Vector2(60, 0) if rubble.size.x < rubble.size.y else Vector2(0, 60))
				await physics_frame
				check(world.player.shift_form("bat"), "%s: bat form is available beside the rubble" % region)
				check(await cross(world, rubble), "%s: a bat flies over the rubble shortcut" % region)
				world.player.shift_form()
				# Hidden caches: loose stones for careful eyes, a clear trail for trackers.
				var hidden: Sprite2D
				for chest in world.chests:
					if chest.get_meta("definition").get("hidden", false): hidden = chest
				world.player.position = hidden.position + Vector2(200, 0)
				world._update_tracking()
				check(not hidden.visible and not world.tracking_cue.visible, "%s: a hidden cache is not visible from afar" % region)
				world.player.scent_time = 5
				world._update_tracking()
				check(hidden.visible and world.tracking_cue.visible, "%s: tracking reveals the cache and points the way" % region)
				world.player.scent_time = 0
				world.player.position = hidden.position + Vector2(30, 0)
				world._update_tracking()
				check(hidden.visible and world.nearby_key() == "CHEST", "%s: an ordinary careful hero finds it by walking close" % region)
	print("Delve world checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
