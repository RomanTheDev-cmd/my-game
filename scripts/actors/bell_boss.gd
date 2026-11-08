extends "res://scripts/actors/boss_enemy.gd"
# The hanging bell never walks. It tolls rings, calls echoes and prepares a great knell
# that only solid cover can stop; after the knell it swings open and is exposed.
const BellRules = preload("res://scripts/combat/bell_rules.gd")
const Echo = preload("res://scripts/actors/echo_enemy.gd")
const RESET_DISTANCE := 560.0
var rings: Array[Dictionary] = []
var minions: Array[Node] = []
var spawn_points: Array[Vector2] = [Vector2(-155, 0), Vector2(155, 0), Vector2(0, -230), Vector2(0, 230)]
var cover_rects: Array[Rect2] = []
var summon_point := Vector2.ZERO
var bounds := Rect2(40, 40, 1840, 1200)

func _ready() -> void:
	super._ready()
	max_health = 460
	health = max_health
	aggro_range = 330
	move_speed = 0
	reward_xp = 0
	for child in get_children():
		if child is CollisionShape2D: (child.shape as CircleShape2D).radius = 26

func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	flash_time = maxf(0, flash_time - delta)
	queue_redraw()
	minions = minions.filter(func(minion): return is_instance_valid(minion) and minion.health > 0)
	if not armed or awaiting_record or not is_instance_valid(target) or target.health <= 0: return
	if engaged and home.distance_to(target.global_position) > RESET_DISTANCE:
		_reset_encounter()
		return
	var step := delta * (slow_multiplier if slow_remaining > 0 else 1.0)
	timer = maxf(0, timer - step)
	_advance_rings(step)
	velocity = Vector2.ZERO
	match state:
		"windup":
			if timer == 0: _release()
		"recover", "exposed":
			if timer == 0: state = "idle"
		_:
			var distance := global_position.distance_to(target.global_position)
			if not engaged and distance < aggro_range and _clear(global_position, target.global_position): engaged = true
			if engaged: _begin_attack()

func _begin_attack() -> void:
	attack_spec = BellRules.attack(phase, attack_index)
	attack_index += 1
	if attack_spec.kind == "summon":
		var point := _summon_point()
		if point == Vector2.INF or minions.size() >= BellRules.MAX_MINIONS:
			attack_spec = BellRules.attack(1, 0)
		else: summon_point = point
	state = "windup"
	timer = attack_spec.windup
	attack_origin = global_position
	if attack_spec.kind == "knell": Session.notice.emit("KNELL_WARNING")

func _release() -> void:
	match attack_spec.kind:
		"toll", "peal":
			for i in int(attack_spec.rings):
				rings.append({"radius": 0.0, "delay": i * float(attack_spec.get("gap", 0.0)), "hit": false, "damage": attack_spec.damage})
			Sound.play_at("toll", global_position)
			state = "recover"
		"summon":
			var echo := Echo.new()
			echo.transient = true
			echo.id = ""
			echo.position = summon_point
			echo.target = target
			echo.navigation = navigation
			echo.aggro_range = 600
			echo.awareness_time = 4.0
			get_parent().add_child(echo)
			minions.append(echo)
			Sound.play_at("toll", summon_point)
			state = "recover"
		"knell":
			Sound.play_at("toll", global_position)
			if global_position.distance_to(target.global_position) < 700 and not BellRules.covered(navigation, global_position, target.global_position):
				target.receive_damage(attack_spec.damage, "ringing")
			state = "exposed"
	timer = attack_spec.recovery
	flash_time = 0.3

func _advance_rings(step: float) -> void:
	var active: Array[Dictionary] = []
	for ring in rings:
		if ring.delay > 0:
			ring.delay = maxf(0, ring.delay - step)
			active.append(ring)
			continue
		var previous: float = ring.radius
		ring.radius = minf(BellRules.BELL_RING, previous + BellRules.RING_SPEED * step)
		var distance := global_position.distance_to(target.global_position)
		if not ring.hit and BellRules.ring_crosses(previous, ring.radius, distance) and not BellRules.covered(navigation, global_position, target.global_position):
			ring.hit = true
			target.receive_damage(ring.damage, "ringing")
		if ring.radius < BellRules.BELL_RING: active.append(ring)
	rings = active

func _summon_point() -> Vector2:
	var best := Vector2.INF
	for offset in spawn_points:
		var point := global_position + offset
		if not bounds.has_point(point) or point.distance_to(target.global_position) < 90: continue
		if navigation != null and not navigation.segment_clear(global_position, point): continue
		if best == Vector2.INF or point.distance_to(target.global_position) > best.distance_to(target.global_position): best = point
	return best

