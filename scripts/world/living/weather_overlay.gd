extends Control
const Clock = preload("res://scripts/world/living/world_clock.gd")
var indoor := false
var elapsed := 0.0
var fog: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog = ColorRect.new()
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/shaders/fog.gdshader")
	fog.material = shader
	add_child(fog)
	_process(0)

func _process(_delta: float) -> void:
	elapsed = fposmod(Session.world_state.minutes, 3600)
	var weather := Clock.weather(Session.world_state.minutes, int(Session.world_state.seed))
	fog.visible = not indoor and weather == "fog"
	if fog.visible:
		fog.material.set_shader_parameter("elapsed", elapsed)
	queue_redraw()

func _draw() -> void:
	if indoor or Clock.weather(Session.world_state.minutes, int(Session.world_state.seed)) != "rain":
		return
	for i in 85:
		var point := Vector2(fposmod(i * 113 + elapsed * 28, maxf(1, size.x)), fposmod(i * 71 + elapsed * 310, maxf(1, size.y)))
		draw_line(point, point + Vector2(-5, 12), Color(0.68, 0.8, 0.85, 0.28), 1)
