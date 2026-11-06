extends Node2D
var event_id := ""
var elapsed := 0.0
var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/wayfarer.png")
	sprite.position.y = -12
	sprite.modulate = Color("c5c7b2")
	add_child(sprite)

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	sprite.visible = event_id not in ["fireflies", "lost_pack"]
	queue_redraw()

func _draw() -> void:
	if event_id == "fireflies":
		for i in 8:
			var point := Vector2(sin(elapsed * 0.6 + i * 2) * 22, cos(elapsed * 0.8 + i * 3) * 13 - 10)
			draw_circle(point, 5, Color(0.9, 0.84, 0.5, 0.1))
			draw_rect(Rect2(point, Vector2(2, 2)), Color("e7d99d"))
	elif event_id == "lost_pack":
		draw_rect(Rect2(-7, -8, 14, 11), Color("574d3d"))
		draw_rect(Rect2(-6, -9, 12, 8), Color("ac9567"))
		draw_rect(Rect2(-2, -8, 4, 5), Color("c7ba89"))
