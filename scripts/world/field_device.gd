extends Node2D
var kind := "sluice"
var progress := 0
var pulse_time := 0.0
var pulse_color := Color("b8dce4")
func pulse(method: String) -> void:
	pulse_color = {"frost": Color("9bcce4"), "heal": Color("9ecb99"), "aegis": Color("c8bd8e")}.get(method, Color("d3b98e"))
	pulse_time = 1.0
	queue_redraw()
func _process(delta: float) -> void:
	if pulse_time > 0:
		pulse_time = maxf(0, pulse_time - delta)
		queue_redraw()
func _draw() -> void:
	var color := Color("adc7a2") if progress == 3 else Color("aaa184")
	match kind:
		"sluice":
			draw_rect(Rect2(-8, -20, 16, 28), Color("78857b"))
			draw_arc(Vector2(0, -14), 16, 0, TAU, 24, color, 3)
			for i in 4: draw_line(Vector2(0, -14), Vector2(0, -14) + Vector2.from_angle(i * PI / 2) * 13, color, 2)
		"garden":
			for i in 3:
				draw_rect(Rect2(-20 + i * 14, -6, 11, 15), Color("716b50"))
				draw_line(Vector2(-15 + i * 14, -6), Vector2(-15 + i * 14, -18 - (8 if progress > i else 0)), color, 3)
				draw_circle(Vector2(-12 + i * 14, -18 - (8 if progress > i else 0)), 5, Color("87b476") if progress > i else Color("8b876a"))
		"relay":
			draw_rect(Rect2(-4, -32, 8, 40), Color("7d8274"))
			draw_line(Vector2(-16, -20), Vector2(16, -20), color, 3)
			draw_arc(Vector2(0, -20), 14, PI, TAU, 20, color, 3)
	for i in 3: draw_rect(Rect2(-12 + i * 9, 13, 6, 3), Color("b4d9b0") if progress > i else Color("646d65"))
	if pulse_time > 0:
		var tint := pulse_color
		tint.a = pulse_time * 0.65
		draw_arc(Vector2(0, -12), 18 + (1.0 - pulse_time) * 30, 0, TAU, 36, tint, 3)
