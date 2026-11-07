extends RefCounted

const CELL := 24.0
const BOUNDS := Vector2(1920, 1280)
var grid := AStarGrid2D.new()
var obstacles: Array[Dictionary] = []

# shortcut: static shapes are unscaled and unrotated; extend when authored terrain uses transformed shapes.
func configure(root: Node2D) -> void:
	grid.region = Rect2i(0, 0, 80, 54)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL / 2, CELL / 2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	obstacles.clear()
	for body in root.get_children():
		if not body is StaticBody2D or body.collision_layer & 17 == 0:
			continue
		for collider in body.get_children():
			if not collider is CollisionShape2D or collider.disabled:
				continue
			var shape: Shape2D = collider.shape
			if shape is RectangleShape2D:
				obstacles.append({"rect": Rect2(collider.global_position - shape.size / 2, shape.size)})
			elif shape is CircleShape2D:
				obstacles.append({"center": collider.global_position, "radius": shape.radius})
	for cell_y in grid.region.size.y:
		for cell_x in grid.region.size.x:
			var cell := Vector2i(cell_x, cell_y)
			var point := grid.get_point_position(cell)
			var solid := point.x < 12 or point.y < 12 or point.x > BOUNDS.x - 12 or point.y > BOUNDS.y - 12
			for obstacle in obstacles:
				if _contains(obstacle, point, 20):
					solid = true
					break
			grid.set_point_solid(cell, solid)

func _contains(obstacle: Dictionary, point: Vector2, margin: float) -> bool:
	if obstacle.has("rect"):
		return (obstacle.rect as Rect2).grow(margin).has_point(point)
	return point.distance_squared_to(obstacle.center) < pow(float(obstacle.radius) + margin, 2)

func segment_clear(start: Vector2, finish: Vector2) -> bool:
	for obstacle in obstacles:
		if obstacle.has("rect"):
			var rect: Rect2 = obstacle.rect.grow(7)
			if rect.has_point(start) or rect.has_point(finish):
				return false
			var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
			for i in 4:
				if Geometry2D.segment_intersects_segment(start, finish, corners[i], corners[(i + 1) % 4]) != null:
					return false
		else:
			var closest := Geometry2D.get_closest_point_to_segment(obstacle.center, start, finish)
			if closest.distance_to(obstacle.center) < float(obstacle.radius) + 7:
				return false
	return true

func _nearby_cell(point: Vector2) -> Vector2i:
	var origin := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
	var best := Vector2i(-1, -1)
	var distance := INF
	for y in range(origin.y - 5, origin.y + 6):
		for x in range(origin.x - 5, origin.x + 6):
			var cell := Vector2i(x, y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell):
				continue
			var candidate := grid.get_point_position(cell)
			var squared := point.distance_squared_to(candidate)
			if squared < distance and segment_clear(point, candidate):
				best = cell
				distance = squared
	return best

func find_path(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var bounds := Rect2(Vector2.ZERO, BOUNDS)
	if not bounds.has_point(start) or not bounds.has_point(finish):
		return PackedVector2Array()
	if segment_clear(start, finish):
		return PackedVector2Array([finish])
	var first := _nearby_cell(start)
	var last := _nearby_cell(finish)
	if first.x < 0 or last.x < 0:
		return PackedVector2Array()
	var path := grid.get_point_path(first, last)
	if not path.is_empty():
		path.append(finish)
	return path
