extends CharacterBody2D
signal defeated(id: String)
var id := ""
var target: CharacterBody2D
var health := 75.0
var max_health := 75.0
var attack_damage := 20.0
var attack_distance := 36.0
var attack_reach := 48.0
var windup_duration := 0.65
var recovery_duration := 0.8
var move_speed := 58.0
var aggro_range := 210.0
var reward_xp := 20
var coin_reward := 3
var home := Vector2.ZERO
var state := "idle"
var timer := 0.0
var attack_origin := Vector2.ZERO
var attack_direction := Vector2.RIGHT
var sprite: Sprite2D
var navigation: RefCounted
var path := PackedVector2Array()
var path_index := 0
var path_timer := 0.0
var path_target := Vector2.INF
var slow_remaining := 0.0
var slow_multiplier := 1.0

func _ready() -> void:
	health = max_health
	collision_layer = 4
	collision_mask = 17
	home = global_position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/enemy.png")
	sprite.position.y = -12
	add_child(sprite)

func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	if not is_instance_valid(target) or target.health <= 0:
		return
	timer = maxf(0, timer - delta)
	path_timer = maxf(0, path_timer - delta)
	var offset := target.global_position - global_position
	if state == "windup":
		velocity = Vector2.ZERO
		if timer == 0:
			if target.global_position.distance_to(attack_origin) < attack_reach:
				var toward := (target.global_position - attack_origin).normalized()
				if toward.dot(attack_direction) > 0.15 and (navigation == null or navigation.segment_clear(attack_origin, target.global_position)):
					target.receive_damage(attack_damage)
			state = "recover"
			timer = recovery_duration
	elif state == "recover":
		velocity = Vector2.ZERO
		if timer == 0:
			state = "idle"
	elif offset.length() < attack_distance and (navigation == null or navigation.segment_clear(global_position, target.global_position)):
		state = "windup"
		timer = windup_duration
		attack_origin = global_position
		attack_direction = offset.normalized()
	elif offset.length() < aggro_range and global_position.distance_to(home) < 320:
		velocity = _steer(target.global_position, move_speed)
	else:
		velocity = _steer(home, 35) if global_position.distance_to(home) > 8 else Vector2.ZERO
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	modulate = modulate.lerp(Color("92c5df") if slow_remaining > 0 else Color.WHITE, delta * 8)
	queue_redraw()

func receive_damage(amount: float, direction: Vector2) -> void:
	if health <= 0:
		return
	Sound.play_at("impact", global_position)
	health -= amount
	modulate = Color(1.9, 0.7, 0.7)
	# Movement goes through collision resolution, including knockback.
	velocity = direction * 200
	move_and_slide()
	if health <= 0:
		defeated.emit(id)
		queue_free()

func _draw() -> void:
	if state == "windup":
		draw_arc(Vector2(0, -6), attack_reach - 10, attack_direction.angle() - 1.1, attack_direction.angle() + 1.1,
			16, Color(0.9, 0.45, 0.27, 0.8), 3)
	if health < max_health or max_health > 100:
		draw_rect(Rect2(-14, -35, 28, 3), Color("302e38"))
		draw_rect(Rect2(-14, -35, 28 * maxf(0, health) / max_health, 3), Color("bd7568"))

func _steer(destination: Vector2, speed: float) -> Vector2:
	speed *= slow_multiplier if slow_remaining > 0 else 1.0
	if navigation == null:
		return (destination - global_position).normalized() * speed
	if path_timer == 0 or path_target.distance_to(destination) > 30:
		path = navigation.find_path(global_position, destination)
		path_index = 0
		path_target = destination
		path_timer = 0.45
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 7:
		path_index += 1
	if path_index >= path.size():
		return Vector2.ZERO
	return (path[path_index] - global_position).normalized() * speed

func apply_slow(duration: float, multiplier: float) -> void:
	if health <= 0 or not is_finite(duration) or not is_finite(multiplier) or duration <= 0:
		return
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.25, 1)) if slow_remaining > 0 else clampf(multiplier, 0.25, 1)
	slow_remaining = maxf(slow_remaining, minf(10, duration))

func _tick_slow(delta: float) -> void:
	slow_remaining = maxf(0, slow_remaining - delta)
	if slow_remaining == 0:
		slow_multiplier = 1.0
