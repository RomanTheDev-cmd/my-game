extends SceneTree
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	var before: float = session.world_state.minutes
	for i in 6:
		await physics_frame
	check(session.world_state.minutes > before, "active gameplay advances actual world clock")
	game.show_pause()
	before = session.world_state.minutes
	for i in 6:
		await physics_frame
	check(session.world_state.minutes == before, "menu pauses clock and schedules")
	game.resume()
	game.world.player.position = Vector2(600, 550)
	check(not game.world.wait(60) and session.world_state.minutes == before, "cannot skip time away from camp")
	game.world.player.position = Vector2(440, 470)
	game.world.player.health = 50
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.wait(60) and session.world_state.minutes == before and game.world.player.health == 50, "failed rest save cannot heal or advance time")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(game.world.wait(60) and is_equal_approx(session.world_state.minutes, before + 60) and game.world.player.health == 100, "camp rest advances time and restores character after successful save")
	session.world_state.minutes = 1380
	game.world._update_npcs()
	game.world.player.position = game.world.merchant.position
	session.inventory["coin"] = 50
	game.world.interact()
	check(game.current_screen == "dialog" and paused, "night merchant explains closure instead of vanishing")
	check(not game.world.trade("herb", false) and session.inventory.coin == 50, "night closure enforced by transaction, not just UI")
	game.resume()
	var merchant = game.world.merchant
	var distance: float = merchant.position.distance_to(merchant.destination)
	merchant.set_physics_process(false)
	for i in 180:
		merchant._physics_process(1.0 / 60)
		await physics_frame
	check(merchant.position.distance_to(merchant.destination) < distance * 0.4, "NPC physically walks toward scheduled rest position")
	check(game.world.keeper.visible, "essential quest giver remains present at night")
	game.world.save_safe()
	var saved_point: Vector2 = merchant.position
	var weather_before := Clock.weather(session.world_state.minutes, int(session.world_state.seed))
	check(session.load_saved(), "world clock and schedules reload from disk")
	game._build_world()
	check(game.world.merchant.position.distance_to(saved_point) < 0.01, "NPC in-transit position survives reload")
	check(Clock.weather(session.world_state.minutes, int(session.world_state.seed)) == weather_before, "weather cannot reroll after reload")
	game.world.player.position = game.world.keeper.position
	game.world.interact()
	check(game.current_screen == "dialog", "main quest conversation remains available at night")
	game.resume()
	game.world.player.position = Vector2(440, 470)
	game.show_wait()
	for child in game.screen.get_children():
		if child is Button and child.text == TranslationServer.translate("WAIT_MORNING"):
			child.pressed.emit()
			break
	check(Clock.hour(session.world_state.minutes) == 7 and game.current_screen == "game", "rest interface reaches morning and resumes play")
	game.new_game()
	session.world_state.active = {"id": "shelter", "region": "crossing", "position": [650, 600]}
	session.inventory = {"herb": 1}
	game.world.player.position = Vector2(650, 600)
	game.world._update_event_marker()
	game.world.interact()
	check(game.current_screen == "dialog" and paused, "peaceful event opens an actual choice interface")
	for child in game.screen.get_children():
		if child is Button and child.text == TranslationServer.translate("EVENT_CHOICE_HERB"):
			child.pressed.emit()
			break
	check(session.inventory.herb == 0 and session.world_state.reputation.roadfolk == 1 and "shelter" in session.world_state.seen, "choice consumes cost and remembers consequence once")
	check(session.quest == 0 and session.aid_quest == 0, "random event never mutates protected quest stages")
	check(not game.world.resolve_encounter("herb"), "completed event cannot grant consequence twice")
	session.world_state.active = {"id": "lost_pack", "region": "crossing", "position": [650, 600]}
	game.world._update_event_marker()
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.resolve_encounter("return") and session.world_state.reputation.roadfolk == 1 and "lost_pack" not in session.world_state.seen, "failed outcome save preserves pending event and previous trust")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(game.world.resolve_encounter("return") and session.world_state.reputation.roadfolk == 3, "second remembered consequence unlocks reputation benefit")
	game.world.player.position = game.world.merchant.position
	session.inventory["coin"] = 5
	check(game.world.trade("herb", false) and session.inventory.coin == 4, "reputation discount changes actual paid price")
	check(session.load_saved() and session.world_state.seen.size() == 2 and session.world_state.reputation.roadfolk == 3, "event memory and reputation survive real reload")
	game.new_game()
	session.world_state.minutes = 1080
	session.world_state.next_event = 0
	game.world.player.position = Vector2(650, 600)
	game.world._poll_encounter()
	check(session.world_state.active.is_empty(), "event never appears immediately on top of player")
	game.world.player.position = Vector2(235, 500)
	game.world._poll_encounter()
	check(not session.world_state.active.is_empty(), "eligible event is placed outside current view")
	print("Living world integration checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
