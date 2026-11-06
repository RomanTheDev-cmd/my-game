extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
var checks := 0
var failures := 0
var cues: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := root.get_node("Session")
	var sound := root.get_node("Sound")
	sound.cue_played.connect(func(id): cues.append(id))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	await physics_frame
	check(sound.play_at("swing", game.world.player.position) and sound.voices.any(func(voice): return voice.playing), "successful cue starts real spatial audio playback")
	check(not sound.play_at("missing", Vector2.ZERO), "unknown sound cannot allocate playback")
	await physics_frame
	await physics_frame
	game.show_pause()
	check(not sound.play_at("swing", Vector2.ZERO), "world effect cannot start during pause")
	check(sound.play_ui() and sound.interface_voice.playing, "menu confirmation can play while world is paused")
	sound._process(0.1)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("WorldEffects")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("WorldAmbience")), "pause silences world effects and ambience while preserving UI audio")
	game.resume()
	sound._process(0.1)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("WorldEffects")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("WorldAmbience")), "world audio resumes after closing menu")
	for voice in sound.voices:
		voice.stop()
	for i in 100:
		sound.play_at("impact", Vector2.ZERO)
	check(sound.voices.size() == 12 and sound.voices.filter(func(voice): return voice.playing).size() == 12, "burst of impacts has bounded polyphony")
	check(not sound.play_at("step_0", Vector2.ZERO), "footsteps do not steal occupied combat voices")
	for voice in sound.voices:
		voice.stop()
	var player = game.world.player
	player.position = Vector2(600, 550)
	cues.clear()
	Input.action_press("move_right")
	for i in 24:
		await physics_frame
	Input.action_release("move_right")
	check(cues.any(func(id): return id.begins_with("step_")), "actual walking produces paced footstep audio")
	cues.clear()
	for i in 12:
		await physics_frame
	check(not cues.any(func(id): return id.begins_with("step_")), "standing still does not produce footsteps")
	player.hurt_time = 0
	player.dodge_time = 0.2
	player.receive_damage(10)
	check(not "impact" in cues and not "block" in cues, "evaded damage has no false hit feedback")
	player.dodge_time = 0
	player.blocking = true
	player.receive_damage(10)
	check("block" in cues, "real blocked hit produces shield feedback")
	cues.clear()
	player.magic_cooldown = 0
	player.mana = 0
	check(not player.cast_magic("light") and not "magic" in cues, "failed spell does not emit successful cast audio")
	player.mana = 100
	check(player.cast_magic("light") and "magic" in cues, "successful spell produces cast feedback")
	player.health = 40
	player.magic_cooldown = 0
	check(player.cast_magic("heal") and "heal" in cues, "healing feedback follows successful resource use")

	session.world_state.minutes = 1440
	sound._process(2)
	check(sound.ambience_levels.rain > 0.5 and sound.ambience.rain.playing, "rainy world activates looping rain ambience")
	session.region = "ruins"
	sound._process(2)
	check(sound.ambience_levels.rain == 0 and sound.ambience_levels.room > 0.5, "interior replaces rain with indoor ambience")
	check(sound.ambience.rain.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambience uses actual looping audio resource")
	var master := AudioServer.get_bus_index("Master")
	check(session.set_volume("master", 0) and AudioServer.is_bus_mute(master), "zero volume mutes the real master bus")
	check(session.set_volume("master", 0.5) and not AudioServer.is_bus_mute(master) and absf(AudioServer.get_bus_volume_db(master) + 6.0206) < 0.01, "linear volume updates actual decibels and unmutes")
	check(session.set_fullscreen(false) and session.set_difficulty(2), "existing settings remain writable")
	var loaded: Dictionary = load("res://scripts/systems/preferences_store.gd").read()
	check(loaded.audio.master == 0.5 and loaded.difficulty == 2, "other setting changes preserve saved audio levels")
	check(not session.set_volume("master", INF) and not session.set_volume("master", -0.1) and session.audio.master == 0.5, "nonfinite and negative volume cannot change live or saved settings")
	game.show_settings()
	var slider: HSlider = game.screen.find_child("volume_effects", true, false)
	check(slider != null and slider.focus_mode == Control.FOCUS_ALL, "volume is available through keyboard-focusable settings control")
	if slider != null:
		slider.value = 0.25
	check(session.audio.effects == 0.25 and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")) + 12.0412) < 0.01, "actual slider updates saved volume and live mix")
	DirAccess.make_dir_absolute("user://preferences.json.tmp")
	if slider != null:
		slider.value = 0.75
	check(session.audio.effects == 0.25 and slider.value == 0.25, "failed settings write restores slider and leaves live mix unchanged")
	DirAccess.remove_absolute("user://preferences.json.tmp")
	game.show_title()
	sound._process(0.1)
	check(sound.ambience.values().all(func(voice): return not voice.playing), "returning to title stops environmental loops")
	game.new_game()
	sound._process(0.2)
	await sound.shutdown()
	check(sound.ambience.values().all(func(voice): return not is_instance_valid(voice)) and not sound.play_ui() and not sound.play_at("swing", Vector2.ZERO), "graceful shutdown releases loops and rejects new playback")
	game.queue_free()
	await process_frame
	await create_timer(0.1, true).timeout
	print("Audio integration checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
