extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/rescue_fixture.gd")
const Rules = preload("res://scripts/quests/rescue_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.selected(session), "physics regression uses genuine ordinary setup")
	session.region = "underhall"
	session.arrival = Vector2(500, 430)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.resume()
	await settle()
	var player = game.world.player
	player.aim_with_mouse = false
	player.facing = Vector2.RIGHT
	session.world_state.minutes = 3
	check(player.cast_magic("light"), "real ordinary casting creates a moving projectile")
	await create_timer(0.6).timeout
	check(Rules.cut(session.gathered, "north") == "" and get_nodes_in_group("spell_projectiles").is_empty(), "authored wall intercepts actual light before the receiver")
	player.position = Vector2(850, 360)
	player.facing = player.position.direction_to(Rules.COILS.north)
	player.magic_cooldown = 0
	check(player.cast_magic("frost"), "real different spell uses the same physical receiver path")
	await create_timer(0.6).timeout
	check(Rules.cut(session.gathered, "north") == "", "frost hitting the receiver cannot masquerade as light or complete the support")
	player.magic_cooldown = 0
	player.mana = 90
	session.world_state.minutes = 1.5
	check(player.cast_magic("light"), "actual light may be fired while target strip is live")
	await create_timer(0.6).timeout
	check(Rules.cut(session.gathered, "north") == "" and player.mana == 72 and player.health == 64, "live receiver rejects proof while normal cast cost remains and off-strip operator stays safe")
	session.world_state.minutes = 3
	player.magic_cooldown = 0
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(player.cast_magic("light"), "real paid projectile still flies when subsequent disk write is refused")
	await create_timer(0.6).timeout
	check(Rules.cut(session.gathered, "north") == "" and player.mana == 54 and not game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "failed light record never removes real restraint or refunds an already performed spell")
	DirAccess.remove_absolute("user://save.json.tmp")
	player.position = Vector2(980, 400)
	check(game.world.rescue_action("manual_north"), "ordinary manual alternative can finish after failed magic without any required spell recast")
	player.position = Vector2(980, 840)
	session.world_state.minutes = 0
	var stamina: float = player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.rescue_action("manual_south") and player.stamina == stamina and not Rules.disconnected(session.gathered) and not game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "failed last manual action preserves resource and actual blocking geometry")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(game.world.rescue_action("manual_south") and game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "saved final action changes actual collision/Nav exactly once")
	player.position = Vector2(430, 960)
	game.world.interact()
	check("underhall:herb_430_960" in session.gathered and session.save_at(player.position, game.world.player_vitals()) and session.load_saved(), "actual resource pickup uses region namespace and remains a valid real save")
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	await settle()
	check(game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)) and not game.world.herbs[0].visible, "rebuild restores open geometry and never respawns collected resource")
	print("Rescue physics checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
