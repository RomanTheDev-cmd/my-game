extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/junction_fixture.gd")
const Rules = preload("res://scripts/quests/junction_rules.gd")
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
func enter() -> void:
	await settle()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event)
		await settle()
func interact_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = pressed
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
	freeze(game)
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "three ordinary regional routes create a real valid common-node save")
	session.region = "workshop"
	session.arrival = Vector2(780, 700)
	game._build_world()
	freeze(game)
	game.resume()
	await speak(game, "mentor")
	check(button(game, "joint_accept") != null and game.world.npcs.mentor.visible, "real mentor conversation recognizes three reports and offers next shared action")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.junction_action("accept") and "junction:accepted" not in session.gathered and game.world.npcs.mentor.visible, "failed invitation cannot relocate mentor or start uncommitted progress")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check("junction:accepted" in session.gathered and not game.world.npcs.mentor.visible, "keyboard invitation moves important character out of old scene only after saving")
	check(not game.world.navigation.find_path(game.world.player.position, Vector2(850, 1120)).is_empty(), "ordinary route reaches the new actual doorway")
	await portal(game, Vector2(850, 1120))
	check(session.region == "rotunda" and game.world.npcs.mentor.visible and game.world.player.health == 64, "actual transition restores mentor at new scene without healing")
	for point in game.world.definition.junction_sites.values() + [game.world.definition.mentor, game.world.definition.steward, Vector2(980, 820), game.world.definition.camp, Vector2(500, 1020)]:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		var clear := not route.is_empty()
		var previous := Vector2(240, 650)
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "ordinary body reaches actual common objects/NPC/night/rest/resource coordinates")
	await speak(game, "steward")
	button(game, "joint_hear").pressed.emit()
	game.world.player.position = game.world.definition.junction_sites.table
	game.world.interact()
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 2 and game.world.junction_objects.table.records == 3, "actual table connects three genuine records after conversation")
	game.world.player.position = game.world.definition.junction_sites.console
	game.world.interact()
	var stamina: float = game.world.player.stamina
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.junction_action("manual") and game.world.player.stamina == stamina and not game.world.junction_objects.console.isolated, "failed preparation cannot spend effort or change physical isolation")
	DirAccess.remove_absolute("user://save.json.tmp")
	button(game, "joint_manual").pressed.emit()
	check(game.world.player.stamina == stamina - 20 and game.world.junction_objects.console.isolated and game.world.player.shield_strength == 0 and not game.world.junction_action("prove"), "manual isolation persists without free hero shield or instant unmeasured proof")
	var console = game.world.junction_objects.console
	game.world.set_process(true)
	await interact_key(true)
	await create_timer(0.25).timeout
	check(console.active and console.progress > 0 and console.progress < 3 and "junction:proof" not in session.gathered, "actual physical E starts a real-time measurement rather than a menu or immediate flag")
	var paused_progress: float = console.progress
	game.show_journal()
	await create_timer(0.2).timeout
	check(is_equal_approx(console.progress, paused_progress), "paused UI cannot advance measurement while game is stopped")
	await interact_key(false)
	await interact_key(true)
	check(not console.active and console.progress == 0 and "junction:proof" not in session.gathered, "release and repress while paused cannot carry an earlier partial hold into a new uninterrupted measurement")
	game.resume()
	await interact_key(false)
	check(not console.active and console.progress == 0 and console.isolated, "releasing actual E resets only transient measure and retains paid preparation")
	await interact_key(true)
	await create_timer(0.2).timeout
	game.world.player.position += Vector2(100, 0)
	await settle()
	check(not console.active and console.progress == 0 and "junction:proof" not in session.gathered, "walking away cancels unsafe measurement without manufacturing progress")
	await interact_key(false)
	game.world.player.position = game.world.definition.junction_sites.console
	await interact_key(true)
	await create_timer(0.1).timeout
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.position = game.world.player.position + Vector2(100, 0)
	enemy.target = game.world.player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	await settle()
	check(not console.active and console.progress == 0 and console.isolated, "real nearby enemy threat interrupts only the current measurement")
	enemy.queue_free()
	await settle()
	await interact_key(false)
	game.world.player.set_physics_process(true)
	await interact_key(true)
	await create_timer(0.1).timeout
	var attack := InputEventKey.new()
	attack.keycode = KEY_J
	attack.physical_keycode = KEY_J
	attack.pressed = true
	Input.parse_input_event(attack)
	await physics_frame
	await physics_frame
	attack.pressed = false
	Input.parse_input_event(attack)
	await settle()
	check(not console.active and console.progress == 0 and console.isolated, "actual keyboard attack interrupts held-input measurement without removing preparation")
	await interact_key(false)
	await create_timer(0.25).timeout
	game.world.player.set_physics_process(false)
	await interact_key(true)
	await create_timer(0.2).timeout
	check(session.save_at(game.world.player.position, game.world.player_vitals()), "saving a partial measurement stores ordinary persistent preparation safely")
	check(session.load_saved(), "partial-measure save loads from actual disk")
	game._build_world()
	freeze(game)
	game.resume()
	await interact_key(false)
	console = game.world.junction_objects.console
	check(console.isolated and not console.active and not console.pending and console.progress == 0 and "junction:proof" not in session.gathered, "rebuilding restores paid isolation but never treats unsaved timer as evidence")
	await portal(game, Vector2(135, 650))
	check(session.region == "workshop" and not game.world.npcs.mentor.visible, "leaving keeps mentor at the new actual location")
	await portal(game, Vector2(850, 1120))
	check(session.region == "rotunda" and game.world.npcs.mentor.visible and game.world.junction_objects.console.isolated, "returning retains location and usable preparation")
	game.world.player.position = game.world.definition.junction_sites.console
	console = game.world.junction_objects.console
	game.world.set_process(true)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	await interact_key(true)
	await create_timer(3.15).timeout
	await interact_key(false)
	check(console.pending and not console.active and console.progress == 3 and "junction:proof" not in session.gathered and not console.proved, "real full hold with failed disk write leaves an explicit retry without visible completed evidence")
	game.update_hud()
	check(game.prompt.text == game.tr("JOINT_RETRY_PROMPT") and game.prompt.text.begins_with("E"), "pending record exposes a persistent actual E retry prompt at the console")
	DirAccess.remove_absolute("user://save.json.tmp")
	var cost: float = game.world.player.stamina
	await interact_key(true)
	await interact_key(false)
	check("junction:proof" in session.gathered and console.proved and not console.pending and game.world.player.stamina == cost, "actual E retries recorded measurement once without duplicate preparation price")
	freeze(game)
	await speak(game, "mentor")
	check(button(game, "joint_public") == null and not game.world.can_junction("public"), "instrument proof cannot bypass actual post-measure explanation")
	await speak(game, "steward")
	button(game, "joint_explain").pressed.emit()
	check("junction:explained" in session.gathered, "participant explanation commits after real proof")
	await speak(game, "mentor")
	var xp: int = session.xp
	session.inventory.coin = 999
	button(game, "joint_public").pressed.emit()
	check(button(game, "joint_confirm_public") != null and Rules.REPORT not in session.opened and session.xp == xp, "shared information choice is reviewed before committing consequences")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.junction_action("public") and session.xp == xp and Rules.REPORT not in session.opened, "failed final choice grants no reward or permanent result")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.stage(session.gathered, session.opened) == 4 and session.xp == xp + 80 and session.inventory.coin == 999 and game.world.junction_objects.console.outcome == "public", "keyboard choice gives one visible full-wallet-safe result")
	check(not game.world.junction_action("private") and session.load_saved() and Rules.stage(session.gathered, session.opened) == 4, "other choice cannot be farmed and completed evidence reloads together")
	game._build_world()
	freeze(game)
	game.resume()
	check(game.world.junction_objects.console.proved and game.world.npcs.mentor.visible, "rebuilt scene retains true evidence and living important character")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and Rules.stage(session.gathered, session.opened) == 4 and session.xp == xp + 80, "death checkpoint preserves complete common result without duplicate reward")
	print("Junction gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
