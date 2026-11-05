extends Node2D
const Regions = preload("res://scripts/world/region_catalog.gd")
const TREE = preload("res://assets/sprites/tree.png")
var trees: Array[Vector2] = []
var region := "crossing"

func _ready() -> void:
	if region == "ruins":
		_build_ruins()
		return
	if region == "lake":
		_build_lake()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 73106
	for i in 180:
		var point := Vector2(rng.randi_range(35, 1880), rng.randi_range(40, 1230))
		if _reserved(point):
			continue
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
	if region == "ruins":
		_draw_ruins()
		return
	if region == "lake":
		_draw_lake()
		return
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
	_camp(Vector2(440, 470))

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

func _camp(center: Vector2) -> void:
	draw_circle(center, 18, Color("696453"))
	for i in 7:
		var point := center + Vector2.from_angle(i * TAU / 7) * 18
		draw_rect(Rect2(point - Vector2(4, 3), Vector2(8, 6)), Color("959181"))
	draw_rect(Rect2(center + Vector2(-9, -4), Vector2(17, 7)), Color("8e5f38"))
	draw_rect(Rect2(center + Vector2(-5, -12), Vector2(9, 11)), Color("e6a45b"))
	draw_rect(Rect2(center + Vector2(-2, -17), Vector2(4, 13)), Color("ffe2a0"))

func _obstacle(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	get_parent().add_child(body)

func _build_lake() -> void:
	for rect in [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30),
		Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280), Rect2(590, 120, 780, 290),
		Rect2(690, 410, 580, 75), Rect2(950, 525, 70, 50)]:
		_obstacle(rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14916
	for i in 110:
		var point := Vector2(rng.randi_range(40, 1880), rng.randi_range(60, 1230))
		if _reserved(point):
			continue
		if absf(point.y - 650) < 95 or point.distance_to(Vector2(360, 610)) < 150:
			continue
		if Rect2(530, 80, 900, 470).has_point(point) or Rect2(850, 500, 350, 400).has_point(point):
			continue
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
		sprite.modulate = Color("bac9a5")
		body.add_child(sprite)
		get_parent().add_child(body)

func _draw_lake() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("405447"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 14917
	for i in 5500:
		var point := Vector2(rng.randi_range(0, 1920), rng.randi_range(0, 1280))
		draw_rect(Rect2(point, Vector2(2, 3)), Color("52684e") if i % 2 else Color("354b40"))
	# Stepped shoreline follows the authored water obstacles.
	for rect in [Rect2(570, 100, 820, 330), Rect2(670, 390, 620, 115)]:
		draw_rect(rect.grow(12), Color("98957a"))
		draw_rect(rect, Color("2f5960"))
		draw_rect(rect.grow(-10), Color("294c59"))
	for i in 280:
		var point := Vector2(rng.randi_range(595, 1360), rng.randi_range(125, 405))
		draw_rect(Rect2(point, Vector2(rng.randi_range(6, 18), 2)), Color("568083"))
	for x in range(0, 1920, 10):
		draw_rect(Rect2(x, 624, 10, 52), Color("898572"))
		for i in 2:
			draw_rect(Rect2(x + i * 4, rng.randi_range(629, 667), 4, 2), Color("b0a78a"))
	draw_rect(Rect2(910, 510, 150, 110), Color("767b70"))
	for y in range(515, 620, 15):
		draw_line(Vector2(910, y), Vector2(1060, y), Color("95978a"), 2)
	draw_rect(Rect2(948, 545, 76, 25), Color("b3ac91"))
	draw_rect(Rect2(961, 500, 50, 45), Color("929686"))
	draw_rect(Rect2(970, 478, 32, 25), Color("c6bda0"))
	for x in range(720, 1260, 50):
		draw_rect(Rect2(x, 485, 3, 18), Color("82936b"))
		draw_rect(Rect2(x - 2, 478, 7, 9), Color("c0aa7e"))
	_camp(Vector2(360, 610))

func _reserved(point: Vector2) -> bool:
	var definition := Regions.get_region(region)
	for key in ["keeper", "wayfarer", "merchant", "camp", "exit"]:
		if definition.has(key) and point.distance_to(definition[key]) < 50:
			return true
	for entry in definition.enemies:
		if point.distance_to(entry[1]) < 45:
			return true
	for herb in definition.herbs:
		if point.distance_to(herb) < 35:
			return true
	return false

const RUIN_WALLS := [
	Rect2(0, 0, 1920, 80), Rect2(0, 1200, 1920, 80), Rect2(0, 0, 80, 1280), Rect2(1840, 0, 80, 1280),
	Rect2(600, 80, 40, 420), Rect2(600, 780, 40, 420), Rect2(1160, 80, 40, 300), Rect2(1160, 810, 40, 390),
	Rect2(850, 300, 50, 90), Rect2(850, 870, 50, 90), Rect2(1420, 850, 50, 90), Rect2(1480, 300, 50, 90)
]

func _build_ruins() -> void:
	for rect in RUIN_WALLS:
		_obstacle(rect)

func _draw_ruins() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("434b4e"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 94023
	for y in range(80, 1200, 32):
		for x in range(80, 1840, 32):
			var color: Color = [Color("505455"), Color("555856"), Color("494f52")][rng.randi_range(0, 2)]
			draw_rect(Rect2(x, y, 31, 31), color)
			if rng.randf() < 0.12:
				draw_line(Vector2(x + 7, y + 4), Vector2(x + 18, y + 22), Color("363e43"), 1)
	for rect in RUIN_WALLS:
		draw_rect(rect, Color("343e46"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(rect.size.y, 12))), Color("81867b"))
		for x in range(int(rect.position.x), int(rect.end.x), 36):
			draw_line(Vector2(x, rect.position.y), Vector2(x, minf(rect.end.y, rect.position.y + 12)), Color("535e61"), 1)
	for x in [280, 800, 1300, 1700]:
		draw_rect(Rect2(x, 48, 40, 32), Color("263742"))
		draw_rect(Rect2(x + 5, 53, 13, 25), Color("65959a"))
		draw_rect(Rect2(x + 21, 53, 13, 25), Color("b9a173"))
	for point in [Vector2(580, 540), Vector2(580, 740), Vector2(1140, 430), Vector2(1140, 760), Vector2(1530, 590)]:
		draw_circle(point + Vector2(0, -10), 22, Color(0.82, 0.64, 0.34, 0.09))
		draw_rect(Rect2(point - Vector2(3, 9), Vector2(6, 10)), Color("b7ab85"))
		draw_rect(Rect2(point - Vector2(1, 14), Vector2(2, 6)), Color("ffe6aa"))
	_camp(Vector2(290, 870))
