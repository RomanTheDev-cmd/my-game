extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
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
	var ward := Magic.cast("aegis", 100, 100, 0)
	check(ward.get("mana") == 72, "protective spell can spend mana at full health")
	var frost := Magic.cast("frost", 100, 100, 0)
	check(frost.get("mana") == 76 and frost.get("damage") == 12, "control spell trades lower direct damage for slowing")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var session := root.get_node("Session")
	session.difficulty = 1
	game.new_game()
	await physics_frame
	var player = game.world.player
	player.set_physics_process(false)
	check(player.cast_magic("aegis") and player.shield_strength == 30 and player.mana == 72, "actual protective spell consumes mana and grants finite shield")
	player.receive_damage(20)
	check(player.health == 100 and player.shield_strength == 10, "shield absorbs actual incoming hit before health")
	player.magic_cooldown = 0
	check(not player.cast_magic("aegis") and player.mana == 72 and player.shield_strength == 10, "repeated shield cannot stack or consume mana during recharge")
	player.hurt_time = 0
	player.dodge_time = 0.2
	player.receive_damage(50)
	check(player.shield_strength == 10 and player.health == 100, "dodge does not waste shield strength")
	player.dodge_time = 0
	player.receive_damage(40)
	check(player.shield_strength == 0 and player.health == 70, "damage exceeding shield still reaches health")
	player.restore()
	player.cast_magic("aegis")
	player._physics_process(6.1)
	check(player.shield_strength == 0 and player.shield_time == 0 and not player.can_cast_magic("aegis"), "expired shield does not bypass its independent recharge")
	player._physics_process(4.0)
	check(player.can_cast_magic("aegis"), "shield becomes available when actual recharge expires")
	player.restore()
	check(player.shield_strength == 0 and player.shield_recharge == 0, "camp restoration clears transient shield state")

	var enemy: Node
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/actors/enemy.gd"):
			enemy = child
			break
	check(enemy != null, "control spell has an actual physical target")
	if enemy == null:
		await TestExit.finish(self, 1)
		return
	player.position = Vector2(600, 550)
	player.facing = Vector2.RIGHT
	enemy.position = Vector2(680, 550)
	enemy.home = enemy.position
	enemy.set_physics_process(false)
	check(player.cast_magic("frost") and player.mana == 76, "actual frost cast consumes its own cost")
	for i in 25:
		await physics_frame
	check(enemy.health == 63 and enemy.slow_remaining > 3, "frost projectile damages and slows the body it collides with")
	check(get_nodes_in_group("spell_projectiles").is_empty(), "control projectile cannot pass through target and hit twice")
	enemy.navigation = null
	check(is_equal_approx(enemy._steer(enemy.position + Vector2(100, 0), 100).length(), 55), "slow affects actual steering speed")
	enemy.apply_slow(4, 0.55)
	check(enemy.slow_remaining == 4 and enemy.slow_multiplier == 0.55, "repeat slow refreshes duration without multiplying strength")
	enemy._physics_process(1.0 / 60)
	check(is_equal_approx(enemy.velocity.length(), 31.9), "slowed melee AI uses reduced physical chase velocity")
	enemy._tick_slow(5)
	check(enemy.slow_remaining == 0 and is_equal_approx(enemy._steer(enemy.position + Vector2(100, 0), 100).length(), 100), "temporary slow expires and restores movement")
	var wall := StaticBody2D.new()
	wall.position = Vector2(640, 550)
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 80)
	collider.shape = box
	wall.add_child(collider)
	game.world.add_child(wall)
	await physics_frame
	player.restore()
	enemy.position = Vector2(680, 550)
	enemy.health = 75
	player.cast_magic("frost")
	for i in 25:
		await physics_frame
	check(enemy.health == 75 and enemy.slow_remaining == 0, "wall blocks both damage and control effect")
	player.magic_cooldown = 0
	player.mana = 0
	check(not player.cast_magic("frost") and get_nodes_in_group("spell_projectiles").is_empty(), "insufficient mana never spawns control projectile")
	var ranged = load("res://scripts/actors/ranged_enemy.gd").new()
	ranged.position = Vector2(1400, 1000)
	ranged.target = player
	game.world.add_child(ranged)
	ranged.set_physics_process(false)
	ranged.apply_slow(1, 0.55)
	ranged._physics_process(1.1)
	check(ranged.slow_remaining == 0, "ranged AI also expires inherited slow state")
	player.restore()
	var event := InputEventAction.new()
	event.action = "spellbook"
	event.pressed = true
	game._unhandled_input(event)
	check(game.current_screen == "spells" and paused, "keyboard action opens paused spellbook")
	var cast_button: Button = game.screen.find_child("cast_aegis", true, false)
	check(cast_button != null and not cast_button.disabled, "spellbook offers real available protective action")
	if cast_button != null:
		await process_frame
		await process_frame
		cast_button.grab_focus()
		for i in 3:
			await process_frame
		var list: Control = cast_button.get_parent()
		var scroll: ScrollContainer = list.get_parent()
		var details: Control = list.get_child(cast_button.get_index() + 1)
		check(scroll.get_global_rect().encloses(cast_button.get_global_rect()) and scroll.get_global_rect().encloses(details.get_global_rect()), "keyboard focus reveals the selected spell and its description together")
		cast_button.pressed.emit()
	check(game.current_screen == "game" and not paused and player.shield_strength == 30, "spellbook action resumes world and casts the selected spell")
	session.xp = 120
	session.skills = {"sword": 1, "ward": 1}
	player.restore()
	check(player.cast_magic("aegis") and player.shield_strength == 40, "existing defensive skill improves actual active protection")
	session.skills = {}
	for example in [[0, 18.0], [1, 10.0], [2, 3.0]]:
		session.difficulty = example[0]
		player.restore()
		player.cast_magic("aegis")
		player.receive_damage(20)
		check(player.health == 100 and is_equal_approx(player.shield_strength, example[1]), "shield absorbs damage after the selected difficulty multiplier")
	game.show_title()
	await process_frame
	game.queue_free()
	await process_frame
	await create_timer(0.1, true).timeout
	print("Defense magic checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
