extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/field_fixture.gd")
const Field = preload("res://scripts/magic/field_rules.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func button(game: Node, label: String) -> Button: return game.screen.find_child(label, true, false) as Button
func settle() -> void:
	await process_frame
	await process_frame
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
	game.world.player.position = game.world.npcs.host.position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	Fixture.ready(session)
	session.region = "haven"
	session.arrival = Vector2(440, 600)
	game._build_world()
	game.resume()
	await physics_frame
	await physics_frame
	var player = game.world.player
	player.set_physics_process(false)
	game.world.set_process(false)
	await speak(game)
	check(button(game, "field_entry") != null, "completed community exposes a separate optional environmental assignment")
	button(game, "field_entry").pressed.emit()
	check(button(game, "field_accept") != null and Field.START not in session.gathered, "reading the offer does not accept the assignment")
	await enter()
	check(Field.START in session.gathered, "keyboard acceptance records the new task")
	check(not game.world.field_action("sluice", "manual"), "remote action cannot repair an authored device")
	check(Regions.camps("haven", session.opened).size() == 1, "extra camp is inactive before actual repair")
	var chest: Dictionary = game.world.definition.chests[0]
	check(not game.world.chests[0].visible and not session.claim_chest(chest, player.position, game.world.player_vitals()), "locked garden stock is hidden and backend cannot claim it")
	for id in game.world.definition.field_sites:
		var path: PackedVector2Array = game.world.navigation.find_path(Vector2(240, 650), game.world.definition.field_sites[id])
		check(not path.is_empty(), "all required device locations have an ordinary authored route")
	player.position = Vector2(850, 380)
	await physics_frame
	await physics_frame
	check(player.test_move(player.transform, Vector2(180, 0)) and not game.world.navigation.segment_clear(Vector2(850, 380), Vector2(1030, 380)), "optional crossing is physically blocked before completion")
	player.mana = 100
	player.health = 54
	player.stamina = 100
	var before: Dictionary = session.snapshot(player.position, game.world.player_vitals())
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.field_action("sluice", "frost") and session.snapshot(player.position, game.world.player_vitals()) == before and player.magic_cooldown == 0, "failed magic write preserves resource progress checkpoint and cooldown")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.resume()
	game.world.interact()
	await settle()
	var scroll: ScrollContainer = button(game, "field_magic").get_parent().get_parent()
	check(scroll.scroll_horizontal == 0, "field action labels cannot horizontally hide the start of device descriptions")
	check(button(game, "field_magic") != null and button(game, "field_manual") != null, "physical device offers magic and ordinary alternatives")
	await enter()
	check(Field.progress(session.gathered, "sluice") == 1 and player.mana == 76 and player.magic_cooldown > 0 and game.world.field_devices.sluice.pulse_time > 0, "actual keyboard cast pays mana and creates partial progress pulse and cooldown")
	check(not game.world.field_action("sluice", "frost") and "field_sluice" not in session.opened, "partial casting cannot bypass cooldown or open crossing early")
	var time_before: float = session.world_state.minutes
	before = session.snapshot(player.position, game.world.player_vitals())
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.field_action("sluice", "manual") and session.snapshot(player.position, game.world.player_vitals()) == before, "failed manual write neither charges time nor stamina")
	DirAccess.remove_absolute("user://save.json.tmp")
	player.shield_time = 5
	player.shield_strength = 10
	player.nature_cooldown = 12
	check(game.world.field_action("sluice", "manual") and player.stamina == 70 and player.health == 54 and player.mana == 76 and session.world_state.minutes == time_before + 10, "mixed manual completion commits real stamina and time without healing")
	check(player.magic_cooldown == 0 and player.shield_time == 0 and player.shield_strength == 0 and player.nature_cooldown == 2, "manual elapsed time expires the previously active spell cooldown")
	await physics_frame
	await physics_frame
	check(not player.test_move(player.transform, Vector2(180, 0)) and game.world.navigation.segment_clear(Vector2(850, 380), Vector2(1030, 380)), "successful work removes the actual obstacle and rebuilds navigation")
	check(session.load_saved() and "field_sluice" in session.opened and player.health == 54, "physical outcome survives disk reload without healing")
	game._build_world()
	game.resume()
	await physics_frame
	await physics_frame
	player = game.world.player
	player.set_physics_process(false)
	game.world.set_process(false)
	check(not player.test_move(player.transform, Vector2(180, 0)), "rebuilt world retains the opened crossing")
	session.xp = 840
	session.skills = {"mending": 2, "aegis": 2}
	player.position = game.world.definition.field_sites.garden
	player.health = 100
	player.mana = 100
	check(game.world.field_action("garden", "heal") and "field_garden" in session.opened and player.mana == 55 and player.health == 100, "ranked external healing finishes actual garden without modifying full-health caster")
	check(game.world.chests[0].visible, "successful garden work reveals the real one-time stock")
	player.position = game.world.chests[0].position
	var prior_items: Dictionary = session.inventory.duplicate()
	game.world.interact()
	check(session.inventory.herb == prior_items.herb + 2 and session.inventory.potion == prior_items.potion + 1 and "field_garden_supplies" in session.opened, "actual stock interaction grants bounded saved supplies")
	game.world.interact()
	check(session.inventory.herb == prior_items.herb + 2, "new stock cannot be harvested repeatedly")
	player.position = game.world.definition.field_sites.relay
	player.magic_cooldown = 0
	player.mana = 100
	player.shield_recharge = 1
	check(not game.world.field_action("relay", "aegis"), "existing protective spell recharge also blocks field use")
	player.shield_recharge = 0
	check(game.world.field_action("relay", "aegis") and player.mana == 64 and player.shield_recharge == 8 and player.shield_strength == 0, "ranked ward strengthens the actual site without giving an unpaid hero shield")
	check(Regions.camps("haven", session.opened).size() == 2 and Field.stage(session.gathered, session.opened) == 2, "new camp becomes active only when all relay work is recorded")
	var lit := false
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/world/living/world_environment.gd"):
			lit = child.camp_lights.has(Vector2(1120, 860)) and is_instance_valid(child.camp_lights[Vector2(1120, 860)])
	check(lit, "new active camp creates an actual environment light")
	player.position = Vector2(1120, 860)
	root.get_node("Sound")._process(0)
	check(root.get_node("Sound").fire_voice.position == Vector2(1120, 860), "camp fire sound follows the nearest active campsite")
	check(game.world.nearby_key() == "REST" and game.world.can_wait(), "new camp exposes actual rest and waiting interaction")
	player.health = 30
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.wait(30) and player.health == 30, "new camp failed rest write cannot heal for free")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(game.world.wait(30) and player.health == 100, "new campsite restores through the existing safe rest transaction")
	await speak(game)
	button(game, "field_entry").pressed.emit()
	var prior_xp: int = session.xp
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not game.world.field_action("report", "report") and session.xp == prior_xp, "failed report grants no experience")
	DirAccess.remove_absolute("user://save.json.tmp")
	await enter()
	check(Field.stage(session.gathered, session.opened) == 3 and session.xp == prior_xp + 80 and not game.world.field_action("report", "report"), "final keyboard report awards exactly one experience reward")
	check(session.load_saved() and Regions.camps("haven", session.opened).size() == 2, "full report stock crossing and new camp persist together")
	print("Field gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
