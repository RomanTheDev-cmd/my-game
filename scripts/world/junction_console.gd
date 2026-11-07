extends Node2D
var kind := "console"
var world: Node2D
var isolated := false
var proved := false
var outcome := ""
var records := 0
var active := false
var pending := false
var progress := 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func cancel_measure() -> void:
	if not active: return
	active = false
	progress = 0
	Session.notice.emit("JOINT_INTERRUPTED")
	queue_redraw()
func _input(event: InputEvent) -> void:
	if kind == "console" and active and event.is_action_released("interact"): cancel_measure()
func activate() -> void:
	if pending:
		if world.junction_action("prove"):
			pending = false
			progress = 0
	elif world.can_measure():
		active = true
		progress = 0
	else:
		Session.notice.emit("NATURE_RETURN_FORM" if Session.nature.form != "human" else "CHECKPOINT_UNSAFE")
	queue_redraw()
func _process(delta: float) -> void:
	if kind != "console" or not active: return
	if not Input.is_action_pressed("interact") or not world.can_measure():
		cancel_measure()
	else:
		if get_tree().paused: return
		progress = minf(3, progress + delta)
		if progress >= 3:
			var saved: bool = world.junction_action("prove")
			active = false
			pending = not saved
			if saved: progress = 0
			else: Session.notice.emit("JOINT_RETRY")
	queue_redraw()
func _draw() -> void:
	if kind == "table":
		draw_rect(Rect2(-45, -27, 90, 40), Color("897d60"))
		for i in records:
			draw_rect(Rect2(-36 + i * 25, -24, 20, 28), Color("d5cfad"))
			for y in [-17, -11, -5]: draw_line(Vector2(-32 + i * 25, y), Vector2(-20 + i * 25, y), Color("5a6d61"), 1)
		return
	draw_rect(Rect2(-32, -24, 64, 36), Color("6e8681"))
	draw_arc(Vector2(0, -15), 17, PI, TAU, 24, Color("d1c497"), 3)
	draw_line(Vector2.ZERO + Vector2(0, -15), Vector2(12, -30) if isolated else Vector2(-12, -30), Color("d1c497"), 3)
	if isolated: draw_rect(Rect2(-40, 10, 80, 7), Color("b2c5aa"))
	if active or pending:
		draw_rect(Rect2(-45, -53, 90, 8), Color("1e363b"))
		draw_rect(Rect2(-45, -53, 30 * progress, 8), Color("cdbb7e") if not pending else Color("c7a177"))
		draw_line(Vector2(25, -17), Vector2(100, -17), Color("b8cfb2"), 3)
	if proved: draw_circle(Vector2(35, -30), 7, Color("aed0ac") if outcome != "private" else Color("d7c98d"))
