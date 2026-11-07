extends CharacterBody2D
var kind := "keeper"
var destination := Vector2.ZERO
var navigation: RefCounted
var sprite: Sprite2D
var path := PackedVector2Array()
var path_index := 0
var path_timer := 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7
	collider.shape = shape
	add_child(collider)
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/keeper.png") if kind == "keeper" else preload("res://assets/sprites/wayfarer.png")
	sprite.position.y = -12
	add_child(sprite)
	sprite.modulate = {"warden": Color("99b6c5"), "wright": Color("d7bb8b"), "tender": Color("a5c9a5"), "tracker": Color("adc49f"), "host": Color("bcbfa5")}.get(kind, Color.WHITE)

func set_destination(point: Vector2) -> void:
	if point.distance_to(destination) > 1:
		destination = point
		path_timer = 0

func _physics_process(delta: float) -> void:
	if not visible or navigation == null:
		return
	path_timer = maxf(0, path_timer - delta)
	if position.distance_to(destination) < 3:
		velocity = Vector2.ZERO
		return
	if path_timer == 0:
		path = navigation.find_path(position, destination)
		path_index = 0
		path_timer = 0.8
	while path_index < path.size() and position.distance_to(path[path_index]) < 4:
		path_index += 1
	velocity = (path[path_index] - position).normalized() * 35 if path_index < path.size() else Vector2.ZERO
	move_and_slide()
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

func _draw() -> void:
	if kind == "host":
		draw_rect(Rect2(-11, -13, 6, 12), Color("d8d1b9"))
		draw_line(Vector2(-10, -9), Vector2(-6, -9), Color("667b75"), 2)
	if kind == "tracker":
		draw_line(Vector2(-11, -25), Vector2(10, -3), Color("bbaa7b"), 3)
		draw_rect(Rect2(-11, -30, 22, 4), Color("526550"))
	if kind == "warden":
		draw_rect(Rect2(-12, -12, 7, 10), Color("a6b6ba"))
		draw_rect(Rect2(-11, -11, 5, 7), Color("53757b"))
	elif kind == "wright":
		draw_rect(Rect2(8, -17, 2, 15), Color("9d8057"))
		draw_rect(Rect2(5, -18, 8, 4), Color("afbbb8"))
	elif kind == "tender":
		draw_rect(Rect2(-12, -5, 8, 5), Color("8b7552"))
		for i in 3:
			draw_rect(Rect2(-12 + i * 2, -10 - i % 2 * 2, 3, 6), Color("a8c084"))
