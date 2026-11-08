extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(90, 170, 1740, 80), Rect2(90, 1160, 1740, 80), Rect2(90, 250, 60, 300), Rect2(90, 750, 60, 410), Rect2(1770, 250, 60, 910),
	Rect2(420, 480, 230, 50), Rect2(420, 800, 180, 50), Rect2(1000, 350, 60, 140), Rect2(1460, 840, 70, 110), Rect2(1130, 980, 110, 70)]
# Solid rock beyond the inner frame: only the exit alcove stays open outside the hall.
const ROCK := [Rect2(0, 0, 90, 1280), Rect2(0, 0, 1920, 170), Rect2(0, 1240, 1920, 40), Rect2(1830, 0, 90, 1280)]
func _ready() -> void:
	for rect in WALLS + ROCK: _obstacle(rect)
	for rect in [Rect2(1540, 250, 180, 20), Rect2(1540, 250, 20, 140), Rect2(1700, 250, 20, 140), Rect2(780, 930, 230, 20), Rect2(990, 930, 20, 170), Rect2(780, 1080, 230, 20)]: _obstacle(rect)
	if "waterworks_flight" not in Session.opened: _gate(Rect2(1560, 380, 140, 16), 16, "waterworks_flight")
	if "waterworks_mist" not in Session.opened:
		_gate(Rect2(780, 930, 20, 78), 1, "waterworks_mist")
		_gate(Rect2(780, 1014, 20, 86), 1, "waterworks_mist")
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("192e34"))
	draw_rect(Rect2(150, 250, 1620, 910), Color("626c69"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 81078
	for y in range(250, 1160, 24):
		for x in range(150, 1770, 32):
			draw_rect(Rect2(x, y, 30, 22), Color("6d7770") if rng.randi_range(0, 2) else Color("59645f"))
	for rect in WALLS:
		draw_rect(rect.grow(4), Color("293f43"))
		draw_rect(rect, Color("899287"))
		for y in range(int(rect.position.y), int(rect.end.y), 18):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("66766f"), 2)
	for x in [380, 670]:
		draw_rect(Rect2(x, 290, 18, 740), Color("344f52"))
		draw_rect(Rect2(x + 4, 290, 5, 740), Color("72928a"))
		for y in range(300, 1040, 80):
			draw_rect(Rect2(x - 4, y, 26, 8), Color("a3a18a"))
	for r in [180, 210]:
		draw_arc(Vector2(1350, 650), r, 0, TAU, 64, Color("a3a58b"), 2)
	for i in 12:
		var point := Vector2(1350, 650) + Vector2.from_angle(i * TAU / 12) * 210
		draw_line(point, point + Vector2.from_angle(i * TAU / 12) * 15, Color("bec0a1"), 3)
	_camp(Vector2(300, 800))
	for rect in [Rect2(1540, 250, 180, 20), Rect2(1540, 250, 20, 140), Rect2(1700, 250, 20, 140), Rect2(780, 930, 230, 20), Rect2(990, 930, 20, 170), Rect2(780, 1080, 230, 20)]: draw_rect(rect, Color("88918a"))
	if "waterworks_flight" not in Session.opened:
		for x in range(1560, 1700, 10): draw_rect(Rect2(x, 380, 4, 16), Color("adb6a6"))
	if "waterworks_mist" not in Session.opened:
		draw_rect(Rect2(780, 930, 20, 78), Color("88918a"))
		draw_rect(Rect2(780, 1014, 20, 86), Color("88918a"))

func _gate(rect: Rect2, layer: int, id: String) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = layer
	body.set_meta("flight_gate", id)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	get_parent().add_child(body)
