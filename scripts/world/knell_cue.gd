extends Node2D
# Faint night tolling above the crossing chapel while the undercroft case is unresolved.
const Knell = preload("res://scripts/quests/knell_rules.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const PERIOD := 6.0
var elapsed := 0.0

func active() -> bool:
	return Knell.available(Session.opened) and Knell.stage(Session.gathered, Session.defeated, Session.opened) < 3 and Clock.daylight(Session.world_state.minutes) < 0.5

func _process(delta: float) -> void:
	var was := elapsed
	elapsed = fmod(elapsed + delta, PERIOD)
	visible = active()
	if visible and elapsed < was: Sound.play_at("toll", global_position)
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var progress := elapsed / 2.4
	if progress > 1: return
	for i in 2:
		var radius := 20 + (progress + i * 0.35) * 70
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(0.8, 0.86, 0.9, maxf(0, 0.5 - progress * 0.45)), 2)
