extends Node2D
var direction := Vector2.RIGHT
var speed := 220.0
var damage := 16.0
var remaining := 2.0

func _ready() -> void:
	add_to_group("hostile_projectiles")
	z_index = 3

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
		return
	var destination := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 1 | 2)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("receive_damage"):
			hit.collider.receive_damage(damage)
		set_physics_process(false)
		queue_free()
		return
	global_position = destination

func _draw() -> void:
	draw_line(Vector2(0, -8) - direction * 12, Vector2(0, -8), Color("b6a28b"), 2)
	draw_line(Vector2(0, -8), Vector2(0, -8) - direction.rotated(0.6) * 5, Color("d8c5a0"), 2)
