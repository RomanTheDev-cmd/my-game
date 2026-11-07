extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.vampire(session)
	session.region = "waterworks"
	session.arrival = Vector2(1200, 650)
	game._build_world()
	game.resume()
	var player = game.world.player
	player.set_physics_process(false)
	player.health = 30
	player.facing = Vector2.RIGHT
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.id = "nature_practice"
	enemy.position = Vector2(1290, 650)
	enemy.target = player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	check(not player.cast_magic("light") and not player.cast_magic("heal") and player.mana == 100, "unavailable sacred spells do not consume vampire mana")
	check(player.use_nature_power() and player.mana == 84 and session.nature.blood <= 68, "blood ability spends its real mana and blood")
	for i in 25: await physics_frame
	check(enemy.health == 51 and player.health == 48, "real blood projectile heals only after actual enemy damage")
	check(not player.use_nature_power(), "blood ability cannot bypass its cooldown")
	enemy.queue_free()
	await physics_frame
	var boss = load("res://scripts/actors/boss_enemy.gd").new()
	boss.position = Vector2(1290, 650)
	boss.target = player
	game.world.add_child(boss)
	boss.set_physics_process(false)
	player.health = 20
	player.nature_cooldown = 0
	check(player.use_nature_power(), "blood projectile can be attempted against a dormant object")
	for i in 25: await physics_frame
	check(boss.health == 420 and player.health == 20, "immune guardian cannot be farmed for free healing")
	boss.queue_free()
	await physics_frame
	player.nature_cooldown = 0
	session.nature.blood = 10
	var original_mana: float = player.mana
	check(not player.use_nature_power() and player.mana == original_mana and session.nature.blood <= 10, "insufficient blood rejects ability without charging mana")
	session.nature.blood = 80
	player.health = 100
	player.hurt_time = 0
	session.region = "crossing"
	player.receive_damage(20)
	check(player.health == 74, "outdoor daylight increases actual incoming damage")
	player.health = 100
	player.hurt_time = 0
	session.region = "waterworks"
	player.receive_damage(20)
	check(player.health == 80, "indoor cover removes sunlight weakness")
	player.health = 20
	session.world_state.minutes = 1320
	player._physics_process(2.0)
	check(player.health == 23, "night regeneration changes actual player health")
	player.health = 20
	session.world_state.minutes = 600
	player._physics_process(2.0)
	check(player.health == 20, "daytime does not grant passive blood regeneration")
	check(player.shift_form() and session.nature.form == "battle" and session.nature.blood == 60, "entering actual combat form spends blood once")
	check(player.weapon_stats().damage == 46 and player.weapon_stats().reach == 58 and not player.can_cast_magic("frost"), "combat shape changes weapon reach and closes normal spellcasting")
	player.health = 100
	player.hurt_time = 0
	player.blocking = true
	player.stamina = 100
	player.receive_damage(20)
	check(player.health == 80 and player.stamina == 100, "combat form cannot use a shield even through a stale block flag")
	player.dodge_time = 0.2
	check(player.shift_form() and session.nature.form == "human" and player.dodge_time == 0, "return to accessible humanoid shape is always possible even while paused during a dodge")
	check(session.nature.blood == 60, "returning shape never refills blood")
	player.health = 61
	check(session.save_at(player.position, game.world.player_vitals()) and session.load_saved() and player.health == 61 and session.nature.blood == 60, "saving and reloading nature does not replenish actual health or blood")
	session.nature = {"kind": "human", "form": "human", "blood": 100.0, "landing": {}, "resolve": 100.0, "stage": 3, "history": [], "cure": 0, "gift": "oath"}
	player.mana = 100
	player.nature_cooldown = 0
	check(player.use_nature_power() and player.mana == 68 and player.shield_strength == 45 and player.shield_time == 8, "human specialization grants its own real defensive ability")
	player.health = 100
	player.hurt_time = 0
	player.dodge_time = 0
	player.blocking = false
	player.receive_damage(40)
	check(player.health == 100 and player.shield_strength == 5, "human oath absorbs damage through normal combat rules")
	check(not player.use_nature_power() and player.mana == 68, "human ability cannot bypass independent cooldown")
	session.nature.gift = "scar"
	session.nature.stage = 4
	session.nature.history = ["vampire"]
	session.nature.cure = 3
	player.nature_cooldown = 0
	check(player.use_nature_power() and player.shield_strength == 40 and not player.shift_form(), "returned human has distinct gift and cannot re-enter lost supernatural form")
	Fixture.vampire(session)
	session.aid_quest = 1
	check(session.advance_aid("magic", 100).is_empty() and session.aid_quest == 1, "vampire cannot use forbidden light healing through a dialogue answer")
	print("Nature combat checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
