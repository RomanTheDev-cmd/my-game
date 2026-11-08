extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/combat/bell_rules.gd")
const Navigator = preload("res://scripts/world/navigation_grid.gd")
var checks := 0
var failures := 0
var arena: Node2D
var player: CharacterBody2D
var session: Node
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func tick(node: Node, seconds: float) -> void:
	for i in roundi(seconds * 60):
		node._physics_process(1.0 / 60)
		player.advance_timers(1.0 / 60)
func wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	arena.add_child(body)
func reset_player(position: Vector2) -> void:
	player.restore()
	player.blocking = false
	player.position = position
	session.nature = session.Nature.defaults()
func echo_at(position: Vector2, navigation: RefCounted = null) -> CharacterBody2D:
	var echo = load("res://scripts/actors/echo_enemy.gd").new()
	echo.position = position
	echo.target = player
	echo.navigation = navigation
	arena.add_child(echo)
	echo.set_physics_process(false)
	return echo
# Drives an echo from detection through its full toll to the ring front.
func toll(echo: CharacterBody2D, before_ring: Callable = func(): pass) -> void:
	tick(echo, 1.0 / 60)
	if echo.state == "fade": tick(echo, echo.FADE + 0.02)
	tick(echo, echo.WINDUP - 0.05)
	before_ring.call()
	tick(echo, 0.6)
