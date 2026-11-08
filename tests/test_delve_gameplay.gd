extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/delve_rules.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
var checks := 0
var failures := 0
var notices: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func label(game: Node, id: String) -> String:
	var found: Label = game.screen.find_child(id, true, false)
	return found.text if found != null else ""
func settle() -> void:
	await process_frame
	await process_frame
func freeze(game: Node) -> void:
	game.world.set_process(false)
	for child in game.world.get_children():
		if child is CharacterBody2D: child.set_physics_process(false)
func key_e(game: Node) -> void:
	game.resume()
	game.world.set_process(true)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame
	await settle()
	freeze(game)
func build(game: Node, session: Node, region: String, arrival: Vector2) -> void:
	session.region = region
	session.arrival = arrival
	game._build_world()
	freeze(game)
	game.resume()
	await settle()
func defeat_near(game: Node, point: Vector2, radius: float) -> void:
	for child in game.world.get_children():
		if child is CharacterBody2D and child != game.world.player and child.get("id") != null and child.position.distance_to(point) < radius: child.receive_damage(9999, Vector2.RIGHT)
	await settle()
func defeat_keystone_guards(game: Node) -> void:
	var room: Rect2 = game.world.DelveGenerator.cell_rect(game.world.definition.keystone)
	await defeat_near(game, room.get_center(), 200)
	# Safety ignores walls, so threats in neighbouring rooms are cleared as a player would.
	await defeat_near(game, room.get_center(), 450)
