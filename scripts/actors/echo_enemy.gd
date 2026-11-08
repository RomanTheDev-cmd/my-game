extends "res://scripts/actors/enemy.gd"
# A wandering toll: it fades, reappears beside the hero and releases a visible ring.
const Rules = preload("res://scripts/combat/bell_rules.gd")
const FADE := 0.55
const WINDUP := 0.8
const RECOVERY := 1.2
const LEASH := 380.0
var transient := false
var ring_radius := 0.0
var ring_hit := false
var blink_target := Vector2.ZERO
var bounds := Rect2(40, 40, 1840, 1200)

func _ready() -> void:
	max_health = 64
	attack_damage = 16
	# Echoes called by the bell hunt across the whole chamber.
	aggro_range = 600.0 if transient else 240.0
	move_speed = 40
	reward_xp = 0 if transient else 30
	coin_reward = 0 if transient else 2
	super._ready()
	sprite.hide()

func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	queue_redraw()
	if not is_instance_valid(target) or target.health <= 0: return
	_tick_awareness(delta)
	# Frost slows the whole toll, not just its drifting.
	var step := delta * (slow_multiplier if slow_remaining > 0 else 1.0)
	timer = maxf(0, timer - step)
	path_timer = maxf(0, path_timer - delta)
	velocity = Vector2.ZERO
	match state:
		"fade":
			if timer == 0:
				global_position = blink_target
				_begin_windup()
		"windup":
			if timer == 0:
				state = "toll"
				ring_radius = 0
				ring_hit = false
				Sound.play_at("toll", global_position)
		"toll":
			var previous := ring_radius
			ring_radius = minf(Rules.ECHO_RING, ring_radius + Rules.RING_SPEED * step)
			var distance := target.global_position.distance_to(attack_origin)
			if not ring_hit and Rules.ring_crosses(previous, ring_radius, distance) and not Rules.covered(navigation, attack_origin, target.global_position):
				ring_hit = true
				target.receive_damage(attack_damage, "ringing")
			if ring_radius >= Rules.ECHO_RING:
				state = "recover"
				timer = RECOVERY
		"recover":
			if timer == 0: state = "idle"
		_:
			var offset := target.global_position - global_position
			var clear: bool = navigation == null or navigation.segment_clear(global_position, target.global_position)
			if detects_target() and offset.length() <= Rules.ECHO_RING * 0.7 and clear:
				_begin_windup()
			elif detects_target() and target.global_position.distance_to(home) < LEASH:
				var point := choose_blink()
				if point != Vector2.INF:
					state = "fade"
					timer = FADE
					blink_target = point
				else:
					velocity = _steer(target.global_position, move_speed)
			else:
				velocity = _steer(home, 35) if global_position.distance_to(home) > 8 else Vector2.ZERO
	move_and_slide()
	modulate = modulate.lerp(Color("92c5df") if slow_remaining > 0 else Color.WHITE, delta * 8)

func _begin_windup() -> void:
	state = "windup"
	timer = WINDUP
	attack_origin = global_position
	attack_direction = global_position.direction_to(target.global_position)

# Only open floor that the hero could also stand on; never inside walls or beyond its haunt.
func choose_blink() -> Vector2:
	var best := Vector2.INF
	for point in Rules.blink_points(target.global_position):
		if not bounds.has_point(point) or point.distance_to(home) > LEASH: continue
		if navigation != null and not navigation.segment_clear(target.global_position, point): continue
		if best == Vector2.INF or point.distance_to(global_position) < best.distance_to(global_position): best = point
	return best

func spell_multiplier(kind: String) -> float:
	return Rules.spell_multiplier(kind)

func receive_damage(amount: float, direction: Vector2) -> void:
	var multiplier := Rules.echo_multiplier(state)
	if multiplier == 0: return
	super.receive_damage(amount * multiplier, Vector2.ZERO if state in ["windup", "toll"] else direction)

# A howl breaks the toll before it rings, leaving the echo exposed.
func disrupt() -> bool:
	if health <= 0 or state not in ["fade", "windup"]: return false
	state = "recover"
	timer = RECOVERY + 0.4
	return true

func faint() -> bool:
	if not is_instance_valid(target) or state in ["windup", "toll", "recover"]: return false
	var tracking: bool = target.has_method("can_track") and target.can_track()
	return not tracking and target.global_position.distance_to(global_position) > 90

func _draw() -> void:
	_draw_awareness()
	var alpha := 0.35 if state == "fade" else (0.45 if faint() else 0.9)
	if state == "fade":
		var mark := blink_target - global_position
		draw_arc(mark, 14, 0, TAU, 20, Color(0.75, 0.85, 0.9, 0.7), 2)
		draw_line(mark + Vector2(0, -20), mark + Vector2(0, -8), Color(0.75, 0.85, 0.9, 0.7), 2)
	if state == "windup":
		draw_arc(Vector2(0, -6), Rules.ECHO_RING, 0, TAU, 48, Color(0.7, 0.82, 0.9, 0.35 + 0.3 * (1.0 - timer / WINDUP)), 2)
	if state == "toll":
		var origin := attack_origin - global_position
		draw_arc(origin, ring_radius, 0, TAU, 48, Color(0.82, 0.9, 0.95, 0.85), Rules.RING_WIDTH * 0.6)
	var body := Color(0.72, 0.8, 0.86, alpha)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -2), Vector2(-7, -22), Vector2(0, -30), Vector2(7, -22), Vector2(9, -2), Vector2(4, -6), Vector2(0, -1), Vector2(-4, -6)]), body)
	draw_rect(Rect2(-5, -21, 3, 2), Color(0.12, 0.16, 0.2, alpha))
	draw_rect(Rect2(2, -21, 3, 2), Color(0.12, 0.16, 0.2, alpha))
	draw_arc(Vector2(0, -14), 11, PI * 1.1, PI * 1.9, 8, Color(0.9, 0.94, 0.96, alpha * 0.6), 1)
	if health < max_health:
		draw_rect(Rect2(-14, -38, 28, 3), Color("302e38"))
		draw_rect(Rect2(-14, -38, 28 * maxf(0, health) / max_health, 3), Color("9fb7c4"))
