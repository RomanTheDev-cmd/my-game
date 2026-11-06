extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/combat/boss_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func prepare(boss: Node, player: Node, kind: String, offset: Vector2) -> void:
	player.restore()
	player.blocking = false
	player.set_physics_process(false)
	boss.position = Vector2(400, 600)
	boss.home = boss.position
	player.position = boss.position + offset
	boss.engaged = false
	boss.armed = true
	boss.health = 420
	boss.phase = 1
	boss.state = "idle"
	boss.attack_index = 0
	boss._begin_attack()
	boss.attack_spec = Rules.attack(2, {"sweep": 0, "pulse": 1, "charge": 2}[kind])
	boss.timer = boss.attack_spec.windup
func run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player = load("res://scripts/actors/player.gd").new()
	arena.add_child(player)
	player.set_physics_process(false)
	var boss = load("res://scripts/actors/boss_enemy.gd").new()
	boss.target = player
	arena.add_child(boss)
	boss.set_physics_process(false)
	boss.receive_damage(50, Vector2.RIGHT)
	check(boss.health == 420, "dormant encounter cannot be killed before preparation")
	var session := root.get_node("Session")
	for difficulty in [0, 1, 2]:
		session.difficulty = difficulty
		prepare(boss, player, "sweep", Vector2(80, 0))
		boss._physics_process(0.3)
		check(player.health == 100 and boss.state == "windup", "telegraph never applies damage before its timer")
		boss._physics_process(0.7)
		check(is_equal_approx(player.health, [84.4, 74.0, 64.9][difficulty]) and boss.state == "recover", "sweep uses real damage settings for every difficulty: health=%s block=%s" % [player.health, player.blocking])
		prepare(boss, player, "pulse", Vector2(0, 100))
		player.blocking = true
		boss._physics_process(1.3)
		check(is_equal_approx(player.health, [96.4, 94.0, 91.9][difficulty]) and player.stamina == 77, "radial strike respects actual block and stamina")
		prepare(boss, player, "sweep", Vector2(80, 0))
		player.dodge_time = 0.2
		boss._physics_process(1.0)
		check(player.health == 100, "actual dodge avoids boss strike on every difficulty")
	session.difficulty = 1
	prepare(boss, player, "sweep", Vector2(80, 0))
	player.position = boss.position + Vector2(-40, 0)
	boss._physics_process(1.0)
	check(player.health == 100, "locked attack direction does not track the dodged target")
	prepare(boss, player, "pulse", Vector2(0, 100))
	player.position.y += 100
	boss._physics_process(1.3)
	check(player.health == 100, "moving beyond warning circle avoids pulse")
	prepare(boss, player, "sweep", Vector2(80, 0))
	boss.state = "recover"
	boss.receive_damage(40, Vector2.RIGHT)
	check(boss.health == 366, "counterattack during exposed recovery deals bonus damage")
	boss.state = "windup"
	boss.receive_damage(40, Vector2.RIGHT)
	check(boss.health == 344, "armored telegraph still permits reduced damage")
	boss.state = "idle"
	boss.receive_damage(140, Vector2.RIGHT)
	check(boss.phase == 2 and boss.state == "recover" and boss.timer == 1.7, "crossing half health changes phase and grants a fair transition window")
	boss.apply_slow(4, 0.55)
	check(boss.slow_remaining == 4 and boss.slow_multiplier == 0.55, "frost remains a usable state effect on the boss")
	prepare(boss, player, "sweep", Vector2(520, 0))
	boss.state = "idle"
	boss.receive_damage(10, Vector2.RIGHT)
	boss._physics_process(0.02)
	check(boss.velocity.x > 0, "distant spell damage acquires target instead of allowing free attacks outside aggro")
	prepare(boss, player, "charge", Vector2(130, 0))
	boss.slow_remaining = 0
	boss._physics_process(1.2)
	for i in 48:
		boss._physics_process(1.0 / 60)
		await physics_frame
	check(player.health == 70 and boss.state == "recover", "physical charge crosses target once and opens recovery: health=%s block=%s state=%s" % [player.health, player.blocking, boss.state])
	var wall := StaticBody2D.new()
	wall.position = Vector2(500, 600)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 170)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	var navigation = load("res://scripts/world/navigation_grid.gd").new()
	navigation.configure(arena)
	boss.navigation = navigation
	prepare(boss, player, "pulse", Vector2(130, 0))
	boss._physics_process(1.3)
	check(player.health == 100, "stone obstacle blocks radial damage through actual navigation geometry")
	prepare(boss, player, "sweep", Vector2(100, 0))
	boss._physics_process(1.0)
	check(player.health == 100, "stone obstacle also blocks committed close attack")
	prepare(boss, player, "charge", Vector2(180, 0))
	boss._physics_process(1.2)
	for i in 48:
		boss._physics_process(1.0 / 60)
		await physics_frame
	check(player.health == 100 and boss.position.x < 490 and boss.state == "recover", "real collision stops charge at the wall without hitting through it")
	boss.health = 50
	boss.phase = 2
	boss.navigation = null
	boss.position = Vector2(1000, 600)
	boss.home = Vector2(400, 600)
	player.position = Vector2(1200, 650)
	boss._physics_process(0.02)
	check(boss.health == 420 and boss.phase == 1 and boss.state == "idle", "far retreat restores a repeatable encounter instead of preserving free damage")
	var victories := [0]
	boss.victory_requested.connect(func(): victories[0] += 1)
	boss.health = 2
	boss.receive_damage(100, Vector2.RIGHT)
	boss.receive_damage(100, Vector2.RIGHT)
	check(victories[0] == 1 and boss.awaiting_record and is_instance_valid(boss), "unrecorded victory requests commit once and keeps retryable world object")
	print("Boss combat checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
