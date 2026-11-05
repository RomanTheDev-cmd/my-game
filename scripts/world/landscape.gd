extends Node2D
const TREE = preload("res://assets/sprites/tree.png")
var trees: Array[Vector2] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73106
	for i in 180:
		var point := Vector2(rng.randi_range(35, 1880), rng.randi_range(40, 1230))
		if absf(point.y - (610 - point.x * 0.07)) < 80 or point.distance_to(Vector2(410, 490)) < 150:
			continue
		if Rect2(970, 270, 310, 330).has_point(point) or Rect2(250, 240, 380, 270).has_point(point):
			continue
		if point.x > 720 and point.x < 820:
			continue
		trees.append(point)
		var body := StaticBody2D.new()
		body.position = point
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10
		shape.shape = circle
		body.add_child(shape)
		get_parent().add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = TREE
		sprite.position.y = -30
		body.add_child(sprite)
	for rect in [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280),
		Rect2(1920, 0, 30, 1280), Rect2(275, 300, 130, 95), Rect2(490, 300, 90, 75),
		Rect2(1050, 300, 140, 100), Rect2(742, 0, 58, 475), Rect2(742, 625, 58, 655)]:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		get_parent().add_child(body)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("31483f"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 614
	for i in 6000:
		var pos := Vector2(rng.randi_range(0, 1920), rng.randi_range(0, 1280))
		draw_rect(Rect2(pos, Vector2(2, rng.randi_range(2, 5))), [Color("3d5747"), Color("293f39"), Color("48604b")][i % 3])
	for x in range(0, 1920, 8):
		var y := 610 - x * 0.07
		draw_rect(Rect2(x, y - 35, 8, 70), Color("777466"))
		for j in 4:
			draw_rect(Rect2(x + j * 2, y + rng.randi_range(-30, 30), 3, 2), Color("8c8873"))
	draw_rect(Rect2(737, 0, 70, 1280), Color("23434c"))
	for i in 250:
		draw_rect(Rect2(rng.randi_range(745, 797), rng.randi_range(0, 1280), 10, 2), Color("365c64"))
	draw_rect(Rect2(719, 475, 105, 150), Color("564e40"))
	for y in range(480, 625, 9):
		draw_rect(Rect2(721, y, 101, 6), Color("a19372"))
	draw_rect(Rect2(714, 471, 5, 160), Color("3a3c34"))
	draw_rect(Rect2(824, 471, 5, 160), Color("3a3c34"))
	_house(Vector2(265, 275), Vector2(150, 120), false)
	_house(Vector2(480, 275), Vector2(110, 100), false)
	_house(Vector2(1038, 250), Vector2(165, 150), true)
	for x in range(880, 1020, 35):
		draw_rect(Rect2(x, 450, 15, 24), Color("7c8076"))
		draw_rect(Rect2(x + 3, 446, 9, 5), Color("92958a"))
	# Camp and warm pools of lamplight are deliberately small against the forest.
	draw_circle(Vector2(440, 470), 18, Color("696453"))
	for i in 7:
		var point := Vector2(440, 470) + Vector2.from_angle(i * TAU / 7) * 18
		draw_rect(Rect2(point - Vector2(4, 3), Vector2(8, 6)), Color("959181"))
	draw_rect(Rect2(431, 466, 17, 7), Color("8e5f38"))
	draw_rect(Rect2(435, 458, 9, 11), Color("e6a45b"))
	draw_rect(Rect2(438, 453, 4, 13), Color("ffe2a0"))

func _house(pos: Vector2, size: Vector2, chapel: bool) -> void:
	draw_rect(Rect2(pos + Vector2(8, 10), size), Color("23352f"))
	draw_rect(Rect2(pos, size), Color("858474") if chapel else Color("a49a7d"))
	for y in range(int(pos.y), int(pos.y + size.y), 12):
		draw_line(Vector2(pos.x, y), Vector2(pos.x + size.x, y), Color("6e7167"), 1)
		for x in range(int(pos.x) + ((y / 12) % 2) * 10, int(pos.x + size.x), 22):
			draw_line(Vector2(x, y), Vector2(x, y + 10), Color("77796c"), 1)
	for row in 7:
		draw_rect(Rect2(pos.x - 8 + row * 3, pos.y - 28 + row * 6, size.x + 16 - row * 6, 6), Color("4f5860") if chapel else Color("695650"))
	draw_rect(Rect2(pos + Vector2(size.x / 2 - 12, size.y - 38), Vector2(24, 38)), Color("303d3b"))
	for x in [pos.x + 16, pos.x + size.x - 34]:
		draw_rect(Rect2(x, pos.y + 58, 15, 23), Color("c7a773"))
		draw_rect(Rect2(x + 6, pos.y + 58, 2, 23), Color("514d43"))
	if chapel:
		draw_rect(Rect2(pos.x + 63, pos.y - 75, 38, 62), Color("777d74"))
		draw_rect(Rect2(pos.x + 70, pos.y - 60, 24, 30), Color("273b3a"))
		draw_rect(Rect2(pos.x + 65, pos.y - 81, 34, 7), Color("4f5860"))