func run() -> void:
	session = root.get_node("Session")
	session.fresh()
	session.difficulty = 1
	arena = Node2D.new()
	root.add_child(arena)
	player = load("res://scripts/actors/player.gd").new()
	arena.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	# --- Echo: fade, blink, telegraph and ring.
	reset_player(Vector2(500, 300))
	var echo := echo_at(Vector2(300, 300))
	tick(echo, 1.0 / 60)
	check(echo.state == "fade" and echo.blink_target.distance_to(player.position) < 81, "distant echo fades toward a point beside the hero")
	echo.receive_damage(40, Vector2.RIGHT)
	check(echo.health == echo.max_health, "a fading echo cannot be struck")
	tick(echo, echo.FADE + 0.02)
	check(echo.state == "windup" and echo.position.distance_to(player.position) < 81, "echo reappears beside the hero and telegraphs before ringing")
	check(player.health == 100, "telegraph never damages")
	tick(echo, echo.WINDUP + 0.4)
	check(is_equal_approx(player.health, 84.0) and player.ringing_time > Rules.RINGING - 0.5, "ring front strikes once with real damage and leaves ringing: %s" % player.health)
	tick(echo, 0.3)
	check(is_equal_approx(player.health, 84.0), "the same ring cannot strike twice")
	check(echo.state == "recover", "echo is exposed after its toll")
	var before: float = echo.health
	echo.receive_damage(20, Vector2.RIGHT)
	check(is_equal_approx(before - echo.health, 28.0), "exposed echo takes heavier damage")
	tick(echo, 1.0)
	check(absf(echo.modulate.r - 1.0) < 0.05 and absf(echo.modulate.g - 1.0) < 0.05, "hit tint fades instead of staying for good: %s" % echo.modulate)
	echo.queue_free()
	await process_frame
	# Ringing changes the body and has natural counters.
	check(is_equal_approx(player.movement_speed(), 115.0 * 0.7), "ringing slows ordinary movement")
	player.stamina = 50
	player._physics_process(0.5)
	check(is_equal_approx(player.stamina, 56.0), "ringing halves stamina recovery: %s" % player.stamina)
	player.health = 60
	check(player.cast_magic("heal") and player.ringing_time == 0, "healing light clears ringing")
	player.ringing_time = 2.0
	player.advance_timers(2.1)
	check(player.ringing_time == 0 and is_equal_approx(player.movement_speed(), 115.0), "ringing fades by itself")
	# Dodge, block, aegis and mist each answer a ring.
	reset_player(Vector2(500, 300))
	echo = echo_at(Vector2(440, 300))
	toll(echo, func(): pass)
	check(player.health < 100, "ordinary unguarded hero is struck in place")
	echo.queue_free()
	for answer in ["dodge", "block", "aegis", "mist"]:
		reset_player(Vector2(500, 300))
		session.region = "undercroft" if answer == "mist" else "crossing"
		if answer == "mist":
			session.nature = {"kind": "vampire", "form": "mist", "blood": 80.0, "resolve": 100.0, "stage": 3, "history": ["vampire"], "cure": 0, "gift": "blood_mist", "landing": {"region": "crossing", "position": [500.0, 300.0]}}
		echo = echo_at(Vector2(440, 300))
		toll(echo, func():
			if answer == "dodge": player.dodge_time = 0.23
			if answer == "block": player.blocking = true
			if answer == "aegis":
				player.shield_strength = 30
				player.shield_time = 6)
		match answer:
			"dodge": check(player.health == 100 and player.ringing_time == 0, "timed roll passes through the ring unharmed")
			"block": check(is_equal_approx(player.health, 96.0) and player.ringing_time == 0 and is_equal_approx(player.stamina, 77.0), "real block reduces damage, costs stamina and prevents ringing")
			"aegis": check(player.health == 100 and player.ringing_time == 0 and player.shield_strength < 30, "protective veil absorbs the ring and its ringing")
			"mist": check(is_equal_approx(player.health, 96.0) and player.ringing_time == 0, "mist takes reduced damage and cannot resonate: %s" % player.health)
		echo.queue_free()
	session.nature = session.Nature.defaults()
	await process_frame
	# Walls stop rings; howl and frost answer a toll before it sounds.
	wall(Rect2(470, 220, 20, 160))
	await physics_frame
	await physics_frame
	var navigation := Navigator.new()
	navigation.configure(arena)
	reset_player(Vector2(520, 300))
	echo = echo_at(Vector2(430, 300), navigation)
	echo.state = "windup"
	echo.timer = 0.05
	echo.attack_origin = echo.position
	tick(echo, 0.6)
	check(player.health == 100, "stone between echo and hero blocks the ring")
	# A thin body pressed against the near face of that wall is not hidden behind it.
	reset_player(Vector2(496, 300))
	session.region = "undercroft"
	session.nature = {"kind": "vampire", "form": "mist", "blood": 80.0, "resolve": 100.0, "stage": 3, "history": ["vampire"], "cure": 0, "gift": "blood_mist", "landing": {"region": "undercroft", "position": [496.0, 300.0]}}
	echo.position = Vector2(580, 300)
	echo.state = "windup"
	echo.timer = 0.05
	echo.attack_origin = echo.position
	tick(echo, 0.6)
	check(is_equal_approx(player.health, 96.0), "wall-hugging mist still meets a ring from its own side: %s" % player.health)
	session.nature = session.Nature.defaults()
	session.region = "crossing"
	reset_player(Vector2(300, 600))
	echo.position = Vector2(240, 600)
	echo.home = echo.position
	echo.state = "idle"
	tick(echo, 1.0 / 60)
	check(echo.state == "windup", "close echo begins its toll")
	check(echo.disrupt() and echo.state == "recover", "howl breaks a toll before it rings")
	tick(echo, 1.0)
	check(player.health == 100, "disrupted toll never strikes")
	echo.state = "idle"
	echo.timer = 0
	tick(echo, 1.0 / 60)
	echo.apply_slow(4, 0.55)
	tick(echo, echo.WINDUP + 0.05)
	check(echo.state == "windup", "frost slows the whole toll rather than only movement")
	echo.queue_free()
	# Werewolf howl clears the hero's own ringing.
	session.nature = {"kind": "werewolf", "form": "human", "blood": 100.0, "resolve": 80.0, "stage": 3, "history": ["werewolf"], "cure": 0, "gift": "wild", "landing": {}}
	player.ringing_time = 3
	check(player.use_nature_power() and player.ringing_time == 0, "a howl shakes off ringing")
	# Light is the human advantage; trackers see faint echoes clearly.
	reset_player(Vector2(900, 900))
	echo = echo_at(Vector2(1100, 900))
	check(echo.faint(), "an echo is only faintly visible at a distance")
	player.scent_time = 5
	check(not echo.faint(), "keen tracking senses reveal the echo")
	player.scent_time = 0
	var bolt = load("res://scripts/magic/spell_bolt.gd").new()
	bolt.position = Vector2(1060, 900)
	bolt.direction = Vector2.RIGHT
	bolt.damage = 24
	bolt.kind = "light"
	arena.add_child(bolt)
	for i in 20: await physics_frame
	check(is_equal_approx(echo.max_health - echo.health, 24.0 * 1.6), "real light bolt deals bonus damage to an echo: %s" % (echo.max_health - echo.health))
	for point in Rules.blink_points(Vector2(1000, 900)): check(point.distance_to(Vector2(1000, 900)) < 81, "blink candidates surround the hero closely")
	echo.position = Vector2(1200, 900)
	echo.home = Vector2(1400, 900)
	echo.state = "idle"
	player.position = Vector2(990, 900)
	tick(echo, 0.5)
	check(echo.state == "idle" and echo.position.x > 1200, "echo never chases or blinks beyond its haunt; it drifts home")
	echo.queue_free()
	await process_frame
	# --- The bell.
	for pillar in [Rect2(1235, 450, 50, 50)]: wall(pillar)
	await physics_frame
	await physics_frame
	navigation.configure(arena)
	var bell = load("res://scripts/actors/bell_boss.gd").new()
	bell.position = Vector2(1455, 705)
	bell.target = player
	bell.navigation = navigation
	arena.add_child(bell)
	bell.set_physics_process(false)
	reset_player(Vector2(1255, 705))
	bell.receive_damage(60, Vector2.RIGHT)
	tick(bell, 2.0)
	check(bell.health == 460 and not bell.engaged and player.health == 100, "dormant bell neither takes damage nor attacks")
	var victories := [0]
	bell.victory_requested.connect(func(): victories[0] += 1)
	bell.armed = true
	tick(bell, 1.0 / 60)
	check(bell.engaged and bell.state == "windup" and bell.attack_spec.kind == "toll", "armed bell engages a nearby hero with a telegraphed toll")
	tick(bell, 1.02)
	check(player.health == 100 and bell.rings.size() == 1, "toll releases a visible ring before any damage")
	tick(bell, 0.6)
	check(is_equal_approx(player.health, 80.0) and player.ringing_time > 0, "bell ring strikes at the right distance: %s" % player.health)
	tick(bell, 1.0)
	player.restore()
	check(bell.attack_spec.kind == "toll", "pattern continues with a second toll")
	tick(bell, 2.2)
	check(bell.attack_spec.kind == "summon" and bell.state == "windup", "third step calls an echo")
	tick(bell, 1.2)
	check(bell.minions.size() == 1 and bell.minions[0].transient and bell.minions[0].reward_xp == 0 and bell.minions[0].id == "", "summoned echo is transient and gives no reward")
	check(bell.minions[0].aggro_range == 600.0, "summoned echo keeps chamber-wide awareness after entering the scene")
	for minion in bell.minions: minion.set_physics_process(false)
	tick(bell, 0.9)
	check(bell.attack_spec.kind == "knell" and bell.state == "windup" and bell.attack_spec.windup >= 2.0, "great knell is long telegraphed")
	# Hide behind the pillar from the bell's point of view.
	player.position = Vector2(1180, 400)
	check(not navigation.segment_clear(bell.position, player.position), "test position is genuinely behind the pillar")
	player.restore()
	tick(bell, 2.5)
	check(player.health == 100 and bell.state == "exposed", "real pillar cover blocks the knell and the bell swings open")
	before = bell.health
	bell.receive_damage(30, Vector2.RIGHT)
	check(is_equal_approx(before - bell.health, 48.0), "exposed bell takes heavier damage")
	bell.state = "idle"
	bell.timer = 0
	bell.attack_index = 3
	player.position = Vector2(1300, 705)
	player.restore()
	tick(bell, 1.0 / 60)
	check(bell.state == "windup" and bell.attack_spec.kind == "knell", "great knell returns in the pattern")
	tick(bell, 2.5)
	check(is_equal_approx(player.health, 56.0), "uncovered hero suffers the full knell: %s" % player.health)
	# Summons stay capped.
	for minion in bell.minions: if is_instance_valid(minion): minion.queue_free()
	bell.minions.clear()
	for i in 2:
		var extra = load("res://scripts/actors/echo_enemy.gd").new()
		extra.transient = true
		arena.add_child(extra)
		extra.set_physics_process(false)
		bell.minions.append(extra)
	bell.state = "idle"
	bell.attack_index = 2
	bell.timer = 0
	tick(bell, 1.0 / 60)
	check(bell.attack_spec.kind == "toll" and bell.minions.size() == 2, "summoning never exceeds two echoes")
	# Phase two: two rings far enough apart to both matter.
	bell.state = "idle"
	bell.receive_damage(bell.health - 200, Vector2.RIGHT)
	check(bell.phase == 2 and bell.state == "recover" and bell.timer == 1.7, "half health opens a fair transition into a second phase")
	player.position = Vector2(1300, 705)
	player.restore()
	tick(bell, 1.76)
	check(bell.attack_spec.kind == "peal" and bell.attack_spec.rings == 2, "second phase rings twice")
	tick(bell, 1.96)
	check(is_equal_approx(player.health, 68.0), "both rings of a peal can strike a hero who stands still: %s" % player.health)
	# Retreat resets; victory requests a record exactly once.
	player.position = Vector2(1455 - 600, 705)
	tick(bell, 1.0 / 60)
	check(bell.health == 460 and bell.phase == 1 and not bell.engaged and bell.minions.is_empty(), "leaving the chamber resets a repeatable encounter")
	player.position = Vector2(1300, 705)
	player.restore()
	bell.health = 2
	bell.receive_damage(100, Vector2.RIGHT)
	bell.receive_damage(100, Vector2.RIGHT)
	tick(bell, 1.0)
	check(victories[0] == 1 and bell.awaiting_record and bell.rings.is_empty() and player.health == 100, "victory requests one record and the yielded bell stops attacking")
	print("Knell combat checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
