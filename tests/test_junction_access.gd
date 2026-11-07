extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/junction_fixture.gd")
const CampaignFixture = preload("res://tests/support/campaign_fixture.gd")
const Rules = preload("res://scripts/quests/junction_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	CampaignFixture.ready(session)
	session.region = "rotunda"
	session.arrival = Vector2(240, 650)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	check(not game.world.npcs.mentor.visible and game.world.npcs.steward.visible, "early visitor can meet participant without duplicating mentor from workshop")
	game.world.player.position = game.world.herbs[0].position
	var herbs: int = session.inventory.herb
	game.world.interact()
	check(session.inventory.herb == herbs + 1 and session.Store.validate(session.snapshot(game.world.player.position, game.world.player_vitals())), "actual new-region harvest uses region namespace without poisoning story validation")
	check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved() and session.region == "rotunda", "early exploration and ordinary resource collection save/load without common progress")
	for missing in Rules.RECORDS:
		check(Fixture.ready(session), "complete regional fixture starts valid before selecting unfinished regional branch")
		if missing == "story_lake_report":
			session.gathered = session.gathered.filter(func(flag): return not flag.begins_with("story:lake:") and not flag.begins_with("story:dial:"))
		else:
			var prefix: String = "forest:" if missing == "forest_report" else "city:"
			session.gathered = session.gathered.filter(func(flag): return not flag.begins_with(prefix))
		session.opened.erase(missing)
		if missing == "forest_report": session.opened.erase("forest_passage")
		session.region = "workshop"
		session.arrival = Vector2(780, 700)
		check(session.Store.validate(session.snapshot(session.arrival)), "unfinished branch remains a valid independently ordered v9 state")
		game._build_world()
		game.world.set_process(false)
		game.world.player.set_physics_process(false)
		game.resume()
		game.world.player.position = game.world.npcs.mentor.position
		game.world.interact()
		check(not game.world.can_junction("accept") and game.screen.find_child("joint_accept", true, false) == null and game.world.npcs.mentor.visible, "each independently missing regional report prevents premature invitation and relocation")
	print("Junction access checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
