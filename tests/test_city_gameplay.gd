extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/city_fixture.gd")
const Rules = preload("res://scripts/quests/city_rules.gd")
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
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func site(game: Node, id: String) -> void:
	game.resume()
	game.world.player.position = game.world.definition.city_sites[id]
	game.world.interact()
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
	freeze(game)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	check(Fixture.ready(session), "human commitment fixture has neither other regional report nor optional faction progress")
	session.region = "workshop"
	session.arrival = Vector2(240, 650)
	game._build_world()
	game.resume()
	var approach: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), Vector2(850, 200))
	check(not approach.is_empty() and session.world_state.commission.stage == 0, "ordinary city approach exists before optional bridge work")
	await portal(game, Vector2(850, 200))
	check(session.region == "velshof" and game.world.player.health == 64 and game.world.safe_to_rest(), "actual city portal preserves wounds and provides a safe arrival")
	for point in game.world.definition.city_sites.values() + game.world.definition.herbs + [game.world.definition.camp, game.world.definition.crafter, game.world.definition.archivist, Vector2(500, 820), Vector2(1190, 820), Vector2(780, 680), Vector2(930, 680), Vector2(980, 780)]:
		var route: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), point)
		var previous := Vector2(240, 650)
		var clear := not route.is_empty()
		for step in route:
			clear = clear and game.world.navigation.segment_clear(previous, step)
			previous = step
		check(clear, "ordinary body can reach actual work/NPC/night/result/resource positions without crossing authored buildings")
	check(not game.world.chests[0].visible, "shared supplies remain hidden before final agreement")
	await speak(game, "crafter")
	check(button(game, "city_accept") != null and button(game, "city_sign_crafter") == null, "first conversation offers separate acceptance without manufactured consent")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.city_action("accept") and "city:accepted" not in session.gathered, "failed acceptance cannot start an unrecorded negotiation")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	await speak(game, "crafter")
	button(game, "city_hear_crafter").pressed.emit()
	await speak(game, "archivist")
	button(game, "city_hear_archivist").pressed.emit()
	await site(game, "board")
	await enter()
	check(Rules.draft(session.gathered) == "shared" and game.world.city_objects.board.plan == "shared" and not game.world.can_city("sign_crafter"), "keyboard draft updates actual board but cannot remotely sign for a party")
	await speak(game, "crafter")
	check(game.screen.find_child("city_counteroffer", true, false) != null and not game.world.can_city("sign_crafter"), "artisan responds to insufficient guarantee with an actual counteroffer")
	button(game, "city_supply").pressed.emit()
	check(session.inventory.potion == 1 and button(game, "city_confirm_supply") != null, "personal aid is reviewed before handing over a real potion")
	await enter()
	check(session.inventory.potion == 0 and "city:supply" in session.gathered, "confirmed aid consumes exactly one existing item")
	await speak(game, "crafter")
	button(game, "city_sign_crafter").pressed.emit()
	check(Rules.SIGNATURES[0] in session.gathered and Rules.SIGNATURES[1] not in session.gathered, "artisan cannot give the archivist's independent consent")
	await site(game, "archive")
	var player = game.world.player
	player.magic_cooldown = 5
	player.shield_time = 4
	player.shield_strength = 30
	player.shield_recharge = 7
	var before_time: float = session.world_state.minutes
	var before_mana: float = player.mana
	button(game, "city_copy").pressed.emit()
	check(session.world_state.minutes == before_time + 10 and player.stamina == 80 and player.health == 64 and player.mana == before_mana and player.magic_cooldown == 0 and player.shield_strength == 0 and player.shield_recharge == 0, "actual copy spends effort/time and expires combat timers without healing or magic regeneration")
	await speak(game, "archivist")
	button(game, "city_sign_archivist").pressed.emit()
	check(Rules.stage(session.gathered, session.opened) == 2 and game.world.city_objects.board.signatures == 2, "independent second consent appears on the physical board")
	await site(game, "board")
	button(game, "city_draft_release").pressed.emit()
	check(button(game, "city_confirm_draft_release") != null and Rules.stage(session.gathered, session.opened) == 2, "revision explicitly reviews withdrawal of both signatures before changing terms")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.city_action("draft_release") and Rules.draft(session.gathered) == "shared" and Rules.stage(session.gathered, session.opened) == 2, "failed revision leaves the old draft and both actual signatures intact")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Rules.draft(session.gathered) == "release" and game.world.city_objects.board.signatures == 0 and "city:copy" in session.gathered and "city:supply" in session.gathered, "actual revision clears both consents while preserving prior help and public copy")
	check(session.load_saved() and Rules.draft(session.gathered) == "release" and Rules.stage(session.gathered, session.opened) == 1, "revised unsigned draft reloads from real JSON without resurrecting stale consent")
	game._build_world()
	game.resume()
	await settle()
	freeze(game)
	check(game.world.city_objects.board.plan == "release" and game.world.city_objects.board.signatures == 0, "rebuilding restores the revised visible record")
	await portal(game, Vector2(135, 650))
	check(session.region == "workshop" and "city:copy" in session.gathered, "leaving city through actual portal preserves negotiation guarantees")
	await portal(game, Vector2(850, 200))
	check(session.region == "velshof" and Rules.draft(session.gathered) == "release" and game.world.city_objects.board.signatures == 0, "returning preserves revised draft and withdrawn signatures")
	await speak(game, "crafter")
	check(not game.world.can_city("sign_crafter") and game.screen.find_child("city_counteroffer", true, false) != null, "new terms require real workshop work despite earlier supply")
	await site(game, "press")
	player = game.world.player
	player.magic_cooldown = 4
	var stamina: float = player.stamina
	before_time = session.world_state.minutes
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.city_action("work") and player.stamina == stamina and session.world_state.minutes == before_time and player.magic_cooldown == 4 and not game.world.city_objects.press.worked, "failed work changes neither time resource timer nor visible press")
	DirAccess.remove_absolute("user://save.json.tmp")
	button(game, "city_work").pressed.emit()
	check(player.stamina == stamina - 20 and session.world_state.minutes == before_time + 20 and player.magic_cooldown == 0 and game.world.city_objects.press.worked, "actual common work fulfills revised guarantee with real cost and environment result")
	for role in ["crafter", "archivist"]:
		await speak(game, role)
		button(game, "city_sign_" + role).pressed.emit()
	await site(game, "board")
	var xp: int = session.xp
	session.inventory.coin = 999
	await enter()
	check(button(game, "city_confirm_seal") != null and session.xp == xp and Rules.REPORT not in session.opened, "final document review cannot commit on opening")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.city_action("seal") and session.xp == xp and not game.world.chests[0].visible, "failed final write cannot grant outcome experience or reveal shared supplies")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(session.xp == xp + 100 and session.inventory.coin == 999 and "city:outcome:release" in session.gathered and game.world.city_objects.board.completed and game.world.chests[0].visible, "confirmed agreement grants one lasting full-wallet-safe result and actual visible supplies")
	check(not game.world.city_action("seal") and not game.world.city_action("draft_shared"), "final agreement cannot be farmed or silently changed")
	game.world.player.position = game.world.chests[0].position
	game.world.interact()
	var stock: int = session.inventory.potion
	game.world.interact()
	check(stock == 1 and session.inventory.potion == 1 and "courtyard_supplies" in session.opened, "post-agreement supply is an actual one-time pickup")
	game.world.player.health = 1
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(999)
	await enter()
	check(game.world.player.health == 100 and session.xp == xp + 100 and Rules.stage(session.gathered, session.opened) == 3 and "courtyard_supplies" in session.opened, "death checkpoint retains completed agreement and one-time stock without duplicating reward")
	print("City gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
