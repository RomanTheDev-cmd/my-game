extends "res://scripts/actors/enemy.gd"
const Arrow = preload("res://scripts/combat/hostile_arrow.gd")

func _ready() -> void:
	max_health = 60
	aggro_range = 320
	reward_xp = 25
	coin_reward = 4
	super._ready()
	sprite.texture = preload("res://assets/sprites/archer.png")

func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	if not is_instance_valid(target) or target.health <= 0:
		return
	timer = maxf(0, timer - delta)
	path_timer = maxf(0, path_timer - delta)
	var offset := target.global_position - global_position
	var clear: bool = navigation == null or navigation.segment_clear(global_position, target.global_position)
	if state == "windup":
		velocity = Vector2.ZERO
		if timer == 0:
			var arrow := Arrow.new()
			arrow.position = global_position + attack_direction * 14
			arrow.direction = attack_direction
			get_parent().add_child(arrow)
			Sound.play_at("arrow", global_position)
			state = "recover"
			timer = 1.25
	elif state == "recover":
		velocity = Vector2.ZERO
		if timer == 0:
			state = "idle"
	elif offset.length() < aggro_range and global_position.distance_to(home) < 380:
		if offset.length() < 85 and clear:
			var retreat := (global_position - offset.normalized() * 70).clamp(Vector2(30, 30), Vector2(1890, 1250))
			velocity = _steer(retreat, 55)
			if velocity == Vector2.ZERO:
				state = "windup"
				timer = 0.8
				attack_direction = offset.normalized()
		elif clear:
			velocity = Vector2.ZERO
			state = "windup"
			timer = 0.8
			attack_direction = offset.normalized()
		else:
			velocity = _steer(target.global_position, 50)
	else:
		velocity = _steer(home, 35) if global_position.distance_to(home) > 8 else Vector2.ZERO
	move_and_slide()
	if offset.x != 0:
		sprite.flip_h = offset.x < 0
	modulate = modulate.lerp(Color("92c5df") if slow_remaining > 0 else Color.WHITE, delta * 8)
	queue_redraw()

func _draw() -> void:
	if state == "windup":
		draw_line(Vector2(0, -6), attack_direction * 75 + Vector2(0, -6), Color("c28c68"), 2)
	if health < max_health:
		draw_rect(Rect2(-14, -35, 28, 3), Color("302e38"))
		draw_rect(Rect2(-14, -35, 28 * maxf(0, health) / max_health, 3), Color("bd7568"))
