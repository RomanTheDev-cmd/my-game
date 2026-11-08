extends StaticBody2D
var side := "north"
var world: Node2D
func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17
	collider.shape = shape
	add_child(collider)
func receive_spell(kind: String, _damage: float) -> void:
	if kind == "light": world.rescue_action("light_" + side, true)
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	var rules = preload("res://scripts/quests/rescue_rules.gd")
	var done: bool = rules.cut(Session.gathered, side) != ""
	draw_circle(Vector2.ZERO, 18, Color("435e5d"))
	draw_arc(Vector2.ZERO, 17, 0, TAU, 24, Color("a8c4ac") if done else Color("c0ab7e"), 3)
	if done: draw_line(Vector2(-12, 0), Vector2(12, 0), Color("a8c4ac"), 3)
	else:
		draw_line(Vector2(0, -15), Vector2(0, 15), Color("d7c28e"), 4)
		if rules.method(Session.gathered) == "scent" and world.player.can_track() and world.player.position.distance_to(position) < 260:
			for x in [-25, 25]: draw_arc(Vector2(x, 0), 5, -PI / 2, PI / 2, 8, Color("d1d7ac"), 2)
