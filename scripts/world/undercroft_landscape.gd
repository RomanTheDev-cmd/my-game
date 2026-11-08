extends "res://scripts/world/landscape.gd"
const Knell = preload("res://scripts/quests/knell_rules.gd")
const WALLS := [Rect2(-30, -30, 1980, 30), Rect2(-30, 1280, 1980, 30), Rect2(-30, 0, 30, 1280), Rect2(1920, 0, 30, 1280),
	Rect2(90, 170, 1740, 80), Rect2(90, 1160, 1740, 80), Rect2(90, 250, 60, 310), Rect2(90, 760, 60, 400), Rect2(1770, 250, 60, 910),
	Rect2(520, 250, 40, 350), Rect2(520, 700, 40, 460), Rect2(560, 780, 200, 40), Rect2(860, 780, 240, 40),
	Rect2(1100, 250, 40, 200), Rect2(1100, 550, 40, 410), Rect2(1100, 1040, 40, 120),
	Rect2(760, 420, 40, 40), Rect2(900, 580, 40, 40)]
# Solid rock around the frame: only the exit alcove stays open beyond the inner walls.
const ROCK := [Rect2(0, 0, 90, 1280), Rect2(0, 0, 1920, 170), Rect2(0, 1240, 1920, 40), Rect2(1830, 0, 90, 1280)]
const PILLARS: Array[Rect2] = [Rect2(1265, 450, 50, 50), Rect2(1595, 450, 50, 50), Rect2(1265, 910, 50, 50), Rect2(1595, 910, 50, 50)]
const GRATE := Rect2(1100, 450, 40, 100)
const PASSAGE := Rect2(1100, 960, 40, 80)
const BELL_POINT := Vector2(1455, 705)
const RENEWAL_CAMP := Vector2(1030, 320)

func _ready() -> void:
	for rect in WALLS + PILLARS + ROCK: _obstacle(rect)
	if grate_closed():
		_obstacle(GRATE)
		get_parent().get_child(get_parent().get_child_count() - 1).set_meta("knell_grate", true)
	if passage_closed():
		_obstacle(PASSAGE)
		get_parent().get_child(get_parent().get_child_count() - 1).set_meta("knell_passage", true)

static func grate_closed() -> bool:
	return Knell.read_count(Session.gathered) < Knell.PLAQUES.size() and Knell.BELL not in Session.defeated
static func passage_closed() -> bool:
	return "accord_release" not in Session.opened

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1280), Color("141f24"))
	draw_rect(Rect2(150, 250, 1620, 910), Color("4d5551"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23071
	for y in range(250, 1160, 28):
		for x in range(150, 1770, 36):
			draw_rect(Rect2(x, y, 34, 26), [Color("565e59"), Color("515954"), Color("5b625b")][rng.randi_range(0, 2)])
			if rng.randf() < 0.08: draw_line(Vector2(x + 6, y + 5), Vector2(x + 20, y + 19), Color("3f4744"), 1)
	# Bell chamber floor: worn concentric bands around the hanging point.
	for radius in [120, 205, 290]:
		draw_arc(BELL_POINT, radius, 0, TAU, 72, Color("6b6f63"), 3)
	for i in 16:
		var point := BELL_POINT + Vector2.from_angle(i * TAU / 16) * 290
		draw_line(point, point + Vector2.from_angle(i * TAU / 16) * 14, Color("7f8273"), 2)
	# Ossuary niches along the southern rooms.
	for x in range(600, 1080, 60):
		draw_rect(Rect2(x, 1124, 44, 30), Color("2c3434"))
		for i in 4: draw_rect(Rect2(x + 4 + i * 10, 1132 + (i % 2) * 6, 7, 6), Color("b6b29a"))
	for rect in WALLS:
		draw_rect(rect.grow(3), Color("26343a"))
		draw_rect(rect, Color("737a70"))
		for y in range(int(rect.position.y), int(rect.end.y), 16):
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("5f675f"), 1)
	for rect in PILLARS:
		draw_rect(rect.grow(4), Color("26343a"))
		draw_rect(rect, Color("8a8d7c"))
		draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)), Color("9a9c89"))
	if grate_closed():
		draw_rect(GRATE, Color("2d3436"))
		for y in range(int(GRATE.position.y) + 4, int(GRATE.end.y), 12): draw_rect(Rect2(GRATE.position.x, y, GRATE.size.x, 4), Color("8f8a6f"))
	else:
		draw_rect(Rect2(GRATE.position.x, GRATE.position.y - 6, GRATE.size.x, 6), Color("8f8a6f"))
	if passage_closed():
		draw_rect(PASSAGE, Color("6b6156"))
		for y in range(int(PASSAGE.position.y), int(PASSAGE.end.y), 10):
			for x in range(int(PASSAGE.position.x) + (int(y / 10) % 2) * 10, int(PASSAGE.end.x), 20): draw_rect(Rect2(x, y, 18, 8), Color("857766"))
	else:
		draw_rect(Rect2(PASSAGE.position.x - 6, PASSAGE.position.y - 4, 8, 6), Color("857766"))
		draw_rect(Rect2(PASSAGE.end.x - 2, PASSAGE.end.y - 2, 8, 6), Color("857766"))
	for point in [Vector2(470, 600), Vector2(470, 700), Vector2(1080, 420), Vector2(1080, 580)]:
		draw_circle(point + Vector2(0, -8), 14, Color(0.9, 0.7, 0.4, 0.1))
		draw_rect(Rect2(point - Vector2(2, 8), Vector2(4, 8)), Color("d9cfae"))
		draw_rect(Rect2(point - Vector2(1, 12), Vector2(2, 4)), Color("ffe2a0"))
	_camp(Vector2(330, 820))
	if "accord_renewal" in Session.opened: _camp(RENEWAL_CAMP)
