extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/pack_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.wolf(session)
	session.region = "thicket"
	session.arrival = Vector2(340, 500)
	game._build_world()
	game.resume()
	var player = game.world.player
	player.set_physics_process(false)
	check(not player.shift_form("hybrid") and session.nature.resolve == 80, "hybrid remains unavailable before mastery and costs nothing on failure")
	check(player.shift_form() and session.nature.form == "wolf" and session.nature.resolve == 70, "wolf uses its independent shape reserve")
	check(player.movement_speed() == 175 and player.weapon_stats().damage == 22 and player.can_track(), "wolf gains real travel speed and scent with a lighter attack")
	game.world._update_tracking()
	check(game.world.tracking_cue.visible and game.world.tracking_cue.direction.y < 0, "actual scent cue points to nearest unopened hidden supply")
	check(not player.can_cast_magic("heal") and not player.cast_magic("frost"), "animal shape cannot bypass spell restriction")
	var wall := StaticBody2D.new()
	wall.position = Vector2(395, 500)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 120)
	collider.shape = shape
	wall.add_child(collider)
	game.world.add_child(wall)
	await physics_frame
	await physics_frame
	player.velocity = Vector2(175, 0)
	for i in 30:
		player.move_and_slide()
		await physics_frame
	check(player.position.x < 380, "fast wolf remains constrained by actual wall collision")
	wall.queue_free()
	await physics_frame
	player.dodge_time = 0.2
	check(player.shift_form() and session.nature.form == "human", "return remains available during a paused dodge")
	session.nature.gift = "wild_master"
	session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
	session.gathered.append("pack:mastery")
	session.nature.resolve = 80
	check(player.shift_form("hybrid") and session.nature.resolve == 60 and player.movement_speed() == 125, "mastered hybrid pays a different price and has distinct movement")
	session.world_state.minutes = 600
	check(player.weapon_stats().damage == 50 and player.weapon_stats().reach == 65, "hybrid has its own actual melee profile")
	session.world_state.minutes = 5760
	check(is_equal_approx(player.weapon_stats().damage, 57.5), "full moon at night changes actual hybrid damage")
	player.position = Vector2(800, 600)
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.id = "pack_practice"
	enemy.position = Vector2(860, 600)
	enemy.target = player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	game.world._on_strike(player.position, Vector2.RIGHT)
	check(is_equal_approx(enemy.health, 17.5), "hybrid reach and lunar damage connect through actual world strike")
	player.health = 60
	player.stamina = 100
	player.nature_cooldown = 0
	check(player.use_nature_power() and player.health == 72 and player.stamina == 80 and player.scent_time == 12, "actual howl spends stamina, heals bounded health and enables sensing")
	check(enemy.slow_remaining == 3 and enemy.slow_multiplier == 0.55, "howl affects a real nearby enemy")
	check(not player.use_nature_power(), "howl cooldown cannot be bypassed")
	player.health = 100
	player.blocking = true
	player.hurt_time = 0
	session.gear_owned.append("chain")
	session.equipped.armor = "chain"
	player.receive_damage(20)
	check(player.health == 80, "animal body cannot retain shield or worn armor reduction")
	player.health = 50
	player.hurt_time = 0
	player.blocking = false
	player._physics_process(2)
	check(is_equal_approx(player.health, 52.6), "night lunar regeneration reaches actual player health")
	print("Pack combat checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
