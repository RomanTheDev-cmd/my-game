extends CharacterBody2D
const Pack = preload("res://scripts/nature/pack_rules.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Gear = preload("res://scripts/items/equipment_rules.gd")
const GearVisual = preload("res://scripts/items/gear_visual.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
signal died
signal strike(origin: Vector2, direction: Vector2)
signal cast_spell(origin: Vector2, direction: Vector2, damage: float, kind: String)
signal howled(origin: Vector2)
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
var verify_arrival := true
var body_collider: CollisionShape2D
var sprite: Sprite2D
var gear_visual: Node2D
var scent_time := 0.0
var nature_cooldown := 0.0
var magic_cooldown := 0.0
var aim_with_mouse := false
var step_distance := 0.0
var shield_strength := 0.0
var shield_time := 0.0
var shield_recharge := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 17
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	shape.shape = circle
	add_child(shape)
	body_collider = shape
	_set_form_shape()
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
	_update_nature_visuals()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	sync_form_geometry()
	advance_timers(delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length() > 0.15:
		facing = direction.normalized()
	if Input.is_action_just_pressed("attack") and attack_cooldown == 0 and dodge_time == 0 and Session.nature.form not in ["bat", "mist"]:
		if get_global_mouse_position().distance_to(global_position) > 3 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			facing = (get_global_mouse_position() - global_position).normalized()
		attack_time = 0.18
		attack_cooldown = weapon_stats().cooldown
		Sound.play_at("swing", global_position)
		strike.emit(global_position, facing)
	if Input.is_action_just_pressed("dodge") and stamina >= 28 and dodge_time == 0:
		stamina -= 28
		dodge_time = 0.23
		dodge_direction = facing
		Sound.play_at("dodge", global_position)
	blocking = Input.is_action_pressed("block") and stamina > 0 and dodge_time == 0 and Session.nature.form == "human"
	velocity = dodge_direction * 310 if dodge_time > 0 else direction * (55 if blocking else movement_speed())
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
	var exposed := Nature.sunlight(Session.nature, Clock.daylight(Session.world_state.minutes), Regions.get_region(Session.region).get("indoor", false)) > 1
	mana = minf(100, mana + delta * (0.8 if exposed else 2.0))
	health = minf(100, health + delta * Nature.regeneration(Session.nature, Session.world_state.minutes))
	if Input.is_action_just_pressed("nature_power"): use_nature_power()
	if Input.is_action_just_pressed("shift_form"): shift_form()
	if Input.is_action_just_pressed("hybrid_form"): shift_form("hybrid")
	if Input.is_action_just_pressed("bat_form"): shift_form("bat")
	if Input.is_action_just_pressed("mist_form"): shift_form("mist")
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
	_update_nature_visuals()
	gear_visual.scale.x = -1 if facing.x < 0 else 1
	gear_visual.queue_redraw()
	sprite.flip_h = facing.x < 0
	sprite.position.y = -12 + (sin(Time.get_ticks_msec() * 0.018) if velocity.length() > 1 else 0)
	modulate = modulate.lerp(Color.WHITE, delta * 8)
	stats_changed.emit()
	queue_redraw()

func advance_timers(delta: float) -> void:
	scent_time = maxf(0, scent_time - delta)
	nature_cooldown = maxf(0, nature_cooldown - delta)
	magic_cooldown = maxf(0, magic_cooldown - delta)
	shield_recharge = maxf(0, shield_recharge - delta)
	shield_time = maxf(0, shield_time - delta)
	if shield_time == 0:
		shield_strength = 0
	attack_time = maxf(0, attack_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	hurt_time = maxf(0, hurt_time - delta)

func receive_damage(amount: float) -> void:
	if health <= 0 or hurt_time > 0:
		return
	var armor: float = 0.0 if Session.nature.kind == "werewolf" and Session.nature.form != "human" else Gear.reduction(Session.equipped)
	var reduced := amount * (1.0 - 0.1 * int(Session.skills.get("ward", 0))) * (1.0 - armor)
	if Session.nature.form == "mist": reduced *= 0.25
	reduced *= Nature.sunlight(Session.nature, Clock.daylight(Session.world_state.minutes), Regions.get_region(Session.region).get("indoor", false))
	var guarded: bool = blocking and Session.nature.form == "human"
	var hit := Rules.damage(reduced, Session.difficulty, guarded, dodge_time > 0, Gear.block(Session.equipped))
	if hit <= 0:
		return
	var absorbed := minf(hit, shield_strength) if shield_time > 0 else 0.0
	shield_strength = maxf(0, shield_strength - absorbed)
	hit -= absorbed
	Sound.play_at("block" if guarded or absorbed > 0 else "impact", global_position)
	if guarded:
		stamina = maxf(0, stamina - 23)
	health = maxf(0, health - hit)
	hurt_time = 0.45
	modulate = Color("b7dce3") if hit == 0 else Color(1.7, 0.55, 0.55)
	stats_changed.emit()
	if health == 0:
		died.emit()

func restore() -> void:
	scent_time = 0
	nature_cooldown = 0
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
	if Session.nature.form == "bat":
		draw_colored_polygon(PackedVector2Array([Vector2(-23, -13), Vector2(-10, -18), Vector2(0, -6), Vector2(10, -18), Vector2(23, -13), Vector2(11, -3), Vector2(0, -2), Vector2(-11, -3)]), Color("616876"))
		draw_rect(Rect2(-4, -14, 8, 14), Color("9eaaa9"))
	if Session.nature.form == "mist":
		for i in 5: draw_circle(Vector2(-18 + i * 8, -7 - i % 2 * 5), 10, Color(0.63, 0.76, 0.8, 0.35))
	if Session.nature.form == "wolf":
		var sign_value := -1 if facing.x < 0 else 1
		draw_rect(Rect2(-15, -15, 30, 15), Color("73776c"))
		draw_rect(Rect2(9 if sign_value > 0 else -21, -23, 14, 13), Color("9c9f8c"))
		draw_rect(Rect2(12 if sign_value > 0 else -18, -27, 5, 7), Color("6a7266"))
		draw_line(Vector2(-sign_value * 13, -12), Vector2(-sign_value * 23, -18), Color("8a9281"), 5)
		for x in [-11, 8]: draw_rect(Rect2(x, -2, 4, 8), Color("535f54"))
	if Session.nature.form == "hybrid":
		draw_rect(Rect2(-13, -31, 26, 31), Color("626e5e"))
		draw_rect(Rect2(-10, -47, 20, 17), Color("9ca38c"))
		for x in [-20, 14]:
			draw_rect(Rect2(x, -30, 6, 26), Color("7d8d72"))
			for i in 3: draw_rect(Rect2(x + i * 2, -4, 1, 8), Color("d5d8b9"))
	if Session.nature.kind == "werewolf" and Session.nature.form != "human" and Pack.moon(Session.world_state.minutes) > 0.8:
		draw_arc(Vector2(0, -12), 26, 0, TAU, 24, Color(0.7, 0.8, 0.9, 0.5), 1)
	if Session.nature.form == "battle":
		draw_rect(Rect2(-11, -25, 22, 25), Color("433844"))
		draw_rect(Rect2(-8, -40, 16, 15), Color("c5c5bb"))
		draw_rect(Rect2(-6, -35, 4, 3), Color("b36665"))
		for x in [-17, 12]:
			draw_rect(Rect2(x, -21, 5, 19), Color("a7ada5"))
			for i in 3: draw_rect(Rect2(x + i * 2, -1, 1, 5), Color("e5dfca"))
	if shield_time > 0 and shield_strength > 0:
		draw_arc(Vector2(0, -8), 22, 0, TAU, 32, Color(0.65, 0.85, 0.92, minf(0.8, shield_time)), 2)
	if attack_time > 0:
		var angle := facing.angle()
		draw_arc(Vector2(0, -8), weapon_stats().reach * 0.72, angle - 0.95, angle + 0.95, 12, Color(0.94, 0.85, 0.63, attack_time / 0.18), 3)
	if blocking:
		draw_arc(Vector2(0, -6), 17, facing.angle() - 0.9, facing.angle() + 0.9, 8, Color("c9b989"), 3)

func can_cast_magic(id: String) -> bool:
	return Nature.can_spell(Session.nature, id) and dodge_time == 0 and not (id == "aegis" and shield_recharge > 0) and not Magic.cast(id, health, mana, magic_cooldown, Session.skills).is_empty()

func cast_magic(id: String) -> bool:
	if not Nature.can_spell(Session.nature, id):
		Session.notice.emit("NATURE_SPELL_BLOCKED")
		return false
	if dodge_time > 0:
		return false
	if id == "aegis" and shield_recharge > 0:
		Session.notice.emit("SPELL_RECHARGING")
		return false
	var result := Magic.cast(id, health, mana, magic_cooldown, Session.skills)
	if result.is_empty():
		if id == "heal" and health >= 100:
			Session.notice.emit("NO_HEAL_NEEDED")
		elif Magic.SPELLS.has(id) and mana < Magic.profile(id, Session.skills).get("cost", INF):
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
		cast_spell.emit(global_position + direction * 12, direction, result.damage, id)
	elif id == "aegis":
		shield_strength = result.shield
		shield_time = result.duration
		shield_recharge = result.recharge
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

func weapon_stats() -> Dictionary:
	match Session.nature.form:
		"bat", "mist": return {"damage": 0.0, "reach": 0.0, "cooldown": 1.0}
		"wolf": return {"damage": 22.0, "reach": 40.0, "cooldown": 0.42}
		"hybrid":
			var bonus := 1.0 + (Pack.moon(Session.world_state.minutes) * 0.15 if Clock.daylight(Session.world_state.minutes) < 0.5 else 0.0)
			return {"damage": 50.0 * bonus, "reach": 65.0, "cooldown": 0.68}
		"battle": return {"damage": 46.0, "reach": 58.0, "cooldown": 0.5}
	return Gear.weapon(Session.equipped)
func movement_speed() -> float:
	return {"bat": 190.0, "mist": 135.0, "wolf": 175.0, "hybrid": 125.0, "battle": 145.0}.get(Session.nature.form, 115.0)
func visibility_scale() -> float:
	return 0.35 if Session.nature.form == "mist" else 1.0

func can_track() -> bool:
	return (Session.nature.kind == "werewolf" and Session.nature.form == "wolf") or scent_time > 0

func can_nature_power() -> bool:
	if health <= 0 or dodge_time > 0 or nature_cooldown > 0: return false
	if Session.nature.kind == "werewolf": return Session.nature.resolve >= 15 and stamina >= 20
	if Session.nature.form != "human": return false
	if Session.nature.gift in ["oath", "scar", "trail_oath", "wild_scar"]: return mana >= 32
	return Session.nature.kind == "vampire" and mana >= 16 and Session.nature.blood >= 12

func use_nature_power() -> bool:
	if not can_nature_power():
		Session.notice.emit("NATURE_POWER_UNAVAILABLE")
		return false
	if Session.nature.kind == "werewolf":
		Session.nature.resolve -= 15
		if Session.nature.resolve == 0: Session.nature.form = "human"
		stamina -= 20
		health = minf(100, health + 12)
		scent_time = 12
		nature_cooldown = 8
		howled.emit(global_position)
		Sound.play_at("magic", global_position)
	elif Session.nature.kind == "vampire":
		mana -= 16
		Session.nature.blood -= 12
		var direction := facing
		if aim_with_mouse and global_position.distance_to(get_global_mouse_position()) > 3:
			direction = global_position.direction_to(get_global_mouse_position())
		cast_spell.emit(global_position + direction * 12, direction, 24.0, "blood")
		nature_cooldown = 1.0
		Sound.play_at("magic", global_position)
	else:
		mana -= 32
		shield_strength = 45 if Session.nature.gift in ["oath", "trail_oath"] else 40
		shield_time = 8
		if Session.nature.gift == "wild_scar": scent_time = 6
		nature_cooldown = 12
		Sound.play_at("block", global_position)
	stats_changed.emit()
	return true

func shift_form(requested: String = "") -> bool:
	if health <= 0 or (dodge_time > 0 and Session.nature.form == "human"): return false
	var next := Nature.shift(Session.nature, requested, landing_context())
	if next.is_empty():
		Session.notice.emit("PACK_FORM_UNAVAILABLE" if Session.nature.kind == "werewolf" else "NATURE_FORM_UNAVAILABLE")
		return false
	Session.nature = next
	sync_form_geometry()
	_update_nature_visuals()
	dodge_time = 0
	blocking = false
	Session.changed.emit()
	return true

func _update_nature_visuals() -> void:
	gear_visual.visible = Session.nature.form == "human"
	sprite.visible = Session.nature.form == "human"
	sprite.modulate = Color("bcc7d1") if Session.nature.kind == "vampire" else Color.WHITE
	queue_redraw()

func _human_space_clear(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 17
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
func _landing_safe(point: Vector2) -> bool:
	return _human_space_clear(point) and (not get_parent().has_method("landing_safe") or get_parent().landing_safe(point))
func landing_context() -> Dictionary:
	if is_inside_tree() and _landing_safe(global_position):
		return {"region": Session.region, "position": [global_position.x, global_position.y]}
	return Session.nature.landing.duplicate(true)
func can_shift_form(requested: String) -> bool:
	return not Nature.shift(Session.nature, requested, landing_context()).is_empty()
func _set_form_shape() -> void:
	if body_collider == null: return
	var radius := 2.0 if Session.nature.form == "mist" else (6.0 if Session.nature.form == "bat" else 8.0)
	if (body_collider.shape as CircleShape2D).radius != radius: (body_collider.shape as CircleShape2D).radius = radius
	collision_mask = 1 if Session.nature.form == "bat" else 17
func sync_form_geometry() -> void:
	if verify_arrival:
		verify_arrival = false
		# Old saves may predate the new walls or closed chambers.
		if Session.nature.form not in ["bat", "mist"] and not _landing_safe(global_position):
			global_position = Regions.get_region(Session.region).camp
	if Session.nature.form in ["bat", "mist"]:
		if _landing_safe(global_position): Session.nature.landing = {"region": Session.region, "position": [global_position.x, global_position.y]}
	elif not Session.nature.landing.is_empty():
		if not _landing_safe(global_position):
			var saved: Array = Session.nature.landing.position
			var anchor := Vector2(saved[0], saved[1])
			global_position = anchor if _landing_safe(anchor) else Regions.get_region(Session.region).camp
		Session.nature.landing = {}
	_set_form_shape()
