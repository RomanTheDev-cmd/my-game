extends "res://scripts/actors/enemy.gd"
const Rules = preload("res://scripts/combat/boss_rules.gd")
signal victory_requested
var engaged := false
var armed := false
var awaiting_record := false
var phase := 1
var attack_index := 0
var attack_spec: Dictionary = {}
var charge_hit := false
var flash_time := 0.0
func _ready() -> void:
	max_health = 420
	move_speed = 64
	aggro_range = 460
	reward_xp = 120
	coin_reward = 0
	super._ready()
	sprite.hide()
func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	flash_time = maxf(0, flash_time - delta)
	queue_redraw()
	if not armed or awaiting_record or not is_instance_valid(target) or target.health <= 0: return
	if global_position.distance_to(target.global_position) > 720 or home.distance_to(target.global_position) > 720:
		_reset_encounter()
		return
	timer = maxf(0, timer - delta)
	path_timer = maxf(0, path_timer - delta)
	velocity = Vector2.ZERO
	if state == "windup":
		if timer == 0:
			if attack_spec.kind == "charge":
				state = "charge"
				timer = 0.65
				charge_hit = false
			else:
				if Rules.hits(attack_spec.kind, target.global_position - attack_origin, attack_direction) and _clear(attack_origin, target.global_position):
					target.receive_damage(attack_spec.damage)
				_recover()
	elif state == "charge":
		var before := global_position
		velocity = attack_direction * 330 * (slow_multiplier if slow_remaining > 0 else 1.0)
		move_and_slide()
		var nearest := Geometry2D.get_closest_point_to_segment(target.global_position, before, global_position)
		if not charge_hit and nearest.distance_to(target.global_position) < 24 and _clear(nearest, target.global_position):
			charge_hit = true
			target.receive_damage(attack_spec.damage)
		if timer == 0 or get_slide_collision_count() > 0:
			_recover()
		return
	elif state == "recover":
		if timer == 0: state = "idle"
	else:
		var distance := global_position.distance_to(target.global_position)
		if distance < aggro_range: engaged = true
		var next_attack := Rules.attack(phase, attack_index)
		var reach := 90.0 if next_attack.kind == "sweep" else (125.0 if next_attack.kind == "pulse" else 250.0)
		if distance < reach and _clear(global_position, target.global_position):
			_begin_attack()
		elif engaged:
			velocity = _steer(target.global_position, move_speed)
		else:
			velocity = _steer(home, 55) if global_position.distance_to(home) > 8 else Vector2.ZERO
	move_and_slide()
func _clear(from: Vector2, to: Vector2) -> bool:
	return navigation == null or navigation.segment_clear(from, to)
func _begin_attack() -> void:
	attack_spec = Rules.attack(phase, attack_index)
	attack_index += 1
	state = "windup"
	timer = attack_spec.windup
	attack_origin = global_position
	attack_direction = global_position.direction_to(target.global_position)
func _recover() -> void:
	state = "recover"
	timer = attack_spec.get("recovery", 1.5)
	flash_time = 0.25
	velocity = Vector2.ZERO
func _reset_encounter() -> void:
	engaged = false
	path = PackedVector2Array()
	path_target = Vector2.INF
	path_timer = 0
	state = "idle"
	timer = 0
	health = max_health
	phase = 1
	attack_index = 0
	slow_remaining = 0
	velocity = _steer(home, 80)
	move_and_slide()
func receive_damage(amount: float, _direction: Vector2) -> void:
	if not armed or awaiting_record or health <= 0 or not is_finite(amount) or amount <= 0: return
	engaged = true
	Sound.play_at("impact", global_position)
	health = maxf(0, health - amount * Rules.damage_multiplier(state))
	flash_time = 0.18
	if health == 0:
		awaiting_record = true
		state = "yielded"
		velocity = Vector2.ZERO
		victory_requested.emit()
	elif Rules.phase(health, max_health) > phase:
		phase = 2
		attack_index = 0
		state = "recover"
		timer = 1.7
		Sound.play_at("block", global_position)
	queue_redraw()
func _draw() -> void:
	if state == "windup":
		var color := Color(0.95, 0.65, 0.25, 0.75)
		if attack_spec.kind == "pulse":
			draw_circle(Vector2.ZERO, Rules.PULSE_RADIUS, Color(0.75, 0.6, 0.3, 0.15))
			draw_arc(Vector2.ZERO, Rules.PULSE_RADIUS, 0, TAU, 48, color, 3)
		elif attack_spec.kind == "charge":
			var side := attack_direction.orthogonal() * 24
			var end := attack_direction * 215
			draw_colored_polygon(PackedVector2Array([-side, side, end + side, end - side]), Color(0.9, 0.55, 0.2, 0.22))
			draw_line(Vector2.ZERO, end, color, 3)
		else:
			var angle := attack_direction.angle()
			var half_angle := acos(0.15)
			draw_arc(Vector2.ZERO, Rules.SWEEP_REACH, angle - half_angle, angle + half_angle, 32, color, 3)
			draw_line(Vector2.ZERO, Vector2.from_angle(angle - half_angle) * Rules.SWEEP_REACH, color, 2)
			draw_line(Vector2.ZERO, Vector2.from_angle(angle + half_angle) * Rules.SWEEP_REACH, color, 2)
	if flash_time > 0 and not awaiting_record:
		draw_circle(Vector2.ZERO, 36, Color(0.8, 0.9, 0.85, flash_time))
	var metal := Color("bdbb9a") if state == "recover" else Color("807e6c")
	if not armed or awaiting_record: metal = Color("626f68")
	draw_rect(Rect2(-22, -32, 44, 34), metal)
	draw_rect(Rect2(-28, -10, 56, 10), Color("a6a38b"))
	draw_rect(Rect2(-17, -48, 34, 15), Color("99a39a"))
	draw_arc(Vector2(0, -28), 12, PI, TAU, 16, Color("d6cfa5"), 4)
	for x in [-19, 15]: draw_rect(Rect2(x, 2, 7, 11), Color("535d56"))
	draw_rect(Rect2(-6, -25, 12, 7), Color("dbac65") if armed and not awaiting_record else Color("506663"))
	if phase == 2: draw_arc(Vector2(0, -20), 31, 0, TAU, 20, Color("b8d6ce"), 2)
