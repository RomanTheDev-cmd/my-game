extends Node2D
var direction := Vector2.RIGHT
func _draw() -> void:
	var tip := direction * 38
	var side := direction.orthogonal() * 5
	draw_colored_polygon(PackedVector2Array([tip + direction * 10, tip - direction * 5 + side, tip - direction * 5 - side]), Color("d4d3a6"))
	for i in 3:
		draw_circle(direction * (20 + i * 5), 1.5, Color(0.8, 0.85, 0.65, 0.4 + i * 0.15))
