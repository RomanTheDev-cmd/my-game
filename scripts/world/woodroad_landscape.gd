extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280), Rect2(1500, 0, 45, 560), Rect2(1500, 730, 45, 550), Rect2(310, 400, 190, 75), Rect2(1110, 350, 140, 85)]
const ROAD := [Rect2(100, 570, 730, 95), Rect2(785, 570, 90, 260), Rect2(785, 745, 400, 90), Rect2(1135, 570, 90, 260), Rect2(1135, 570, 650, 95)]
func _ready() -> void:
	for rect in WALLS: _obstacle(rect)
	if "forest_passage" not in Session.opened:
		var gate := StaticBody2D.new()
		gate.position = Vector2(1522.5, 645)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(45, 170)
		var collider := CollisionShape2D.new()
		collider.shape = shape
		gate.add_child(collider)
		get_parent().add_child(gate)
		gate.set_meta("forest_gate", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 171107
	for i in 160:
		var point := Vector2(rng.randi_range(70, 1850), rng.randi_range(100, 1190))
		if _reserved(point) or ROAD.any(func(rect): return rect.grow(75).has_point(point)): continue
		if point.distance_to(Vector2(390, 800)) < 120: continue
		if point.distance_to(Vector2(1640, 650)) < 100: continue
		if point.distance_to(Vector2(1750, 1060)) < 170: continue
		trees.append(point)
		var body := StaticBody2D.new()
		body.position = point
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10
		collider.shape = shape
		body.add_child(collider)
		var sprite := Sprite2D.new()
		sprite.texture = TREE
		sprite.position.y = -30
		body.add_child(sprite)
		get_parent().add_child(body)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("344a3d"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11717
	for i in 3000: draw_rect(Rect2(Vector2(rng.randi_range(10, 1910), rng.randi_range(10, 1270)), Vector2(3, 3)), Color("496146") if i % 2 else Color("293c34"))
	for rect in ROAD: draw_rect(rect, Color("80775d"))
	for rect in WALLS.slice(4):
		draw_rect(rect, Color("5b6c59"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("a3a38a"), 3)
	if "forest_passage" not in Session.opened:
		draw_rect(Rect2(1500, 560, 45, 170), Color("7c7053"))
		for y in range(570, 730, 22): draw_line(Vector2(1495, y), Vector2(1550, y + 8), Color("b1a17c"), 4)
	_camp(Vector2(390, 800))
