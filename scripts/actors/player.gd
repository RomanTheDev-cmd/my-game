extends CharacterBody2D
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
signal died
signal strike(origin: Vector2, direction: Vector2)
signal cast_spell(origin: Vector2, direction: Vector2, damage: float)
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
var magic_cooldown := 0.0
var aim_with_mouse := false

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
	magic_cooldown = maxf(0, magic_cooldown - delta)
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
		cast_magic("heal")
	if Input.is_action_just_pressed("cast"):
		cast_magic("light")
	if Input.is_action_just_pressed("use_potion"):
		drink_potion()
	sprite.flip_h = facing.x < 0
	sprite.position.y = -12 + (sin(Time.get_ticks_msec() * 0.018) if velocity.length() > 1 else 0)
	modulate = modulate.lerp(Color.WHITE, delta * 8)
	stats_changed.emit()
	queue_redraw()

func receive_damage(amount: float) -> void:
	if health <= 0 or hurt_time > 0:
		return
	var reduced := amount * (1.0 - 0.1 * int(Session.skills.get("ward", 0)))
	var hit := Rules.damage(reduced, Session.difficulty, blocking, dodge_time > 0)
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

func cast_magic(id: String) -> bool:
	if dodge_time > 0:
		return false
	var result := Magic.cast(id, health, mana, magic_cooldown)
	if result.is_empty():
		if id == "heal" and health >= 100:
			Session.notice.emit("NO_HEAL_NEEDED")
		elif Magic.SPELLS.has(id) and mana < Magic.SPELLS[id].cost:
			Session.notice.emit("NOT_ENOUGH_MANA")
		return false
	health = result.health
	mana = result.mana
	magic_cooldown = result.cooldown
	if id == "light":
		var direction := facing
		if aim_with_mouse and global_position.distance_to(get_global_mouse_position()) > 3:
			direction = (get_global_mouse_position() - global_position).normalized()
		cast_spell.emit(global_position + direction * 12, direction, result.damage + 6 * int(Session.skills.get("light", 0)))
	else:
		modulate = Color(1, 1.4, 1.15)
	stats_changed.emit()
	return true

func drink_potion() -> bool:
	if health >= 100:
		Session.notice.emit("NO_HEAL_NEEDED")
		return false
	if health <= 0 or not Session.consume_item("potion"):
		Session.notice.emit("NO_POTION")
		return false
	health = minf(100, health + 60)
	modulate = Color(1, 1.4, 1.15)
	stats_changed.emit()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_with_mouse = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		aim_with_mouse = false
