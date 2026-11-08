extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/accord_fixture.gd")
const Rules = preload("res://scripts/quests/accord_rules.gd")
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
	session.arrival = Vector2(600, 600) if region == "crossing" else Vector2(620, 650)
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
func cure(session: Node, kind: String) -> void:
	var events := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
	for event in events: check(session.nature_event(event, Vector2(600, 600), {"health": 64.0, "stamina": 100.0, "mana": 90.0}) if kind == "vampire" else session.pack_event(event, Vector2(600, 600), {"health": 64.0, "stamina": 100.0, "mana": 90.0}), "real separate human return keeps agreement history valid")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.ready(session, kind, "private", "release"), "distinct real regional/common histories reach the later conversation")
		await build(game, session, "crossing")
		await speak(game, "mentor", "honest" if kind == "vampire" else "pack_word")
		var identity: Label = game.screen.find_child("accord_identity", true, false)
		check(identity != null and identity.text == game.tr("ACCORD_IDENTITY_" + kind.to_upper()) and Dialogue.memory(session.gathered, "mentor", kind) != "", "actual special-path conversation differs and retains a genuine personal reply")
		button(game, "accord_return_info").pressed.emit()
		check(session.nature.kind == kind and Rules.recorded(session.gathered) == "", "return information opens existing system without free nature switch or auto affirmation")
		await speak(game, "mentor")
		button(game, "accord_affirm").pressed.emit()
		button(game, "accord_confirm_affirm").pressed.emit()
		await build(game, session, "rotunda")
		await speak(game, "steward", "honest" if kind == "vampire" else "pack_word")
		check(game.screen.find_child("joint_previous_release", true, false) != null, "assembly still acknowledges actual earlier regional outcome")
		button(game, "accord_accept").pressed.emit()
		for role in ["witness", "crafter"]:
			await speak(game, role, "honest" if kind == "vampire" else "pack_word")
			button(game, "accord_hear_" + role).pressed.emit()
		check(Rules.stage(session.gathered, session.opened) == 3, "each special nature can hear both real participants without forced cure")
		await cure(session, kind)
		check(session.load_saved() and Rules.recorded(session.gathered) == kind and Rules.HEARD.all(func(flag): return flag in session.gathered), "actual load retains old recorded path as history without invalidating heard voices")
		await build(game, session, "rotunda")
		game.world.player.position = game.world.definition.junction_sites.table
		check(not game.world.can_accord("release"), "changed current nature must be reaffirmed before permanent outcome")
		await build(game, session, "crossing")
		await speak(game, "mentor", "explain" if kind == "vampire" else "remember_pack")
		identity = game.screen.find_child("accord_identity", true, false)
		check(identity != null and identity.text == game.tr("ACCORD_IDENTITY_RETURNED" if kind == "vampire" else "ACCORD_IDENTITY_WILD_RETURNED") and button(game, "accord_return_info") == null, "each changed-human history has its own current statement and no forced second return")
		button(game, "accord_affirm").pressed.emit()
		button(game, "accord_confirm_affirm").pressed.emit()
		check(Dialogue.memory(session.gathered, "mentor", kind) != "" and Dialogue.memory(session.gathered, "mentor", "returned" if kind == "vampire" else "wild_returned") != "", "past and changed-human personal memories survive reaffirmation")
		await build(game, session, "rotunda")
		game.world.player.position = game.world.definition.junction_sites.table
		game.world.interact()
		var choice := "release" if kind == "vampire" else "community"
		button(game, "accord_" + choice).pressed.emit()
		button(game, "accord_confirm_" + choice).pressed.emit()
		var epilogue: Label = game.screen.find_child("accord_epilogue", true, false)
		check(epilogue != null and epilogue.text == game.tr("ACCORD_EPILOGUE_" + choice.to_upper()) and session.load_saved() and Rules.outcome(session.opened) == choice, "each returned-human route reaches a different actual retained outcome")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.accepted(session, kind) and session.accord_event("renewal", Vector2(620, 650), {"health": 64.0, "stamina": 100.0, "mana": 90.0}), "uncured special nature can also make the complete final decision")
		await cure(session, kind)
		check(session.load_saved() and Rules.outcome(session.opened) == "renewal" and session.nature.kind == "human", "post-decision human return preserves fixed world without retroactive identity invalidation")
	check(Fixture.ready(session, "vampire"), "human-oath fixture has actual optional study history")
	session.nature.kind = "human"
	session.nature.history = []
	session.nature.blood = 100.0
	session.nature.gift = "oath"
	check(session.Store.validate(session.snapshot(Vector2(600, 600))), "human oath is a valid distinct non-transforming history")
	await build(game, session, "crossing")
	await speak(game, "mentor", "pledge")
	check(game.screen.find_child("accord_identity", true, false).text == game.tr("ACCORD_IDENTITY_OATH") and Dialogue.memory(session.gathered, "mentor", "oath") == "pledge", "human oath gets its own actual statement and personal response")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		var kind := "werewolf" if form in ["wolf", "hybrid"] else "vampire"
		check(Fixture.ready(session, kind), "temporary-body continuation starts from actual lived history")
		if kind == "vampire":
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		elif form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		await build(game, session, "crossing")
		game.world.player.position = game.world.npcs.mentor.position
		check(game.world.player.shift_form(form), "real available temporary shape is entered")
		game.world.interact()
		check(game.screen.find_child("nature_reaction", true, false).text == game.tr("DIALOGUE_MENTOR_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "each temporary shape gets its own prior mentor reaction and accessible return")
		button(game, "dialogue_return_form").pressed.emit()
		check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary body never locks the path discussion")
	print("Accord history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
