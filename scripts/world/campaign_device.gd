extends Node2D
var kind := "marks"
var settings := [0, 0, 0]
var resolved := false
func _draw() -> void:
	if kind == "control":
		draw_rect(Rect2(-43, -24, 86, 38), Color("748c84"))
		for i in 3:
			var center := Vector2(-27 + i * 27, -13)
			draw_arc(center, 11, 0, TAU, 18, Color("a8cbbb") if resolved else Color("c2b68f"), 2)
			draw_line(center, center + Vector2.from_angle(-PI / 2 + settings[i] * TAU / 3) * 9, Color("e2d4aa"), 3)
	elif kind == "marks":
		for i in 3:
			draw_rect(Rect2(-24 + i * 18, -14, 13, 18), Color("a4b7a5"))
			draw_line(Vector2(-20 + i * 18, -7), Vector2(-15 + i * 18, -7 + [3, 6, 0][i]), Color("516c63"), 2)
	else:
		for i in 5: draw_line(Vector2(-20 + i * 9, -2), Vector2(-13 + i * 9, -6), Color("a7c9b4"), 2)
