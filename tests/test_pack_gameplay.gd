extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/pack_fixture.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, name: String) -> Button: return game.screen.find_child(name, true, false) as Button
func enter() -> void:
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await process_frame
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await physics_frame
		await physics_frame
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await process_frame
	await process_frame
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	var continuation := button(game, "dialogue_continue")
	if continuation != null: continuation.pressed.emit()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.NatureFixture.completed_episode(session)
	session.region = "workshop"
	session.arrival = Vector2(1820, 1190)
	game._build_world()
	game.resume()
	await portal(game, Vector2(1780, 1200))
	await speak(game, "tracker")
	check(button(game, "pack_invite") != null and button(game, "pack_accept") == null, "new NPC offers explanation without immediate transformation")
	await enter()
	check("pack:invited" in session.gathered and session.nature.kind == "human", "keyboard invitation preserves ordinary nature")
	for site in ["trail_0", "trail_1", "trail_2"]:
		game.world.player.position = game.world.definition.pack_sites[site]
		game.world.interact()
		check(button(game, "pack_" + site) != null, "physical trail offers its own observation")
		await enter()
		check("pack:" + site in session.gathered and not game.world.pack_action(site), "trail observation commits once and cannot replace other evidence")
	await portal(game, Vector2(135, 650))
	await speak(game, "warden")
	check(button(game, "pack_warden") != null, "second NPC has a distinct preparation conversation")
	button(game, "pack_warden").pressed.emit()
	await enter()
	await portal(game, Vector2(1780, 1200))
	await speak(game, "tracker")
	check(button(game, "pack_accept") != null and button(game, "pack_decline") != null, "prepared scene exposes both permanent choices")
	button(game, "pack_accept").pressed.emit()
	check(session.nature.kind == "human" and button(game, "pack_confirm_accept") != null, "reviewing consequences never transforms by itself")
	await enter()
	check(session.nature.kind == "werewolf" and session.nature.form == "human" and session.xp == 220, "explicit keyboard consent commits new nature without forced animal shape")
	await key(KEY_U)
	check(session.nature.form == "wolf", "physical U selects actual wolf shape")
	game.world.player.position = game.world.npcs.tracker.position
	game.world.interact()
	check(button(game, "dialogue_return_form") != null, "seventh NPC reacts to animal form and provides a return action")
	await enter()
	check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "keyboard return restores normal access to important NPC")
	game.resume()
	await key(KEY_U)
	var caches: Array = game.world.chests.duplicate()
	for i in caches.size():
		game.world.player.position = caches[i].position
		if i == 2:
			DirAccess.make_dir_absolute("user://save.json.tmp")
			game.world.interact()
			check(session.nature.gift == "wild" and "pack:mastery" not in session.gathered and session.xp == 220, "failed final cache write cannot grant mastery or consume reward")
			DirAccess.remove_absolute("user://save.json.tmp")
		game.world.interact()
	check(session.nature.gift == "wild_master" and session.xp == 280 and session.inventory.coin == 33, "three actual findings unlock hybrid and reward exactly once")
	game.world.interact()
	check(session.xp == 280 and session.inventory.coin == 33, "repeated finding cannot farm mastery or currency")
	await key(KEY_Y)
	check(session.nature.form == "hybrid", "physical Y selects progressively unlocked hybrid")
	game.world.player.hurt_time = 0
	game.world.player.health = 1
	game.world.player.receive_damage(999)
	await enter()
	check(session.nature.kind == "werewolf" and session.nature.gift == "wild_master" and game.world.player.health == 100, "death checkpoint keeps permanent nature and earned mastery")
	game.world.player.shift_form()
	if session.nature.form != "human": game.world.player.shift_form()
	var regions := {"keeper": "crossing", "merchant": "crossing", "wayfarer": "lake", "warden": "workshop", "wright": "workshop", "tender": "workshop", "tracker": "thicket"}
	for role in regions:
		session.region = regions[role]
		session.arrival = Vector2(400, 650)
		game._build_world()
		game.resume()
		game.world.player.position = game.world.npcs[role].position
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_WEREWOLF"), "each of seven NPCs recognizes wolf nature with a separate reaction")
		var prior: int = session.world_state.reputation[Dialogue.GROUPS[role]]
		button(game, "dialogue_pack_word").pressed.emit()
		check(Dialogue.memory(session.gathered, role, "werewolf") == "pack_word" and session.world_state.reputation[Dialogue.GROUPS[role]] == prior + 1, "wolf response commits its own memory and group consequence")
		check(not game.world.dialogue_action(role, "pack_word"), "new response cannot farm trust")
	button(game, "dialogue_continue").pressed.emit()
	button(game, "pack_return_start").pressed.emit()
	check(session.nature.cure == 1, "return begins as separate procedure after mastery")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await speak(game, "keeper")
	check(button(game, "pack_keeper") != null and button(game, "nature_keeper") == null, "wolf return uses its own dialogue rather than blood-path ritual")
	button(game, "pack_keeper").pressed.emit()
	await enter()
	await portal(game, Vector2(1800, 500))
	await portal(game, Vector2(1750, 1120))
	await portal(game, Vector2(1780, 1200))
	game.world.player.position = game.world.definition.pack_sites.den
	game.world.interact()
	await enter()
	await speak(game, "tracker")
	button(game, "pack_return_finish").pressed.emit()
	check(session.nature.kind == "werewolf" and button(game, "pack_confirm_return_finish") != null, "permanent return has its own explicit consequence review")
	await enter()
	check(session.nature.kind == "human" and session.nature.gift == "wild_scar" and session.nature.history == ["werewolf"] and session.xp == 320, "return preserves wolf history and has distinct human aftermath")
	for role in regions:
		session.region = regions[role]
		game._build_world()
		game.resume()
		game.world.player.position = game.world.npcs[role].position
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_WILD_RETURNED") and Dialogue.memory(session.gathered, role, "werewolf") == "pack_word", "returned wolf receives different remembered dialogue at all seven NPCs")
	check(session.load_saved() and session.nature.history == ["werewolf"], "full nature and dialogue history reloads from disk")
	Fixture.prepared(session)
	session.region = "thicket"
	session.arrival = Vector2(450, 600)
	game._build_world()
	game.resume()
	game.show_pack()
	button(game, "pack_decline").pressed.emit()
	await enter()
	check(session.nature.kind == "human" and session.nature.gift == "trail_oath" and session.nature.history.is_empty(), "explicit refusal grants useful human alternative without transformation")
	check(not game.world.pack_action("accept") and not game.world.player.shift_form(), "declined path is not a free nature switch")
	print("Pack gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
