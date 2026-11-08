extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/knell_fixture.gd")
const Rules = preload("res://scripts/quests/knell_rules.gd")
var Undercroft: GDScript
var Echo: GDScript
var checks := 0
var failures := 0
var notices: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, id: String) -> Button: return game.screen.find_child(id, true, false) as Button
func settle() -> void:
	await process_frame
	await process_frame
func freeze(game: Node) -> void:
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	for child in game.world.get_children():
		if child is CharacterBody2D and child != game.world.player: child.set_physics_process(false)
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func key_e(game: Node) -> void:
	game.world.set_process(true)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame
	game.world.set_process(false)
func release_moves() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
# Real keyboard movement along the actual navigation route; walls are never ignored.
func walk(game: Node, target: Vector2) -> bool:
	game.resume()
	var player: CharacterBody2D = game.world.player
	var route: PackedVector2Array = game.world.navigation.find_path(player.position, target)
	if route.is_empty(): return false
	player.set_physics_process(true)
	for point in route:
		for i in 400:
			release_moves()
			var difference: Vector2 = point - player.position
			if difference.length() < 6: break
			if absf(difference.x) > 3: Input.action_press("move_right" if difference.x > 0 else "move_left")
			if absf(difference.y) > 3: Input.action_press("move_down" if difference.y > 0 else "move_up")
			await physics_frame
	release_moves()
	player.set_physics_process(false)
	return player.position.distance_to(target) < 10
func route_clear(game: Node, start: Vector2, finish: Vector2) -> bool:
	var route: PackedVector2Array = game.world.navigation.find_path(start, finish)
	if route.is_empty(): return false
	var previous := start
	for point in route:
		if not game.world.navigation.segment_clear(previous, point): return false
		previous = point
	return true
func grate_bodies(game: Node) -> int:
	return game.world.get_children().filter(func(child): return child is StaticBody2D and child.has_meta("knell_grate")).size()
