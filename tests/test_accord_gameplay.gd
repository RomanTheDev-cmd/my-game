extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/accord_fixture.gd")
const Rules = preload("res://scripts/quests/accord_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, id: String) -> Button: return game.screen.find_child(id, true, false) as Button
func settle() -> void:
	await process_frame
	await process_frame
func freeze(game: Node) -> void:
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
	await settle()
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
	freeze(game)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "real preceding campaign and aftermath unlock present-path conversation")
	session.gathered.erase("rescue:rested")
	session.region = "crossing"
	session.arrival = Vector2(600, 600)
	game._build_world()
	freeze(game)
	await speak(game, "mentor")
	check(session.Store.validate(session.snapshot(Vector2(600, 600))) and button(game, "accord_affirm") == null and button(game, "rescue_rest") != null, "actual valid pre-aftermath visit cannot skip directly to the new node")
	button(game, "rescue_rest").pressed.emit()
	check(Rules.ready(session.gathered, session.opened), "actual preceding conversation unlocks later continuation without a fabricated flag")
	await speak(game, "mentor")
	check(button(game, "accord_affirm") != null and button(game, "accord_return_info") == null, "ordinary human receives meaningful own continuation without transformation menu")
	button(game, "accord_affirm").pressed.emit()
	check(button(game, "accord_confirm_affirm") != null and Rules.recorded(session.gathered) == "", "personal statement is reviewed before it is saved")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.accord_action("affirm") and Rules.recorded(session.gathered) == "", "failed identity write cannot fabricate a recorded statement")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.recorded(session.gathered) == "human" and session.nature.kind == "human", "keyboard confirms current ordinary path without changing nature")
	await portal(game, Vector2(1800, 500))
	await portal(game, Vector2(1750, 1120))
	await portal(game, Vector2(850, 1120))
	check(session.region == "rotunda" and game.world.npcs.witness.visible and game.world.npcs.crafter.visible and game.world.npcs.steward.visible, "real old transitions reach living actual participants")
	await speak(game, "steward")
	check(button(game, "accord_accept") != null, "actual participant offers next common conversation after statement")
	await enter()
	check("accord:accepted" in session.gathered, "keyboard accepts separate common step")
	game.world.player.position = game.world.definition.junction_sites.table
	check(not game.world.can_accord("community"), "physical table cannot replace listening to real participants")
	for role in ["witness", "crafter"]:
		await speak(game, role)
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.accord_action("hear_" + role) and "accord:heard:" + role not in session.gathered, "failed conversation record cannot satisfy the next decision")
		DirAccess.remove_absolute("user://save.json.tmp")
		await enter()
		check("accord:heard:" + role in session.gathered, "each participant is genuinely heard through keyboard interaction")
	game.resume()
	game.world.player.position = game.world.definition.junction_sites.table
	game.world.interact()
	for choice in Rules.CHOICES: check(button(game, "accord_" + choice) != null, "ordinary body has actual access to each world outcome: " + choice)
	var xp: int = session.xp
	var health: float = game.world.player.health
	button(game, "accord_renewal").pressed.emit()
	check(button(game, "accord_confirm_renewal") != null and Rules.outcome(session.opened) == "" and session.xp == xp, "final choice shows consequences before irreversible commitment")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.accord_action("renewal") and Rules.outcome(session.opened) == "" and session.xp == xp, "failed decision grants no outcome or experience")
	DirAccess.remove_absolute("user://save.json.tmp")
	session.inventory.coin = 999
	await enter()
	check(Rules.outcome(session.opened) == "renewal" and session.xp == xp + 100 and session.inventory.coin == 999 and game.world.player.health == health, "keyboard decision commits one full-wallet-safe reward without healing or forced nature")
	var epilogue: Label = game.screen.find_child("accord_epilogue", true, false)
	check(epilogue != null and epilogue.text == game.tr("ACCORD_EPILOGUE_RENEWAL"), "actual ending panel matches recorded choice")
	await enter()
	check(game.current_screen == "game" and not paused and not game.world.accord_action("release"), "keyboard continues exploration and cannot replace final outcome")
	check(session.load_saved() and Rules.outcome(session.opened) == "renewal", "actual JSON loads unique outcome and old region history together")
	game._build_world()
	freeze(game)
	game.resume()
	check(game.world.npcs.witness.visible and game.world.npcs.crafter.visible and game.world.npcs.steward.visible, "ending keeps existing participants alive and available")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and Rules.outcome(session.opened) == "renewal" and session.xp == xp + 100, "death checkpoint keeps chosen future with exactly one reward")
	print("Accord gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
