extends Node2D
var kind := "wheel"
var done := false

func _draw() -> void:
	var metal := Color("a6b4a4") if done else Color("b2a383")
	match kind:
		"wheel":
			draw_rect(Rect2(-19, -5, 38, 12), Color("5a5a4b"))
			draw_arc(Vector2(0, -12), 16, 0, TAU, 24, metal, 3)
			for i in 6:
				draw_line(Vector2(0, -12), Vector2(0, -12) + Vector2.from_angle(i * TAU / 6) * 16, metal, 2)
			draw_rect(Rect2(-3, -15, 6, 6), Color("5b7a75") if done else Color("635642"))
		"archive":
			draw_rect(Rect2(-11, -12, 22, 15), Color("716957"))
			draw_rect(Rect2(-10, -17, 20, 13), metal)
			draw_line(Vector2(0, -17), Vector2(0, -4), Color("666453"), 1)
			for y in [-14, -11, -8]:
				draw_line(Vector2(3, y), Vector2(8, y), Color("6a6d60"), 1)
		"workbench":
			draw_rect(Rect2(-16, -12, 32, 9), Color("8f805e"))
			draw_rect(Rect2(-12, -3, 4, 8), Color("605d49"))
			draw_rect(Rect2(8, -3, 4, 8), Color("605d49"))
			draw_line(Vector2(-6, -13), Vector2(6, -19), metal, 3)
		"cache":
			draw_rect(Rect2(-14, -14, 28, 18), Color("71644b"))
			for x in [-11, 7]:
				draw_rect(Rect2(x, -14, 4, 18), metal)
		"scrap":
			for i in 3:
				draw_rect(Rect2(-7 + i * 5, -4 - i % 2 * 3, 4, 7), metal)
