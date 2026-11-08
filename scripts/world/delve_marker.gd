extends Node2D
# Stairs down to the next hollow, or the old surveyors' note at a hollow's entrance.
var kind := "stairs"
var open := false

func _draw() -> void:
	if kind == "note":
		draw_rect(Rect2(-12, -26, 24, 20), Color("6b5f4c"))
		draw_rect(Rect2(-10, -24, 20, 16), Color("c9bb94"))
		for y in [-20, -16, -12]: draw_line(Vector2(-7, y), Vector2(7, y), Color("6f6450"), 1)
		draw_rect(Rect2(-2, -6, 4, 10), Color("4f4639"))
		return
	draw_rect(Rect2(-30, -22, 60, 44), Color("0f1416"))
	for i in 4: draw_rect(Rect2(-26 + i * 5, -18 + i * 10, 52 - i * 10, 6), Color("4c5551") if open else Color("3a403e"))
	if not open:
		for x in [-24, -8, 8, 24]: draw_line(Vector2(x, -22), Vector2(x, 22), Color("8f8a6f"), 3)
	else:
		draw_circle(Vector2(0, 0), 26, Color(0.75, 0.85, 0.9, 0.08))
