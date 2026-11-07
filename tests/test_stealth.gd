extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Navigation = preload("res://scripts/world/navigation_grid.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	Fixture.vampire(session)
	session.nature.gift = "blood_mist"
	session.gathered.append_array(["flight:bat", "flight:mist"])
	session.opened.append("waterworks_flight")
	var arena := Node2D.new()
	root.add_child(arena)
	var player = load("res://scripts/actors/player.gd").new()
	player.position = Vector2(500, 500)
	arena.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.shift_form("mist")
	for script in ["enemy", "ranged_enemy", "heavy_enemy"]:
		var enemy = load("res://scripts/actors/" + script + ".gd").new()
		enemy.position = Vector2(350, 500)
		enemy.target = player
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy._physics_process(1.0 / 60)
		check(enemy.velocity == Vector2.ZERO and enemy.state == "idle", "mist at 150 is unseen by fresh ordinary enemy " + script)
		player.shift_form()
		enemy._physics_process(0.01)
		check(enemy.awareness_time == 4 and enemy.detects_target(), "ordinary body retains normal detection " + script)
		player.shift_form("mist")
		enemy.state = "idle"
		enemy._physics_process(0.1)
		check(enemy.detects_target() and enemy.awareness_time > 3, "changing shape does not instantly erase pursuit " + script)
		enemy.state = "idle"
		enemy.awareness_time = 0.05
		enemy._physics_process(0.1)
		check(not enemy.detects_target() and enemy.state == "idle", "mist outside reduced sight loses pursuit after memory expires " + script)
		var previous: float = enemy.health
		enemy.receive_damage(0, Vector2.ZERO)
		enemy.receive_damage(NAN, Vector2.ZERO)
		check(enemy.awareness_time == 0 and enemy.health == previous, "invalid or blocked damage cannot manufacture aggro " + script)
		enemy.receive_damage(1, Vector2.ZERO)
		enemy._physics_process(0.1)
		check(enemy.detects_target() and enemy.awareness_time > 3, "real hit alerts the enemy even outside reduced sight " + script)
		player.position = enemy.position + Vector2(30, 0)
		player.health = 100
		player.hurt_time = 0
		enemy.state = "windup"
		enemy.timer = 0.01
		enemy.attack_origin = enemy.position
		enemy.attack_direction = Vector2.RIGHT
		enemy._physics_process(0.02)
		for frame in 20: await physics_frame
		check(player.health < 100 and enemy.state == "recover", "mist cannot cancel an already committed melee or ranged attack " + script)
		player.position = Vector2(500, 500)
		enemy.queue_free()
		await process_frame
	var wall := StaticBody2D.new()
	wall.position = Vector2(475, 500)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 100)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	var hidden = load("res://scripts/actors/enemy.gd").new()
	hidden.position = Vector2(450, 500)
	hidden.target = player
	arena.add_child(hidden)
	hidden.set_physics_process(false)
	var navigation := Navigation.new()
	navigation.configure(arena)
	hidden.navigation = navigation
	await physics_frame
	await physics_frame
	hidden._physics_process(0.1)
	check(hidden.awareness_time == 0 and hidden.state == "idle", "solid wall blocks first mist detection even inside reduced range")
	wall.queue_free()
	await process_frame
	navigation.configure(arena)
	hidden._physics_process(0.1)
	check(hidden.detects_target() and hidden.state == "idle", "nearby mist is detected when the real obstruction is removed")
	player.shift_form()
	check(player.visibility_scale() == 1, "human body keeps normal visibility")
	player.shift_form("bat")
	check(player.visibility_scale() == 1, "bat does not inherit mist concealment")
	player.shift_form("mist")
	var boss = load("res://scripts/actors/boss_enemy.gd").new()
	boss.position = Vector2(300, 700)
	boss.target = player
	boss.armed = true
	arena.add_child(boss)
	boss.set_physics_process(false)
	player.position = Vector2(500, 700)
	boss.engaged = true
	boss._physics_process(0.1)
	check(boss.engaged and (boss.velocity != Vector2.ZERO or boss.state == "windup"), "engaged boss keeps its own pursuit in mist")
	arena.queue_free()
	await process_frame
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	Fixture.vampire(session)
	session.nature.gift = "blood_mist"
	session.gathered.append_array(["flight:bat", "flight:mist"])
	session.opened.append("waterworks_flight")
	session.region = "lake"
	session.arrival = Vector2(360, 610)
	game._build_world()
	game.resume()
	await physics_frame
	await physics_frame
	game.world.player.shift_form("mist")
	var threat = load("res://scripts/actors/enemy.gd").new()
	threat.position = game.world.player.position + Vector2(150, 0)
	threat.target = game.world.player
	game.world.add_child(threat)
	threat.set_physics_process(false)
	threat._physics_process(0.01)
	check(threat.awareness_time == 0 and not game.world.safe_to_rest(), "concealment does not make nearby threat safe for saving or rest")
	print("Stealth checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
