extends Node2D
const Rules = preload("res://scripts/quests/rescue_rules.gd")
var world: Node2D
var pending := false
func phase(side: String) -> int:
	if Rules.stage(Session.gathered, Session.opened) != 2 or Rules.method(Session.gathered) == "blood" or Rules.cut(Session.gathered, side) != "": return 2
	var cycle := fposmod(Session.world_state.minutes + (3 if side == "south" else 0), 6)
	return 0 if cycle < 1 else (1 if cycle < 2.5 else 2)
func zone(side: String) -> Rect2: return Rect2(720, 416 if side == "north" else 856, 530, 28)
func dangerous(point: Vector2) -> bool:
	for side in Rules.COILS:
		if phase(side) == 1 and zone(side).has_point(point): return true
	return false
func arrived() -> bool:
	return Rules.stage(Session.gathered, Session.opened) == 3 and world.npcs.mentor.visible and world.player.position.distance_to(Rules.EXIT) < 75 and world.npcs.mentor.position.distance_to(Rules.EXIT) < 85 and world.player.position.distance_to(world.npcs.mentor.position) < 100
func retry() -> void:
	if pending and world.rescue_action("safe"):
		pending = false
		queue_redraw()
func _process(_delta: float) -> void:
	if world.player.health > 0 and dangerous(world.player.position): world.player.receive_damage(8)
	if arrived() and not pending and world.can_rescue("safe"):
		if not world.rescue_action("safe"):
			pending = true
			Session.notice.emit("RESCUE_RETRY")
	queue_redraw()
func _draw() -> void:
	if "rescue:accepted" not in Session.gathered: return
	for side in Rules.COILS:
		var rect := zone(side)
		var state := phase(side)
		draw_rect(rect, Color("886c4e") if state == 0 else (Color("b1695b") if state == 1 else Color("557c75")))
		if state != 2:
			for x in range(int(rect.position.x), int(rect.end.x), 24): draw_line(Vector2(x, rect.position.y), Vector2(x + 15, rect.end.y), Color("d4bd85"), 2)
	if not "rescue:freed" in Session.gathered:
		for point in Rules.COILS.values(): draw_line(point, Vector2(1440, 650), Color("ad9975"), 2)
	if Rules.stage(Session.gathered, Session.opened) == 3:
		draw_arc(Rules.EXIT, 70, 0, TAU, 48, Color("dcc489") if pending else Color("a8c5b0"), 3)
