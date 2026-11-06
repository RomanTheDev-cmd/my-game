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

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	await physics_frame
	var player = game.world.player
	player.position = Vector2(600, 550)
	player.facing = Vector2.RIGHT
	var enemy: Node
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/actors/enemy.gd"):
			enemy = child
			break
	if enemy:
		enemy.position = Vector2(680, 550)
		enemy.home = enemy.position
	if not InputMap.has_action("cast"):
		InputMap.add_action("cast")
	Input.action_press("cast")
	await physics_frame
	await physics_frame
	Input.action_release("cast")
	check(player.mana < 83, "casting light bolt consumes actual player mana")
	check(get_nodes_in_group("spell_projectiles").size() == 1, "cast creates one real projectile")
	for i in 25:
		await physics_frame
	if enemy:
		check(enemy.health == 51, "projectile damages a real enemy once")
	check(get_nodes_in_group("spell_projectiles").is_empty(), "projectile disappears on impact")
	var wall := StaticBody2D.new()
	wall.position = Vector2(640, 550)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 80)
	shape.shape = box
	wall.add_child(shape)
	game.world.add_child(wall)
	await physics_frame
	player.magic_cooldown = 0
	player.mana = 100
	player.position = Vector2(600, 550)
	check(player.cast_magic("light"), "ready character can cast again")
	for i in 25:
		await physics_frame
	if enemy:
		check(enemy.health == 51, "wall blocks projectile damage")
	check(get_nodes_in_group("spell_projectiles").is_empty(), "wall absorbs projectile")
	player.magic_cooldown = 0
	player.mana = 0
	check(not player.cast_magic("light") and get_nodes_in_group("spell_projectiles").is_empty(), "insufficient mana never creates a projectile")
	var session := root.get_node("Session")
	session.inventory = {"herb": 3}
	check(session.craft_item("potion"), "actual session crafts from collected ingredients")
	player.health = 100
	check(not player.drink_potion() and session.inventory.potion == 1, "full health does not waste potion")
	player.health = 20
	check(player.drink_potion() and player.health == 80 and session.inventory.potion == 0, "potion heals actual character and is consumed once")
	check(not player.drink_potion() and player.health == 80, "empty inventory cannot heal again")
	print("Magic checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
