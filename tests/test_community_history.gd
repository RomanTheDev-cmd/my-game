extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Community = preload("res://scripts/factions/community_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, label: String) -> Button: return game.screen.find_child(label, true, false) as Button
func run() -> void:
	var session := root.get_node("Session")
	Fixture.completed_episode(session)
	var old: Dictionary = session.snapshot(Vector2(410, 490), {"health": 52.0, "stamina": 61.0, "mana": 80.0})
	check(old.version == 9 and session.Store.migrate(old) == old and session.Store.validate(old), "existing v9 without new flags keeps its complete former state")
	check(session.Store.write_game(old) == OK and session.load_saved() and session.vitals.health == 52 and Community.guild(session.gathered) == "", "old v9 disk roundtrip neither joins nor heals")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	Fixture.vampire(session)
	var vitals := {"health": 52.0, "stamina": 61.0, "mana": 80.0}
	check(session.community_event("join_circle", Vector2(480, 620), vitals), "circle membership starts before a separate cure")
	check(session.community_event("seen_supply", Vector2(720, 420), vitals) and session.community_event("seen_route", Vector2(1320, 600), vitals), "observations persist separately from nature ritual")
	session.region = "haven"
	session.arrival = Vector2(440, 600)
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.host.position
	game.world.interact()
	check(button(game, "dialogue_honest") != null, "new host has her own vampire response")
	button(game, "dialogue_honest").pressed.emit()
	check(Dialogue.memory(session.gathered, "host", "vampire") == "honest", "new host remembers personal answer on disk")
	for event in ["cure_start", "release_water", "release_garden", "cure_finish"]:
		check(session.nature_event(event, Vector2(440, 600), vitals), "nature return remains possible during community assignment")
	check(session.nature.kind == "human" and Community.guild(session.gathered) == "circle" and Community.stage(session.gathered) == 2, "return changes nature while retaining membership and unfinished observations")
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.host.position
	game.world.interact()
	var reaction: Label = game.screen.find_child("nature_reaction", true, false)
	check(reaction != null and reaction.text == game.tr("DIALOGUE_HOST_RETURNED") and button(game, "dialogue_explain") != null and button(game, "dialogue_honest") == null, "return changes actual host lines and response choices")
	button(game, "dialogue_explain").pressed.emit()
	check(Dialogue.memory(session.gathered, "host", "returned") == "explain" and Dialogue.memory(session.gathered, "host", "vampire") == "honest", "both phases of relationship history coexist")
	check(not game.world.dialogue_action("host", "explain"), "new host cannot farm trust through repeated replies")
	check(game.world.community_action("aid_craft") and Community.stage(session.gathered) == 3, "returned human can finish former vampire assignment through actual craft alternative")
	check(game.world.community_action("report_share") and session.load_saved() and Community.guild(session.gathered) == "circle" and Community.stage(session.gathered) == 4, "old membership and new human outcome persist together")
	check(not game.world.community_action("join_watch") and not session.community_event("join_circle", Vector2(440, 600), vitals), "return cannot reset one-time membership into free rejoining")
	for form in ["battle", "bat", "mist", "wolf", "hybrid"]:
		if form in ["wolf", "hybrid"]: PackFixture.wolf(session, form == "hybrid")
		else:
			Fixture.vampire(session)
			session.nature.gift = "blood_mist"
			session.gathered.append_array(["flight:bat", "flight:mist"])
			session.opened.append("waterworks_flight")
		session.region = "haven"
		session.arrival = Vector2(440, 600)
		game._build_world()
		game.resume()
		await physics_frame
		await physics_frame
		game.world.player.position = game.world.npcs.host.position
		game.world.player.shift_form(form)
		game.world.interact()
		reaction = game.screen.find_child("nature_reaction", true, false)
		var context := Dialogue.context(session.nature)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_HOST_" + context.to_upper()) and button(game, "dialogue_return_form") != null, "new host distinguishes each supernatural shape and permits return")
		button(game, "dialogue_return_form").pressed.emit()
		check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "temporary shape never blocks the new NPC permanently")
	for state in ["oath", "werewolf", "wild_returned"]:
		if state == "oath":
			Fixture.completed_episode(session)
			session.nature.stage = 3
			session.nature.gift = "oath"
			session.gathered.append_array(["nature:water", "nature:garden"])
		else:
			PackFixture.wolf(session)
			if state == "wild_returned":
				session.nature = {"kind": "human", "form": "human", "blood": 100.0, "landing": {}, "resolve": 100.0, "stage": 4, "history": ["werewolf"], "cure": 3, "gift": "wild_scar"}
				session.gathered.append_array(["pack:return_started", "pack:release_den", "pack:release_word", "pack:returned"])
		session.region = "haven"
		session.arrival = Vector2(440, 600)
		game._build_world()
		game.resume()
		game.world.player.position = game.world.npcs.host.position
		game.world.interact()
		reaction = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_HOST_" + state.to_upper()), "new host has a separate human oath wolf and returned wolf conversation")
		var answer: String = {"oath": "pledge", "werewolf": "pack_word", "wild_returned": "remember_pack"}[state]
		button(game, "dialogue_" + answer).pressed.emit()
		check(Dialogue.memory(session.gathered, "host", state) == answer and session.load_saved(), "new path-specific response commits actual persistent memory")
	print("Community history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
