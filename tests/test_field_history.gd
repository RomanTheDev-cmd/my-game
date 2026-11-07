extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/field_fixture.gd")
const Field = preload("res://scripts/magic/field_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	for kind in ["vampire", "werewolf"]:
		Fixture.ready(session, kind)
		session.region = "haven"
		session.arrival = Vector2(440, 600)
		session.xp = 840
		session.skills = {"frost": 2, "aegis": 2}
		game._build_world()
		game.resume()
		await physics_frame
		await physics_frame
		var player = game.world.player
		player.set_physics_process(false)
		game.world.set_process(false)
		player.position = game.world.npcs.host.position
		check(game.world.field_action("accept", "accept"), "each supernatural path can accept the same ordinary assignment")
		player.position = game.world.definition.field_sites.sluice
		player.shift_form("battle" if kind == "vampire" else "wolf")
		check(not game.world.field_action("sluice", "manual") and not game.world.field_action("sluice", "frost"), "real temporary shapes cannot perform precise work or ordinary field casting")
		player.shift_form()
		player.position = game.world.definition.field_sites.garden
		player.health = 52
		player.mana = 66
		player.stamina = 100
		var reserve: float = session.nature.blood if kind == "vampire" else session.nature.resolve
		check(kind != "vampire" or not game.world.field_action("garden", "heal"), "vampire cannot bypass healing restriction by choosing a different target")
		check(game.world.field_action("garden", "manual") and player.health == 52 and player.mana == 66 and player.stamina == 70, "ordinary alternative works without healing or mana gain for both natures")
		check(is_equal_approx(session.nature.blood, reserve - 0.4) if kind == "vampire" else is_equal_approx(session.nature.resolve, minf(100, reserve + 8)), "manual elapsed time updates the correct nature reserve")
		if kind == "vampire":
			var vitals: Dictionary = game.world.player_vitals()
			for event in ["cure_start", "release_water", "release_garden", "cure_finish"]:
				check(session.nature_event(event, player.position, vitals), "separate return remains valid during environmental work")
			player.mana = session.vitals.mana
			check(session.nature.kind == "human" and Field.progress(session.gathered, "garden") == 3, "returned human retains completed work and prior membership")
		player.position = game.world.definition.field_sites.sluice
		player.mana = 100
		check(game.world.field_action("sluice", "frost") and "field_sluice" in session.opened, "remaining ranked magic keeps working after path-specific earlier choices")
		player.position = game.world.definition.field_sites.relay
		player.magic_cooldown = 0
		check(game.world.field_action("relay", "aegis") and "field_relay" in session.opened, "remaining defensive work is reachable for both histories")
		player.position = game.world.npcs.host.position
		check(game.world.field_action("report", "report") and session.load_saved() and Field.stage(session.gathered, session.opened) == 3, "each path records and reloads complete real environmental work")
	Fixture.ready(session)
	session.region = "haven"
	session.arrival = Vector2(850, 380)
	game._build_world()
	game.resume()
	await physics_frame
	await physics_frame
	var player = game.world.player
	player.set_physics_process(false)
	game.world.set_process(false)
	player.position = game.world.npcs.host.position
	game.world.field_action("accept", "accept")
	player.position = Vector2(850, 380)
	player.mana = 100
	game.world.field_action("sluice", "frost")
	check(session.load_saved() and Field.progress(session.gathered, "sluice") == 1 and "field_sluice" not in session.opened, "partial progress reloads without inventing a completed crossing")
	game._build_world()
	game.resume()
	await physics_frame
	await physics_frame
	player = game.world.player
	player.set_physics_process(false)
	game.world.set_process(false)
	check(player.test_move(player.transform, Vector2(180, 0)), "partial loaded work restores actual closed collision")
	check(game.world.field_action("sluice", "manual") and "field_sluice" in session.opened, "partially loaded work can be completed by a different method")
	player.health = 0
	check(not game.world.field_action("garden", "manual"), "dead actor cannot spend or complete an environmental action")
	print("Field history checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
