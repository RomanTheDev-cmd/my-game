extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame
func button(game: Node, label: String) -> Button: return game.screen.find_child(label, true, false) as Button
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.vampire(session)
	session.region = "lake"
	game._build_world()
	game.resume()
	await settle()
	game.world.player.position = game.world.npcs.wayfarer.position
	game.world.interact()
	button(game, "dialogue_continue").pressed.emit()
	button(game, "nature_invitation").pressed.emit()
	check(button(game, "nature_learn_bat") != null and not button(game, "nature_learn_bat").disabled, "NPC exposes actual first lesson through normal dialogue")
	button(game, "nature_learn_bat").pressed.emit()
	check(session.nature.gift == "blood_bat" and game.world.player.mana < 81, "UI training updates the player's actual mana and unlocks flight")
	session.region = "waterworks"
	session.arrival = Vector2(1640, 430)
	game._build_world()
	game.resume()
	await settle()
	var player = game.world.player
	var old: Dictionary = session.snapshot(Vector2(1640, 320), {"health": 54.0, "stamina": 37.0, "mana": 73.0})
	old.version = 8
	old.nature.gift = "blood"
	old.nature.erase("landing")
	old.gathered.erase("flight:bat")
	check(session.Store.write_game(old) == OK and session.load_saved(), "old ordinary save inside a newly authored chamber remains loadable")
	game._build_world()
	game.resume()
	await settle()
	player = game.world.player
	check(player.position.distance_to(Vector2(1640, 320)) > 50 and player._landing_safe(player.position) and player.health < 55, "legacy chamber spawn relocates safely without healing")
	session.nature.gift = "blood_bat"
	session.gathered.append("flight:bat")
	player.position = Vector2(1640, 430)
	check(player.test_move(player.transform, Vector2(0, -100)), "ordinary body cannot cross low gate")
	await key(KEY_Z)
	check(session.nature.form == "bat" and player.collision_mask == 1 and player.body_collider.shape.radius == 6, "physical Z changes actual collider and low obstacle mask")
	check(not player.test_move(player.transform, Vector2(0, -100)), "bat flies across low gate")
	check(player.test_move(player.transform, Vector2(200, 0)), "bat still collides with solid walls")
	check(not player.use_nature_power() and not player.cast_magic("frost") and player.weapon_stats().damage == 0, "mobile form cannot attack or cast its old powers")
	await key(KEY_J)
	check(player.attack_time == 0, "actual attack key cannot start a bat attack")
	var anchor: Dictionary = session.nature.landing.duplicate(true)
	player.position = Vector2(1640, 320)
	await settle()
	check(session.nature.landing == anchor, "closed chamber never becomes a trapping human landing anchor")
	check(player.shift_form() and player.position.distance_to(Vector2(anchor.position[0], anchor.position[1])) < 1, "manual return inside closed chamber lands outside safely")
	player.position = Vector2(1640, 430)
	player.shift_form("bat")
	player.position = Vector2(1640, 320)
	check(session.save_at(player.position, game.world.player_vitals()), "flight inside chamber can be saved")
	check(session.load_saved() and session.nature.form == "bat", "saved mobile form reloads")
	game._build_world()
	game.resume()
	await settle()
	player = game.world.player
	check(player.body_collider.shape.radius == 6 and player.collision_mask == 1, "load restores geometry before movement")
	session.nature.blood = 0.001
	game.world._process(0.1)
	check(session.nature.form == "human" and player.position.y > 400 and session.nature.landing.is_empty() and player.body_collider.shape.radius == 8, "resource exhaustion synchronously resolves geometry and safe position before checkpoint")
	game.world.save_safe()
	var safe_save: Dictionary = session.Store.load_game()
	check(not safe_save.is_empty() and safe_save.position[1] > 400 and safe_save.nature.form == "human", "checkpoint after depletion writes the safe ordinary position")
	session.nature.blood = 100
	var chest: Dictionary = game.world.definition.chests[0]
	check(not session.claim_chest(chest, player.position, game.world.player_vitals()), "treasure backend requires actual bat shape")
	player.position = Vector2(1640, 430)
	player.shift_form("bat")
	player.position = Vector2(1640, 320)
	await settle()
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.interact()
	check("waterworks_flight" not in session.opened and not game.world.landing_safe(player.position), "failed treasure write cannot grant the opening or change safe landing")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	check("waterworks_flight" in session.opened, "actual physical treasure interaction records flight challenge")
	await settle()
	player.shift_form()
	check(player.position.distance_to(Vector2(1640, 320)) < 1 and not player.test_move(player.transform, Vector2(0, 110)), "claimed treasure opens an ordinary exit and permits local landing")
	session.region = "lake"
	session.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	await settle()
	game.world.player.position = game.world.npcs.wayfarer.position
	check(game.world.nature_action("learn_mist") and session.nature.gift == "blood_mist", "real successful flight challenge unlocks the next lesson")
	session.region = "waterworks"
	session.arrival = Vector2(740, 1011)
	game._build_world()
	game.resume()
	await settle()
	player = game.world.player
	check(player.test_move(player.transform, Vector2(100, 0)), "human body cannot squeeze through six pixel slit")
	player.shift_form("bat")
	check(player.test_move(player.transform, Vector2(100, 0)), "bat cannot pass the solid narrow slit")
	player.shift_form()
	await key(KEY_X)
	check(session.nature.form == "mist" and player.body_collider.shape.radius == 2 and not player.test_move(player.transform, Vector2(100, 0)), "physical X fits real mist collider through slit")
	player.health = 100
	player.hurt_time = 0
	session.difficulty = 1
	player.receive_damage(40)
	check(is_equal_approx(player.health, 90), "mist takes quarter damage in actual combat without full invulnerability")
	player.position = Vector2(790, 1011)
	await settle()
	player.shift_form()
	check(player.position.x < 770 and player._human_space_clear(player.position), "return inside slit never embeds the ordinary body in a wall")
	player.shift_form("mist")
	player.position = Vector2(940, 1011)
	await settle()
	game.world.interact()
	check("waterworks_mist" in session.opened, "mist exploration treasure commits separately")
	await settle()
	player.shift_form()
	check(player.position.x > 800 and not player.test_move(player.transform, Vector2(-220, 0)), "mist reward opens a full exit for normal body")
	player.position = Vector2(1640, 430)
	player.shift_form("bat")
	player.position = Vector2(1545, 280)
	session.nature.landing.position = [1545.0, 280.0]
	player.shift_form()
	check(player._landing_safe(player.position), "invalid physical anchor from damaged save falls back to an authored safe point")
	var regions := {"keeper": "crossing", "merchant": "crossing", "wayfarer": "lake", "warden": "workshop", "wright": "workshop", "tender": "workshop", "tracker": "thicket"}
	for role in regions:
		for form in ["bat", "mist"]:
			session.nature.blood = 100
			session.region = regions[role]
			game._build_world()
			game.resume()
			await settle()
			game.world.player.position = game.world.npcs[role].position
			game.world.player.shift_form(form)
			game.world.interact()
			var reaction: Label = game.screen.find_child("nature_reaction", true, false)
			check(reaction != null and reaction.text == game.tr("DIALOGUE_" + role.to_upper() + "_" + form.to_upper() + "_FORM") and button(game, "dialogue_return_form") != null, "each NPC reacts distinctly to each exploration form and permits return")
			button(game, "dialogue_return_form").pressed.emit()
			check(session.nature.kind == "vampire" and session.nature.form == "human" and button(game, "dialogue_continue") != null, "return restores dialogue access without changing permanent nature")
	print("Flight gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
