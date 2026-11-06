extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
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
func game_key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)
		await physics_frame
		await physics_frame
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await process_frame
	await process_frame
func talk_nature(game: Node, kind: String, entry: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[kind].position
	game.world.interact()
	var continuation := button(game, "dialogue_continue")
	if continuation != null: continuation.pressed.emit()
	var link := button(game, entry)
	check(link != null, "nature task remains reachable through the actual NPC dialogue")
	if link != null: link.pressed.emit()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(session.nature.kind == "human" and session.nature.stage == 0, "new game does not offer a starting transformation")
	Fixture.completed_episode(session)
	session.region = "lake"
	session.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	await talk_nature(game, "wayfarer", "nature_invitation")
	check(button(game, "nature_invite") != null and button(game, "nature_vampire") == null, "first explanation asks no immediate transformation")
	await enter()
	check(session.nature.stage == 1 and session.nature.kind == "human", "keyboard invitation leaves ordinary human nature intact")
	check(not game.world.nature_action("vampire") and not game.world.nature_action("garden"), "backend rejects unprepared or remote nature choices")
	await portal(game, Vector2(1750, 1120))
	check(session.region == "workshop", "preparation uses existing real region connection")
	await talk_nature(game, "tender", "nature_garden")
	await enter()
	check("nature:garden" in session.gathered and session.nature.stage == 1, "first physical conversation does not replace both preparations")
	await portal(game, Vector2(1800, 420))
	game.world.player.position = Vector2(820, 650)
	game.world.interact()
	check(button(game, "nature_water") != null, "real altar offers separate nature investigation")
	button(game, "nature_water").pressed.emit()
	await enter()
	check(session.nature.stage == 2 and session.nature.kind == "human", "completed explanations still leave final nature undecided")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await talk_nature(game, "wayfarer", "nature_invitation")
	check(button(game, "nature_human") != null and button(game, "nature_vampire") != null, "both lasting paths are visibly available together")
	button(game, "nature_vampire").pressed.emit()
	check(session.nature.kind == "human" and button(game, "nature_confirm_vampire") != null, "reviewing consequences does not itself transform the player")
	await enter()
	check(session.nature.kind == "vampire" and session.nature.history == ["vampire"] and session.xp == 220, "explicit keyboard confirmation commits the chosen nature once")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	check(game.current_screen == "death", "transformed character uses normal death flow")
	await enter()
	check(session.nature.kind == "vampire" and game.world.player.health == 100, "death retry preserves permanent nature instead of undoing the decision")
	await game_key(KEY_U)
	check(session.nature.form == "battle", "keyboard U enters the unlocked combat shape")
	game.world.player.position = game.world.npcs.wayfarer.position
	game.world.interact()
	check(button(game, "dialogue_return_form") != null, "NPC reacts to beastly appearance and offers accessible return rather than locking the quest")
	await enter()
	check(session.nature.form == "human" and button(game, "dialogue_continue") != null, "keyboard return to humanoid shape restores normal conversation access")
	game.resume()
	session.nature.blood = 30
	game.world.player.position = game.world.npcs.wayfarer.position
	game.show_nature("wayfarer")
	var supply := button(game, "nature_supply")
	check(supply != null and not supply.disabled, "consensual blood supply is available through actual path NPC")
	supply.pressed.emit()
	check(session.inventory.coin == 18 and session.nature.blood > 69, "supply spends coins and raises bounded resource")
	await portal(game, Vector2(135, 650))
	await talk_nature(game, "keeper", "nature_keeper")
	await enter()
	check(session.nature.cure == 1 and session.nature.kind == "vampire", "return starts a separate persisted procedure without instant cure")
	await portal(game, Vector2(1800, 500))
	await portal(game, Vector2(1750, 1120))
	await talk_nature(game, "tender", "nature_garden")
	await enter()
	check("nature:release_garden" in session.gathered, "return requires its own garden action rather than reusing first preparation")
	await portal(game, Vector2(1800, 420))
	game.world.player.position = Vector2(820, 650)
	game.world.interact()
	button(game, "nature_water").pressed.emit()
	await enter()
	check(session.nature.cure == 2 and session.nature.kind == "vampire", "both return actions prepare but do not execute final ritual")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await talk_nature(game, "keeper", "nature_keeper")
	button(game, "nature_cure_finish").pressed.emit()
	check(session.nature.kind == "vampire" and button(game, "nature_confirm_cure_finish") != null, "permanent loss of supernatural powers requires its own explicit confirmation")
	var mana_before: float = game.world.player.mana
	await enter()
	check(session.nature.kind == "human" and session.nature.gift == "scar" and session.nature.history == ["vampire"], "completed return preserves personal history with a distinct human gift")
	check(game.world.player.mana <= mana_before - 29 and session.xp == 260, "ritual spends actual player mana and grants only its one final reward")
	check(not game.world.nature_action("vampire") and not game.world.nature_action("cure_finish"), "returned nature cannot be switched back or rewarded repeatedly")
	check(session.load_saved() and session.nature.gift == "scar", "full return survives disk reload")
	game._build_world()
	game.show_nature()
	check(button(game, "nature_power") != null and button(game, "nature_shift") == null, "returned human UI exposes its own ability and removes lost form")
	Fixture.completed_episode(session)
	session.gathered.append_array(["nature:water", "nature:garden"])
	session.nature.stage = 2
	session.region = "lake"
	session.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	game.show_nature("wayfarer")
	button(game, "nature_human").pressed.emit()
	await enter()
	check(session.nature.kind == "human" and session.nature.gift == "oath" and session.nature.history.is_empty(), "declining transformation produces lasting distinct human specialization")
	game.show_nature()
	button(game, "nature_power").pressed.emit()
	check(game.world.player.shield_strength == 45 and game.world.player.mana <= 68, "human path power is usable from actual keyboard-friendly ability page")
	check(not game.world.nature_action("vampire"), "human decision is not a free nature toggle")
	var open_key := InputEventKey.new()
	open_key.physical_keycode = KEY_N
	open_key.keycode = KEY_N
	open_key.pressed = true
	root.push_input(open_key)
	await process_frame
	check(game.current_screen == "nature", "physical N key opens nature description through actual input routing")
	game.resume()
	game.world.player.nature_cooldown = 0
	game.world.player.mana = 100
	await game_key(KEY_V)
	check(game.world.player.shield_strength == 45 and game.world.player.mana < 69, "physical V key applies actual human ability without a gamepad")
	print("Nature gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
