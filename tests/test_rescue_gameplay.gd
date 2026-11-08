extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/rescue_fixture.gd")
const Rules = preload("res://scripts/quests/rescue_rules.gd")
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
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
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
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
	await settle()
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
	freeze(game)
func walk(game: Node, until_x: float) -> void:
	game.world.set_process(true)
	game.world.npcs.mentor.set_physics_process(true)
	game.world.player.set_physics_process(true)
	await key(KEY_K, true)
	await key(KEY_A, true)
	var frames := 0
	while game.world.player.position.x > until_x and frames < 1800:
		await physics_frame
		frames += 1
	await key(KEY_A, false)
	await key(KEY_K, false)
	freeze(game)
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "genuine prior reports and preparation unlock the actual next episode")
	session.region = "rotunda"
	session.arrival = Vector2(650, 820)
	game._build_world()
	freeze(game)
	game.resume()
	await speak(game)
	check(button(game, "rescue_accept") != null and game.world.npcs.mentor.visible, "prepared mentor offers a separate next action")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.rescue_action("accept") and game.world.npcs.mentor.visible and "rescue:accepted" not in session.gathered, "failed acceptance cannot relocate participant or advance the episode")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check("rescue:accepted" in session.gathered and not game.world.npcs.mentor.visible, "keyboard acceptance relocates the original participant only after saving")
	await portal(game, Vector2(1700, 650))
	check(session.region == "underhall" and game.world.npcs.mentor.visible and game.world.player.health == 64, "actual new doorway reaches the real participant without healing")
	for point in Rules.COILS.values() + [Vector2(1440, 650), Rules.EXIT, game.world.definition.camp, Vector2(430, 960)]:
		var path: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		var clear := not path.is_empty()
		var previous := Vector2(240, 650)
		for step in path:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "ordinary body reaches actual new controls, participant, exit, rest and resource")
	check(not game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "real live restraint initially blocks the direct shortcut")
	await speak(game)
	check(button(game, "rescue_tools") != null and button(game, "rescue_blood") == null and button(game, "rescue_free") == null, "ordinary player has useful approach without fake nature or premature release")
	await enter()
	check(Rules.method(session.gathered) == "tools", "keyboard chooses the ordinary actual approach")
	session.world_state.minutes = 0
	game.world.player.position = Vector2(940, 430)
	await settle()
	check(game.world.rescue_engine.phase("north") == 0 and game.world.player.health == 64, "visible warning precedes real harm")
	session.world_state.minutes = 1.5
	game.world.player.hurt_time = 0
	await settle()
	check(game.world.rescue_engine.phase("north") == 1 and game.world.player.health == 56 and not game.world.safe_to_rest() and not game.world.can_rescue("manual_north"), "actual live marked strip damages and forbids work/rest/checkpoint while warning alone does not")
	game.show_journal()
	var health: float = game.world.player.health
	await create_timer(0.15).timeout
	check(game.world.player.health == health and session.world_state.minutes == 1.5, "pause does not advance electrical cycle or inflict damage")
	game.resume()
	session.world_state.minutes = 3
	var stamina: float = game.world.player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.rescue_action("manual_north") and game.world.player.stamina == stamina and Rules.cut(session.gathered, "north") == "", "disk failure cannot spend ordinary effort or disconnect a real support")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.set_process(true)
	await key(KEY_E, true)
	await key(KEY_E, false)
	freeze(game)
	check(Rules.cut(session.gathered, "north") == "manual" and game.world.player.stamina == stamina - 18 and game.world.player.health == 56, "actual E in safe period spends18 effort and stores one cut without healing")
	game.world.save_safe()
	check(session.load_saved(), "partial cut reloads from actual JSON")
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
	check(Rules.cut(session.gathered, "north") == "manual" and not game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "partial reload retains exactly one cut and keeps real restraint")
	await portal(game, Vector2(135, 650))
	check(session.region == "rotunda" and not game.world.npcs.mentor.visible, "early retreat does not duplicate the participant at original location")
	await portal(game, Vector2(1700, 650))
	check(session.region == "underhall" and Rules.cut(session.gathered, "north") == "manual", "return retains partial actual work")
	session.world_state.minutes = 0
	game.world.player.position = Vector2(850, 870)
	game.world.player.facing = Vector2.RIGHT
	game.world.player.aim_with_mouse = false
	game.world.player.magic_cooldown = 0
	var mana: float = game.world.player.mana
	game.world.player.set_physics_process(true)
	await key(KEY_F, true)
	await key(KEY_F, false)
	game.world.player.set_physics_process(false)
	check(game.world.player.mana < mana and Rules.cut(session.gathered, "south") == "", "physical F spends real casting mana before projectile arrival rather than instant menu progress")
	await create_timer(0.5).timeout
	check(Rules.cut(session.gathered, "south") == "light" and game.world.navigation.segment_clear(Vector2(700, 650), Vector2(850, 650)), "actual light projectile hits its receiver and removes physical restraint/Nav only after save")
	await speak(game)
	button(game, "rescue_free").pressed.emit()
	check(button(game, "rescue_confirm_free") != null and "rescue:freed" not in session.gathered, "participant is separately asked before actual release")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.rescue_action("free") and "rescue:freed" not in session.gathered, "failed release cannot begin an unsaved escort")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check("rescue:freed" in session.gathered, "keyboard release begins genuine actor movement")
	var position_before: Vector2 = game.world.npcs.mentor.position
	game.world.player.position = Vector2(900, 650)
	game.world.set_process(true)
	game.world.npcs.mentor.set_physics_process(true)
	await create_timer(0.2).timeout
	check(game.world.npcs.mentor.position.distance_to(position_before) < 2 and "rescue:safe" not in session.gathered, "mentor waits when player abandons range rather than teleporting or reporting arrival")
	game.world.player.position = Vector2(1380, 650)
	await walk(game, 1000)
	check(game.world.npcs.mentor.position.x < position_before.x - 250 and game.world.npcs.mentor.position.x > game.world.player.position.x and "rescue:safe" not in session.gathered, "real keyboard guide and actual NPC navigation make partial escort progress")
	game.world.save_safe()
	var saved_position: Vector2 = game.world.npcs.mentor.position
	check(session.load_saved(), "partial escort loads from genuine disk")
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
	check(game.world.npcs.mentor.position.distance_to(saved_position) < 1 and "rescue:freed" in session.gathered and "rescue:safe" not in session.gathered, "load restores actual escort coordinates without fabricating the remaining road")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	await walk(game, 280)
	check(game.world.rescue_engine.pending and game.world.npcs.mentor.visible and "rescue:safe" not in session.gathered, "both actually reach exit but failed write keeps participant and explicit retry")
	game.update_hud()
	check(game.prompt.text == game.tr("RESCUE_RETRY_PROMPT") and game.quest_label.text == game.tr("RESCUE_RETRY"), "unrecorded shared exit exposes matching persistent actual E retry and quest instructions")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.set_process(true)
	await key(KEY_E, true)
	await key(KEY_E, false)
	freeze(game)
	check("rescue:safe" in session.gathered and not game.world.npcs.mentor.visible and not game.world.rescue_engine.pending, "actual E retry records physical joint arrival before relocating participant")
	await portal(game, Vector2(135, 650))
	check(session.region == "rotunda" and game.world.npcs.mentor.visible and game.world.npcs.witness.visible and game.world.npcs.crafter.visible, "real return keeps all three living participants at recovery location")
	await speak(game)
	button(game, "rescue_report").pressed.emit()
	var xp: int = session.xp
	check(button(game, "rescue_confirm_report") != null and Rules.REPORT not in session.opened, "final result is reviewed rather than granted by release or arrival")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.rescue_action("report") and session.xp == xp and game.world.npcs.mentor.visible, "failed final confirmation grants no experience or home relocation")
	DirAccess.remove_absolute("user://save.json.tmp")
	session.inventory.coin = 999
	await enter()
	check(Rules.REPORT in session.opened and session.xp == xp + 120 and session.inventory.coin == 999 and not game.world.npcs.mentor.visible, "confirmed full-wallet result rewards once and moves participant from old recovery place")
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	await portal(game, Vector2(135, 650))
	check(session.region == "crossing" and game.world.npcs.mentor.visible, "actual chain of existing doorways reaches the returned participant at home")
	await speak(game)
	check(button(game, "rescue_rest") != null and button(game, "rescue_keep") == null, "ordinary aftermath has its own real optional conversation")
	await enter()
	check("rescue:rested" in session.gathered and session.xp == xp + 120 and session.load_saved() and "rescue:rested" in session.gathered, "aftermath memory persists without duplicate experience")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and Rules.REPORT in session.opened and session.xp == xp + 120 and game.world.npcs.mentor.visible, "death checkpoint keeps actual completed result, home location and one reward")
	print("Rescue gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
