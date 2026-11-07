extends Node2D
var repaired := false
var outcome := ""
func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -40), Color("807455"), 7)
	draw_rect(Rect2(-25, -38, 50, 20), Color("b7b99b") if repaired else Color("817e67"))
	var ink := Color("3c6451") if repaired else Color("4a443b")
	draw_line(Vector2(-18, -31), Vector2(18, -31), ink, 3)
	if repaired:
		draw_arc(Vector2.ZERO + Vector2(0, -26), 6, 0, PI, 12, ink, 2)
	else: draw_line(Vector2(-14, -23), Vector2(13, -34), ink, 2)
	if outcome != "": draw_circle(Vector2(22, -39), 5, Color("a7c9a7") if outcome == "commons" else Color("d5bd7b"))
