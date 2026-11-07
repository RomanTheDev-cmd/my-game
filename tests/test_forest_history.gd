extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/forest_fixture.gd")
const Rules = preload("res://scripts/quests/forest_rules.gd")
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
	game.world.npcs.roadkeeper.set_physics_process(false)
func speak(game: Node, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs.roadkeeper.position
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
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		var method := "blood" if kind == "vampire" else "scent"
		var previous_report := "provision" if kind == "vampire" else "share"
		check(Fixture.ready(session, kind, true, previous_report, method), "previous distinctive method and outcome are valid persisted campaign history")
		session.region = "woodroad"
		session.arrival = Vector2(430, 620)
		game._build_world()
		game.resume()
		await settle()
		freeze(game)
		await speak(game, "honest" if kind == "vampire" else "pack_word")
		var prior_method: Label = game.screen.find_child("forest_prior_method", true, false)
		var prior_report: Label = game.screen.find_child("forest_prior_report", true, false)
		check(prior_method != null and prior_method.text == game.tr("FOREST_LAKE_" + method.to_upper()) and prior_report != null and prior_report.text == game.tr("FOREST_LAKE_" + previous_report.to_upper()), "actual conversation distinguishes both earlier help and final choice")
		check(Dialogue.memory(session.gathered, "roadkeeper", kind) != "", "new companion records a nature-specific personal answer")
		button(game, "forest_accept").pressed.emit()
		await speak(game)
		var reserve: float = session.nature.blood if kind == "vampire" else session.nature.resolve
		if kind == "vampire":
			var mana: float = game.world.player.mana
			button(game, "forest_aid_blood").pressed.emit()
			check(button(game, "forest_confirm_aid_blood") != null and session.nature.blood == reserve, "explicit consent and limits are reviewed before blood aid")
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not game.world.forest_action("aid_blood") and session.nature.blood == reserve and game.world.player.mana == mana and not session.gathered.any(func(flag): return flag in Rules.AIDS), "failed aid write changes neither companion help nor actual blood/magic")
			DirAccess.remove_absolute("user://save.json.tmp")
			await enter()
			game.world._update_npcs()
			check(session.nature.blood == reserve - 15 and game.world.player.mana == mana - 10 and game.world.npcs.roadkeeper.walk_speed == 90, "confirmed aid applies actual finite price and the same useful pace as common orientation")
		else:
			game.resume()
			game.world.player.position = Rules.POINTS[0]
			game.world.npcs.roadkeeper.position = Rules.POINTS[0] - Vector2(70, 0)
			game.world.player.shift_form("wolf")
			check(session.nature.resolve == reserve - 10, "entering actual wolf form retains its separate normal transformation price")
			reserve = session.nature.resolve
			game.world.interact()
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not game.world.forest_action("howl") and session.nature.resolve == reserve and Rules.progress(session.gathered) == 0, "failed wolf work consumes no resolve and repairs no sign")
			DirAccess.remove_absolute("user://save.json.tmp")
			button(game, "forest_howl").pressed.emit()
			check(session.nature.resolve == reserve - 12 and Rules.progress(session.gathered) == 1 and game.world.forest_signs[0].repaired, "actual wolf body and voice complete a real sign with their distinct cost")
			game.world.player.shift_form()
		var vitals: Dictionary = game.world.player_vitals()
		var cure := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in cure:
			check(session.nature_event(event, game.world.player.position, vitals) if kind == "vampire" else session.pack_event(event, game.world.player.position, vitals), "separate valid return transition remains compatible with partial forest work")
		game.world.player.mana = session.vitals.mana
		await speak(game, "explain" if kind == "vampire" else "remember_pack")
		check(Dialogue.memory(session.gathered, "roadkeeper", "returned" if kind == "vampire" else "wild_returned") != "" and Dialogue.memory(session.gathered, "roadkeeper", kind) != "", "new companion remembers separate before/after-return answers together")
		game.resume()
		for i in range(Rules.progress(session.gathered), 3):
			game.world.player.position = Rules.POINTS[i]
			game.world.npcs.roadkeeper.position = Rules.POINTS[i] - Vector2(70, 0)
			game.world.interact()
			check(button(game, "forest_work") != null and not button(game, "forest_work").disabled, "returned hero retains reachable ordinary continuation at each remaining road point")
			button(game, "forest_work").pressed.emit()
		await speak(game)
		var xp: int = session.xp
		button(game, "forest_watch").pressed.emit()
		await enter()
		game.world._update_npcs()
		check(session.xp == xp + 90 and Rules.OUTCOMES[1] in session.gathered and game.world.npcs.roadkeeper.destination == Vector2(1640, 620) and game.world.forest_signs[0].outcome == "watch", "other confirmed outcome applies distinct visible marks and an actual destination beyond the opened gate")
		check(session.load_saved() and Rules.stage(session.gathered, session.opened) == 3 and (Rules.AIDS[1] in session.gathered if kind == "vampire" else "forest:step:0:howl" in session.gathered), "completed road reloads earlier special work and returned history without reset")
		await speak(game)
		var outcome_memory: Label = game.screen.find_child("forest_outcome_memory", true, false)
		check(outcome_memory != null and outcome_memory.text == game.tr("FOREST_DONE_WATCH"), "returned companion dialogue remembers the chosen lasting outcome")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		var kind := "werewolf" if form in ["wolf", "hybrid"] else "vampire"
		check(Fixture.ready(session, kind), "shape fixture retains ordinary campaign and save invariants")
		if form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		if form in ["bat", "mist"]:
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		session.region = "woodroad"
		session.arrival = Vector2(430, 620)
		game._build_world()
		game.resume()
		await settle()
		freeze(game)
		game.world.player.position = game.world.npcs.roadkeeper.position
		game.world.player.shift_form(form)
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_ROADKEEPER_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "new companion distinguishes temporary body and offers accessible return")
		button(game, "dialogue_return_form").pressed.emit()
		check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary body cannot lock the companion conversation")
	check(Fixture.ready(session, "vampire"), "human commitment dialogue fixture begins with valid earlier episode")
	session.nature.kind = "human"
	session.nature.blood = 100.0
	session.nature.history = []
	session.nature.gift = "oath"
	session.region = "woodroad"
	session.arrival = Vector2(430, 620)
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
	game.world.player.position = game.world.npcs.roadkeeper.position
	game.world.interact()
	check(button(game, "dialogue_pledge") != null and button(game, "dialogue_honest") == null, "ordinary human commitment has a distinct personal reply")
	var trust: int = session.world_state.reputation.tenders
	button(game, "dialogue_pledge").pressed.emit()
	check(Dialogue.memory(session.gathered, "roadkeeper", "oath") == "pledge" and session.world_state.reputation.tenders == trust + 1 and not game.world.dialogue_action("roadkeeper", "pledge"), "human promise creates one memory and cannot farm trust")
	button(game, "dialogue_continue").pressed.emit()
	var manual_memory: Label = game.screen.find_child("forest_prior_method", true, false)
	check(manual_memory != null and manual_memory.text == game.tr("FOREST_LAKE_MANUAL"), "ordinary earlier tool work has its own actual dialogue memory")
	check(session.load_saved() and Dialogue.memory(session.gathered, "roadkeeper", "oath") == "pledge", "human personal promise survives disk reload")
	print("Forest history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
