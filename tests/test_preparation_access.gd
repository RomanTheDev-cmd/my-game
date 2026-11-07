extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/preparation_fixture.gd")
const JunctionFixture = preload("res://tests/support/junction_fixture.gd")
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
func build(game: Node, session: Node, region: String = "rotunda") -> void:
	session.region = region
	session.arrival = Vector2(1580, 650) if region == "rotunda" else Vector2(240, 650)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.resume()
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(JunctionFixture.ready(session), "real three-region v9 exists before common-node completion")
	await build(game, session)
	game.world.player.position = game.world.npcs.steward.position
	game.world.interact()
	check(game.screen.find_child("prep_accept", true, false) == null and not game.world.can_preparation("accept") and not game.world.npcs.witness.visible, "three regional reports alone do not skip the common episode or recruit witnesses")
	check(Fixture.configured(session), "genuine common result and separate consents configure preparation")
	await build(game, session)
	for role in ["witness", "crafter"]: game.world.npcs[role].position = Rules.post(session.gathered, role)
	check(game.world.can_rehearse(), "correct real post positions permit rehearsal")
	game.world.npcs.witness.position += Vector2(80, 0)
	check(not game.world.can_rehearse() and not game.world.start_preparation(), "saved agreement is insufficient while a participant is physically away")
	game.world.npcs.witness.position = Rules.post(session.gathered, "witness")
	game.world.player.position = Rules.CONTROLS.finish
	check(not game.world.start_preparation(), "trial must be started at its actual entrance")
	game.world.player.position = Rules.CONTROLS.gate
	check(game.world.start_preparation(), "valid physical entrance starts rehearsal")
	game.world.player.position = Rules.CONTROLS.finish
	await settle()
	check(game.world.preparation_route.step == 0 and "prep:tested" not in session.gathered, "visiting the final ring first cannot bypass ordered checkpoints")
	game.world.player.position = Rules.ROUTE[0]
	await settle()
	check(game.world.preparation_route.step == 1, "first checkpoint alone advances only one route segment")
	game.world.player.position = game.world.definition.junction_sites.table
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.preparation_action("layout_city") and Rules.layout(session.gathered) == "lake" and game.world.preparation_route.active, "failed changed assignment preserves both prior plan and current trial")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(game.world.preparation_action("layout_city") and not game.world.preparation_route.active and Rules.layout(session.gathered) == "city", "successful reassignment cancels transient progress and sends participants to new posts")
	check(not game.world.can_rehearse(), "old positions cannot satisfy swapped assignments")
	for role in ["witness", "crafter"]: game.world.npcs[role].position = Rules.post(session.gathered, role)
	game.world.player.position = Rules.CONTROLS.gate
	check(game.world.start_preparation(), "reassigned team can restart after actually occupying new posts")
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.position = game.world.player.position + Vector2(100, 0)
	enemy.target = game.world.player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	await settle()
	check(not game.world.preparation_route.active and game.world.preparation_route.step == 0 and Rules.configured(session.gathered), "real threat interrupts only the rehearsal and keeps saved preparation")
	enemy.queue_free()
	await settle()
	check(game.world.start_preparation(), "safe team can start again after threat leaves")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await settle()
	check(session.region == "workshop" and Rules.configured(session.gathered), "actual exit keeps consents, distribution and tuning")
	game.world.player.set_physics_process(false)
	game.world.player.position = Vector2(850, 1120)
	game.world.interact()
	await settle()
	game.world.player.set_physics_process(false)
	check(session.region == "rotunda" and not game.world.preparation_route.active and game.world.preparation_route.step == 0 and Rules.layout(session.gathered) == "city", "actual return rebuilds an unproved trial rather than retaining a partial route")
	for pair in [["terrace", "witness"], ["velshof", "crafter"]]:
		await build(game, session, pair[0])
		check(not game.world.npcs[pair[1]].visible and not game.world.can_preparation("invite_" + pair[1]), "visited old region never duplicates an already relocated participant")
	print("Preparation access checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