func run() -> void:
	Undercroft = load("res://scripts/world/undercroft_landscape.gd")
	Echo = load("res://scripts/actors/echo_enemy.gd")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.notice.connect(func(key): notices.append(key))
	check(Fixture.ready(session, "human", "renewal"), "real campaign and recorded renewal decision")
	session.region = "crossing"
	session.arrival = Vector2(1120, 470)
	session.world_state.minutes = 1400
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
	check(game.world.knell_cue != null and game.world.knell_cue.active(), "night toll is heard above the chapel while the case is open")
	game.world.player.position = Vector2(1120, 450)
	check(game.world.nearby_key() == "TO_UNDERCROFT", "actual lower chapel door is reachable from the crossing")
	await key_e(game)
	await settle()
	check(session.region == "crossing" and "KNELL_DOOR_LOCKED" in notices, "real E at the locked door explains instead of travelling")
	check(not session.travel("undercroft", Vector2(1120, 450), game.world.player_vitals()) and session.region == "crossing", "backend refuses the crypt before the keeper's key")
	game.update_hud()
	check(game.quest_label.text == game.tr("KNELL_HUD_0"), "finished common decision now points to the optional lead")
	# Keeper conversation through the existing dialogue.
	game.world.player.position = game.world.keeper.position
	game.world.interact()
	check(button(game, "knell_entry") != null, "keeper's ordinary conversation offers the new case")
	button(game, "knell_entry").pressed.emit()
	var request: Label = game.screen.find_child("knell_request", true, false)
	var accord: Label = game.screen.find_child("knell_accord", true, false)
	check(request != null and accord != null and accord.text == game.tr("KNELL_ACCORD_RENEWAL") and (game.screen.find_child("knell_identity", true, false) as Label).text == game.tr("KNELL_REQUEST_HUMAN"), "request reacts to the recorded decision and the ordinary human path")
	check(button(game, "knell_accept") != null and button(game, "knell_other") != null, "case can be accepted and the old conversation stays reachable")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.knell_action("accept") and not Rules.can_enter(session.gathered), "failed write cannot hand over the key")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.can_enter(session.gathered) and Rules.recorded(session.gathered) == "human" and game.current_screen == "game", "keyboard acceptance records the case and returns to play")
	for child in game.world.get_children():
		if child is CharacterBody2D and child.has_method("apply_slow") and child.health > 0: child.receive_damage(999, Vector2.RIGHT)
	await settle()
	game.world.player.position = Vector2(1120, 450)
	game.world.interact()
	await settle()
	check(session.region == "undercroft" and game.world.definition.location == "LOCATION_UNDERCROFT", "real door leads into the crypt")
	freeze(game)
	game.resume()
	await settle()
	var world: Node2D = game.world
	check(grate_bodies(game) == 1 and not world.navigation.segment_clear(Vector2(1080, 500), Vector2(1160, 500)) and is_instance_valid(world.bell) and not world.bell.armed, "bell chamber grate is a real closed body and the bell sleeps")
	check(not world.navigation.segment_clear(Vector2(1080, 1000), Vector2(1160, 1000)), "renewal world keeps the bricked side passage")
	check(world.Regions.camps("undercroft", session.opened).size() == 2 and Undercroft.RENEWAL_CAMP in world.Regions.camps("undercroft", session.opened), "renewal adds an actual second rest in the crypt")
	var supplies: Sprite2D
	for chest in world.chests:
		if chest.get_meta("definition").id == Rules.SUPPLIES: supplies = chest
	check(supplies != null and not supplies.visible, "community supplies stay hidden in a renewal world")
	var echoes: Array = world.get_children().filter(func(child): return child.get_script() == Echo)
	check(echoes.size() == 3, "three echoes haunt the crypt")
	for point in world.definition.knell_sites.values() + world.definition.herbs + [world.definition.camp, Undercroft.RENEWAL_CAMP, world.definition.exit, Vector2(1060, 500)]:
		check(route_clear(game, Vector2(240, 650), point), "ordinary body has a clear route to %s" % point)
	# The entrance plaque is safe to read at once.
	check(await walk(game, Vector2(430, 355)), "keyboard movement reaches the entrance plaque")
	check(world.nearby_key() == "KNELL_PLAQUE_HALL", "actual plaque prompt")
	world.interact()
	check(game.screen.find_child("knell_inscription", true, false) != null and button(game, "knell_read") != null, "plaque page shows inscription and a reading action")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not world.knell_action("read_hall") and Rules.read_count(session.gathered) == 0, "failed write does not record a reading")
	DirAccess.remove_absolute("user://save.json.tmp")
	var xp: int = session.xp
	await enter()
	check(Rules.read_count(session.gathered) == 1 and session.xp == xp + 10 and world.knell_plaques.hall.read, "keyboard reading records the plaque once and lights a candle")
	check(button(game, "knell_read") == null, "read plaque offers no second reward")
	game.resume()
	# An echo blocks reading the gallery plaque until it is dealt with.
	var near: CharacterBody2D = echoes[0]
	world.player.position = Vector2(650, 330)
	check(not world.can_knell("read_gallery"), "a nearby echo makes reading unsafe")
	world.interact()
	check(button(game, "knell_read") == null and game.screen.find_child("knell_unsafe", true, false) != null, "plaque page explains why reading is unsafe instead of hiding the action silently")
	game.resume()
	world.player.position = near.position + Vector2(-30, 0)
	world.player.facing = Vector2.RIGHT
	var coins: int = session.inventory.coin
	xp = session.xp
	world.player.set_physics_process(true)
	for i in 6:
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
		for frame in 30: await physics_frame
		if not is_instance_valid(near): break
	world.player.set_physics_process(false)
	check(not is_instance_valid(near) and "undercroft_echo_1" in session.defeated and session.xp == xp + 30 and session.inventory.coin == coins + 2, "real sword strikes defeat an echo and record it")
	for echo in echoes:
		if is_instance_valid(echo): echo.receive_damage(999, Vector2.RIGHT)
	await settle()
	check(Rules.ECHOES.all(func(id): return id in session.defeated), "all echoes recorded through the ordinary defeat path")
	for id in ["gallery", "ossuary"]:
		var point: Vector2 = world.definition.knell_sites[id] + (Vector2(0, 25) if id == "gallery" else Vector2(0, -25))
		check(await walk(game, point), "keyboard movement reaches plaque: " + id)
		world.interact()
		await enter()
		check("knell:plaque:" + id in session.gathered, "plaque read through actual dialogue: " + id)
		game.resume()
	check(Rules.armed(session.gathered, session.defeated) and grate_bodies(game) == 0 and world.navigation.segment_clear(Vector2(1080, 500), Vector2(1160, 500)) and world.bell.armed and "KNELL_GRATE_OPEN" in notices, "third plaque lifts the real grate, updates navigation and wakes the bell")
	session.changed.emit()
	check(grate_bodies(game) == 0, "re-applying state never rebuilds the grate")
	check(await walk(game, Vector2(1060, 500)) and await walk(game, Vector2(1180, 500)), "keyboard movement passes through the opened grate")
	world.bell.set_physics_process(false)
	# Renewal rest before the fight.
	world.player.position = Undercroft.RENEWAL_CAMP
	world.player.health = 50
	var minutes: float = session.world_state.minutes
	world.interact()
	check(world.player.health == 100 and session.world_state.minutes >= minutes + 30, "actual rest at the renewal camp heals and records time")
	# The recorded victory.
	world.player.position = Vector2(1400, 705)
	world.bell.engaged = true
	check(not world.safe_to_rest(), "engaged bell blocks resting and saving")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	world.bell.receive_damage(9999, Vector2.RIGHT)
	await settle()
	check(is_instance_valid(world.bell) and world.bell.awaiting_record and Rules.BELL not in session.defeated, "failed write keeps the bell yielded but unrecorded")
	game.update_hud()
	check(world.nearby_key() == "KNELL_RECORD" and game.quest_label.text == game.tr("KNELL_RECORD_HELP") and game.boss_panel.visible, "HUD and prompt explain how to retry the record")
	DirAccess.remove_absolute("user://save.json.tmp")
	xp = session.xp
	await key_e(game)
	await settle()
	check(Rules.BELL in session.defeated and session.xp == xp + 120 and not is_instance_valid(world.bell), "real E retries and commits the victory once")
	world.player.position = Vector2(1700, 1060)
	coins = session.inventory.coin
	var potions: int = session.inventory.get("potion", 0)
	world.interact()
	check(Rules.CACHE in session.opened and session.inventory.coin == coins + 14 and session.inventory.potion == potions + 1, "bell chamber cache opens only after the recorded victory")
	world.interact()
	check(session.inventory.coin == coins + 14, "cache cannot be claimed twice")
	check(session.load_saved() and Rules.stage(session.gathered, session.defeated, session.opened) == 3, "JSON load restores the silenced bell")
	game._build_world()
	freeze(game)
	check(not is_instance_valid(game.world.bell) and grate_bodies(game) == 0, "rebuilt crypt has no bell and an open grate")
	# Report to the keeper.
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await settle()
	freeze(game)
	check(session.region == "crossing", "return through the real exit")
	game.update_hud()
	check(game.quest_label.text == game.tr("KNELL_HUD_3"), "HUD points back to the keeper")
	game.world.player.position = game.world.keeper.position
	game.world.interact()
	button(game, "knell_entry").pressed.emit()
	check((game.screen.find_child("knell_report", true, false) as Label).text == game.tr("KNELL_REPORT_HUMAN") and button(game, "knell_keeper") != null and button(game, "knell_kept") != null, "report reacts to the human path and offers both choices")
	button(game, "knell_kept").pressed.emit()
	check(button(game, "knell_confirm_kept") != null and Rules.outcome(session.opened) == "", "choice is reviewed before commitment")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.knell_action("kept") and Rules.TONGUE not in session.gear_owned, "failed choice gives no weapon")
	DirAccess.remove_absolute("user://save.json.tmp")
	xp = session.xp
	await enter()
	check(Rules.outcome(session.opened) == "kept" and Rules.TONGUE in session.gear_owned and session.xp == xp + 80, "keyboard confirms a single kept-tongue outcome")
	var epilogue: Label = game.screen.find_child("knell_epilogue", true, false)
	check(epilogue != null and epilogue.text == game.tr("KNELL_EPILOGUE_KEPT"), "epilogue matches the recorded choice")
	check(not game.world.knell_action("keeper"), "outcome cannot be replaced")
	game.resume()
	check(session.equip_item(Rules.TONGUE) and game.world.player.weapon_stats().damage == 38.0, "kept tongue is a real equippable weapon")
	check(not session.trade_item(Rules.TONGUE, true, game.world.player.position, game.world.player_vitals()), "unique tongue cannot be sold")
	var target = load("res://scripts/actors/enemy.gd").new()
	target.position = game.world.player.position + Vector2(30, 0)
	target.target = game.world.player
	game.world.add_child(target)
	target.set_physics_process(false)
	game.world._on_strike(game.world.player.position, Vector2.RIGHT)
	check(target.health < target.max_health and target.slow_remaining > 0, "tongue strike staggers its target")
	target.queue_free()
	check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved() and Rules.outcome(session.opened) == "kept" and session.equipped.weapon == Rules.TONGUE, "JSON save keeps outcome and equipped weapon")
	game._build_world()
	freeze(game)
	game.resume()
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	var mentor: Label = game.screen.find_child("knell_mentor", true, false)
	check(mentor != null and mentor.text == game.tr("KNELL_MENTOR_KEPT"), "the mentor remembers the kept tongue")
	game.resume()
	check(game.world.knell_cue != null and not game.world.knell_cue.active(), "night tolling ends once the case is resolved")
	print("Knell gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
