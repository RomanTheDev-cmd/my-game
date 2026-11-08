extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/knell_fixture.gd")
const Rules = preload("res://scripts/quests/knell_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
var Echo: GDScript
const VITALS := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
var checks := 0
var failures := 0
var notices: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, id: String) -> Button: return game.screen.find_child(id, true, false) as Button
func label(game: Node, id: String) -> String:
	var found: Label = game.screen.find_child(id, true, false)
	return found.text if found != null else ""
func settle() -> void:
	await process_frame
	await process_frame
func build(game: Node, session: Node, region: String, arrival: Vector2) -> void:
	session.region = region
	session.arrival = arrival
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for child in game.world.get_children():
		if child is CharacterBody2D and child != game.world.player: child.set_physics_process(false)
	game.resume()
	await settle()
# Talk to the keeper as the current self; non-ordinary paths first meet her nature reaction.
func keeper(game: Node, answer: String = "") -> void:
	game.resume()
	game.world.player.position = game.world.keeper.position
	game.world.interact()
	if answer != "" and button(game, "dialogue_" + answer) != null: button(game, "dialogue_" + answer).pressed.emit()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
	if button(game, "knell_entry") != null: button(game, "knell_entry").pressed.emit()
	await settle()
func cure(session: Node, kind: String) -> void:
	var events := ["cure_start", "release_water", "release_garden", "cure_finish"] if kind == "vampire" else ["return_start", "release_den", "release_word", "return_finish"]
	for event in events: check(session.nature_event(event, Vector2(600, 600), VITALS) if kind == "vampire" else session.pack_event(event, Vector2(600, 600), VITALS), "real separate return remains possible: " + event)
func finish_crypt(session: Node) -> void:
	session.region = "undercroft"
	for id in Rules.PLAQUES: check(session.knell_event("read_" + id, Vector2(330, 820), VITALS), "plaque recorded: " + id)
	check(session.knell_event("silence", Vector2(1300, 705), VITALS), "silence recorded")
