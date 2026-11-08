extends "res://scripts/world/landscape.gd"
# Builds and paints a generated hollow from the layout merged into the world definition.
const Generator = preload("res://scripts/world/delve_generator.gd")
const PALETTES := {1: ["2a2622", "4d463d", "57504a", "6f6556"], 2: ["1d2630", "3b4652", "45515d", "5e6d7a"], 3: ["1b2523", "354441", "3e4d49", "56665f"]}
var layout: Dictionary = {}

func _ready() -> void:
	layout = get_parent().definition
	for rect in Generator.ROCK + Generator.FRAME + layout.walls + layout.pillars: _obstacle(rect)
	# Rubble chokes a spare loop: ordinary bodies walk around, a bat flies over it.
	for rect in layout.rubble:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 16
		body.set_meta("rubble", true)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		body.add_child(collider)
		get_parent().add_child(body)

func _draw() -> void:
	var depth: int = layout.get("depth", 1)
	var palette: Array = PALETTES[depth]
	draw_rect(Rect2(0, 0, 1920, 1280), Color(palette[0]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150 + depth
	var floor_rect := Rect2(135, 185, 1650, 990)
	for y in range(int(floor_rect.position.y), int(floor_rect.end.y), 26):
		for x in range(int(floor_rect.position.x), int(floor_rect.end.x), 34):
			draw_rect(Rect2(x, y, 33, 25), Color(palette[1]) if rng.randi_range(0, 2) else Color(palette[2]))
	if depth == 2:
		# Crystal veins: the quiet beauty of the middle depth.
		for i in 26:
			var start := Vector2(rng.randi_range(160, 1760), rng.randi_range(200, 1150))
			var end := start + Vector2(rng.randi_range(-40, 40), rng.randi_range(-40, 40))
			draw_line(start, end, Color(0.55, 0.78, 0.9, 0.55), 2)
			draw_circle(end, 3, Color(0.7, 0.9, 1.0, 0.35))
	if depth == 3:
		for i in 14:
			var pool := Vector2(rng.randi_range(180, 1740), rng.randi_range(220, 1130))
			draw_circle(pool, rng.randi_range(14, 26), Color(0.16, 0.3, 0.32, 0.6))
	for point in layout.get("marks", []):
		# Loose stones above a hidden cache: careful eyes can find it without tracking.
		for offset in [Vector2(-9, 4), Vector2(6, -3), Vector2(1, 8)]: draw_rect(Rect2(point + offset, Vector2(5, 3)), Color(palette[3]))
	for rect in Generator.FRAME + layout.walls:
		draw_rect(rect.grow(3), Color(palette[0]))
		draw_rect(rect, Color(palette[3]))
		for y in range(int(rect.position.y), int(rect.end.y), 14):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(palette[2]), 1)
	for rect in layout.pillars:
		draw_rect(rect.grow(3), Color(palette[0]))
		draw_rect(rect, Color(palette[3]))
	for rect in layout.rubble:
		draw_rect(rect.grow(2), Color(palette[0]))
		draw_rect(rect, Color(palette[3]).darkened(0.3))
		for i in 9:
			var stone := Vector2(rect.position.x + rng.randf() * rect.size.x, rect.position.y + rng.randf() * rect.size.y)
			draw_rect(Rect2(stone - Vector2(6, 4), Vector2(12, 8)), Color(palette[3]).darkened(0.15))
	_camp(Vector2(230, 780))
