extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(340, 450, 220, 70), Rect2(620, 820, 160, 60), Rect2(310, 280, 220, 100), Rect2(1200, 200, 240, 100),
	Rect2(550, 950, 180, 45), Rect2(1190, 1040, 220, 45), Rect2(1730, 550, 60, 240)]
const BANKS := [Rect2(900, 0, 80, 330), Rect2(900, 430, 80, 40), Rect2(900, 750, 80, 530)]
func _ready() -> void:
	for rect in WALLS + BANKS: _obstacle(rect)
	if "field_sluice" not in Session.opened:
		var body := StaticBody2D.new()
		body.position = Vector2(940, 380)
		body.set_meta("field_gate", "field_sluice")
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(80, 100)
		collider.shape = box
		body.add_child(collider)
		get_parent().add_child(body)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("374e46"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 131107
	for i in 3400:
		draw_rect(Rect2(Vector2(rng.randi_range(20, 1900), rng.randi_range(20, 1260)), Vector2(2, 3)), Color("4f6551") if i % 2 else Color("31473e"))
	draw_rect(Rect2(0, 610, 1920, 80), Color("8c8776"))
	draw_rect(Rect2(670, 400, 100, 230), Color("7d7f69"))
	draw_rect(Rect2(1280, 650, 100, 250), Color("7d7f69"))
	for rect in BANKS:
		draw_rect(rect.grow(9), Color("727e71"))
		draw_rect(rect, Color("2b555e"))
	if "field_sluice" in Session.opened:
		for y in range(334, 431, 12): draw_line(Vector2(885, y), Vector2(995, y), Color("baac89"), 6)
	else: draw_rect(Rect2(900, 330, 80, 100), Color("2b555e"))
	if "field_relay" in Session.opened: _camp(Vector2(1120, 860))
	for y in range(480, 750, 18): draw_line(Vector2(885, y), Vector2(995, y), Color("b4a787"), 6)
	for rect in WALLS.slice(4):
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
