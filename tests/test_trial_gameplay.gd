extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/trial_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, name: String) -> Button:
	return game.screen.find_child(name, true, false) as Button
func enter() -> void:
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key)
		await process_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.quest = 3
	session.world_state.commission = {"stage": 6, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "craft", "settlement": "shared"}
	session.world_state.minutes = 600
	session.inventory = {"coin": 7, "herb": 3}
	session.region = "workshop"
	session.arrival = Vector2(570, 540)
	game._build_world()
	game.resume()
	game.world.interact()
	check(button(game, "trial_assignment") != null, "previous episode exposes the next real assignment through its NPC")
	button(game, "trial_assignment").pressed.emit()
	check(button(game, "trial_accept") != null and not button(game, "trial_accept").disabled, "assignment can be accepted with a native button")
	await enter()
	check(Rules.stage(session.gathered, session.defeated, session.opened) == 1 and game.current_screen == "game", "keyboard acceptance commits progress and resumes play")
	game.world.player.position = Vector2(1800, 420)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "waterworks" and game.quest_label.text == game.tr("TRIAL_HINT_1"), "real transition and HUD track current assignment")
	check(not game.world.trial_action("north") and not game.world.trial_action("report"), "backend rejects distant or wrong-region task actions")
	for site in ["south", "north"]:
		game.world.player.position = game.world.definition.trial_sites[site]
		game.world.interact()
		var read := button(game, "trial_" + site)
		check(read != null and not read.disabled, "physical observation exposes its own valid action")
		read.pressed.emit()
		check("waterworks:" + site in session.gathered, "actual observation writes its own permanent flag")
		check(not game.world.trial_action(site), "repeat observation cannot advance progress twice")
	game.world.player.position = Vector2(820, 650)
	game.world.interact()
	await enter()
	check(is_instance_valid(game.world.boss) and game.world.boss.armed and Rules.stage(session.gathered, session.defeated, session.opened) == 3, "prepared start activates the real guardian and writes retry state")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	check(game.current_screen == "death", "boss approach retains the actual death screen")
	await enter()
	check(game.current_screen == "game" and game.world.player.health == 100 and game.world.boss.health == 420 and game.world.boss.armed, "keyboard retry restores healthy player and complete encounter from checkpoint")
	game.world.boss.set_physics_process(false)
	game.world.player.set_physics_process(false)
	game.world.player.position = game.world.boss.position + Vector2(-40, 0)
	game.world.player.facing = Vector2.RIGHT
	game.world._on_strike(game.world.player.position, Vector2.RIGHT)
	check(game.world.boss.health == 392, "real player weapon connects through shared world strike rules")
	game.world.player.position = game.world.boss.position - Vector2(500, 0)
	check(not game.world.safe_to_rest(), "engaged boss blocks saving even beyond initial awareness distance")
	game.world.player.position = game.world.boss.position - Vector2(40, 0)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.boss.receive_damage(999, Vector2.RIGHT)
	check(is_instance_valid(game.world.boss) and game.world.boss.awaiting_record and session.defeated.is_empty() and session.xp == 0, "failed victory save retains retry object and grants no experience")
	game.update_hud()
	check(game.boss_panel.visible and game.quest_label.text == game.tr("TRIAL_RECORD_HELP"), "pending victory visibly explains recovery action")
	check(not game.world.safe_to_rest() and game.world.nearby_key() == "TRIAL_RECORD", "unrecorded victory prevents unsafe checkpoint replacement and offers interaction")
	var saved: Dictionary = session.Store.load_game()
	check("waterworks_guardian" not in saved.defeated and "waterworks:awakened" in saved.gathered, "disk still contains a repeatable pre-victory encounter after write failure")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	check(not is_instance_valid(game.world.boss) and session.defeated == ["waterworks_guardian"] and session.xp == 120, "real retry interaction records victory once before actor disappears")
	game.world.interact()
	check(session.xp == 120, "repeated interaction does not duplicate boss experience")
	check(session.load_saved(), "victory reloads from disk")
	game._build_world()
	game.resume()
	check(not is_instance_valid(game.world.boss), "recorded victory prevents respawn on reload")
	check(game.world.trial_markers.north.done and game.world.trial_markers.south.done, "loaded observations are visually complete immediately after rebuilding")
	game.world.player.position = Vector2(1660, 1020)
	game.world.interact()
	check("waterworks_supplies" in session.opened and session.inventory.coin == 25 and session.inventory.potion == 2, "victory unlocks actual guarded supplies")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	await process_frame
	check(session.region == "workshop", "victory leaves real return portal usable")
	game.world.player.position = game.world.npcs.wright.position
	game.show_trial("wright")
	session.inventory.coin = 976
	game.show_trial("wright")
	check(button(game, "trial_report").disabled, "full purse retains unclaimed turn-in")
	session.inventory.coin = 25
	game.show_trial("wright")
	await enter()
	check(Rules.stage(session.gathered, session.defeated, session.opened) == 5 and session.inventory.coin == 49 and session.xp == 180, "keyboard turn-in completes real assignment with one final reward")
	check(not game.world.trial_action("report") and session.inventory.coin == 49, "finished assignment cannot be farmed")
	check(session.load_saved() and Rules.stage(session.gathered, session.defeated, session.opened) == 5, "full completion survives disk reload")
	game.show_journal()
	check(game.current_screen == "journal", "completed task remains accessible in normal journal")
	print("Trial gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
