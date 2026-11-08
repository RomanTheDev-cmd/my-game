extends Node2D
var read := false

func _draw() -> void:
	draw_rect(Rect2(-15, -30, 30, 32), Color("3f4645"))
	draw_rect(Rect2(-12, -27, 24, 26), Color("8f927f") if read else Color("7b7f70"))
	for y in [-22, -17, -12, -7]:
		draw_line(Vector2(-8, y), Vector2(8, y), Color("575c52"), 1)
	draw_rect(Rect2(-17, 2, 34, 4), Color("5b5d51"))
	draw_rect(Rect2(14, -4, 4, 8), Color("d9cfae"))
	if read:
		draw_circle(Vector2(16, -9), 5, Color(1.0, 0.8, 0.45, 0.25))
		draw_rect(Rect2(15, -11, 2, 5), Color("ffe2a0"))
