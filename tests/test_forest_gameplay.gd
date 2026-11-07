extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/forest_fixture.gd")
const Rules = preload("res://scripts/quests/forest_rules.gd")
var checks := 0
var failures := 0
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
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func speak(game: Node) -> void:
	game.resume()
	game.world.player.position = game.world.npcs.roadkeeper.position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func walk(game: Node, target: Vector2) -> void:
	game.resume()
	game.world.player.set_physics_process(true)
	for i in 900:
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		var difference: Vector2 = target - game.world.player.position
		if absf(difference.x) < 10 and absf(difference.y) < 10: break
		if absf(difference.x) >= 10: Input.action_press("move_right" if difference.x > 0 else "move_left")
		else: Input.action_press("move_down" if difference.y > 0 else "move_up")
		game.world._update_npcs()
		await physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	game.world.player.set_physics_process(false)
	check(game.world.player.position.distance_to(target) < 16, "keyboard movement reaches actual authored road waypoint")
func wait_for_guide(game: Node, target: Vector2) -> void:
	for i in 900:
		game.world._update_npcs()
		if game.world.npcs.roadkeeper.position.distance_to(target) <= 82: break
		await physics_frame
	check(game.world.npcs.roadkeeper.position.distance_to(target) <= 82, "companion physically navigates toward player without teleportation")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session, "human", false), "ordinary route fixture starts without optional episodes or lake completion")
	session.region = "thicket"
	session.arrival = Vector2(1680, 620)
	game._build_world()
	game.resume()
	game.world.player.position = Vector2(1750, 620)
	game.world.interact()
	await settle()
	freeze(game)
	check(session.region == "woodroad" and game.world.player.health == 64 and game.world.safe_to_rest(), "actual forest portal is safe and preserves wounds")
	var guide: CharacterBody2D = game.world.npcs.roadkeeper
	for point in Rules.POINTS + [Vector2(430, 780), game.world.definition.camp]:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 620), point)
		var clear := not route.is_empty()
		var previous := Vector2(240, 620)
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "ordinary body has an unobstructed route to compulsory point and night/rest positions")
	check(not game.world.navigation.segment_clear(Vector2(1470, 645), Vector2(1570, 645)), "actual persistent passage starts physically closed")
	await speak(game)
	check(button(game, "forest_accept") != null and not button(game, "forest_accept").disabled, "new NPC offers a separate accessible road commitment")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.forest_action("accept") and Rules.stage(session.gathered, session.opened) == 0, "failed acceptance does not start an unrecorded escort")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 1 and not game.world.forest_action("work"), "keyboard acceptance starts escort without remote progress")
	game.world._update_npcs()
	check(guide.walk_speed == 70, "ordinary escort starts with its own finite walking pace")
	await speak(game)
	var effort: float = game.world.player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.forest_action("aid_brief") and game.world.player.stamina == effort, "failed common briefing never spends effort or grants aid")
	DirAccess.remove_absolute("user://save.json.tmp")
	button(game, "forest_aid_brief").pressed.emit()
	game.world._update_npcs()
	check(guide.walk_speed == 90 and game.world.player.stamina == effort - 15, "ordinary briefing has the same actual useful pace as blood aid with its own price")
	var original: Vector2 = guide.position
	game.world.player.position = Vector2(900, 620)
	game.world._update_npcs()
	check(guide.destination == guide.position, "guide waits rather than teleporting or following across a large gap")
	for i in 5: await physics_frame
	check(guide.position.distance_to(original) < 1, "waiting companion actually remains at its own location")
	game.world.player.position = original + Vector2(30, 0)
	Engine.time_scale = 4
	await walk(game, Rules.POINTS[0])
	check(not game.world.can_forest("work") or guide.position.distance_to(Rules.POINTS[0]) <= 90, "arrival alone cannot replace companion presence")
	await wait_for_guide(game, Rules.POINTS[0])
	game.world.interact()
	var stamina: float = game.world.player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.forest_action("work") and Rules.progress(session.gathered) == 0 and game.world.player.stamina == stamina and not game.world.forest_signs[0].repaired, "failed shared work preserves stamina progress and visible sign")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(button(game, "forest_work") != null and not button(game, "forest_work").disabled, "real road point exposes an available shared action")
	var saved_guide: Vector2 = guide.position
	await enter()
	check(Rules.progress(session.gathered) == 1 and game.world.player.stamina == stamina - 12 and game.world.forest_signs[0].repaired, "actual first work commits real effort and visible sign")
	var enemy: CharacterBody2D
	for child in game.world.get_children():
		if child is CharacterBody2D and child.get("id") == "woodroad_guard": enemy = child
	check(enemy != null, "optional encounter exists outside compulsory road")
	var enemy_origin: Vector2 = enemy.position
	enemy.set_physics_process(false)
	enemy.position = game.world.player.position + Vector2(60, 0)
	game.world._update_npcs()
	check(guide.destination == guide.position and not game.world.can_forest("work"), "actual nearby threat pauses companion and prevents shared work")
	enemy.position = enemy_origin
	check(session.load_saved() and Rules.progress(session.gathered) == 1 and Vector2(session.world_state.npcs["woodroad:roadkeeper"][0], session.world_state.npcs["woodroad:roadkeeper"][1]).distance_to(saved_guide) < 2, "partial work and actual companion position load together from JSON")
	game._build_world()
	guide = game.world.npcs.roadkeeper
	check(guide.position.distance_to(saved_guide) < 1 and game.world.forest_signs[0].repaired, "rebuilding restores visible work and companion without sending her home")
	game.resume()
	await settle()
	freeze(game)
	guide = game.world.npcs.roadkeeper
	guide.set_physics_process(false)
	var departure: Vector2 = guide.position
	game.world.player.position = Vector2(135, 620)
	game.world.interact()
	await settle()
	freeze(game)
	check(session.region == "thicket" and Rules.progress(session.gathered) == 1, "leaving through actual portal preserves partial shared work")
	game.world.player.position = Vector2(1750, 620)
	game.world.interact()
	await settle()
	freeze(game)
	guide = game.world.npcs.roadkeeper
	check(session.region == "woodroad" and guide.position.distance_to(departure) < 2 and game.world.forest_signs[0].repaired, "returning restores waiting companion at the saved road location")
	await walk(game, Vector2(830, 620))
	await wait_for_guide(game, Vector2(830, 620))
	await walk(game, Vector2(830, 780))
	await wait_for_guide(game, Vector2(830, 780))
	await walk(game, Rules.POINTS[1])
	await wait_for_guide(game, Rules.POINTS[1])
	game.world.interact()
	button(game, "forest_work").pressed.emit()
	check(Rules.progress(session.gathered) == 2 and not game.world.can_forest("work"), "second real work advances once and cannot repeat at the old point")
	await walk(game, Vector2(1180, 780))
	await wait_for_guide(game, Vector2(1180, 780))
	await walk(game, Vector2(1180, 620))
	await wait_for_guide(game, Vector2(1180, 620))
	await walk(game, Rules.POINTS[2])
	await wait_for_guide(game, Rules.POINTS[2])
	game.world.interact()
	button(game, "forest_work").pressed.emit()
	check(Rules.stage(session.gathered, session.opened) == 2 and game.world.navigation.segment_clear(Vector2(1470, 645), Vector2(1570, 645)), "third actual work removes a physical gate and rebuilds navigation")
	check(not game.world.navigation.find_path(game.world.player.position, Vector2(1640, 650)).is_empty(), "permanent passage provides actual access to an optional supply")
	await speak(game)
	session.inventory.coin = 999
	var xp: int = session.xp
	button(game, "forest_commons").pressed.emit()
	check(button(game, "forest_confirm_commons") != null and session.xp == xp, "final consequences are reviewed before commitment")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.forest_action("commons") and session.xp == xp and Rules.REPORT not in session.opened, "failed final write cannot grant experience or an outcome")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(session.xp == xp + 90 and session.inventory.coin == 999 and Rules.OUTCOMES[0] in session.gathered and game.world.forest_signs[2].outcome == "commons", "keyboard outcome changes visible signs and grants one reward without a full-wallet block")
	game.world._update_npcs()
	check(guide.destination == Vector2(430, 780) and not game.world.forest_action("watch"), "committed outcome changes companion destination and cannot be switched for another reward")
	check(session.load_saved() and Rules.stage(session.gathered, session.opened) == 3, "completed outcome and permanent passage survive disk load")
	Engine.time_scale = 1
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
	check(game.world.navigation.segment_clear(Vector2(1470, 645), Vector2(1570, 645)) and game.world.forest_signs[1].outcome == "commons", "rebuilt world preserves gate and visible final care marks")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and Rules.stage(session.gathered, session.opened) == 3 and session.xp == xp + 90, "death checkpoint preserves completed road and does not duplicate reward")
	print("Forest gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
