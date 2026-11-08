extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280), Rect2(90, 170, 1740, 80), Rect2(90, 1160, 1740, 80), Rect2(90, 250, 60, 310), Rect2(90, 760, 60, 400), Rect2(1770, 250, 60, 910), Rect2(820, 340, 50, 180), Rect2(820, 900, 50, 180), Rect2(1430, 350, 60, 180), Rect2(1430, 880, 60, 180)]
# Solid rock beyond the inner frame: only the exit alcove stays open outside the hall.
const ROCK := [Rect2(0, 0, 90, 1280), Rect2(0, 0, 1920, 170), Rect2(0, 1240, 1920, 40), Rect2(1830, 0, 90, 1280)]
func _ready() -> void:
	for rect in WALLS + ROCK: _obstacle(rect)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("20383d"))
	draw_rect(Rect2(150, 250, 1620, 910), Color("777e72"))
	for y in range(250, 1160, 24):
		for x in range(150, 1770, 32): draw_rect(Rect2(x, y, 30, 22), Color("858977") if (x + y) % 3 else Color("68756a"))
	for rect in WALLS:
		draw_rect(rect.grow(4), Color("354d4d"))
		draw_rect(rect, Color("b0b3a0"))
	for x in [360, 620, 1030, 1580]:
		draw_rect(Rect2(x, 255, 110, 35), Color("5a787c"))
		draw_line(Vector2(x, 290), Vector2(x + 110, 290), Color("c9c9ad"), 3)
	for r in [70, 100, 130]: draw_arc(Vector2(1210, 650), r, -PI / 2, PI / 2, 48, Color("9ca58e"), 3)
	_camp(Vector2(340, 820))
