extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/rescue_fixture.gd")
const PreparationFixture = preload("res://tests/support/preparation_fixture.gd")
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
func settle() -> void:
	await process_frame
	await process_frame
func build(game: Node, session: Node, region: String = "underhall") -> void:
	session.region = region
	session.arrival = Vector2(280, 650)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.resume()
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(not game.world.npcs.mentor.visible, "human opening does not spawn future returned participant at home")
	check(PreparationFixture.configured(session), "genuine preparation exists without its final report")
	await build(game, session, "rotunda")
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	check(game.screen.find_child("rescue_accept", true, false) == null and not game.world.can_rescue("accept"), "configured rehearsal alone cannot skip final preparation report")
	await build(game, session)
	check(not game.world.npcs.mentor.visible and not game.world.rescue_engine.dangerous(Vector2(980, 430)), "early visit is honest and safe without moving a future participant or activating unchosen mechanism")
	game.world.player.position = Vector2(430, 960)
	game.world.interact()
	check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved(), "early optional resource remains compatible with old valid v9 before new episode")
	check(Fixture.selected(session), "actual selected approach supports access tests")
	var vitals := {"health": 64.0, "stamina": 100.0, "mana": 90.0}
	for event in ["manual_north", "manual_south", "free"]: check(session.rescue_event(event, Vector2(1440, 650), vitals, true), "partial fixture releases participant only after both committed cuts")
	await build(game, session)
	check(not game.world.can_rescue("safe") and not game.world.rescue_action("safe"), "player at exit cannot replace actual participant arrival")
	game.world.npcs.mentor.position = Vector2(380, 650)
	await settle()
	check("rescue:safe" not in session.gathered and not game.world.rescue_engine.pending, "nearly arrived but still outside safe radius cannot claim exit or enter misleading disk retry")
	game.world.player.position = Vector2(1200, 650)
	game.world.npcs.mentor.position = Vector2(1440, 650)
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.position = game.world.player.position + Vector2(100, 0)
	enemy.target = game.world.player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	game.world._update_npcs()
	check(game.world.npcs.mentor.destination == game.world.npcs.mentor.position and not game.world.safe_to_rest(), "real nearby threat prevents guiding a vulnerable participant into danger")
	enemy.queue_free()
	await settle()
	game.world._update_npcs()
	check(game.world.npcs.mentor.destination == game.world.player.position, "safe ordinary body resumes real follow destination after threat leaves")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		var kind := "werewolf" if form in ["wolf", "hybrid"] else "vampire"
		check(Fixture.selected(session, kind), "shape interaction uses genuine prepared special history")
		if kind == "vampire":
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		elif form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		await build(game, session)
		game.world.player.position = game.world.npcs.mentor.position
		check(game.world.player.shift_form(form), "real actor adopts each available temporary form")
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_MENTOR_" + Dialogue.context(session.nature).to_upper()) and game.screen.find_child("dialogue_return_form", true, false) != null, "relocated mentor keeps own reaction and accessible return for every temporary form")
		game.screen.find_child("dialogue_return_form", true, false).pressed.emit()
		check(session.nature.form == "human" and game.screen.find_child("dialogue_continue", true, false) != null, "temporary nature never locks the real participant conversation")
	print("Rescue access checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
