extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/accord_fixture.gd")
const Rules = preload("res://scripts/quests/accord_rules.gd")
const ROUTES := {"terrace": [Vector2(680, 850), Vector2(680, 960), "move_down"], "woodroad": [Vector2(1450, 300), Vector2(1600, 300), "move_right"], "velshof": [Vector2(620, 995), Vector2(920, 995), "move_right"]}
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
func freeze(game: Node) -> void:
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
func cache(game: Node, id: String) -> Node2D:
	for chest in game.world.chests:
		if chest.get_meta("definition").id == id: return chest
	return null
func walk(game: Node, start: Vector2, finish: Vector2, action: String) -> bool:
	game.world.player.position = start
	game.world.player.set_physics_process(true)
	Input.action_press(action)
	var frames := 0
	while game.world.player.position.distance_to(finish) > 6 and frames < 300:
		await physics_frame
		frames += 1
	Input.action_release(action)
	game.world.player.set_physics_process(false)
	return game.world.player.position.distance_to(finish) < 8
func run() -> void:
	var env_script = load("res://scripts/world/living/world_environment.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for choice in ["renewal", "release", "community"]:
		for region in ["terrace", "woodroad", "velshof"]:
			check(Fixture.accepted(session), "world-effects fixture contains all actual earlier reports/voices")
			session.region = region
			session.arrival = Vector2(240, 650)
			game._build_world()
			freeze(game)
			game.resume()
			await settle()
			var points: Array = ROUTES[region]
			var entry: Dictionary = Rules.CACHES[region]
			var chest = cache(game, entry.id)
			check(not game.world.navigation.segment_clear(points[0], points[1]) and not chest.visible and game.world.Regions.camps(region, session.opened).size() == 1, "before decision real shortcut is blocked, supply hidden, extra rest unavailable")
			check(not session.claim_chest(chest.get_meta("definition"), entry.point, game.world.player_vitals()), "backend denies an unearned civic supply even when invoked directly")
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not session.accord_event(choice, game.world.player.position, game.world.player_vitals()) and not game.world.navigation.segment_clear(points[0], points[1]) and not chest.visible and game.world.Regions.camps(region, session.opened).size() == 1, "failed decision cannot change any live regional benefit")
			DirAccess.remove_absolute("user://save.json.tmp")
			check(session.accord_event(choice, game.world.player.position, game.world.player_vitals()), "actual recorded policy applies to a loaded region")
			check(game.world.navigation.segment_clear(points[0], points[1]) == (choice == "release") and chest.visible == (choice == "community") and (Rules.CAMPS[region] in game.world.Regions.camps(region, session.opened)) == (choice == "renewal"), "each chosen future changes only its actual collision/supply/camp benefit")
			var before_count: int = game.world.navigation.obstacles.size()
			session.changed.emit()
			check(game.world.navigation.obstacles.size() == before_count, "reapplying world state never duplicates replacement wall pieces")
			if choice == "release":
				check(await walk(game, points[0], points[1], points[2]), "real ordinary actor physically traverses the newly opened regional passage")
			elif choice == "renewal":
				var ambience: Node
				for child in game.world.get_children():
					if child.get_script() == env_script: ambience = child
				check(ambience != null and ambience.camp_lights.has(Rules.CAMPS[region]), "extra rest has an actual attached light, not only map text")
				game.world.player.position = Rules.CAMPS[region]
				game.world.player.health = 40
				var minutes: float = session.world_state.minutes
				DirAccess.make_dir_absolute("user://save.json.tmp")
				game.world.interact()
				check(game.world.player.health == 40 and session.world_state.minutes == minutes, "failed actual new-camp rest cannot heal or advance clock")
				DirAccess.remove_absolute("user://save.json.tmp")
				game.world.interact()
				check(game.world.player.health == 100 and session.world_state.minutes >= minutes + 30, "actual E at new camp performs real rest and saved time advance")
			else:
				game.world.player.position = entry.point
				var herbs: int = session.inventory.herb
				var potions: int = session.inventory.potion
				DirAccess.make_dir_absolute("user://save.json.tmp")
				game.world.interact()
				check(entry.id not in session.opened and session.inventory.herb == herbs and session.inventory.potion == potions, "failed actual civic pickup grants nothing")
				DirAccess.remove_absolute("user://save.json.tmp")
				game.world.interact()
				check(entry.id in session.opened and session.inventory.herb == herbs + 2 and session.inventory.potion == potions + 1, "actual common supply gives exactly two herbs and one potion")
				game.world.interact()
				check(session.inventory.herb == herbs + 2 and session.inventory.potion == potions + 1, "repeated civic interaction cannot duplicate contents")
			check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved(), "real regional benefit and old progress survive JSON save/load")
			game._build_world()
			freeze(game)
			game.resume()
			await settle()
			check(game.world.navigation.segment_clear(points[0], points[1]) == (choice == "release") and (Rules.CAMPS[region] in game.world.Regions.camps(region, session.opened)) == (choice == "renewal") and (entry.id in session.opened) == (choice == "community"), "rebuilt region retains exactly chosen geometry/rest/claimed supplies")
	print("Accord world checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
