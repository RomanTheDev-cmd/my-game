extends "res://scripts/world/landscape.gd"
const GATE := Rect2(1095, 560, 80, 120)
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(440, 240, 250, 180), Rect2(220, 350, 125, 115), Rect2(1420, 200, 270, 180),
	Rect2(1100, 140, 70, 150), Rect2(1100, 390, 70, 170), Rect2(1100, 680, 70, 260), Rect2(1100, 1040, 70, 140),
	Rect2(500, 930, 300, 35), Rect2(500, 1000, 300, 35), Rect2(1510, 650, 140, 70)]

func _ready() -> void:
	for rect in WALLS:
		_obstacle(rect)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("3c5045"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71631
	for i in 4200:
		var point := Vector2(rng.randi_range(20, 1900), rng.randi_range(20, 1260))
		draw_rect(Rect2(point, Vector2(2, 3)), Color("50604b") if i % 2 else Color("31463e"))
	for rect in [Rect2(120, 580, 1680, 100), Rect2(330, 440, 600, 140), Rect2(800, 300, 750, 70), Rect2(800, 960, 750, 70), Rect2(800, 320, 85, 700)]:
		draw_rect(rect, Color("85816c"))
		for y in range(int(rect.position.y), int(rect.end.y), 18):
			for x in range(int(rect.position.x), int(rect.end.x), 24):
				draw_rect(Rect2(x, y, 22, 16), Color("93917c") if rng.randi_range(0, 2) else Color("777c6d"))
	draw_rect(Rect2(1090, 130, 90, 1060), Color("aca38a"))
	draw_rect(Rect2(1100, 140, 70, 1040), Color("2e5960"))
	for i in 120:
		draw_rect(Rect2(rng.randi_range(1105, 1150), rng.randi_range(145, 1170), 12, 2), Color("60837f"))
	for y in [290, 940]:
		_bridge(y, 100, true)
	_bridge(560, 120, Session.world_state.commission.stage >= 5)
	_house(Vector2(430, 210), Vector2(270, 210), false)
	_house(Vector2(210, 330), Vector2(145, 135), false)
	# An inhabited belfry, distinct from the abandoned interior region.
	_house(Vector2(1440, 180), Vector2(240, 200), true)
	for x in range(1450, 1670, 40):
		draw_rect(Rect2(x, 383, 26, 8), Color("b6ad90"))
	for y in [930, 1000]:
		draw_rect(Rect2(490, y - 5, 320, 45), Color("6c5a43"))
		for x in range(510, 795, 15):
			draw_rect(Rect2(x, y, 3, 24), Color("9ba77c"))
			draw_rect(Rect2(x - 3, y + 4, 9, 6), Color("71885d"))
			if x % 3:
				draw_rect(Rect2(x, y - 2, 4, 4), Color("c5b28a"))
	for point in [Vector2(320, 800), Vector2(740, 780), Vector2(1300, 300), Vector2(1740, 500)]:
		draw_circle(point, 17, Color("35453c"))
		draw_rect(Rect2(point - Vector2(13, 20), Vector2(26, 18)), Color("4b6753"))
		draw_rect(Rect2(point - Vector2(3, 6), Vector2(6, 10)), Color("726750"))
	for x in [730, 1420]:
		draw_rect(Rect2(x, 555, 45, 7), Color("6d6350"))
		draw_rect(Rect2(x + 3, 562, 4, 9), Color("4c5044"))
		draw_rect(Rect2(x + 37, 562, 4, 9), Color("4c5044"))
	draw_rect(Rect2(1510, 650, 140, 70), Color("575b53"))
	for x in range(1515, 1640, 22):
		draw_rect(Rect2(x, 646, 18, 13), Color("a29f85"))
	_camp(Vector2(380, 730))

func _bridge(y: float, height: float, restored: bool) -> void:
	for row in range(int(y), int(y + height), 10):
		var offset := 0 if restored else (7 if int(row / 10) % 2 else -6)
		draw_rect(Rect2(1085 + offset, row, 100 if restored else 72, 7), Color("b0a185") if restored else Color("6f6250"))
	draw_rect(Rect2(1080, y, 5, height), Color("4d574e"))
	draw_rect(Rect2(1183, y, 5, height), Color("4d574e"))
