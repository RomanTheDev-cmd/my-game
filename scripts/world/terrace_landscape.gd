extends "res://scripts/world/landscape.gd"
const WATER := [Rect2(740, 160, 600, 260), Rect2(900, 940, 550, 230)]
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(340, 430, 180, 80), Rect2(1540, 150, 150, 100), Rect2(620, 890, 120, 40), Rect2(1550, 810, 170, 35)]
func _ready() -> void:
	for rect in WALLS + WATER: _obstacle(rect)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("3b5650"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 161107
	for i in 3500:
		draw_rect(Rect2(Vector2(rng.randi_range(20, 1900), rng.randi_range(20, 1260)), Vector2(3, 3)), Color("527262") if i % 2 else Color("304d48"))
	for rect in WATER:
		draw_rect(rect.grow(10), Color("8d9a88"))
		draw_rect(rect, Color("315d69"))
		for x in range(int(rect.position.x) + 20, int(rect.end.x), 30):
			draw_line(Vector2(x, rect.position.y + 25), Vector2(x + 12, rect.position.y + 25), Color("6f9a9c"), 2)
	draw_rect(Rect2(120, 610, 1640, 90), Color("8c9383"))
	draw_rect(Rect2(980, 430, 110, 200), Color("8c9383"))
	draw_rect(Rect2(1120, 680, 100, 200), Color("8c9383"))
	draw_rect(Rect2(1300, 560, 180, 180), Color("a8ab97"))
	for y in range(570, 740, 20): draw_line(Vector2(1300, y), Vector2(1480, y), Color("89968a"), 1)
	for rect in WALLS.slice(4):
		draw_rect(rect.grow(4), Color("2b4440"))
		draw_rect(rect, Color("8b9b8e"))
	for x in [360, 400, 440, 480]: draw_rect(Rect2(x, 450, 15, 25), Color("c6ceae"))
	for point in [Vector2(1020, 440), Vector2(1260, 610), Vector2(1490, 640)]:
		draw_rect(Rect2(point, Vector2(10, 35)), Color("a3ae9c"))
		draw_circle(point + Vector2(5, -2), 9, Color("c5cbb0"))
	_camp(Vector2(350, 780))
