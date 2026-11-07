extends Control
const Regions = preload("res://scripts/world/region_catalog.gd")
var region := "crossing"
var player_position := Vector2.ZERO
var facing := Vector2.RIGHT
var obstacles: Array[Dictionary] = []
var npcs: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(680, 280)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func map_rect() -> Rect2:
	var scale_factor := minf((size.x - 20) / 1920.0, (size.y - 20) / 1280.0)
	var extent := Vector2(1920, 1280) * scale_factor
	return Rect2((size - extent) / 2, extent)

func project(point: Vector2) -> Vector2:
	var area := map_rect()
	return area.position + Vector2(clampf(point.x / 1920.0, 0, 1), clampf(point.y / 1280.0, 0, 1)) * area.size

func _box(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(project(rect.position), project(rect.end) - project(rect.position)), color)

func _draw() -> void:
	var area := map_rect()
	draw_rect(area, Color("344e43"))
	if region == "crossing":
		_box(Rect2(737, 0, 70, 1280), Color("507c88"))
		draw_line(project(Vector2(0, 610)), project(Vector2(1920, 476)), Color("aa9f7e"), 7)
		_box(Rect2(719, 475, 105, 150), Color("d6c29c"))
	elif region == "lake":
		_box(Rect2(570, 100, 820, 330), Color("507c88"))
		_box(Rect2(670, 390, 620, 115), Color("507c88"))
		draw_line(project(Vector2(0, 650)), project(Vector2(1920, 650)), Color("aa9f7e"), 7)
	if region == "workshop":
		_box(Rect2(1090, 130, 90, 1060), Color("507c88"))
		for y in [340, 620, 990]:
			_box(Rect2(1080, y - 25, 110, 50), Color("c0b598"))
	if region == "terrace":
		for rect in [Rect2(740, 160, 600, 260), Rect2(900, 940, 550, 230)]: _box(rect, Color("507c88"))
		draw_line(project(Vector2(120, 650)), project(Vector2(1760, 650)), Color("aa9f7e"), 7)
	if region == "velshof":
		for rect in preload("res://scripts/world/city_landscape.gd").ROADS: _box(rect, Color("aaa58a"))
		for rect in preload("res://scripts/world/city_landscape.gd").WALLS.slice(4): _box(rect, Color("8c947d"))
	if region == "woodroad":
		for rect in preload("res://scripts/world/woodroad_landscape.gd").ROAD: _box(rect, Color("aa9f7e"))
		for rect in preload("res://scripts/world/woodroad_landscape.gd").WALLS.slice(4): _box(rect, Color("8c947d"))
		if "forest_passage" not in Session.opened: _box(Rect2(1500, 560, 45, 170), Color("bdab7b"))
	if region == "haven":
		_box(Rect2(900, 0, 80, 470), Color("507c88"))
		_box(Rect2(900, 750, 80, 530), Color("507c88"))
		_box(Rect2(885, 470, 110, 280), Color("c0b598"))
		if "field_sluice" in Session.opened: _box(Rect2(885, 330, 110, 100), Color("c0b598"))
		draw_line(project(Vector2(0, 650)), project(Vector2(1920, 650)), Color("aa9f7e"), 7)
	if Regions.get_region(region).get("indoor", false):
		draw_rect(area, Color("4b5356"))
	for obstacle in obstacles:
		if obstacle.has("center"):
			draw_circle(project(obstacle.center), 2, Color("233e35"))
		elif (Regions.get_region(region).get("indoor", false) and obstacle.rect.position.x >= 80 and obstacle.rect.position.y >= 80 and obstacle.rect.end.x <= 1840 and obstacle.rect.end.y <= 1200) or (obstacle.rect.size.x < 250 and obstacle.rect.size.y < 250):
			_box(obstacle.rect, Color("9a9d89"))
	if region == "rotunda" and "prep:accepted" in Session.gathered:
		var preparation = preload("res://scripts/quests/preparation_rules.gd")
		for point in preparation.CONTROLS.values():
			var mark := project(point)
			draw_rect(Rect2(mark - Vector2(3, 3), Vector2(6, 6)), Color("cfbf8a"), false, 1)
	var definition := Regions.get_region(region)
	for point in Regions.camps(region, Session.opened):
		var camp := project(point)
		draw_rect(Rect2(camp - Vector2(4, 4), Vector2(8, 8)), Color("e9bd77"))
	for portal in Regions.exits(region):
		var exit_point := project(portal.point)
		draw_rect(Rect2(exit_point - Vector2(3, 6), Vector2(6, 12)), Color("c6d9cd"))
	if definition.has("merchant"):
		draw_circle(project(npcs.get("merchant", definition.merchant)), 3, Color("d9b88a"))
	if definition.has("keeper"):
		var keeper := project(npcs.get("keeper", definition.keeper))
		draw_circle(keeper, 3, Color("e9e1ce"))
	if definition.has("wayfarer"):
		draw_circle(project(npcs.get("wayfarer", definition.wayfarer)), 3, Color("e9e1ce"))
	for kind in ["warden", "wright", "tender", "tracker", "host", "mentor", "witness", "roadkeeper", "crafter", "archivist", "steward"]:
		if npcs.has(kind):
			draw_circle(project(npcs[kind]), 3, Color("d5d7af"))
	var player := project(player_position)
	var direction := facing.normalized()
	var side := direction.orthogonal()
	draw_circle(player, 10, Color("172829"))
	draw_colored_polygon(PackedVector2Array([player + direction * 9, player - direction * 6 + side * 5, player - direction * 6 - side * 5]), Color("fff0ba"))
	draw_rect(area, Color("b2a783"), false, 1)
