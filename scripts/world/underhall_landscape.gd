extends "res://scripts/world/landscape.gd"
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280), Rect2(100, 170, 1720, 80), Rect2(100, 1080, 1720, 80), Rect2(100, 250, 55, 310), Rect2(100, 760, 55, 320), Rect2(1765, 250, 55, 830), Rect2(560, 310, 100, 180), Rect2(560, 830, 100, 180), Rect2(1250, 300, 70, 200), Rect2(1250, 800, 70, 220)]
const GATE := Rect2(760, 600, 44, 100)
# Solid rock beyond the inner frame: only the exit alcove stays open outside the hall.
const ROCK := [Rect2(0, 0, 100, 1280), Rect2(0, 0, 1920, 170), Rect2(0, 1160, 1920, 120), Rect2(1820, 0, 100, 1280)]
func _ready() -> void:
	for rect in WALLS + ROCK: _obstacle(rect)
	_obstacle(GATE)
	get_parent().get_child(get_parent().get_child_count() - 1).set_meta("rescue_gate", true)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("172e35"))
	draw_rect(Rect2(155, 250, 1610, 830), Color("66736f"))
	for x in range(155, 1765, 40):
		for y in range(250, 1080, 32): draw_rect(Rect2(x, y, 38, 30), Color("737e75"))
	for rect in WALLS:
		draw_rect(rect.grow(4), Color("2b4447"))
		draw_rect(rect, Color("929f91"))
	for point in [Vector2(980, 430), Vector2(980, 870)]:
		draw_line(point, Vector2(1440, 650), Color("8c9a84"), 4)
		draw_line(point, Vector2(380, 650), Color("738f83"), 3)
	draw_arc(Vector2(1440, 650), 55, 0, TAU, 48, Color("b8ad87"), 4)
	if not preload("res://scripts/quests/rescue_rules.gd").disconnected(Session.gathered): draw_rect(GATE, Color("b6ac82"))
	_camp(Vector2(340, 820))
