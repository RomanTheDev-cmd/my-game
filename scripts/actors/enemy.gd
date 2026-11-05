extends CharacterBody2D
signal defeated(id: String)
var id := ""
var target: CharacterBody2D
var health := 75.0
var home := Vector2.ZERO
var state := "idle"
var timer := 0.0
var attack_origin := Vector2.ZERO
var attack_direction := Vector2.RIGHT
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
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
	if not is_instance_valid(target) or target.health <= 0:
		return
	timer = maxf(0, timer - delta)
	var offset := target.global_position - global_position
	if state == "windup":
		velocity = Vector2.ZERO
		if timer == 0:
			if target.global_position.distance_to(attack_origin) < 48:
				var toward := (target.global_position - attack_origin).normalized()
				if toward.dot(attack_direction) > 0.15:
					target.receive_damage(20)
			state = "recover"
			timer = 0.8
	elif state == "recover":
		velocity = Vector2.ZERO
		if timer == 0:
			state = "idle"
	elif offset.length() < 36:
		state = "windup"
		timer = 0.65
		attack_origin = global_position
		attack_direction = offset.normalized()
	elif offset.length() < 210 and global_position.distance_to(home) < 320:
		velocity = offset.normalized() * 58
	else:
		velocity = (home - global_position).normalized() * 35 if global_position.distance_to(home) > 8 else Vector2.ZERO
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	modulate = modulate.lerp(Color.WHITE, delta * 8)
	queue_redraw()

func receive_damage(amount: float, direction: Vector2) -> void:
	if health <= 0:
		return
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
		draw_arc(Vector2(0, -6), 38, attack_direction.angle() - 1.1, attack_direction.angle() + 1.1,
			16, Color(0.9, 0.45, 0.27, 0.8), 3)
	if health < 75:
		draw_rect(Rect2(-14, -35, 28, 3), Color("302e38"))
		draw_rect(Rect2(-14, -35, 28 * maxf(0, health) / 75, 3), Color("bd7568"))
