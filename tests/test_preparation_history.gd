extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/preparation_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Rules = preload("res://scripts/quests/preparation_rules.gd")
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
func build(game: Node, session: Node, region: String) -> void:
	session.region = region
	session.arrival = Vector2(1580, 650) if region == "rotunda" else Vector2(240, 650)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.resume()
	await settle()
func speak(game: Node, role: String, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
	await settle()
func input_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
func posts(game: Node) -> void:
	for role in ["witness", "crafter"]: game.world.npcs[role].position = Rules.post(root.get_node("Session").gathered, role)
func walk_all(game: Node) -> void:
	game.world.player.position = Rules.CONTROLS.gate
	check(game.world.start_preparation(), "changed-human preparation starts at the actual gate")
	game.world.player.set_physics_process(true)
	await input_key(KEY_A, true)
	var frames := 0
	while game.world.player.position.x > 525 and frames < 900:
		await physics_frame
		frames += 1
	await input_key(KEY_A, false)
	game.world.player.set_physics_process(false)
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.ready(session, kind, "private", "release"), "distinct private/release history reaches preparation for each voluntary nature")
		var answer := "honest" if kind == "vampire" else "pack_word"
		var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
		for pair in [["terrace", "witness"], ["velshof", "crafter"]]:
			await build(game, session, pair[0])
			await speak(game, pair[1], answer)
			check(Dialogue.memory(session.gathered, pair[1], kind) == answer, "existing participant's real earlier personal reply is saved before moving")
		check(session.preparation_event("accept", Vector2(1000, 480), vitals), "separate preparation acceptance follows previous personal history")
		for pair in [["terrace", "witness"], ["velshof", "crafter"]]:
			await build(game, session, pair[0])
			await speak(game, pair[1])
			check(game.screen.find_child("joint_previous_release", true, false) != null, "recruitment conversation retains the actual earlier city decision")
			button(game, "prep_invite_" + pair[1]).pressed.emit()
			button(game, "prep_confirm_invite_" + pair[1]).pressed.emit()
			check("prep:consent:" + pair[1] in session.gathered and not game.world.npcs[pair[1]].visible, "each nature obtains actual reviewed consent and relocation")
		for event in ["layout_city", "tune_north", "tune_north", "tune_south", "tune_south"]:
			check(session.preparation_event(event, Vector2(1580, 650), vitals), "alternate regional history supports the other distribution and both changed settings")
		await build(game, session, "rotunda")
		posts(game)
		check(Rules.angle(session.gathered, "north") == 2 and Rules.angle(session.gathered, "south") == 2 and game.world.can_rehearse(), "actual private/release settings and reversed assignments enable the physical trial")
		for role in ["witness", "crafter"]:
			await speak(game, role)
			check(Dialogue.memory(session.gathered, role, kind) == answer and not game.world.dialogue_action(role, answer), "relocation keeps earlier personal memory and prevents duplicated trust")
		game.resume()
		game.world.player.position = Rules.CONTROLS.gate
		check(game.world.start_preparation(), "each current nature can begin ordinary-body rehearsal")
		game.show_journal()
		game.world.player.shift_form()
		game.world.player.shift_form()
		check(not game.world.preparation_route.active and Rules.configured(session.gathered), "shape change and return in one paused frame cancel only transient trial")
		game.resume()
		var cure := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in cure: check(session.nature_event(event, game.world.player.position, game.world.player_vitals()) if kind == "vampire" else session.pack_event(event, game.world.player.position, game.world.player_vitals()), "separate voluntary return remains possible after recruiting and configuring")
		game.world.player.mana = session.vitals.mana
		for role in ["witness", "crafter"]:
			await speak(game, role, "explain" if kind == "vampire" else "remember_pack")
			check(Dialogue.memory(session.gathered, role, kind) == answer and Dialogue.memory(session.gathered, role, "returned" if kind == "vampire" else "wild_returned") != "", "both old and changed-human personal replies remain distinct after relocation")
		game.resume()
		await walk_all(game)
		check("prep:tested" in session.gathered and Rules.layout(session.gathered) == "city", "actual returned-human walking completes altered support setup without loss of consent")
		await speak(game, "mentor")
		button(game, "prep_report").pressed.emit()
		button(game, "prep_confirm_report").pressed.emit()
		check(session.load_saved() and session.nature.kind == "human" and Rules.REPORT in session.opened and Rules.angle(session.gathered, "south") == 2, "different preparation and returned nature persist together through actual disk load")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		var kind := "werewolf" if form in ["wolf", "hybrid"] else "vampire"
		check(Fixture.configured(session, kind), "temporary-shape conversation starts from genuine preparation")
		if kind == "vampire":
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		elif form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		await build(game, session, "rotunda")
		posts(game)
		for role in ["witness", "crafter"]:
			game.resume()
			game.world.player.position = game.world.npcs[role].position
			check(game.world.player.shift_form(form), "actual player adopts available temporary shape")
			game.world.interact()
			var reaction: Label = game.screen.find_child("nature_reaction", true, false)
			check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "each relocated participant retains their own reaction and accessible return for every shape")
			button(game, "dialogue_return_form").pressed.emit()
			check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "shape reaction never locks the shared preparation conversation")
	print("Preparation history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
