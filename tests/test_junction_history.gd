extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/junction_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Rules = preload("res://scripts/quests/junction_rules.gd")
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
	session.arrival = Vector2(780, 700) if region == "workshop" else Vector2(1000, 480)
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
func speak(game: Node, role: String, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func interact_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		var method := "blood" if kind == "vampire" else "scent"
		var forest := "watch" if kind == "vampire" else "commons"
		var city := "release" if kind == "vampire" else "shared"
		check(Fixture.ready(session, kind, method, forest, city), "different regional methods/outcomes form valid historical common-node fixtures")
		await build(game, session, "workshop")
		await speak(game, "mentor", "honest" if kind == "vampire" else "pack_word")
		check(Dialogue.memory(session.gathered, "mentor", kind) != "", "invitation preserves existing mentor's personal nature conversation")
		button(game, "joint_accept").pressed.emit()
		await build(game, session, "rotunda")
		await speak(game, "steward", "honest" if kind == "vampire" else "pack_word")
		for variant in [method, forest, city]: check(game.screen.find_child("joint_previous_" + variant, true, false) != null, "common conversation responds to each actual earlier method or decision")
		check(Dialogue.memory(session.gathered, "steward", kind) != "", "new important character has a distinct one-time personal memory")
		button(game, "joint_hear").pressed.emit()
		game.world.player.position = game.world.definition.junction_sites.table
		game.world.interact()
		button(game, "joint_map").pressed.emit()
		game.world.player.position = game.world.definition.junction_sites.console
		game.world.interact()
		var player = game.world.player
		var mana: float = player.mana
		player.magic_cooldown = 0.1
		check(not game.world.junction_action("aegis") and player.mana == mana, "external spell preparation respects existing combat readiness")
		player.magic_cooldown = 0
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.junction_action("aegis") and player.mana == mana and player.shield_recharge == 0 and not game.world.junction_objects.console.isolated, "failed magic isolation grants neither preparation nor resource/timer charge")
		DirAccess.remove_absolute("user://save.json.tmp")
		button(game, "joint_aegis").pressed.emit()
		check(player.mana == mana - 28 and player.magic_cooldown == 0.8 and player.shield_recharge == 10 and player.shield_strength == 0 and "junction:isolation:aegis" in session.gathered, "actual external magic applies profile cost/cooldown/recharge without free hero protection")
		game.world.set_process(true)
		await interact_key(true)
		await create_timer(0.15).timeout
		check(game.world.junction_objects.console.active, "each current nature starts actual prepared measurement in ordinary body")
		game.show_journal()
		player.shift_form()
		player.shift_form()
		check(not game.world.junction_objects.console.active and game.world.junction_objects.console.progress == 0 and game.world.junction_objects.console.isolated, "shape change and return within the same paused frame cannot retain interrupted measurement")
		game.resume()
		await interact_key(false)
		freeze(game)
		var vitals: Dictionary = game.world.player_vitals()
		var cure := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in cure: check(session.nature_event(event, player.position, vitals) if kind == "vampire" else session.pack_event(event, player.position, vitals), "independent human return remains compatible with persistent preparation")
		player.mana = session.vitals.mana
		await speak(game, "steward", "explain" if kind == "vampire" else "remember_pack")
		check(Dialogue.memory(session.gathered, "steward", "returned" if kind == "vampire" else "wild_returned") != "" and Dialogue.memory(session.gathered, "steward", kind) != "", "new character retains separate personal replies before and after human return")
		game.resume()
		player.position = game.world.definition.junction_sites.console
		game.world.set_process(true)
		await interact_key(true)
		await create_timer(3.15).timeout
		await interact_key(false)
		freeze(game)
		check("junction:proof" in session.gathered and "junction:isolation:aegis" in session.gathered, "returned ordinary body completes actual held-input demonstration without repurchasing past magic preparation")
		await speak(game, "steward")
		button(game, "joint_explain").pressed.emit()
		await speak(game, "mentor", "explain" if kind == "vampire" else "remember_pack")
		check(Dialogue.memory(session.gathered, "mentor", kind) != "" and Dialogue.memory(session.gathered, "mentor", "returned" if kind == "vampire" else "wild_returned") != "", "relocated mentor preserves earlier and changed-human relationship phases")
		var xp: int = session.xp
		button(game, "joint_private").pressed.emit()
		check(button(game, "joint_confirm_private") != null and session.xp == xp, "other information-handling choice is reviewed before committing")
		await enter()
		check(session.xp == xp + 80 and Rules.CHOICES[1] in session.gathered and Rules.stage(session.gathered, session.opened) == 4, "changed-human history reaches distinct actual final information choice")
		check(session.load_saved() and "junction:isolation:aegis" in session.gathered and Rules.CHOICES[1] in session.gathered and session.nature.kind == "human", "proof preparation outcome and changed nature reload together from real disk")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		if form in ["wolf", "hybrid"]: PackFixture.wolf(session, form == "hybrid")
		else:
			NatureFixture.vampire(session)
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		await build(game, session, "rotunda")
		game.world.player.position = game.world.npcs.steward.position
		game.world.player.shift_form(form)
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_STEWARD_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "new character distinguishes each temporary shape and provides accessible return")
		button(game, "dialogue_return_form").pressed.emit()
		check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary shape cannot lock the common participant conversation")
	NatureFixture.vampire(session)
	session.nature.kind = "human"
	session.nature.blood = 100.0
	session.nature.history = []
	session.nature.gift = "oath"
	await build(game, session, "rotunda")
	game.world.player.position = game.world.npcs.steward.position
	game.world.interact()
	check(button(game, "dialogue_pledge") != null and button(game, "dialogue_honest") == null, "human commitment has its own personal response")
	var trust: int = session.world_state.reputation.wardens
	button(game, "dialogue_pledge").pressed.emit()
	check(session.world_state.reputation.wardens == trust + 1 and not game.world.dialogue_action("steward", "pledge"), "human promise gains one actual relation without repeated farming")
	check(session.load_saved() and Dialogue.memory(session.gathered, "steward", "oath") == "pledge", "human personal promise persists on disk")
	print("Junction history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
