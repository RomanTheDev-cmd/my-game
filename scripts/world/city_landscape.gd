extends "res://scripts/world/landscape.gd"
const Accord = preload("res://scripts/world/accord_changes.gd")
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280), Rect2(300, 280, 310, 200), Rect2(1010, 230, 330, 220), Rect2(1450, 290, 260, 220), Rect2(650, 930, 240, 130), Rect2(1100, 970, 300, 150)]
const ROADS := [Rect2(100, 580, 1660, 140), Rect2(680, 450, 300, 470), Rect2(480, 700, 200, 175), Rect2(1120, 450, 190, 420)]
func _ready() -> void:
	for rect in WALLS: _obstacle(rect)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("4e6655"))
	for rect in ROADS:
		draw_rect(rect, Color("aaa58a"))
		for y in range(int(rect.position.y), int(rect.end.y), 20):
			for x in range(int(rect.position.x), int(rect.end.x), 28): draw_rect(Rect2(x, y, 26, 18), Color("95967e") if (x + y) % 3 else Color("b2ae94"))
	for rect in WALLS.slice(4): _house(rect.position - Vector2(10, 20), rect.size + Vector2(20, 20), true)
	if "accord_release" in Session.opened: draw_rect(Accord.PASSAGES.velshof.grow_individual(10, 0, 18, 0), Color("aaa58a"))
	for point in [Vector2(400, 530), Vector2(750, 510), Vector2(1370, 600), Vector2(980, 850)]:
		draw_rect(Rect2(point - Vector2(32, 14), Vector2(64, 28)), Color("6a7560"))
		for i in 4:
			draw_circle(point + Vector2(-22 + i * 15, -12), 11, Color("5b7c58"))
			draw_circle(point + Vector2(-22 + i * 15, -17), 3, Color("d4bc83"))
	for point in [Vector2(270, 600), Vector2(960, 610), Vector2(1360, 480)]:
		draw_line(point, point - Vector2(0, 40), Color("677262"), 4)
		draw_rect(Rect2(point - Vector2(7, 47), Vector2(14, 17)), Color("dfcb8c"))
	_camp(Vector2(350, 840))

	if "accord_renewal" in Session.opened: _camp(Accord.Rules.CAMPS[region])
