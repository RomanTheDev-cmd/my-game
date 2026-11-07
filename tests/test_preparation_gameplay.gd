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
func button(game: Node, id: String) -> Button: return game.screen.find_child(id, true, false) as Button
func settle() -> void:
	await process_frame
	await process_frame
func build(game: Node, session: Node, region: String, point: Vector2 = Vector2(240, 650)) -> void:
	session.region = region
	session.arrival = point
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	await settle()
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
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
func walk_to(game: Node, x: float) -> bool:
	game.world.player.set_physics_process(true)
	await key(KEY_A, true)
	var frames := 0
	while game.world.player.position.x > x + 6 and frames < 900:
		await physics_frame
		frames += 1
	await key(KEY_A, false)
	game.world.player.set_physics_process(false)
	await settle()
	return absf(game.world.player.position.x - x) < 26
func wait_posts(game: Node) -> bool:
	var frames := 0
	while not game.world.can_rehearse() and frames < 1100:
		await physics_frame
		frames += 1
	return game.world.can_rehearse()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "actual common result unlocks the next independent preparation")
	await build(game, session, "rotunda")
	check(not game.world.npcs.witness.visible and not game.world.npcs.crafter.visible, "uninvited characters are not duplicated in the shared location")
	await speak(game, "steward")
	check(button(game, "prep_accept") != null, "actual existing participant offers preparation only after the common result")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.preparation_action("accept") and "prep:accepted" not in session.gathered, "failed acceptance does not start an unsaved preparation")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check("prep:accepted" in session.gathered, "keyboard accepts preparation as a separate step")
	for pair in [["terrace", "witness"], ["velshof", "crafter"]]:
		await build(game, session, pair[0])
		await speak(game, pair[1])
		var xp: int = session.xp
		button(game, "prep_invite_" + pair[1]).pressed.emit()
		check(button(game, "prep_confirm_invite_" + pair[1]) != null and "prep:consent:" + pair[1] not in session.gathered, "each real participant's relocation is reviewed before consent")
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.preparation_action("invite_" + pair[1]) and game.world.npcs[pair[1]].visible, "disk refusal cannot remove the original participant")
		DirAccess.remove_absolute("user://save.json.tmp")
		await enter()
		check("prep:consent:" + pair[1] in session.gathered and not game.world.npcs[pair[1]].visible and session.xp == xp, "confirmed consent moves one character without early reward")
	await build(game, session, "rotunda")
	check(game.world.npcs.witness.visible and game.world.npcs.crafter.visible and game.world.player.health == 64, "both distinct participants meet in the real room without healing the hero")
	for point in Rules.CONTROLS.values() + Rules.POSTS.values() + Rules.ROUTE:
		var path: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		var clear := not path.is_empty()
		var previous := Vector2(240, 650)
		for step in path:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "ordinary body reaches every actual control, post and route marker")
	game.world.player.position = game.world.definition.junction_sites.table
	game.world.interact()
	await enter()
	check(Rules.layout(session.gathered) == "lake" and not game.world.can_rehearse(), "keyboard assignment sets real destinations; distant witnesses are not instantly ready")
	var start_position: Vector2 = game.world.npcs.witness.position
	await create_timer(0.3).timeout
	check(game.world.npcs.witness.position.distance_to(start_position) > 5 and game.world.npcs.witness.position.distance_to(Rules.POSTS.north) > 24, "assigned witness actually walks instead of teleporting to a post")
	game.world.set_process(true)
	for side in ["north", "south"]:
		game.world.player.position = Rules.CONTROLS[side]
		await key(KEY_E, true)
		await key(KEY_E, false)
		check(Rules.angle(session.gathered, side) == 1 and game.world.player.health == 64, "physical E turns and saves the actual support without free healing")
	check(await wait_posts(game), "both participants reach and hold their actual navigation posts")
	game.world.player.position = Rules.CONTROLS.finish
	check(not game.world.preparation_action("prove"), "standing at exit cannot bypass the actual ordered trial")
	game.world.player.position = Rules.CONTROLS.gate
	game.world.interact()
	check(button(game, "prep_start") != null and not button(game, "prep_start").disabled, "gate exposes the real route trial only when both posts and settings are ready")
	await enter()
	check(game.world.preparation_route.active, "keyboard starts a visible transient route without granting readiness")
	check(await walk_to(game, 1420) and game.world.preparation_route.step == 1, "real keyboard movement reaches the first ordered ring")
	game.show_journal()
	await create_timer(0.15).timeout
	check(game.world.preparation_route.step == 1 and game.world.preparation_route.active, "pause cannot manufacture further walked checkpoints")
	game.resume()
	game.world.player.set_physics_process(true)
	await key(KEY_J, true)
	await key(KEY_J, false)
	await settle()
	check(not game.world.preparation_route.active and game.world.preparation_route.step == 0 and Rules.configured(session.gathered), "actual attack interrupts the rehearsal but retains consents, plan and tuning")
	await create_timer(0.25).timeout
	game.world.player.set_physics_process(false)
	game.world.player.position = Rules.CONTROLS.gate
	check(game.world.start_preparation(), "same prepared team can retry without repeated consent")
	check(await walk_to(game, 1420), "second real rehearsal reaches the first ring")
	game.world.save_safe()
	check(session.load_saved(), "partial-route save reloads from real disk")
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	await settle()
	check(not game.world.preparation_route.active and game.world.preparation_route.step == 0 and Rules.configured(session.gathered) and "prep:tested" not in session.gathered, "loading retains paid preparation and actual positions but never upgrades transient route progress")
	check(game.world.can_rehearse(), "saved participants resume holding the correct posts")
	game.world.player.position = Rules.CONTROLS.gate
	check(game.world.start_preparation(), "loaded preparation starts the actual trial again")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	for point in Rules.ROUTE: check(await walk_to(game, point.x), "normal physical walking reaches the next ordered checkpoint")
	check(game.world.preparation_route.pending and not game.world.preparation_route.active and "prep:tested" not in session.gathered, "failed proof write after actual full route remains a retry, not a completed result")
	game.update_hud()
	check(game.prompt.text == game.tr("PREP_RETRY_PROMPT") and game.quest_label.text == game.tr("PREP_PENDING_HUD"), "pending route has persistent matching keyboard and quest retry instructions")
	DirAccess.remove_absolute("user://save.json.tmp")
	var xp_before: int = session.xp
	game.world.set_process(true)
	await key(KEY_E, true)
	await key(KEY_E, false)
	check("prep:tested" in session.gathered and not game.world.preparation_route.pending and session.xp == xp_before, "actual E records the completed route once without granting the final reward early")
	game.world.set_process(false)
	await speak(game, "mentor")
	button(game, "prep_report").pressed.emit()
	check(button(game, "prep_confirm_report") != null and Rules.REPORT not in session.opened, "readiness is separately reviewed after the physical trial")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.preparation_action("report") and session.xp == xp_before and Rules.REPORT not in session.opened, "failed readiness report cannot pay experience or complete the episode")
	DirAccess.remove_absolute("user://save.json.tmp")
	session.inventory.coin = 999
	await enter()
	check(Rules.REPORT in session.opened and session.xp == xp_before + 60 and session.inventory.coin == 999, "confirmed readiness pays once even with a full wallet")
	check(not game.world.preparation_action("report") and session.load_saved() and Rules.REPORT in session.opened, "readiness survives real load and cannot be farmed")
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	await settle()
	check(game.world.npcs.witness.visible and game.world.npcs.crafter.visible and game.world.npcs.mentor.visible, "completed preparation keeps every important participant present and alive")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and Rules.REPORT in session.opened and session.xp == xp_before + 60, "death checkpoint keeps preparation and does not duplicate its reward")
	print("Preparation gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
