extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/commission_rules.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	call_deferred("run")
func press(game: Node, name: String) -> bool:
	for child in game.screen.find_children("*", "Button", true, false):
		if child.name == name or child.text == TranslationServer.translate(name):
			check(not child.disabled, "required native UI action is available")
			if not child.disabled:
				child.pressed.emit()
				return true
			return false
	check(false, "required native UI action exists")
	return false
func interact(game: Node, point: Vector2) -> void:
	game.world.player.position = point
	game.world.interact()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	interact(game, game.world.keeper.position)
	press(game, "ACCEPT")
	interact(game, Vector2(1240, 420))
	interact(game, game.world.keeper.position)
	press(game, "GIVE_LANTERN")
	check(session.quest == 3, "existing introductory UI unlocks new content")
	press(game, "COMMISSION_TITLE")
	press(game, "commission_accept")
	check(session.world_state.commission.stage == 1 and game.current_screen == "game", "actual acceptance saves first new phase and resumes play")
	game.update_hud()
	check(game.quest_label.text == TranslationServer.translate("COMMISSION_HINT_1"), "HUD points to active new objective")
	game.show_journal()
	await process_frame
	await process_frame
	var journal_text := []
	for label in game.screen.find_children("*", "Label", true, false):
		journal_text.append(label.text)
	check(journal_text.has(TranslationServer.translate("COMMISSION_TITLE")) and journal_text.has(TranslationServer.translate("FACTION_WARDENS") + ": 0"), "journal shows active line and actual group relationships")
	game.resume()
	game.world.player.health = 71
	interact(game, Vector2(1800, 500))
	await process_frame
	await process_frame
	interact(game, Vector2(1750, 1120))
	await process_frame
	await process_frame
	check(session.region == "workshop" and game.world.player.health == 71, "accepted line reaches authored region through real portals without free healing")
	check(not game.world.commission_action("inspect_wheel") and session.world_state.commission.survey.is_empty(), "backend rejects remote investigation")
	interact(game, game.world.definition.commission_sites.wheel)
	press(game, "commission_inspect_wheel")
	check(not game.world.commission_action("inspect_wheel"), "repeated physical investigation cannot count twice")
	interact(game, game.world.definition.commission_sites.archive)
	press(game, "commission_inspect_archive")
	check(session.world_state.commission.stage == 2, "both actual world observations unlock conversations")
	session.world_state.minutes = 1380
	game.world._update_npcs()
	interact(game, game.world.npcs.warden.position)
	press(game, "commission_hear_wardens")
	interact(game, game.world.npcs.tender.position)
	press(game, "commission_hear_tenders")
	check(session.world_state.commission.stage == 3, "essential conversations remain available at night")
	session.inventory.coin = 0
	game.world.player.position = game.world.npcs.wright.position
	check(not game.world.can_commission("supply_purchase"), "empty purse cannot use paid alternative")
	var first: Dictionary = game.world.definition.salvage[0]
	game.world.player.position = first.point
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.interact()
	check(int(session.inventory.get("scrap", 0)) == 0 and first.id not in session.gathered, "failed salvage save cannot grant material or remove it")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	check(session.inventory.scrap == 1 and first.id in session.gathered, "physical salvage saves item and memory together")
	check(session.load_saved(), "new line reloads from real disk midway through collection")
	game._build_world()
	game.resume()
	interact(game, first.point)
	check(session.inventory.scrap == 1, "loaded resource cannot be collected a second time")
	for entry in game.world.definition.salvage.slice(1):
		interact(game, entry.point)
	check(session.inventory.scrap == 3, "all materials can be gathered without money or combat")
	interact(game, game.world.definition.commission_sites.workbench)
	press(game, "commission_supply_craft")
	check(session.world_state.commission.stage == 4 and session.inventory.scrap == 0 and session.inventory.coin == 0 and session.defeated.is_empty(), "peaceful resource route advances without hidden combat or payment")
	interact(game, game.world.definition.commission_sites.wheel)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.commission_action("restore_shared") and session.world_state.commission.stage == 4 and session.world_state.reputation.wardens == 0 and not game.world.navigation.segment_clear(Vector2(960, 600), Vector2(1230, 600)), "failed settlement save cannot change relationships or physical passage")
	DirAccess.remove_absolute("user://save.json.tmp")
	press(game, "commission_restore_shared")
	check(session.world_state.commission.stage == 5 and session.world_state.reputation.wardens == 2 and session.world_state.reputation.tenders == 2, "actual settlement saves consequences for both groups")
	check(game.world.navigation.segment_clear(Vector2(960, 600), Vector2(1230, 600)), "saved result removes real navigation obstacle immediately")
	game.world.player.position = Vector2(960, 600)
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
	Input.action_release("move_right")
	check(game.world.player.position.x > 1190, "hero physically crosses changed passage, beyond a visual-only update")
	check(session.load_saved(), "changed environment reloads its saved phase")
	game._build_world()
	check(game.world.navigation.segment_clear(Vector2(960, 600), Vector2(1230, 600)), "reloaded environment keeps the opened route")
	game.resume()
	interact(game, game.world.definition.exit)
	await process_frame
	await process_frame
	interact(game, Vector2(135, 650))
	await process_frame
	await process_frame
	interact(game, game.world.keeper.position)
	press(game, "COMMISSION_TITLE")
	var before_xp: int = session.xp
	session.inventory.coin = 984
	game.show_commission("keeper")
	var report_button: Button = game.screen.find_child("commission_report", true, false)
	var explained := false
	for label in game.screen.find_children("*", "Label", true, false):
		if label.text == TranslationServer.translate("COMMISSION_REWARD_FULL") % 16:
			explained = true
	check(report_button != null and report_button.disabled and explained and session.xp == before_xp, "full purse is explained before final reward without partial XP")
	session.inventory.coin = 0
	game.show_commission("keeper")
	press(game, "commission_report")
	check(session.world_state.commission.stage == 6 and session.xp == before_xp + 80 and session.inventory.coin == 16, "real report grants one final reward")
	check(not game.world.commission_action("report") and session.inventory.coin == 16, "completed physical report cannot repeat reward")

	# Other combinations use explicit preparation fixtures; the first route above covers discovery and travel end to end.
	for supply in ["purchase", "craft", "recover"]:
		for settlement in ["shared", "wardens", "tenders"]:
			game.new_game()
			session.quest = 3
			session.xp = 40
			session.region = "workshop"
			session.arrival = Vector2(240, 650)
			session.inventory = {"coin": 8, "scrap": 3}
			session.world_state.commission = {"stage": 3, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "", "settlement": ""}
			game._build_world()
			game.resume()
			if supply == "recover":
				for child in game.world.get_children():
					if child is CharacterBody2D and child.has_signal("defeated"):
						child.receive_damage(1000, Vector2.RIGHT)
				await process_frame
			var event: String = "supply_" + supply
			var target: String = Rules.SITES[event][1]
			var point: Vector2 = game.world.npcs[target].position if game.world.npcs.has(target) else game.world.definition.commission_sites[target]
			interact(game, point)
			press(game, "commission_" + event)
			check(session.world_state.commission.stage == 4, "each real supply alternative advances exactly one phase")
			interact(game, game.world.definition.commission_sites.wheel)
			press(game, "commission_restore_" + settlement)
			var expected: Array = {"shared": [2, 2, 2], "wardens": [1, 3, -1], "tenders": [1, -1, 3]}[settlement]
			check([session.world_state.reputation.roadfolk, session.world_state.reputation.wardens, session.world_state.reputation.tenders] == expected, "each actual choice stores its distinct relationship result")
			check(session.load_saved() and session.world_state.commission.supply == supply and session.world_state.commission.settlement == settlement, "all supply and decision combinations retain identity after reload")
			session.region = "crossing"
			session.arrival = Vector2(520, 490)
			game._build_world()
			game.resume()
			interact(game, game.world.keeper.position)
			press(game, "COMMISSION_TITLE")
			press(game, "commission_report")
			check(session.world_state.commission.stage == 6 and session.quest == 3 and session.aid_quest == 0, "all alternatives finish without modifying protected existing quest states")
	print("Commission gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
