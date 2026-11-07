extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Community = preload("res://scripts/factions/community_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
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
func speak(game: Node, role: String) -> void:
	game.resume()
	game.world.player.position = game.world.npcs[role].position
	game.world.interact()
	if button(game, "dialogue_continue") != null: button(game, "dialogue_continue").pressed.emit()
func portal(game: Node, point: Vector2) -> void:
	game.resume()
	game.world.player.position = point
	game.world.interact()
	await settle()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	for id in ["watch", "circle", "pack"]:
		if id == "watch": Fixture.completed_episode(session)
		elif id == "circle": Fixture.vampire(session)
		else: PackFixture.wolf(session)
		var role: String = Community.HOSTS[id]
		session.region = {"watch": "crossing", "circle": "lake", "pack": "thicket"}[id]
		game._build_world()
		await speak(game, role)
		check(button(game, "community_entry") != null, "each path exposes its own community through the appropriate NPC")
		button(game, "community_entry").pressed.emit()
		button(game, "community_join_" + id).pressed.emit()
		check(Community.guild(session.gathered) == "" and button(game, "community_confirm_join_" + id) != null, "membership requires separate informed confirmation")
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.community_action("join_" + id) and Community.guild(session.gathered) == "", "failed membership write cannot grant membership")
		DirAccess.remove_absolute("user://save.json.tmp")
		await enter()
		check(Community.guild(session.gathered) == id and not game.world.community_action("seen_supply"), "keyboard confirmation joins once and remote observation is rejected")
		if id == "watch": await portal(game, Vector2(1800, 500))
		if id == "pack":
			await portal(game, Vector2(135, 650))
			await portal(game, Vector2(135, 650))
		await portal(game, Vector2(135, 1000))
		check(session.region == "haven", "community task is reached by actual connected portals")
		for site in ["supply", "route"]:
			game.world.player.position = game.world.definition.community_sites[site]
			game.world.interact()
			check(button(game, "community_seen_" + site) != null, "authored observation has its own real action")
			if site == "route":
				DirAccess.make_dir_absolute("user://save.json.tmp")
				check(not game.world.community_action("seen_route") and "community:seen:supply" in session.gathered and "community:seen:route" not in session.gathered, "failed second observation keeps earlier evidence without inventing progress")
				DirAccess.remove_absolute("user://save.json.tmp")
			await enter()
		check(Community.stage(session.gathered) == 2, "two physical observations prepare the actual help")
		var method: String = {"watch": "craft", "circle": "blood", "pack": "track"}[id]
		if id == "pack":
			game.world.player.shift_form()
			game.world.player.position = game.world.definition.community_sites.search
			check(not game.world.community_action("aid_track"), "hostile nearby archer prevents safe tracking assistance")
			for child in game.world.get_children():
				if child.get("id") == "haven_archer": child.receive_damage(1000, Vector2.ZERO)
			await settle()
			game.world.interact()
		else:
			await speak(game, "host")
		if id == "watch":
			await settle()
			var craft: Button = button(game, "community_aid_craft")
			var scroll: ScrollContainer = craft.get_parent().get_parent()
			check(scroll.get_global_rect().grow(1).encloses(craft.get_global_rect()), "initial keyboard focus scrolls the actual aid action into view")
		if id == "circle":
			button(game, "community_aid_blood").pressed.emit()
			check(button(game, "community_confirm_aid_blood") != null and Community.stage(session.gathered) == 2, "blood aid first explains consent and actual costs")
		var prior_items: Dictionary = session.inventory.duplicate()
		var reserve: float = session.nature.resolve if id == "pack" else session.nature.blood
		var mana: float = game.world.player.mana
		var prior_nature: Dictionary = session.nature.duplicate(true)
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.community_action("aid_" + method) and session.nature == prior_nature and game.world.player.mana == mana and session.inventory == prior_items and Community.stage(session.gathered) == 2, "failed help write consumes no inventory and records no help")
		DirAccess.remove_absolute("user://save.json.tmp")
		if id == "circle": await enter()
		else: button(game, "community_aid_" + method).pressed.emit()
		check(Community.stage(session.gathered) == 3 and not game.world.community_action("aid_" + method), "actual help records one method and cannot farm repeat rewards")
		if id == "watch": check(session.inventory.herb == prior_items.herb - 2 and session.inventory.potion == prior_items.potion - 1, "human help consumes the advertised supplies")
		elif id == "circle": check(absf(session.nature.blood - (reserve - 20)) < 0.5 and absf(game.world.player.mana - (mana - 15)) < 0.5 and session.inventory == prior_items, "blood help changes actual player resources without charging craft supplies")
		else:
			check(absf(session.nature.resolve - (reserve - 20)) < 0.5 and session.inventory == prior_items, "tracking help changes actual wolf resolve without craft supplies")
			game.world.player.shift_form()
		await speak(game, "host")
		var event := "report_provision" if id == "circle" else "report_share"
		var prior_xp: int = session.xp
		var prior_coins: int = session.inventory.coin
		button(game, "community_" + event).pressed.emit()
		check(Community.stage(session.gathered) == 3 and session.xp == prior_xp, "reviewing reward consequences grants nothing")
		DirAccess.make_dir_absolute("user://save.json.tmp")
		check(not game.world.community_action(event) and "relay_cloak" not in session.gear_owned, "failed report write grants no unique gear or completion")
		DirAccess.remove_absolute("user://save.json.tmp")
		await enter()
		check(Community.stage(session.gathered) == 4 and session.xp == prior_xp + 60 and "relay_cloak" in session.gear_owned, "keyboard report commits single experience reward gear and completion")
		check(session.inventory.coin == prior_coins + (12 if id == "circle" else 0) and not game.world.community_action(event), "reward choice changes actual money once")
		check(session.load_saved() and Community.guild(session.gathered) == id and "community:aid:" + method in session.gathered, "full membership method and reward reload from actual disk")
		game.show_equipment()
		button(game, "equip_relay_cloak").pressed.emit()
		check(session.equipped.armor == "relay_cloak" and is_equal_approx(session.Gear.reduction(session.equipped), 0.18), "unique community reward is a usable piece of equipment")
	print("Community gameplay checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
