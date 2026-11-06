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