func run() -> void:
	Echo = load("res://scripts/actors/echo_enemy.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.notice.connect(func(key): notices.append(key))
	# Each voluntary path hears its own request and its own report; history is remembered.
	var answers := {"vampire": "honest", "werewolf": "pack_word"}
	for kind in ["vampire", "werewolf"]:
		check(Fixture.ready(session, kind, "community"), "real special-nature history with community decision")
		await build(game, session, "crossing", Vector2(600, 600))
		await keeper(game, answers[kind])
		check(label(game, "knell_identity") == game.tr("KNELL_REQUEST_" + kind.to_upper()) and label(game, "knell_accord") == game.tr("KNELL_ACCORD_COMMUNITY"), "special nature receives its own request and the community framing")
		check(Dialogue.memory(session.gathered, "keeper", kind) == answers[kind] or Dialogue.memory(session.gathered, "keeper", kind) != "", "keeper conversation keeps the personal answer memory")
		button(game, "knell_accept").pressed.emit()
		check(Rules.recorded(session.gathered) == kind and session.nature.kind == kind, "acceptance never changes nature")
		await keeper(game)
		check(label(game, "knell_waiting") != "" and label(game, "knell_changed") == "", "unchanged self hears the ordinary waiting line")
		await cure(session, kind)
		var returned := "returned" if kind == "vampire" else "wild_returned"
		await build(game, session, "crossing", Vector2(600, 600))
		await keeper(game, "explain" if kind == "vampire" else "remember_pack")
		check(label(game, "knell_changed") != "", "keeper remembers the self who took the key")
		finish_crypt(session)
		await build(game, session, "crossing", Vector2(600, 600))
		await keeper(game)
		check(label(game, "knell_report") == game.tr("KNELL_REPORT_" + returned.to_upper()) and label(game, "knell_changed") != "", "returned human has a distinct report that remembers the change")
		session.inventory.coin = 999
		var trust: int = session.world_state.reputation.roadfolk
		button(game, "knell_keeper").pressed.emit()
		button(game, "knell_confirm_keeper").pressed.emit()
		check(Rules.outcome(session.opened) == "keeper" and session.inventory.coin == 999 and session.world_state.reputation.roadfolk == mini(10, trust + 1) and Rules.TONGUE not in session.gear_owned, "returned tongue path: full purse is safe, trust rises, no weapon")
		check(label(game, "knell_epilogue") == game.tr("KNELL_EPILOGUE_KEEPER") and game.screen.find_child("knell_accord", true, false) == null, "epilogue reflects the keeper choice")
		game.resume()
		game.world.player.position = game.world.npcs.mentor.position
		game.world.interact()
		if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
		check(label(game, "knell_mentor") == game.tr("KNELL_MENTOR_KEEPER"), "mentor remembers the restored bell")
	# Oath and the wild path without cure each have their own lines.
	check(Fixture.oath_ready(session, "release"), "oath fixture built from actual history with its own recorded decision")
	check(session.Store.validate(session.snapshot(Vector2(600, 600))), "human oath remains a valid save")
	await build(game, session, "crossing", Vector2(600, 600))
	await keeper(game, "pledge")
	check(label(game, "knell_identity") == game.tr("KNELL_REQUEST_OATH") and label(game, "knell_accord") == game.tr("KNELL_ACCORD_RELEASE"), "oath and release produce their own request")
	button(game, "knell_accept").pressed.emit()
	# Release opens a real side passage into the bell chamber.
	await build(game, session, "undercroft", Vector2(240, 650))
	var world: Node2D = game.world
	check(not world.get_children().any(func(child): return child is StaticBody2D and child.has_meta("knell_passage")) and world.navigation.segment_clear(Vector2(1080, 1000), Vector2(1160, 1000)), "release world has an open bricked passage with navigation")
	check(world.Regions.camps("undercroft", session.opened).size() == 1, "release adds no renewal rest")
	world.player.position = Vector2(1070, 1000)
	world.player.set_physics_process(true)
	Input.action_press("move_right")
	for i in 120:
		await physics_frame
		if world.player.position.x > 1170: break
	Input.action_release("move_right")
	world.player.set_physics_process(false)
	check(world.player.position.x > 1170, "ordinary body physically walks through the released passage")
	# Ossuary reading notes differ by nature.
	world.player.position = world.definition.knell_sites.ossuary + Vector2(0, -25)
	for echo in world.get_children().filter(func(child): return child.get_script() == Echo): echo.receive_damage(999, Vector2.RIGHT)
	await settle()
	world.interact()
	check(label(game, "knell_sense") == game.tr("KNELL_SENSE_OATH"), "oath has its own reading at the ossuary")
	game.resume()
	# Temporary bodies: keeper reacts and offers a return, plaques ask for a speaking body.
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		var kind := "werewolf" if form in ["wolf", "hybrid"] else "vampire"
		check(Fixture.accepted(session, kind, "renewal"), "temporary-body check starts from an accepted case")
		if kind == "vampire":
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		elif form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		await build(game, session, "crossing", Vector2(600, 600))
		game.world.player.position = game.world.keeper.position
		check(game.world.player.shift_form(form), "real temporary shape entered: " + form)
		game.world.interact()
		check(label(game, "nature_reaction") == game.tr("DIALOGUE_KEEPER_" + Dialogue.context(session.nature).to_upper()) and button(game, "dialogue_return_form") != null and button(game, "knell_entry") == null, "keeper reacts to the shape and offers a return before the case")
		button(game, "dialogue_return_form").pressed.emit()
		check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary body never locks the case")
		check(session.region == "crossing" and not session.knell_event("read_hall", Vector2(330, 820), VITALS), "plaque backend is not reachable from the crossing")
		await build(game, session, "undercroft", Vector2(430, 355))
		check(game.world.player.shift_form(form), "temporary shape in the crypt: " + form)
		notices.clear()
		game.world.interact()
		check("NATURE_RETURN_FORM" in notices and Rules.read_count(session.gathered) == 0 and game.current_screen == "game", "reading names needs a speaking body")
		game.world.player.shift_form()
		game.world.interact()
		check(button(game, "knell_read") != null, "after returning to ordinary form the plaque can be read")
		game.resume()
	# Community supplies: real one-time pickup with disk failure.
	check(Fixture.accepted(session, "human", "community"), "community decision with accepted case")
	await build(game, session, "undercroft", Vector2(330, 520))
	world = game.world
	var supplies: Sprite2D
	for chest in world.chests:
		if chest.get_meta("definition").id == Rules.SUPPLIES: supplies = chest
	check(supplies != null and supplies.visible, "community leaves real supplies at the crypt entrance")
	world.player.position = Vector2(330, 500)
	var herbs: int = session.inventory.herb
	var potions: int = session.inventory.get("potion", 0)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	world.interact()
	check(Rules.SUPPLIES not in session.opened and session.inventory.herb == herbs, "failed pickup grants nothing")
	DirAccess.remove_absolute("user://save.json.tmp")
	world.interact()
	check(Rules.SUPPLIES in session.opened and session.inventory.herb == herbs + 2 and session.inventory.potion == potions + 1, "supplies give exactly two herbs and one potion")
	world.interact()
	check(session.inventory.herb == herbs + 2, "supplies cannot be taken twice")
	check(world.Regions.camps("undercroft", session.opened).size() == 1 and not world.navigation.segment_clear(Vector2(1080, 1000), Vector2(1160, 1000)), "community adds neither rest nor passage")
	# Mist slips past an echo; a real howl breaks a toll in the scene.
	check(Fixture.accepted(session, "vampire", "renewal"), "vampire can explore the crypt")
	session.nature.gift = "blood_mist"
	session.gathered.append_array(["flight:bat", "flight:mist"])
	session.opened.append("waterworks_flight")
	await build(game, session, "undercroft", Vector2(560, 650))
	world = game.world
	var echo: CharacterBody2D = world.get_children().filter(func(child): return child.get_script() == Echo)[0]
	world.player.position = echo.position + Vector2(150, 0)
	check(world.player.shift_form("mist"), "mist entered in the crypt")
	echo.awareness_time = 0
	for i in 20: echo._physics_process(1.0 / 60)
	check(echo.state == "idle" and echo.awareness_time == 0, "mist slips past an echo unnoticed")
	world.player.shift_form()
	check(Fixture.accepted(session, "werewolf", "renewal"), "werewolf can explore the crypt")
	await build(game, session, "undercroft", Vector2(560, 650))
	world = game.world
	echo = world.get_children().filter(func(child): return child.get_script() == Echo)[0]
	world.player.position = echo.position + Vector2(-60, 0)
	for i in 2: echo._physics_process(1.0 / 60)
	check(echo.state == "windup", "echo begins a toll beside the werewolf")
	check(world.player.use_nature_power() and echo.state == "recover", "real howl in the scene breaks the toll")
	# Death after the recorded victory keeps the result without a second reward.
	check(Fixture.silenced(session, "human", "renewal"), "silenced case for the death check")
	session.region = "undercroft"
	check(session.save_at(Vector2(1300, 705), VITALS), "checkpoint inside the silent chamber")
	await build(game, session, "undercroft", Vector2(1300, 705))
	var xp: int = session.xp
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	check(game.current_screen == "death", "death opens recovery")
	for child in game.screen.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await settle()
	check(Rules.BELL in session.defeated and session.xp == xp and not is_instance_valid(game.world.bell), "death restore keeps the silenced bell and its single reward")
	print("Knell history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
