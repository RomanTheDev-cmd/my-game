extends Node2D
signal blood_drained(amount: float)
var direction := Vector2.RIGHT
var kind := "light"
var damage := 24.0
var speed := 360.0
var remaining := 1.4

func _ready() -> void:
	add_to_group("spell_projectiles")
	if kind == "frost":
		speed = 300
	z_index = 3
	queue_redraw()

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
		return
	var destination := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 1 | 4)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("receive_damage"):
			var previous_health: float = hit.collider.health
			hit.collider.receive_damage(damage, direction)
			if kind == "blood" and hit.collider.health < previous_health:
				blood_drained.emit(minf(18, (previous_health - maxf(0, hit.collider.health)) * 0.75))
			if kind == "frost" and hit.collider.has_method("apply_slow"):
				hit.collider.apply_slow(4.0, 0.55)
		queue_free()
		set_physics_process(false)
		return
	global_position = destination

func _draw() -> void:
	var center := Vector2(0, -8)
	draw_line(center - direction * 12, center, Color("bc6471") if kind == "blood" else (Color("96c4da") if kind == "frost" else Color("cead6d")), 4)
	draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), Color("edb5b3") if kind == "blood" else (Color("d4f1fa") if kind == "frost" else Color("fff0b9")))
