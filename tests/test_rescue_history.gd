extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/rescue_fixture.gd")
const Rules = preload("res://scripts/quests/rescue_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
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
func build(game: Node, session: Node, region: String) -> void:
	session.region = region
	session.arrival = Vector2(1440, 650) if region == "underhall" else Vector2(600, 600)
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
func speak(game: Node, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
	await settle()
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
func cure(session: Node, kind: String, point: Vector2, vitals: Dictionary) -> void:
	var events := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
	for event in events: check(session.nature_event(event, point, vitals) if kind == "vampire" else session.pack_event(event, point, vitals), "genuine separate return remains possible with partial special help")
func walk_out(game: Node) -> void:
	game.resume()
	game.world.player.position = Vector2(1380, 650)
	game.world.set_process(true)
	game.world.npcs.mentor.set_physics_process(true)
	game.world.player.set_physics_process(true)
	await key(KEY_K, true)
	await key(KEY_A, true)
	var frames := 0
	while game.world.player.position.x > 280 and frames < 1800:
		await physics_frame
		frames += 1
	await key(KEY_A, false)
	await key(KEY_K, false)
	freeze(game)
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.ready(session, kind, "private", "release"), "distinct prior choices and actual nature unlock the same prepared episode")
		await build(game, session, "rotunda")
		await speak(game, "honest" if kind == "vampire" else "pack_word")
		check(Dialogue.memory(session.gathered, "mentor", kind) != "", "earlier personal answer is genuinely saved before new relocation")
		button(game, "rescue_accept").pressed.emit()
		await build(game, session, "underhall")
		await speak(game)
		check(game.screen.find_child("joint_previous_release", true, false) != null, "actual conversation acknowledges previous regional outcome")
		var mode := "blood" if kind == "vampire" else "scent"
		button(game, "rescue_" + mode).pressed.emit()
		check(button(game, "rescue_confirm_" + mode) != null and Rules.method(session.gathered) == "", "each special approach is separately explained/reviewed before commitment")
		var blood: float = session.nature.blood
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.rescue_action(mode) and session.nature.blood == blood and Rules.method(session.gathered) == "", "failed special choice grants no support or hidden nature-resource charge")
		DirAccess.remove_absolute("user://save.json.tmp")
		button(game, "rescue_confirm_" + mode).pressed.emit()
		check(Rules.method(session.gathered) == mode and (session.nature.blood == blood - 20 if kind == "vampire" else session.nature.blood == blood), "actual reviewed method pays only its advertised nature cost")
		if kind == "vampire":
			session.world_state.minutes = 1.5
			game.world.player.position = Vector2(980, 400)
			check(game.world.rescue_engine.phase("north") == 2 and game.world.rescue_engine.phase("south") == 2, "paid blood assistance genuinely stabilizes both real pulse strips")
			var stamina: float = game.world.player.stamina
			check(game.world.rescue_action("manual_north") and game.world.player.stamina == stamina - 10, "stabilized ordinary action has actual reduced effort")
		else:
			game.world.player.position = Vector2(980, 400)
			check(game.world.player.shift_form("wolf") and game.world.player.can_track(), "actual available wolf form supplies real tracking for the special approach")
			game.world.player.facing = Vector2.UP
			game.world.player.set_physics_process(true)
			await key(KEY_J, true)
			await key(KEY_J, false)
			check(Rules.cut(session.gathered, "north") == "", "actual directed attack facing away cannot cut the nearby connection")
			await create_timer(0.5).timeout
			game.world.player.facing = Vector2.DOWN
			var resolve: float = session.nature.resolve
			DirAccess.make_dir_absolute("user://save.json.tmp")
			await key(KEY_J, true)
			await key(KEY_J, false)
			check(Rules.cut(session.gathered, "north") == "" and session.nature.resolve == resolve, "failed real claw record cannot charge resolve or change support")
			DirAccess.remove_absolute("user://save.json.tmp")
			await create_timer(0.5).timeout
			await key(KEY_J, true)
			await key(KEY_J, false)
			freeze(game)
			check(Rules.cut(session.gathered, "north") == "claw" and session.nature.resolve == resolve - 12, "real close J strike uses tracking approach and actual12 resolve")
			game.world.player.shift_form()
		await cure(session, kind, game.world.player.position, game.world.player_vitals())
		check(session.nature.kind == "human" and Rules.cut(session.gathered, "north") != "" and Rules.method(session.gathered) == mode, "human return retains real partial support and its historical approach")
		await speak(game, "explain" if kind == "vampire" else "remember_pack")
		check(Dialogue.memory(session.gathered, "mentor", kind) != "" and Dialogue.memory(session.gathered, "mentor", "returned" if kind == "vampire" else "wild_returned") != "", "relocated participant keeps separate earlier and changed-human memories")
		game.resume()
		game.world.player.set_physics_process(true)
		await create_timer(0.25).timeout
		game.world.player.set_physics_process(false)
		session.world_state.minutes = 0
		game.world.player.position = Vector2(980, 840)
		check(game.world.rescue_action("manual_south"), "changed human can finish remaining support through useful ordinary action")
		await speak(game)
		button(game, "rescue_free").pressed.emit()
		button(game, "rescue_confirm_free").pressed.emit()
		await walk_out(game)
		check("rescue:safe" in session.gathered, "each changed-human history completes actual physical mentor navigation to exit")
		await build(game, session, "rotunda")
		await speak(game)
		button(game, "rescue_report").pressed.emit()
		button(game, "rescue_confirm_report").pressed.emit()
		await build(game, session, "crossing")
		await speak(game)
		var outcome: Label = game.screen.find_child("rescue_outcome", true, false)
		check(outcome != null and outcome.text == game.tr("RESCUE_AFTER_" + mode.to_upper()), "different actual method produces its own recovery conversation")
		if kind == "vampire":
			button(game, "rescue_release").pressed.emit()
			button(game, "rescue_confirm_release").pressed.emit()
		else: button(game, "rescue_rest").pressed.emit()
		check(session.load_saved() and session.nature.kind == "human" and "rescue:rested" in session.gathered and Rules.REPORT in session.opened, "real JSON preserves returned nature, historical help, outcome and aftermath")
	check(Fixture.selected(session, "vampire", "blood"), "live tether follow-up uses genuine voluntary blood history")
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["manual_north", "manual_south", "free", "safe", "report"]: check(session.rescue_event(event, Vector2(600, 600), vitals, true, false, true), "completed history fixture retains valid committed sequence")
	await build(game, session, "crossing")
	await speak(game)
	button(game, "rescue_keep").pressed.emit()
	check(button(game, "rescue_confirm_keep") != null and "rescue:boundary:keep" not in session.gathered, "retaining a voluntary link requires its own boundary review")
	button(game, "rescue_confirm_keep").pressed.emit()
	game.world.player.position = Vector2(450, 600)
	game.world._update_tracking()
	check(game.world.tracking_cue.visible and game.world.tracking_cue.direction.dot(Vector2.RIGHT) > 0.99, "retained vampire link gives actual nearby participant tracking rather than only descriptive text")
	await cure(session, "vampire", game.world.player.position, game.world.player_vitals())
	game.world._update_tracking()
	check(not game.world.tracking_cue.visible and "rescue:boundary:keep" in session.gathered and game.world.npcs.mentor.visible, "return removes active supernatural tracking without erasing friendship, past help or living participant")
	print("Rescue history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
