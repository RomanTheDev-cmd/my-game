extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Rules = preload("res://scripts/quests/campaign_rules.gd")
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
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func speak(game: Node, role: String, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
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
	for kind in ["vampire", "werewolf"]:
		if kind == "vampire": NatureFixture.vampire(session)
		else: PackFixture.wolf(session)
		session.region = "workshop"
		session.arrival = Vector2(780, 700)
		game._build_world()
		game.resume()
		await settle()
		freeze(game)
		var answer := "honest" if kind == "vampire" else "pack_word"
		await speak(game, "mentor", answer)
		check(Dialogue.memory(session.gathered, "mentor", kind) == answer, "new mentor records separate nature-specific personal answer")
		button(game, "story_greet").pressed.emit()
		await speak(game, "mentor")
		button(game, "story_accept").pressed.emit()
		await portal(game, Vector2(135, 650))
		await portal(game, Vector2(1750, 340))
		await speak(game, "witness", answer)
		check(Dialogue.memory(session.gathered, "witness", kind) == answer, "new witness records her own persistent answer")
		button(game, "story_hear").pressed.emit()
		if kind == "vampire":
			await speak(game, "witness")
			check(button(game, "story_consent") != null and "story:lake:consent" not in session.gathered, "blood approach exposes a separate explicit consent conversation")
			button(game, "story_consent").pressed.emit()
		game.world.player.position = game.world.definition.story_sites.marks
		game.world.interact()
		button(game, "story_inspect").pressed.emit()
		var player = game.world.player
		player.position = game.world.definition.story_sites.control if kind == "vampire" else game.world.definition.story_sites.shore
		if kind == "werewolf": player.shift_form("wolf")
		game.world.interact()
		var event := "blood" if kind == "vampire" else "scent"
		var reserve: float = session.nature.blood if kind == "vampire" else session.nature.resolve
		var mana: float = player.mana
		if kind == "vampire":
			button(game, "story_blood").pressed.emit()
			check(button(game, "story_confirm_blood") != null and Rules.stage(session.gathered, session.opened) == 3, "blood costs and boundaries are reviewed before player confirmation")
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.campaign_action(event) and Rules.stage(session.gathered, session.opened) == 3 and player.mana == mana and is_equal_approx(session.nature.blood if kind == "vampire" else session.nature.resolve, reserve), "failed special evidence write consumes no nature reserve or magic")
		DirAccess.remove_absolute("user://save.json.tmp")
		if kind == "vampire": await enter()
		else: button(game, "story_scent").pressed.emit()
		check(Rules.stage(session.gathered, session.opened) == 4 and Rules.positions(session.gathered) == [0, 0, 0], "distinct actual ability approach confirms evidence without requiring manual configuration")
		check(is_equal_approx(session.nature.blood, reserve - 20) and player.mana == mana - 15 if kind == "vampire" else is_equal_approx(session.nature.resolve, reserve - 20) and player.mana == mana, "actual special approach applies its own advertised resource price")
		if kind == "vampire":
			var vitals: Dictionary = game.world.player_vitals()
			for cure in ["cure_start", "release_water", "release_garden", "cure_finish"]:
				check(session.nature_event(cure, player.position, vitals), "separate return remains compatible with already confirmed campaign evidence")
			player.mana = session.vitals.mana
			check(session.nature.kind == "human" and "story:lake:method:blood" in session.gathered, "return preserves the chosen special evidence and tool")
		else: player.shift_form()
		await portal(game, Vector2(135, 650))
		await portal(game, Vector2(1750, 1120))
		await speak(game, "mentor", "explain" if kind == "vampire" else "")
		if kind == "vampire": check(Dialogue.memory(session.gathered, "mentor", "returned") == "explain" and Dialogue.memory(session.gathered, "mentor", "vampire") == "honest", "new mentor remembers both before and after return conversations")
		var prior_xp: int = session.xp
		var coins: int = session.inventory.coin
		button(game, "story_report_provision").pressed.emit()
		await enter()
		check(session.xp == prior_xp + 80 and session.inventory.coin == coins + 12 and session.inventory.story_tool == 1 and Rules.stage(session.gathered, session.opened) == 5, "each history completes actual report with its preserved instrument and one reward")
		check(session.load_saved() and "story:lake:method:" + event in session.gathered, "distinct completed evidence method reloads with persistent personal history")
	for role in ["mentor", "witness"]:
		for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
			if form in ["wolf", "hybrid"]: PackFixture.wolf(session, form == "hybrid")
			else:
				NatureFixture.vampire(session)
				session.nature.gift = "blood_mist"
				session.gathered.append_array(["flight:bat", "flight:mist"])
				session.opened.append("waterworks_flight")
			session.region = "workshop" if role == "mentor" else "terrace"
			session.arrival = Vector2(240, 650)
			game._build_world()
			game.resume()
			await settle()
			freeze(game)
			game.world.player.position = game.world.npcs[role].position
			game.world.player.shift_form(form)
			game.world.interact()
			var reaction: Label = game.screen.find_child("nature_reaction", true, false)
			check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null, "both new NPCs distinguish all current shapes and provide accessible return")
			button(game, "dialogue_return_form").pressed.emit()
			check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary shape cannot permanently block an essential campaign character")
	for role in ["mentor", "witness"]:
		for history in ["oath", "wild_returned"]:
			if history == "oath":
				NatureFixture.vampire(session)
				session.nature.kind = "human"
				session.nature.blood = 100.0
				session.nature.history = []
				session.nature.gift = "oath"
			else:
				PackFixture.wolf(session)
				for event in ["return_start", "release_den", "release_word", "return_finish"]:
					check(session.pack_event(event, Vector2(410, 490), {"health": 80.0, "mana": 100.0, "stamina": 100.0}), "returned history fixture uses valid committed return transitions")
			session.region = "workshop" if role == "mentor" else "terrace"
			session.arrival = Vector2(240, 650)
			game._build_world()
			game.resume()
			await settle()
			freeze(game)
			game.world.player.position = game.world.npcs[role].position
			game.world.interact()
			var reaction: Label = game.screen.find_child("nature_reaction", true, false)
			check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_" + history.to_upper()), "both new characters distinguish human commitment and returned wolf history")
			var answer := "pledge" if history == "oath" else "remember_pack"
			var group: String = Dialogue.GROUPS[role]
			var trust: int = session.world_state.reputation[group]
			button(game, "dialogue_" + answer).pressed.emit()
			check(Dialogue.memory(session.gathered, role, history) == answer and session.world_state.reputation[group] == trust + 1, "new personal answer commits its own one-time memory and relationship")
			check(button(game, "dialogue_" + answer) == null and not game.world.dialogue_action(role, answer), "remembered reply cannot farm relationship")
			check(session.load_saved() and Dialogue.memory(session.gathered, role, history) == answer, "new oath and returned history survive actual JSON load")
	print("Campaign path checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
