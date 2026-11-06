extends Node2D
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Overlay = preload("res://scripts/world/living/weather_overlay.gd")
var region := "crossing"
var player: Node2D
var modulation: CanvasModulate
var hero_light: PointLight2D
var light_texture: GradientTexture2D

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	light_texture = GradientTexture2D.new()
	light_texture.width = 256
	light_texture.height = 256
	light_texture.gradient = gradient
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(0.5, 0)
	modulation = CanvasModulate.new()
	add_child(modulation)
	hero_light = _light(Vector2.ZERO, Color("b8d7dc"), 1.0, 0.55)
	var points: Array = [get_parent().definition.camp]
	if region == "ruins":
		points.append_array([Vector2(580, 540), Vector2(580, 740), Vector2(1140, 430), Vector2(1140, 760), Vector2(1530, 590)])
	for point in points:
		_light(point + Vector2(0, -10), Color("f6c88a"), 0.7, 0.9)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var overlay := Overlay.new()
	overlay.indoor = region == "ruins"
	layer.add_child(overlay)
	_process(0)

func _light(point: Vector2, color: Color, texture_scale: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture
	light.position = point
	light.color = color
	light.texture_scale = texture_scale
	light.energy = energy
	add_child(light)
	return light

func _process(_delta: float) -> void:
	var daylight := Clock.daylight(Session.world_state.minutes)
	var color := Color("5c6e8f").lerp(Color.WHITE, daylight)
	if region == "ruins":
		color = Color("9da6b5")
	else:
		var weather := Clock.weather(Session.world_state.minutes, int(Session.world_state.seed))
		if weather == "rain":
			color *= Color("cbd8e1")
		elif weather == "fog":
			color *= Color("d9e2df")
	modulation.color = color
	hero_light.visible = daylight < 0.85 or region == "ruins"
	if is_instance_valid(player):
		hero_light.global_position = player.global_position + Vector2(0, -8)
