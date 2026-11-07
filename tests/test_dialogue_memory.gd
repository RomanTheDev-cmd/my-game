extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
const Rules = preload("res://scripts/nature/dialogue_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	session.fresh()
	var invalid: Dictionary = session.snapshot(Vector2(410, 490))
	invalid.gathered.append_array(["dialogue:keeper:vampire:honest", "dialogue:keeper:vampire:distance"])
	check(not session.Store.validate(invalid), "save rejects contradictory remembered responses in the same conversation")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	Fixture.vampire(session)
	var regions := {"keeper": "crossing", "merchant": "crossing", "wayfarer": "lake", "warden": "workshop", "wright": "workshop", "tender": "workshop"}
	var original_reactions := {}
	for kind in regions:
		session.region = regions[kind]
		session.arrival = Vector2(400, 650)
		game._build_world()
		game.resume()
		game.world.player.position = game.world.npcs[kind].position
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text == game.tr("DIALOGUE_" + kind.to_upper() + "_VAMPIRE"), "each NPC shows its own vampire reaction before ordinary business")
		original_reactions[kind] = reaction.text if reaction != null else ""
		var group: String = Rules.GROUPS[kind]
		var prior: int = session.world_state.reputation[group]
		if kind == "keeper":
			DirAccess.make_dir_absolute("user://save.json.tmp")
			check(not game.world.dialogue_action(kind, "honest") and session.world_state.reputation[group] == prior and Rules.memory(session.gathered, kind, "vampire") == "", "failed conversation save changes neither trust nor remembered answer")
			DirAccess.remove_absolute("user://save.json.tmp")
		var honest: Button = game.screen.find_child("dialogue_honest", true, false)
		check(honest != null and not honest.disabled, "vampire has its own available response choices")
		if honest != null: honest.pressed.emit()
		check(session.world_state.reputation[group] == prior + 1 and Rules.memory(session.gathered, kind, "vampire") == "honest", "actual answer commits one lasting consequence for the appropriate group")
		check(game.screen.find_child("dialogue_honest", true, false) == null and game.screen.find_child("dialogue_memory", true, false) != null, "remembered conversation replaces repeated reward choices")
		check(not game.world.dialogue_action(kind, "honest") and session.world_state.reputation[group] == prior + 1, "repeated conversation cannot farm relationship")
		var continuation: Button = game.screen.find_child("dialogue_continue", true, false)
		if continuation != null: continuation.pressed.emit()
		check(game.current_screen in ["dialog", "shop"] and game.screen.find_child("nature_reaction", true, false) == null, "nature reaction leaves original quest and trade flow accessible")
	check(session.load_saved() and Rules.memory(session.gathered, "keeper", "vampire") == "honest", "NPC memory and trust survive a real reload")
	var before_xp: int = session.xp
	var permanent_flags: Array = session.gathered.duplicate()
	session.nature = {"kind": "human", "form": "human", "blood": 100.0, "landing": {}, "resolve": 100.0, "stage": 4, "history": ["vampire"], "cure": 3, "gift": "scar"}
	session.gathered.append_array(["nature:release_water", "nature:release_garden"])
	for kind in regions:
		session.region = regions[kind]
		game._build_world()
		game.resume()
		game.world.player.position = game.world.npcs[kind].position
		game.world.interact()
		var reaction: Label = game.screen.find_child("nature_reaction", true, false)
		check(reaction != null and reaction.text != original_reactions[kind] and reaction.text == game.tr("DIALOGUE_" + kind.to_upper() + "_RETURNED"), "returned human receives a new role-specific reaction rather than forgetting old nature")
		check(game.screen.find_child("dialogue_explain", true, false) != null and game.screen.find_child("dialogue_honest", true, false) == null, "returned history changes available responses")
		check(Rules.memory(session.gathered, kind, "vampire") == "honest", "return preserves earlier vampire conversation memory")
	var previous_trust: int = session.world_state.reputation.tenders
	game.screen.find_child("dialogue_explain", true, false).pressed.emit()
	check(session.world_state.reputation.tenders == previous_trust + 1 and Rules.memory(session.gathered, "tender", "returned") == "explain", "returned conversation has its own one-time consequence")
	check(session.load_saved() and Rules.memory(session.gathered, "tender", "vampire") == "honest" and Rules.memory(session.gathered, "tender", "returned") == "explain", "both phases of relationship memory persist together on disk")
	check(session.xp == before_xp and permanent_flags.all(func(flag): return flag in session.gathered), "dialogue differences grant no hidden repeated experience and retain old history")
	var ordinary: Dictionary = session.Nature.defaults()
	check(Rules.reaction(ordinary, "keeper") == "", "ordinary human retains existing introduction")
	ordinary.stage = 3
	ordinary.gift = "oath"
	check(Rules.reaction(ordinary, "keeper") == "DIALOGUE_KEEPER_OATH" and Rules.context(ordinary) == "oath", "human specialization has its own dialogue context")
	check(not game.world.dialogue_action("merchant", "explain"), "remote NPC response cannot bypass physical conversation checks")
	print("Dialogue memory checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
