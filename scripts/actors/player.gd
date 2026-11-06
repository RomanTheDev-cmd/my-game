extends CharacterBody2D
const Gear = preload("res://scripts/items/equipment_rules.gd")
const GearVisual = preload("res://scripts/items/gear_visual.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
signal died
signal strike(origin: Vector2, direction: Vector2)
signal cast_spell(origin: Vector2, direction: Vector2, damage: float, kind: String)
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
var gear_visual: Node2D
var magic_cooldown := 0.0
var aim_with_mouse := false
var step_distance := 0.0
var shield_strength := 0.0
var shield_time := 0.0
var shield_recharge := 0.0

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
	gear_visual = GearVisual.new()
	add_child(gear_visual)
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
	shield_recharge = maxf(0, shield_recharge - delta)
	shield_time = maxf(0, shield_time - delta)
	if shield_time == 0:
		shield_strength = 0
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
		attack_cooldown = Gear.weapon(Session.equipped).cooldown
		Sound.play_at("swing", global_position)
		strike.emit(global_position, facing)
	if Input.is_action_just_pressed("dodge") and stamina >= 28 and dodge_time == 0:
		stamina -= 28
		dodge_time = 0.23
		dodge_direction = facing
		Sound.play_at("dodge", global_position)
	blocking = Input.is_action_pressed("block") and stamina > 0 and dodge_time == 0
	velocity = dodge_direction * 310 if dodge_time > 0 else direction * (55 if blocking else 115)
	var previous_position := global_position
	move_and_slide()
	if dodge_time == 0 and direction.length() > 0.15:
		step_distance += global_position.distance_to(previous_position)
		if step_distance >= 38:
			step_distance = fmod(step_distance, 38)
			Sound.footstep(global_position)
	else:
		step_distance = 0
	stamina = minf(100, stamina + delta * (10 if blocking else 24))
	mana = minf(100, mana + delta * 2)
	if Input.is_action_just_pressed("heal"):
		cast_magic("heal")
	if Input.is_action_just_pressed("cast"):
		cast_magic("light")
	if Input.is_action_just_pressed("frost"):
		cast_magic("frost")
	if Input.is_action_just_pressed("aegis"):
		cast_magic("aegis")
	if Input.is_action_just_pressed("use_potion"):
		drink_potion()
	gear_visual.scale.x = -1 if facing.x < 0 else 1
	gear_visual.queue_redraw()
	sprite.flip_h = facing.x < 0
	sprite.position.y = -12 + (sin(Time.get_ticks_msec() * 0.018) if velocity.length() > 1 else 0)
	modulate = modulate.lerp(Color.WHITE, delta * 8)
	stats_changed.emit()
	queue_redraw()

func receive_damage(amount: float) -> void:
	if health <= 0 or hurt_time > 0:
		return
	var reduced := amount * (1.0 - 0.1 * int(Session.skills.get("ward", 0))) * (1.0 - Gear.reduction(Session.equipped))
	var hit := Rules.damage(reduced, Session.difficulty, blocking, dodge_time > 0, Gear.block(Session.equipped))
	if hit <= 0:
		return
	var absorbed := minf(hit, shield_strength) if shield_time > 0 else 0.0
	shield_strength = maxf(0, shield_strength - absorbed)
	hit -= absorbed
	Sound.play_at("block" if blocking or absorbed > 0 else "impact", global_position)
	if blocking:
		stamina = maxf(0, stamina - 23)
	health = maxf(0, health - hit)
	hurt_time = 0.45
	modulate = Color("b7dce3") if hit == 0 else Color(1.7, 0.55, 0.55)
	stats_changed.emit()
	if health == 0:
		died.emit()

func restore() -> void:
	magic_cooldown = 0
	shield_strength = 0
	shield_time = 0
	shield_recharge = 0
	attack_cooldown = 0
	hurt_time = 0
	dodge_time = 0
	health = 100
	stamina = 100
	mana = 100
	stats_changed.emit()

func _draw() -> void:
	if shield_time > 0 and shield_strength > 0:
		draw_arc(Vector2(0, -8), 22, 0, TAU, 32, Color(0.65, 0.85, 0.92, minf(0.8, shield_time)), 2)
	if attack_time > 0:
		var angle := facing.angle()
		draw_arc(Vector2(0, -8), Gear.weapon(Session.equipped).reach * 0.72, angle - 0.95, angle + 0.95, 12, Color(0.94, 0.85, 0.63, attack_time / 0.18), 3)
	if blocking:
		draw_arc(Vector2(0, -6), 17, facing.angle() - 0.9, facing.angle() + 0.9, 8, Color("c9b989"), 3)

func can_cast_magic(id: String) -> bool:
	return dodge_time == 0 and not (id == "aegis" and shield_recharge > 0) and not Magic.cast(id, health, mana, magic_cooldown).is_empty()

func cast_magic(id: String) -> bool:
	if dodge_time > 0:
		return false
	if id == "aegis" and shield_recharge > 0:
		Session.notice.emit("SPELL_RECHARGING")
		return false
	var result := Magic.cast(id, health, mana, magic_cooldown)
	if result.is_empty():
		if id == "heal" and health >= 100:
			Session.notice.emit("NO_HEAL_NEEDED")
		elif Magic.SPELLS.has(id) and mana < Magic.SPELLS[id].cost:
			Session.notice.emit("NOT_ENOUGH_MANA")
		return false
	Sound.play_at("block" if id == "aegis" else ("magic" if id in ["light", "frost"] else "heal"), global_position)
	health = result.health
	mana = result.mana
	magic_cooldown = result.cooldown
	if id in ["light", "frost"]:
		var direction := facing
		if aim_with_mouse and global_position.distance_to(get_global_mouse_position()) > 3:
			direction = (get_global_mouse_position() - global_position).normalized()
		var bonus := 6 * int(Session.skills.get("light", 0)) if id == "light" else 0
		cast_spell.emit(global_position + direction * 12, direction, result.damage + bonus, id)
	elif id == "aegis":
		shield_strength = result.shield + 10 * int(Session.skills.get("ward", 0))
		shield_time = Magic.SPELLS.aegis.duration
		shield_recharge = Magic.SPELLS.aegis.recharge
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
	Sound.play_at("heal", global_position)
	health = minf(100, health + 60)
	modulate = Color(1, 1.4, 1.15)
	stats_changed.emit()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_with_mouse = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		aim_with_mouse = false
