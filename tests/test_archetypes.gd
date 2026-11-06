extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
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
	var arena := Node2D.new()
	root.add_child(arena)
	var player = load("res://scripts/actors/player.gd").new()
	player.position = Vector2(400, 300)
	arena.add_child(player)
	player.set_physics_process(false)
	var ranged = load("res://scripts/actors/ranged_enemy.gd").new()
	ranged.position = Vector2(200, 300)
	ranged.target = player
	arena.add_child(ranged)
	ranged.set_physics_process(false)
	check(ranged.health == 60 and ranged.aggro_range == 320, "ranged enemy has distinct health and awareness")
	for i in 150:
		ranged._physics_process(1.0 / 60)
		await physics_frame
	check(player.health == 84, "telegraphed ranged attack sends a real damaging arrow")
	var original: Vector2 = ranged.position
	player.position = ranged.position + Vector2(50, 0)
	ranged.state = "idle"
	ranged.timer = 0
	ranged._physics_process(1.0 / 60)
	check(ranged.position.x < original.x, "ranged enemy retreats when player closes distance")
	ranged.queue_free()
	for projectile in get_nodes_in_group("hostile_projectiles"):
		projectile.queue_free()
	await physics_frame
	player.position = Vector2(400, 300)
	player.restore()
	player.hurt_time = 0
	var wall := StaticBody2D.new()
	wall.position = Vector2(300, 300)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15, 100)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	await physics_frame
	var arrow = load("res://scripts/combat/hostile_arrow.gd").new()
	arrow.position = Vector2(200, 300)
	arena.add_child(arrow)
	for i in 70:
		await physics_frame
	check(player.health == 100 and get_nodes_in_group("hostile_projectiles").is_empty(), "wall absorbs hostile projectile before it reaches player")
	wall.queue_free()
	await physics_frame
	player.blocking = true
	player.hurt_time = 0
	arrow = load("res://scripts/combat/hostile_arrow.gd").new()
	arrow.position = Vector2(350, 300)
	arena.add_child(arrow)
	for i in 25:
		await physics_frame
	check(player.health == 96, "shield blocks hostile arrow through normal damage rules")
	player.blocking = false
	player.restore()
	player.hurt_time = 0
	player.position = Vector2(300, 600)
	var heavy = load("res://scripts/actors/heavy_enemy.gd").new()
	heavy.position = Vector2(240, 600)
	heavy.target = player
	arena.add_child(heavy)
	heavy.set_physics_process(false)
	check(heavy.health == 180 and heavy.windup_duration == 1.0, "heavy enemy has increased health and a longer telegraph")
	heavy.state = "windup"
	heavy.timer = 0.01
	heavy.attack_origin = heavy.position
	heavy.attack_direction = Vector2.RIGHT
	heavy._physics_process(0.02)
	check(player.health == 68 and heavy.state == "recover", "heavy sweep has distinct reach and damage with recovery")
	print("Enemy archetype checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
