extends Node2D
const Rules = preload("res://scripts/quests/preparation_rules.gd")
var world: Node2D
var active := false
var pending := false
var step := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -1
func cancel() -> void:
	if not active and not pending: return
	active = false
	pending = false
	step = 0
	Session.notice.emit("PREP_INTERRUPTED")
	queue_redraw()
func activate() -> void:
	if pending:
		if world.preparation_action("prove"):
			pending = false
			step = 0
	elif world.can_rehearse():
		active = true
		step = 0
		Session.notice.emit("PREP_WALK")
	else: Session.notice.emit("PREP_NOT_READY")
	queue_redraw()
func _process(_delta: float) -> void:
	if active:
		if not world.can_rehearse(): cancel()
		elif not get_tree().paused and Session.running:
			var point: Vector2 = Rules.ROUTE[step]
			if world.player.position.distance_to(point) < 26:
				step += 1
				if step == Rules.ROUTE.size():
					var saved: bool = world.preparation_action("prove")
					active = false
					pending = not saved
					if saved: step = 0
					else: Session.notice.emit("PREP_RETRY")
		queue_redraw()
func _draw() -> void:
	if "prep:accepted" not in Session.gathered: return
	var tested := "prep:tested" in Session.gathered
	for side in ["north", "south"]:
		var point: Vector2 = Rules.CONTROLS[side]
		draw_circle(point, 23, Color("344e4a"))
		draw_arc(point, 20, 0, TAU, 32, Color("a9ac8e"), 2)
		var angle: int = Rules.angle(Session.gathered, side)
		var direction := Vector2.from_angle(-PI / 2 + angle * PI / 2)
		draw_line(point, point + direction * 17, Color("e0c888"), 4)
		var post: Vector2 = Rules.POSTS[side]
		draw_arc(post, 20, 0, TAU, 24, Color("b1c2a2"), 2)
		if active or tested: draw_line(post, Rules.CONTROLS.gate, Color("738f7b"), 2)
	var gate: Vector2 = Rules.CONTROLS.gate
	draw_rect(Rect2(gate - Vector2(12, 32), Vector2(24, 64)), Color("b9b38d") if tested else Color("677e76"), false, 4)
	if active:
		for i in Rules.ROUTE.size():
			var point: Vector2 = Rules.ROUTE[i]
			draw_arc(point, 25, 0, TAU, 32, Color("ebd397") if i == step else Color("617b70"), 3)
			if i < step: draw_circle(point, 5, Color("b9d4b0"))
		var next: Vector2 = Rules.ROUTE[step]
		draw_line(world.player.position, next, Color("b6bb91"), 1)
	if pending: draw_arc(Rules.CONTROLS.finish, 28, 0, TAU, 32, Color("e0bd84"), 4)