func keystone_chest(game: Node) -> Sprite2D:
	for chest in game.world.chests:
		if chest.get_meta("definition").id.begins_with("delve_keystone_"): return chest
	return null
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	session.notice.connect(func(key): notices.append(key))
	session.world_state["delve_seed"] = 424242
	await build(game, session, "ruins", Vector2(1620, 1000))
	for child in game.world.get_children():
		if child is CharacterBody2D and child.get("id") != null and child.health > 0: child.receive_damage(9999, Vector2.RIGHT)
	await settle()
	game.world.player.position = Vector2(1690, 1000)
	check(game.world.nearby_key() == "TO_HOLLOW", "the guardhouse has a real way down")
	await key_e(game)
	check(session.region == "hollow_1" and game.world.definition.location == "LOCATION_HOLLOW_1" and game.world.player.position == Vector2(250, 680), "real E descends to the first generated depth")
	check(session.checkpoint.region == "hollow_1" and session.Store.validate(session.checkpoint), "arrival in a generated hollow is a valid saved checkpoint")
	var layout: Dictionary = game.world.definition
	# The surveyors' note differs for the ordinary path.
	game.world.player.position = layout.note + Vector2(0, 25)
	game.world.interact()
	check(label(game, "delve_note") == game.tr("DELVE_NOTE_TEXT_1") and label(game, "delve_sense") == game.tr("DELVE_SENSE_HUMAN") and label(game, "delve_progress") == game.tr("DELVE_PROGRESS") % [0, 3], "entrance note, ordinary reading and progress")
	game.resume()
	# Sealed stairs, then the keystone.
	game.world.player.position = layout.stairs + Vector2(0, -30)
	check(game.world.nearby_key() == "DELVE_STAIRS", "stairs are sealed before the keystone")
	notices.clear()
	game.world.interact()
	check("DELVE_STAIRS_SEALED" in notices and session.region == "hollow_1", "sealed stairs explain instead of descending")
	check(not session.travel("hollow_2", game.world.player.position, game.world.player_vitals()), "backend also refuses the sealed depth")
	var chest := keystone_chest(game)
	game.world.player.position = chest.position + Vector2(0, 25)
	check(not game.world.safe_to_rest(), "the keystone is guarded")
	var xp: int = session.xp
	await defeat_keystone_guards(game)
	check(session.xp > xp and game.world.safe_to_rest(), "real guard defeats give experience and make the room safe")
	var coins: int = session.inventory.get("coin", 0)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.interact()
	check(Rules.keystone(1) not in session.opened and session.inventory.get("coin", 0) == coins and not game.world.delve_stairs.open, "failed write keeps the keystone and seal")
	DirAccess.remove_absolute("user://save.json.tmp")
	notices.clear()
	game.world.interact()
	check(Rules.keystone(1) in session.opened and session.inventory.coin == coins + 12 and game.world.delve_stairs.open and "DELVE_STAIRS_OPEN" in notices, "keystone opens once, gives its supplies and unseals the stairs")
	game.world.interact()
	check(session.inventory.coin == coins + 12, "keystone cannot be claimed twice")
	await defeat_near(game, game.world.definition.stairs, 450)
	# A hidden cache found by walking close.
	var hidden: Sprite2D
	for item in game.world.chests:
		if item.get_meta("definition").get("hidden", false): hidden = item
	for child in game.world.get_children():
		if child is CharacterBody2D and child != game.world.player and child.get("id") != null and child.position.distance_to(hidden.position) < 400: child.receive_damage(9999, Vector2.RIGHT)
	await settle()
	game.world.player.position = hidden.position + Vector2(25, 0)
	game.world._update_tracking()
	coins = session.inventory.coin
	game.world.interact()
	check(hidden.get_meta("definition").id in session.opened and session.inventory.coin == coins + 6, "hidden cache gives its small one-time supplies")
	# Herb in the hollow: real pickup, later saved with the generated ID.
	var herb: Sprite2D = game.world.herbs[0]
	game.world.player.position = herb.position
	game.world.interact()
	check(herb.get_meta("id") in session.gathered and herb.get_meta("id").begins_with("hollow_1:"), "hollow herb uses the region namespace")
	check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved() and Rules.keystone(1) in session.opened and herb.get_meta("id") in session.gathered, "JSON save/load keeps keystone, cache and herb against the regenerated layout")
	game._build_world()
	freeze(game)
	game.resume()
	check(game.world.delve_stairs.open and not game.world.herbs[0].visible, "rebuilt hollow keeps open stairs and gathered herb")
	# Down the stairs, then back to the surface.
	game.world.player.position = game.world.definition.stairs + Vector2(0, -30)
	check(game.world.nearby_key() == "DELVE_DESCEND", "open stairs offer a descent")
	await key_e(game)
	check(session.region == "hollow_2" and game.world.definition.depth == 2 and game.world.definition.location == "LOCATION_HOLLOW_2", "real E leads to the second depth")
	check(game.world.definition.walls != layout.walls, "second depth has its own layout")
	game.world.player.position = Vector2(175, 680)
	await key_e(game)
	check(session.region == "ruins" and game.world.player.position == Vector2(1620, 1000), "the hollow exit returns to the guardhouse surface")
	# Death inside a hollow keeps recorded progress.
	await build(game, session, "hollow_2", Vector2(250, 680))
	check(session.save_at(Vector2(250, 680), game.world.player_vitals()), "checkpoint at the second depth")
	var defeated: Array = session.defeated.duplicate()
	game.world.player.hurt_time = 0
	game.world.player.receive_damage(9999)
	check(game.current_screen == "death", "death in a hollow opens recovery")
	for child in game.screen.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await settle()
	check(session.region == "hollow_2" and Rules.keystone(1) in session.opened and session.defeated == defeated, "restore keeps the hollow and earlier progress")
	# The deepest keystone and its armour.
	session.opened.append("delve_keystone_2")
	await build(game, session, "hollow_3", Vector2(250, 680))
	check(not game.world.definition.has("stairs") and game.world.delve_stairs == null, "the deepest hollow has no further stairs")
	chest = keystone_chest(game)
	await defeat_keystone_guards(game)
	game.world.player.position = chest.position + Vector2(0, 25)
	notices.clear()
	game.world.interact()
	check(Rules.keystone(3) in session.opened and "deep_mail" in session.gear_owned and "DELVE_COMPLETE" in notices, "last keystone gives the unique armour once")
	check(session.equip_item("deep_mail") and not session.trade_item("deep_mail", true, game.world.player.position, game.world.player_vitals()), "armour can be worn and not sold")
	check(session.save_at(game.world.player.position, game.world.player_vitals()) and session.load_saved() and session.equipped.armor == "deep_mail", "complete descent survives JSON")
	game.show_journal()
	check(label(game, "delve_progress") == game.tr("DELVE_PROGRESS") % [3, 3], "journal shows the full descent")
	game.resume()
	# Other paths read the note differently; temporary shapes cannot read it.
	for kind in ["vampire", "werewolf"]:
		if kind == "vampire": NatureFixture.vampire(session)
		else: PackFixture.wolf(session)
		await build(game, session, "hollow_1", Vector2(250, 680))
		game.world.player.position = game.world.definition.note + Vector2(0, 25)
		game.world.interact()
		check(label(game, "delve_sense") == game.tr("DELVE_SENSE_" + kind.to_upper()), "%s reads the entrance in its own way" % kind)
		game.resume()
		check(game.world.player.shift_form(), "%s takes a temporary shape" % kind)
		game.world.interact()
		check(label(game, "delve_sense") == game.tr("DELVE_SENSE_FORM"), "%s in a temporary shape cannot read the letters" % kind)
		game.resume()
	print("Delve gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
