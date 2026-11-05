extends SceneTree
var checks := 0
var failures := 0
var game: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var session := root.get_node("Session")
	check(paused and game.current_screen == "title", "game starts in menu")
	check(TranslationServer.translate("NEW_GAME") == "Начать путешествие", "Russian locale resolves UI key")
	game.new_game()
	await physics_frame
	var player = game.world.player
	var start: Vector2 = player.position
	Input.action_press("move_right")
	for i in 12:
		await physics_frame
	Input.action_release("move_right")
	check(player.position.x > start.x + 10, "mapped action moves the actual player")
	game.show_pause()
	start = player.position
	Input.action_press("move_right")
	for i in 4:
		await physics_frame
	Input.action_release("move_right")
	check(player.position == start, "pause prevents world movement")
	game.resume()
	player.blocking = true
	player.receive_damage(20)
	check(player.health == 95, "player receives blocked damage through combat rules")
	player.hurt_time = 0
	player.dodge_time = 0.2
	player.receive_damage(20)
	check(player.health == 95, "actual player dodge prevents incoming damage")
	player.restore()
	player.dodge_time = 0
	player.position = Vector2(480, 490)
	game.world.interact()
	check(game.current_screen == "dialog" and paused, "nearby interaction opens dialogue and pauses combat")
	# Activate the actual accept button rather than setting its result directly.
	var accept: Button
	for child in game.screen.get_children():
		if child is Button and child.text == TranslationServer.translate("ACCEPT"):
			accept = child
	check(accept != null, "quest offers an actionable acceptance")
	if accept:
		accept.pressed.emit()
	check(session.quest == 1 and not paused, "accepting advances the quest")
	player.position = Vector2(1240, 420)
	game.world.interact()
	check(session.quest == 2 and session.inventory.get("lantern") == 1, "interacting with objective collects it")
	game.world.interact()
	check(session.inventory.get("lantern") == 1, "objective cannot be collected twice")
	player.position = Vector2(650, 670)
	game.world.interact()
	check(session.inventory.get("herb") == 1, "herb pickup changes inventory")
	player.position = Vector2(440, 470)
	game.world.interact()
	check(not session.checkpoint.is_empty(), "camp interaction creates a checkpoint")
	check(session.load_saved(), "checkpoint loads from real user storage")
	game._build_world()
	player = game.world.player
	check(not game.world.herbs[0].visible, "gathered resource stays gathered after reload")
	check(not game.world.lantern.visible, "objective stays collected after reload")
	var enemy: Node
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/actors/enemy.gd"):
			enemy = child
			break
	if enemy:
		player.restore()
		player.hurt_time = 0
		player.position = enemy.position + Vector2(25, 0)
		enemy.state = "windup"
		enemy.timer = 0.01
		enemy.attack_origin = enemy.position
		enemy.attack_direction = Vector2.RIGHT
		enemy._physics_process(0.02)
		check(player.health == 80, "telegraphed enemy attack hits a nearby forward target")
		check(enemy.state == "recover", "enemy recovers rather than hitting every frame")
		player.hurt_time = 0
		player.position = enemy.position + Vector2(80, 0)
		enemy.state = "windup"
		enemy.timer = 0.01
		enemy._physics_process(0.02)
		check(player.health == 80, "stepping out of telegraph avoids enemy hit")
		player.position = enemy.position + Vector2(25, 0)
		player.dodge_time = 0.2
		enemy.state = "windup"
		enemy.timer = 0.01
		enemy._physics_process(0.02)
		check(player.health == 80, "dodge avoids an actual enemy attack")
		player.dodge_time = 0
		player.position = enemy.position - Vector2(25, 0)
		game.world._on_strike(player.position, Vector2.RIGHT)
		check(enemy.health == 47, "player strike damages enemy within forward arc")
		game.world._on_strike(player.position, Vector2.LEFT)
		check(enemy.health == 47, "back-facing strike misses enemy")
		enemy.receive_damage(100, Vector2.RIGHT)
		check(enemy.id in session.defeated, "defeat persists enemy identity")
	player.position = Vector2(480, 490)
	game.show_dialog()
	for child in game.screen.get_children():
		if child is Button and child.text == TranslationServer.translate("GIVE_LANTERN"):
			child.pressed.emit()
			break
	check(session.quest == 3 and not session.inventory.has("lantern"), "turn-in completes quest and removes item")
	game.resume()
	player.hurt_time = 0
	player.blocking = false
	player.receive_damage(200)
	check(game.current_screen == "death" and paused, "lethal damage opens recoverable death screen")
	for child in game.screen.get_children():
		if child is Button:
			child.pressed.emit()
			break
	check(game.world.player.health == 100 and not paused, "retry restores health and resumes")
	check(session.quest == 3, "checkpoint restore preserves completed quest")
	game.show_title()
	game.show_settings()
	for child in game.screen.get_children():
		if child is Button and child.text == TranslationServer.translate("BACK"):
			child.pressed.emit()
			break
	check(game.current_screen == "title", "settings opened from title return to title")
	print("Gameplay checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
