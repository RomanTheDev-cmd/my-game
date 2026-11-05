extends CharacterBody2D
const Rules = preload("res://scripts/combat/combat_rules.gd")
signal died
signal strike(origin: Vector2, direction: Vector2)
signal stats_changed
var health := 100.0
var stamina := 100.0
var mana := 100.0
var facing := Vector2.RIGHT
var attack_time := 0.0
var attack_cooldown := 0.0
var dodge_time := 0.0
var hurt_time := 0.0
var blocking := false
var dodge_direction := Vector2.ZERO
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/traveler.png")
	sprite.position.y = -12
	add_child(sprite)
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.65, 1.65)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1920
	camera.limit_bottom = 1280
	add_child(camera)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	attack_time = maxf(0, attack_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	hurt_time = maxf(0, hurt_time - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length() > 0.15:
		facing = direction.normalized()
	if Input.is_action_just_pressed("attack") and attack_cooldown == 0 and dodge_time == 0:
		if get_global_mouse_position().distance_to(global_position) > 3 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			facing = (get_global_mouse_position() - global_position).normalized()
		attack_time = 0.18
		attack_cooldown = 0.42
		strike.emit(global_position, facing)
	if Input.is_action_just_pressed("dodge") and stamina >= 28 and dodge_time == 0:
		stamina -= 28
		dodge_time = 0.23
		dodge_direction = facing
	blocking = Input.is_action_pressed("block") and stamina > 0 and dodge_time == 0
	velocity = dodge_direction * 310 if dodge_time > 0 else direction * (55 if blocking else 115)
	move_and_slide()
	stamina = minf(100, stamina + delta * (10 if blocking else 24))
	mana = minf(100, mana + delta * 2)
	if Input.is_action_just_pressed("heal"):
		if health >= 100:
			Session.notice.emit("NO_HEAL_NEEDED")
		elif mana < 35:
			Session.notice.emit("NOT_ENOUGH_MANA")
		else:
			mana -= 35
			health = minf(100, health + 40)
			modulate = Color(1, 1.4, 1.15)
	sprite.flip_h = facing.x < 0
	sprite.position.y = -12 + (sin(Time.get_ticks_msec() * 0.018) if velocity.length() > 1 else 0)
	modulate = modulate.lerp(Color.WHITE, delta * 8)
	stats_changed.emit()
	queue_redraw()

func receive_damage(amount: float) -> void:
	if health <= 0 or hurt_time > 0:
		return
	var hit := Rules.damage(amount, Session.difficulty, blocking, dodge_time > 0)
	if hit <= 0:
		return
	if blocking:
		stamina = maxf(0, stamina - 23)
	health = maxf(0, health - hit)
	hurt_time = 0.45
	modulate = Color(1.7, 0.55, 0.55)
	stats_changed.emit()
	if health == 0:
		died.emit()

func restore() -> void:
	health = 100
	stamina = 100
	mana = 100
	stats_changed.emit()

func _draw() -> void:
	if attack_time > 0:
		var angle := facing.angle()
		draw_arc(Vector2(0, -8), 32, angle - 0.95, angle + 0.95, 12, Color(0.94, 0.85, 0.63, attack_time / 0.18), 3)
	if blocking:
		draw_arc(Vector2(0, -6), 17, facing.angle() - 0.9, facing.angle() + 0.9, 8, Color("c9b989"), 3)
