extends SceneTree
var failures := 0
var checks := 0

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
	var session := root.get_node("Session")
	for route in ["herbs", "coins", "magic"]:
		game.new_game()
		session.region = "lake"
		session.arrival = Vector2(480, 620)
		session.inventory = {"herb": 3, "coin": 8}
		game._build_world()
		game.world.interact()
		check(game.current_screen == "dialog" and paused, "second NPC opens own dialogue")
		for child in game.screen.get_children():
			if child is Button and child.text == TranslationServer.translate("AID_ACCEPT"):
				child.pressed.emit()
				break
		check(session.aid_quest == 1, "dialogue starts independent side quest")
		var label: String = "AID_" + route.to_upper()
		for child in game.screen.get_children():
			if child is Button and child.text == TranslationServer.translate(label):
				check(not child.disabled, "available alternative remains actionable")
				child.pressed.emit()
				break
		check(session.aid_quest == 2 and session.quest == 0, "alternative completes side quest without changing main quest")
		check(session.xp == 30, "alternative grants one experience reward")
		if route == "herbs":
			check(session.inventory.herb == 0 and session.inventory.coin == 8, "herb route consumes only herbs")
		elif route == "coins":
			check(session.inventory.coin == 0 and session.inventory.herb == 3, "coin route consumes only coins")
		else:
			check(game.world.player.mana == 65 and session.inventory.herb == 3 and session.inventory.coin == 8, "magic route spends focus instead of inventory")
		check(not game.world.aid_choice(route) and session.xp == 30, "completed branch cannot duplicate reward")
		check(session.load_saved() and session.aid_quest == 2, "branch result survives real save and reload")
	game.new_game()
	session.region = "lake"
	session.arrival = Vector2(480, 620)
	game._build_world()
	game.world.player.mana = 0
	game.world.aid_choice("accept")
	check(not game.world.aid_choice("magic") and session.aid_quest == 1, "missing focus cannot bypass branch condition")
	check(not game.world.aid_choice("herbs") and session.aid_quest == 1, "missing herbs do not consume a partial cost")
	check(not game.world.aid_choice("coins") and session.aid_quest == 1, "missing coins do not complete quest")
	print("Alternative quest checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
