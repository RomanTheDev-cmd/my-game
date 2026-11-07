extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/city_fixture.gd")
const ForestFixture = preload("res://tests/support/forest_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Rules = preload("res://scripts/quests/city_rules.gd")
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
func speak(game: Node, role: String, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func site(game: Node, id: String) -> void:
	game.resume()
	game.world.player.position = game.world.definition.city_sites[id]
	game.world.interact()
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func build(game: Node, session: Node) -> void:
	session.region = "velshof"
	session.arrival = Vector2(500, 620)
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for kind in ["vampire", "werewolf"]:
		var report := "provision" if kind == "vampire" else "share"
		var forest := "watch" if kind == "vampire" else "commons"
		check(ForestFixture.ready(session, kind, true, report), "earlier lake report is a valid persistent history fixture")
		for event in ["accept", "work", "work", "work", forest]: check(session.forest_event(event, Vector2(410, 490), {"health": 64.0, "stamina": 100.0, "mana": 90.0}), "earlier forest result uses valid committed transitions")
		if kind == "werewolf":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		await build(game, session)
		for role in ["crafter", "archivist"]:
			await speak(game, role, "honest" if kind == "vampire" else "pack_word")
			check(game.screen.find_child("city_previous_" + report, true, false) != null and game.screen.find_child("city_previous_" + forest, true, false) != null, "both new NPC conversations remember distinct earlier regional outcomes")
			check(Dialogue.memory(session.gathered, role, kind) != "", "each city character commits its own nature-specific reply")
		await speak(game, "crafter")
		button(game, "city_accept").pressed.emit()
		for role in ["crafter", "archivist"]:
			await speak(game, role)
			button(game, "city_hear_" + role).pressed.emit()
		await site(game, "board")
		button(game, "city_draft_shared").pressed.emit()
		if kind == "vampire":
			await speak(game, "crafter")
			button(game, "city_supply").pressed.emit()
			await enter()
			await site(game, "archive")
			var reserve: float = session.nature.blood
			var mana: float = game.world.player.mana
			button(game, "city_memory").pressed.emit()
			check(button(game, "city_confirm_memory") != null and session.nature.blood == reserve, "own-blood confirmation is explicitly reviewed without charging on opening")
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not game.world.city_action("memory") and session.nature.blood == reserve and game.world.player.mana == mana and "city:memory" not in session.gathered, "failed supernatural guarantee consumes no blood/magic and grants no evidence")
			DirAccess.remove_absolute("user://save.json.tmp")
			await enter()
			check(session.nature.blood == reserve - 20 and game.world.player.mana == mana - 10 and "city:memory" in session.gathered and "city:copy" not in session.gathered, "confirmed blood route uses its distinct actual resources and scope")
		else:
			await site(game, "press")
			game.resume()
			var reserve: float = session.nature.resolve
			check(game.world.player.shift_form("hybrid") and session.nature.resolve == reserve - 20, "mastered hybrid retains its normal transformation price")
			game.world.interact()
			reserve = session.nature.resolve
			var stamina: float = game.world.player.stamina
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not game.world.city_action("strength") and session.nature.resolve == reserve and not game.world.city_objects.press.worked, "failed hybrid work consumes no reserve and changes no press")
			DirAccess.remove_absolute("user://save.json.tmp")
			button(game, "city_strength").pressed.emit()
			check(session.nature.resolve == reserve - 18 and game.world.player.stamina == stamina and game.world.city_objects.press.worked, "actual hybrid holds the press with distinct cost and visible repaired result")
			game.world.player.shift_form()
			await site(game, "archive")
			button(game, "city_copy").pressed.emit()
		var vitals: Dictionary = game.world.player_vitals()
		var cure := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
		for event in cure: check(session.nature_event(event, game.world.player.position, vitals) if kind == "vampire" else session.pack_event(event, game.world.player.position, vitals), "separate return remains compatible with already performed city guarantee")
		game.world.player.mana = session.vitals.mana
		for role in ["crafter", "archivist"]:
			await speak(game, role, "explain" if kind == "vampire" else "remember_pack")
			check(Dialogue.memory(session.gathered, role, "returned" if kind == "vampire" else "wild_returned") != "" and Dialogue.memory(session.gathered, role, kind) != "", "city characters retain separate replies before and after human return")
			check(button(game, "city_sign_" + role) != null and not button(game, "city_sign_" + role).disabled, "past supernatural help remains an accepted guarantee after return")
			button(game, "city_sign_" + role).pressed.emit()
		await site(game, "board")
		var xp: int = session.xp
		button(game, "city_seal").pressed.emit()
		await enter()
		game.world._update_npcs()
		check(session.xp == xp + 100 and "city:outcome:shared" in session.gathered and game.world.npcs.crafter.destination == Vector2(780, 680) and game.world.npcs.archivist.destination == Vector2(930, 680), "shared accepted terms give one reward and real distinct joint meeting destinations")
		check(session.load_saved() and Rules.stage(session.gathered, session.opened) == 3 and ("city:memory" in session.gathered if kind == "vampire" else "city:work:strength" in session.gathered), "real JSON load preserves final agreement special work and changed human history together")
	for role in ["crafter", "archivist"]:
		for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
			if form in ["wolf", "hybrid"]: PackFixture.wolf(session, form == "hybrid")
			else:
				NatureFixture.vampire(session)
				session.nature.gift = "blood_mist"
				session.gathered.append_array(["flight:bat", "flight:mist"])
				session.opened.append("waterworks_flight")
			await build(game, session)
			game.world.player.position = game.world.npcs[role].position
			game.world.player.shift_form(form)
			game.world.interact()
			var reaction: Label = game.screen.find_child("nature_reaction", true, false)
			check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "both city characters distinguish all shapes with an accessible return action")
			button(game, "dialogue_return_form").pressed.emit()
			check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary shape cannot lock an important city conversation")
	for role in ["crafter", "archivist"]:
		NatureFixture.vampire(session)
		session.nature.kind = "human"
		session.nature.blood = 100.0
		session.nature.history = []
		session.nature.gift = "oath"
		await build(game, session)
		game.world.player.position = game.world.npcs[role].position
		game.world.interact()
		check(button(game, "dialogue_pledge") != null and button(game, "dialogue_honest") == null, "human commitment has distinct reply choices for each city character")
		var group: String = Dialogue.GROUPS[role]
		var trust: int = session.world_state.reputation[group]
		button(game, "dialogue_pledge").pressed.emit()
		check(session.world_state.reputation[group] == trust + 1 and not game.world.dialogue_action(role, "pledge"), "human reply changes one actual relationship once")
		check(session.load_saved() and Dialogue.memory(session.gathered, role, "oath") == "pledge", "human promise to each city character survives real JSON load")
	print("City history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