func _reset_encounter() -> void:
	engaged = false
	state = "idle"
	timer = 0
	health = max_health
	phase = 1
	attack_index = 0
	slow_remaining = 0
	rings.clear()
	_release_minions()

func _release_minions() -> void:
	for minion in minions:
		if is_instance_valid(minion): minion.queue_free()
	minions.clear()

func spell_multiplier(kind: String) -> float:
	return BellRules.spell_multiplier(kind)

func receive_damage(amount: float, _direction: Vector2) -> void:
	if not armed or awaiting_record or health <= 0 or not is_finite(amount) or amount <= 0: return
	engaged = true
	Sound.play_at("impact", global_position)
	health = maxf(0, health - amount * BellRules.bell_multiplier(state))
	flash_time = 0.18
	if health == 0:
		awaiting_record = true
		state = "yielded"
		rings.clear()
		_release_minions()
		victory_requested.emit()
	elif BellRules.phase(health, max_health) > phase:
		phase = 2
		attack_index = 0
		state = "recover"
		timer = 1.7
		Sound.play_at("block", global_position)
	queue_redraw()

func _draw() -> void:
	for ring in rings:
		if ring.delay == 0: draw_arc(Vector2.ZERO, ring.radius, 0, TAU, 72, Color(0.85, 0.9, 0.95, 0.85), BellRules.RING_WIDTH * 0.7)
	if state == "windup":
		var progress: float = 1.0 - timer / maxf(0.01, attack_spec.windup)
		match attack_spec.kind:
			"knell":
				draw_circle(Vector2.ZERO, 80 + 30 * progress, Color(0.95, 0.75, 0.45, 0.12 + 0.18 * progress))
				for rect in cover_rects: _draw_shadow(rect)
			"summon":
				draw_arc(summon_point - global_position, 18, 0, TAU, 24, Color(0.75, 0.85, 0.9, 0.4 + 0.5 * progress), 2)
			_:
				draw_arc(Vector2.ZERO, BellRules.BELL_RING, 0, TAU, 72, Color(0.9, 0.8, 0.55, 0.25 + 0.35 * progress), 2)
	if flash_time > 0 and not awaiting_record:
		draw_circle(Vector2.ZERO, 40, Color(0.85, 0.92, 0.9, flash_time))
	draw_line(Vector2(0, -110), Vector2(0, -52), Color("4c5352"), 4)
	draw_rect(Rect2(-40, -116, 80, 8), Color("5b4a3a"))
	var swing := sin(Time.get_ticks_msec() * 0.006) * 4.0 if state == "exposed" else 0.0
	var metal := Color("8d8a6e") if armed and not awaiting_record else Color("5f6a64")
	if state == "exposed": metal = Color("b9b48f")
	draw_colored_polygon(PackedVector2Array([Vector2(-15 + swing, -52), Vector2(15 + swing, -52), Vector2(22 + swing, -30), Vector2(30 + swing, 2), Vector2(-30 + swing, 2), Vector2(-22 + swing, -30)]), metal)
	draw_rect(Rect2(-34 + swing, 0, 68, 7), metal.darkened(0.2))
	draw_line(Vector2(6 + swing, -48), Vector2(-3 + swing, -26), Color("3b3f3a"), 2)
	draw_line(Vector2(-3 + swing, -26), Vector2(8 + swing, -6), Color("3b3f3a"), 2)
	if phase == 2: draw_arc(Vector2(0, -22), 40, 0, TAU, 24, Color("b8d6ce"), 2)

# Darkened wedge behind each pillar shows where the knell cannot reach.
func _draw_shadow(rect: Rect2) -> void:
	var grown := rect.grow(7)
	var center := grown.get_center() - global_position
	var corners := [grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y)]
	var low := Vector2.INF
	var high := Vector2.INF
	var low_angle := INF
	var high_angle := -INF
	for corner in corners:
		var local: Vector2 = corner - global_position
		var angle := wrapf(local.angle() - center.angle(), -PI, PI)
		if angle < low_angle:
			low_angle = angle
			low = local
		if angle > high_angle:
			high_angle = angle
			high = local
	# The wedge ends near the chamber wall instead of spilling into other rooms.
	var reach := 560.0
	draw_colored_polygon(PackedVector2Array([low, high, high.normalized() * maxf(high.length(), reach), low.normalized() * maxf(low.length(), reach)]), Color(0.05, 0.08, 0.1, 0.45))
