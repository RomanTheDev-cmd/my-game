extends SceneTree
var failures := 0
var checks := 0
var arena: Node2D
var player: CharacterBody2D
var enemy: CharacterBody2D

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	var wall := StaticBody2D.new()
	wall.position = Vector2(290, 300)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 150)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	player = load("res://scripts/actors/player.gd").new()
	player.position = Vector2(370, 300)
	arena.add_child(player)
	player.set_physics_process(false)
	enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.position = Vector2(210, 300)
	enemy.target = player
	arena.add_child(enemy)
	if ResourceLoader.exists("res://scripts/world/navigation_grid.gd"):
		var navigation = load("res://scripts/world/navigation_grid.gd").new()
		navigation.configure(arena)
		enemy.navigation = navigation
		check(not navigation.segment_clear(Vector2(210, 300), Vector2(370, 300)), "wall blocks a direct melee line")
		check(navigation.find_path(Vector2(210, 300), Vector2(290, 300)).is_empty(), "cannot route into a solid wall")
		check(navigation.find_path(Vector2(210, 300), Vector2(-20, 300)).is_empty(), "path cannot leave authored map bounds")
		var route: PackedVector2Array = navigation.find_path(Vector2(210, 300), Vector2(370, 300))
		var previous := Vector2(210, 300)
		for point in route:
			check(navigation.segment_clear(previous, point), "each route segment clears the physical obstacle")
			previous = point
	# Run actual physics at a deterministic fixed step without a multi-second sleep.
	enemy.set_physics_process(false)
	for i in 550:
		enemy._physics_process(1.0 / 60)
		await physics_frame
	check(enemy.position.x > 320, "enemy navigates around the wall instead of pushing against it")
	check(enemy.position.distance_to(player.position) < 50, "enemy reaches player after detour")
	check(player.health < 100, "enemy resumes real attacks after navigating")
	print("Navigation checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
