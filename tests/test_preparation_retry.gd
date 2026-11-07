extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/preparation_fixture.gd")
const Rules = preload("res://scripts/quests/preparation_rules.gd")
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
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for change in ["layout_city", "tune_north"]:
		check(Fixture.configured(session), "retry regression starts from genuine consents and support settings")
		session.region = "rotunda"
		session.arrival = Rules.CONTROLS.gate
		game._build_world()
		game.world.set_process(false)
		game.world.player.set_physics_process(false)
		for npc in game.world.npcs.values(): npc.set_physics_process(false)
		game.resume()
		await settle()
		for role in ["witness", "crafter"]: game.world.npcs[role].position = Rules.post(session.gathered, role)
		check(game.world.start_preparation(), "real trial starts before retry invalidation")
		DirAccess.make_dir_absolute("user://save.json.tmp")
		game.world.player.set_physics_process(true)
		Input.action_press("move_left")
		var frames := 0
		while game.world.player.position.x > 525 and frames < 900:
			await physics_frame
			frames += 1
		Input.action_release("move_left")
		game.world.player.set_physics_process(false)
		await settle()
		check(game.world.preparation_route.pending and "prep:tested" not in session.gathered, "actual full physical walk with disk refusal enters unrecorded proof state")
		game.world.player.position = game.world.definition.junction_sites.table if change == "layout_city" else Rules.CONTROLS.north
		check(not game.world.preparation_action(change) and game.world.preparation_route.pending, "failed preparation edit keeps old pending evidence and unchanged setup")
		DirAccess.remove_absolute("user://save.json.tmp")
		check(game.world.preparation_action(change), "prepared assignment or support can be edited before committed proof")
		check(not game.world.preparation_route.pending and game.world.preparation_route.step == 0 and not game.world.preparation_route.active, "successful setup edit invalidates pending evidence as well as active progress: " + change)
		if change == "tune_north":
			check(game.world.preparation_action("tune_north") and game.world.preparation_action("tune_north"), "support can be turned back to its required orientation")
		for role in ["witness", "crafter"]: game.world.npcs[role].position = Rules.post(session.gathered, role)
		game.world.player.position = Rules.CONTROLS.finish
		game.world.interact()
		check(game.world.can_rehearse() and not game.world.can_preparation("prove") and "prep:tested" not in session.gathered, "restored valid setup cannot reuse the former route through E at its exit")
	print("Preparation retry checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
