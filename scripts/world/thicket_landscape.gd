extends "res://scripts/world/landscape.gd"
func _ready() -> void:
	for rect in [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
		Rect2(660, 250, 70, 170), Rect2(950, 740, 80, 150), Rect2(1460, 450, 110, 90)]: _obstacle(rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101019
	for i in 120:
		var point := Vector2(rng.randi_range(70, 1860), rng.randi_range(80, 1210))
		if point.y > 540 and point.y < 700: continue
		if point.y > 900: continue
		if point.x > 1280 and point.y > 650 and point.y < 810: continue
		if _reserved(point): continue
		var reserved := false
		for target in Regions.get_region(region).pack_sites.values():
			if point.distance_to(target) < 105: reserved = true
		for entry in Regions.get_region(region).chests:
			if point.distance_to(entry.point) < 110: reserved = true
		if reserved: continue
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
	draw_rect(Rect2(0, 0, 1920, 1280), Color("344b40"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71010
	for i in 4000:
		var point := Vector2(rng.randi_range(10, 1910), rng.randi_range(10, 1270))
		draw_rect(Rect2(point, Vector2(2, 4)), Color("52604a") if i % 2 else Color("2d4037"))
	for rect in [Rect2(100, 580, 1700, 70), Rect2(780, 590, 70, 450), Rect2(780, 990, 1000, 55)]:
		draw_rect(rect, Color("716d5b"))
		for i in 150:
			draw_rect(Rect2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y), 4, 2), Color("908974"))
	for rect in [Rect2(660, 250, 70, 170), Rect2(950, 740, 80, 150), Rect2(1460, 450, 110, 90)]:
		draw_rect(rect, Color("7b8377"))
		draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 18)), Color("919786"))
	for x in range(1490, 1660, 18):
		draw_rect(Rect2(x, 690, 12, 30), Color("596450"))
	_camp(Vector2(350, 760))
