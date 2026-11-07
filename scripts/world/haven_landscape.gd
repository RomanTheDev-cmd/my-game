extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(900, 0, 80, 470), Rect2(900, 750, 80, 530), Rect2(340, 450, 220, 70), Rect2(620, 820, 160, 60), Rect2(310, 280, 220, 100), Rect2(1200, 200, 240, 100),
	Rect2(550, 950, 180, 45), Rect2(1190, 1040, 220, 45), Rect2(1730, 550, 60, 240)]
func _ready() -> void:
	for rect in WALLS: _obstacle(rect)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("374e46"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 131107
	for i in 3400:
		draw_rect(Rect2(Vector2(rng.randi_range(20, 1900), rng.randi_range(20, 1260)), Vector2(2, 3)), Color("4f6551") if i % 2 else Color("31473e"))
	draw_rect(Rect2(0, 610, 1920, 80), Color("8c8776"))
	draw_rect(Rect2(670, 400, 100, 230), Color("7d7f69"))
	draw_rect(Rect2(1280, 650, 100, 250), Color("7d7f69"))
	for rect in [WALLS[4], WALLS[5]]:
		draw_rect(rect.grow(9), Color("727e71"))
		draw_rect(rect, Color("2b555e"))
	for y in range(480, 750, 18): draw_line(Vector2(885, y), Vector2(995, y), Color("b4a787"), 6)
	for rect in WALLS.slice(6):
		draw_rect(rect.grow(4), Color("293d39"))
		draw_rect(rect, Color("7f8a7e"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), Color("aca98e"))
	for x in [365, 420, 475, 530]:
		draw_rect(Rect2(x, 473, 16, 22), Color("c1c5a5"))
		draw_line(Vector2(x + 8, 473), Vector2(x + 8, 495), Color("69796f"), 2)
	for x in [640, 690, 740]: draw_rect(Rect2(x, 840, 18, 22), Color("bdc2a6"))
	for x in [330, 385, 440, 495]: draw_rect(Rect2(x, 305, 22, 32), Color("b9bb9a"))
	for x in [1220, 1280, 1340, 1400]: draw_rect(Rect2(x, 230, 22, 35), Color("bac6b1"))
	for x in range(560, 850, 35):
		draw_rect(Rect2(x, 330, 4, 30), Color("716d51"))
		draw_circle(Vector2(x + 2, 325), 11, Color("6c8960"))
	for point in [Vector2(720, 420), Vector2(1320, 600), Vector2(1450, 860)]:
		draw_circle(point, 25, Color(0.77, 0.76, 0.54, 0.15))
	_camp(Vector2(350, 760))
