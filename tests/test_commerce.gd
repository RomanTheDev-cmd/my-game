extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func find_button(game: Node, name: String) -> Button:
	for button in game.screen.find_children("*", "Button", true, false):
		if button.name == name:
			return button
	return null

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	var player = game.world.player
	player.position = Vector2(235, 500)
	session.inventory["coin"] = 30
	game.world.interact()
	check(game.current_screen == "shop" and paused, "merchant opens a paused shop")
	await process_frame
	var bottom := find_button(game, "trade_iron_shield")
	if bottom:
		bottom.grab_focus()
		await process_frame
		await process_frame
		var scroll: Node = bottom.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		check(scroll != null and scroll.get_global_rect().intersects(bottom.get_global_rect()), "keyboard focus scrolls distant shop action into view")
	var sword := find_button(game, "trade_iron_sword")
	check(sword != null and not sword.disabled, "affordable equipment is offered")
	if sword:
		sword.pressed.emit()
	check(session.inventory.coin == 15 and "iron_sword" in session.gear_owned, "actual purchase transfers money and gear")
	check(session.equipped.weapon == "road_sword", "purchase does not silently equip item")
	game.show_equipment()
	var equip := find_button(game, "equip_iron_sword")
	if equip:
		equip.pressed.emit()
	check(session.equipped.weapon == "iron_sword", "equipment screen equips owned weapon")
	var enemy: Node
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/actors/enemy.gd"):
			enemy = child
			break
	if enemy:
		var before: Vector2 = enemy.position
		enemy.position = player.position + Vector2(40, 0)
		game.world._on_strike(player.position, Vector2.RIGHT)
		check(enemy.health == 39, "equipped weapon modifies actual strike damage")
		enemy.position = before
	session.inventory.coin = 20
	check(game.world.trade("chain", false), "merchant sells armor through real world transaction")
	check(session.equip_item("chain"), "owned armor equips")
	player.restore()
	player.hurt_time = 0
	player.receive_damage(20)
	check(is_equal_approx(player.health, 84.8), "armor reduces incoming damage")
	session.inventory.coin = 12
	check(game.world.trade("iron_shield", false) and session.equip_item("iron_shield"), "shield purchase and equip succeed")
	player.restore()
	player.hurt_time = 0
	player.blocking = true
	player.receive_damage(20)
	check(is_equal_approx(player.health, 97.72), "shield and armor combine in real block")
	player.blocking = false
	session.inventory.coin = 30
	var previous_owned: Array = session.gear_owned.duplicate()
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.trade("herb", false), "disk failure rejects trade")
	check(session.inventory.coin == 30 and session.gear_owned == previous_owned, "failed trade never partially charges player")
	DirAccess.remove_absolute("user://save.json.tmp")
	player.position = Vector2(600, 550)
	check(not game.world.trade("herb", false), "cannot trade remotely from merchant")
	player.position = Vector2(235, 500)
	session.inventory["herb"] = 1
	load("res://scripts/ui/equipment_screen.gd").shop(game, true)
	var sell := find_button(game, "trade_herb")
	if sell:
		sell.pressed.emit()
	check(session.inventory.get("herb") == 0 and session.inventory.coin == 31, "sell-mode button executes and persists the actual sale")
	print("Commerce integration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
