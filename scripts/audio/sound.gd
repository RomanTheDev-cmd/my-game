extends Node
const Regions = preload("res://scripts/world/region_catalog.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const SAMPLE_NAMES := ["step_0", "step_1", "step_2", "swing", "dodge", "arrow", "impact", "block", "magic", "heal", "collect", "ui"]
const ATMOSPHERE_NAMES := ["wind", "rain", "room", "fire"]
var samples := {}
var atmosphere := {}
signal cue_played(id: String)
var voices: Array[AudioStreamPlayer2D] = []
var interface_voice: AudioStreamPlayer
var fire_voice: AudioStreamPlayer2D
var ambience: Dictionary = {}
var ambience_levels := {"wind": 0.0, "rain": 0.0, "room": 0.0}
var step_index := 0
var shutting_down := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load after import: preloading audio in an autoload breaks a clean editor import.
	for id in SAMPLE_NAMES:
		samples[id] = load("res://assets/audio/%s.wav" % id)
	for id in ATMOSPHERE_NAMES:
		atmosphere[id] = load("res://assets/audio/%s.wav" % id)
	for bus in ["Effects", "Ambience", "WorldEffects", "WorldAmbience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, bus.trim_prefix("World") if bus.begins_with("World") else "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1
	AudioServer.add_bus_effect(0, limiter)
	for i in 12:
		var voice := AudioStreamPlayer2D.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.bus = "WorldEffects"
		voice.max_distance = 650
		voice.attenuation = 1.5
		add_child(voice)
		voices.append(voice)
	interface_voice = AudioStreamPlayer.new()
	interface_voice.bus = "Effects"
	interface_voice.max_polyphony = 4
	interface_voice.volume_db = -16
	add_child(interface_voice)
	for id in ["wind", "rain", "room"]:
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.bus = "WorldAmbience"
		voice.stream = loop_sample(id)
		voice.volume_db = -80
		add_child(voice)
		ambience[id] = voice
	fire_voice = AudioStreamPlayer2D.new()
	fire_voice.stream = loop_sample("fire")
	fire_voice.bus = "WorldAmbience"
	fire_voice.volume_db = -12
	fire_voice.max_distance = 220
	add_child(fire_voice)
	apply_volumes(Session.audio)
	Session.notice.connect(_notice)

func apply_volumes(levels: Dictionary) -> void:
	for key in ["master", "effects", "ambience"]:
		var index := AudioServer.get_bus_index("Master" if key == "master" else key.capitalize())
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, levels[key])))
		AudioServer.set_bus_mute(index, levels[key] == 0)

func loop_sample(id: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = atmosphere[id].duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream

func play_at(id: String, point: Vector2) -> bool:
	if shutting_down or not samples.has(id) or not Session.running or get_tree().paused:
		return false
	var occupied := 0
	for voice in voices:
		if voice.playing:
			occupied += 1
	if id.begins_with("step_") and occupied >= 8:
		return false
	for voice in voices:
		if not voice.playing:
			voice.stream = samples[id]
			voice.global_position = point
			voice.volume_db = -18 if id.begins_with("step_") else -10
			voice.play()
			cue_played.emit(id)
			return true
	return false

func footstep(point: Vector2) -> void:
	play_at("step_%d" % step_index, point)
	step_index = (step_index + 1) % 3

func play_ui(id: String = "ui") -> bool:
	if shutting_down or not samples.has(id):
		return false
	interface_voice.stream = samples[id]
	interface_voice.play()
	cue_played.emit(id)
	return true

func _process(delta: float) -> void:
	if shutting_down:
		return
	var paused := get_tree().paused
	for bus in ["WorldEffects", "WorldAmbience"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), paused or not Session.running)
	for voice in voices:
		if not Session.running:
			voice.stop()
	fire_voice.position = Regions.get_region(Session.region).camp
	if Session.running and not fire_voice.playing:
		fire_voice.play()
	elif not Session.running:
		fire_voice.stop()
	var weather := Clock.weather(Session.world_state.minutes, int(Session.world_state.seed))
	var targets := {"wind": 0.0, "rain": 0.0, "room": 0.0}
	if Session.region == "ruins":
		targets.room = 0.6
	else:
		targets.wind = 0.25 if weather == "rain" else 0.6
		targets.rain = 0.8 if weather == "rain" else 0.0
	for id in ambience:
		var voice: AudioStreamPlayer = ambience[id]
		if not Session.running:
			voice.stop()
			ambience_levels[id] = 0.0
			continue
		if not voice.playing:
			voice.play()
		if not paused:
			ambience_levels[id] = move_toward(ambience_levels[id], targets[id], delta * 0.7)
		voice.volume_db = linear_to_db(maxf(0.0001, ambience_levels[id])) - 16

func _notice(key: String) -> void:
	if key in ["HERB_FOUND", "LANTERN_FOUND", "CHEST_OPENED", "TRADE_DONE", "POTION_CRAFTED", "LEVEL_UP", "ENCOUNTER_SAVED"]:
		play_ui("collect")
	elif key == "RESTED":
		play_ui("heal")

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null

func shutdown() -> void:
	shutting_down = true
	get_tree().paused = true
	var players: Array[Node] = []
	for type in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		players.append_array(get_tree().root.find_children("*", type, true, false))
	for voice in players:
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
	# A 2D play request is queued until physics; drain it even when quitting from pause.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for voice in players:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
			voice.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1, true).timeout
