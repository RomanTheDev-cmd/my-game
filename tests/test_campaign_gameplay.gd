extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
const Rules = preload("res://scripts/quests/campaign_rules.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
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
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
	freeze(game)
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.ready(session)
	session.region = "workshop"
	session.arrival = Vector2(780, 700)
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
	game.world.player.health = 52
	await speak(game, "mentor")
	check(button(game, "story_greet") != null and not session.inventory.has("story_tool"), "real first conversation does not silently grant or accept")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.campaign_action("greet") and not session.inventory.has("story_tool"), "failed gift write cannot duplicate a campaign item")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(session.inventory.story_tool == 1 and Rules.stage(session.gathered, session.opened) == 1 and "story:accepted" not in session.gathered, "actual keyboard meeting gifts the instrument before an obligation")
	check(Trade.sell("story_tool", session.inventory, session.gear_owned, session.equipped).is_empty(), "campaign instrument cannot be accidentally sold as ordinary stock")
	await speak(game, "mentor")
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 2 and not game.world.campaign_action("inspect"), "separate keyboard acceptance starts the task and rejects remote observation")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(1750, 340))
	check(session.region == "terrace" and game.world.player.health == 52 and session.world_state.commission.stage == 0, "main episode is reached through real portals without optional prerequisites or free healing")
	await speak(game, "witness")
	check(button(game, "story_hear") != null, "essential witness provides an actual recorded conversation")
	await enter()
	game.world.player.position = game.world.definition.story_sites.marks
	game.world.interact()
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 3 and "story:lake:heard" in session.gathered and "story:lake:marks" in session.gathered, "two physical sources prepare the mechanism in the real scene")
	game.world.player.position = game.world.definition.story_sites.control
	game.world.interact()
	check(button(game, "story_manual").disabled and not game.world.campaign_action("manual"), "unconfigured real mechanism cannot grant evidence")
	game.world.player.stamina = 100
	button(game, "story_turn_b").pressed.emit()
	await settle()
	check(Rules.positions(session.gathered) == [0, 1, 0] and button(game, "story_turn_b").has_focus(), "turn updates real persistent state and retains keyboard focus on the selected control")
	var scroll: ScrollContainer = button(game, "story_turn_b").get_parent().get_parent()
	check(scroll.scroll_horizontal == 0 and scroll.get_h_scroll_bar().max_value <= scroll.size.x, "mechanism actions preserve fully visible descriptions without horizontal scrolling")
	var stamina: float = game.world.player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.campaign_action("turn_b") and Rules.positions(session.gathered) == [0, 1, 0] and game.world.player.stamina == stamina, "failed dial write preserves prior position and stamina")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	button(game, "story_turn_a").pressed.emit()
	check(Rules.positions(session.gathered) == [1, 2, 0] and game.world.player.stamina == 94 and game.world.campaign_devices.control.settings == [1, 2, 0], "actual controls apply advertised effort and visible authored dial configuration")
	check(session.load_saved() and Rules.positions(session.gathered) == [1, 2, 0] and session.vitals.health == 52, "dial positions and actual wounds load from real disk")
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
	check(game.world.campaign_devices.control.settings == [1, 2, 0], "rebuilt scene restores visible dial orientation")
	game.world.interact()
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.campaign_action("manual") and Rules.stage(session.gathered, session.opened) == 3, "failed evidence write never records an uncommitted solution")
	DirAccess.remove_absolute("user://save.json.tmp")
	button(game, "story_manual").pressed.emit()
	check(Rules.stage(session.gathered, session.opened) == 4 and session.defeated.is_empty(), "human mechanism route confirms evidence without obligatory killing or transformation")
	check(not game.world.campaign_action("turn_a"), "committed evidence cannot be broken by subsequent control changes")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(1750, 1120))
	await speak(game, "mentor")
	var prior_xp: int = session.xp
	button(game, "story_report_share").pressed.emit()
	check(button(game, "story_confirm_report_share") != null and session.xp == prior_xp, "report explains reward consequences before committing")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.campaign_action("report_share") and session.xp == prior_xp, "failed report cannot grant experience or a story outcome")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 5 and session.xp == prior_xp + 80 and session.inventory.coin == 15 and session.world_state.reputation.roadfolk == 2, "keyboard report commits exactly one explained outcome")
	check(not game.world.campaign_action("report_provision") and session.inventory.story_tool == 1, "other reward cannot be farmed and personal instrument remains")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and session.inventory.story_tool == 1 and Rules.stage(session.gathered, session.opened) == 5 and session.xp == prior_xp + 80, "death checkpoint restores completed campaign state without duplicating reward")
	print("Campaign gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
