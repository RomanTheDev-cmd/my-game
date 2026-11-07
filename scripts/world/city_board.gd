extends Node2D
var kind := "board"
var plan := ""
var signatures := 0
var completed := false
var worked := false
func _draw() -> void:
	if kind == "board":
		draw_rect(Rect2(-30, -45, 60, 42), Color("806e51"))
		draw_rect(Rect2(-24, -40, 48, 30), Color("d6ceb1"))
		for y in [-33, -26, -19]: draw_line(Vector2(-18, y), Vector2(10 if plan == "shared" else 18, y), Color("566658"), 2)
		for i in signatures: draw_circle(Vector2(10 + i * 8, -14), 3, Color("426d5c"))
		for x in [-24, 24]: draw_line(Vector2(x, -3), Vector2(x, 12), Color("806e51"), 4)
		if completed: draw_circle(Vector2(25, -39), 6, Color("a8c5a2") if plan == "shared" else Color("c8b77a"))
	elif kind == "press":
		draw_rect(Rect2(-28, -19, 56, 22), Color("8c785b"))
		for x in [-22, 22]: draw_line(Vector2(x, -40), Vector2(x, 8), Color("b2b39a"), 5)
		draw_line(Vector2(-27, -40), Vector2(27, -40), Color("b2b39a"), 5)
		draw_rect(Rect2(-17, -10, 34, 8), Color("cbbd99") if worked else Color("5e6555"))
	else:
		draw_rect(Rect2(-30, -15, 60, 20), Color("8c785b"))
		for i in 3: draw_rect(Rect2(-22 + i * 15, -29, 13, 18), Color("c9c7a4"))
