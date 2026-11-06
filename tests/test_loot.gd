extends SceneTree
const Loot = preload("res://scripts/items/loot_rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var chest := {"id": "test", "requires": ["guard"], "items": {"coin": 5}, "gear": ["chain"]}
	check(Loot.claim(chest, {}, [], [], []).is_empty(), "guard condition prevents premature chest reward")
	check(Loot.claim(chest, {"coin": 999}, [], [], ["guard"]).is_empty(), "full purse does not consume chest")
	var reward := Loot.claim(chest, {"coin": 2}, [], [], ["guard"])
	check(reward.get("inventory", {}).get("coin") == 7 and "chain" in reward.get("owned", []), "chest grants its defined items and equipment")
	check(Loot.claim(chest, reward.inventory, reward.owned, reward.opened, ["guard"]).is_empty(), "opened chest cannot be farmed")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	game.world.player.position = Vector2(1800, 500)
	game.world.interact()
	await process_frame
	game.world.player.position = Vector2(1800, 650)
	game.world.interact()
	await process_frame
	for point in [Vector2(290, 870), Vector2(1000, 1020), Vector2(1510, 450)]:
		var route: PackedVector2Array = game.world.navigation.find_path(game.world.player.position, point)
		check(not route.is_empty(), "authored interior keeps checkpoint and rewards physically reachable")
	check(session.region == "ruins" and game.world.definition.location == "LOCATION_RUINS", "second exit enters third authored location")
	game.world.player.position = Vector2(1510, 450)
	game.world.interact()
	check(session.opened.is_empty(), "guarded reward remains locked in real world")
	for child in game.world.get_children():
		if child is CharacterBody2D and child != game.world.player and child.has_method("receive_damage"):
			child.receive_damage(999, Vector2.RIGHT)
	await process_frame
	check(session.xp == 105 and session.inventory.get("coin") == 17, "different enemies award their own experience and currency once")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.interact()
	check(session.opened.is_empty() and session.inventory.coin == 17 and "chain" not in session.gear_owned, "failed chest save preserves closed cache and all prior rewards")
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	check("ruins_cache" in session.opened and "chain" in session.gear_owned and session.inventory.coin == 35, "actual guarded chest transfers and saves reward")
	game.world.interact()
	check(session.inventory.coin == 35, "repeated interaction cannot duplicate currency")
	game.world.player.position = Vector2(1000, 1020)
	game.world.interact()
	check(session.inventory.coin == 41 and session.inventory.get("potion") == 2, "exploration cache provides consumable supplies")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	check(session.region == "lake", "third location has a working return route")
	game.world.player.position = Vector2(1800, 650)
	game.world.interact()
	await process_frame
	check(session.region == "ruins" and session.opened.size() == 2, "return visit retains both opened caches")
	check(session.load_saved(), "third-location state reloads from disk")
	game._build_world()
	check(session.region == "ruins" and "chain" in session.gear_owned and session.inventory.coin == 41, "third location and rewards survive reload")
	var arrow = load("res://scripts/combat/hostile_arrow.gd").new()
	arrow.position = game.world.player.position + Vector2(100, 0)
	game.world.add_child(arrow)
	check(not game.world.safe_to_rest(), "active hostile projectile blocks unsafe checkpoint writes")
	arrow.queue_free()
	await process_frame
	check(game.world.safe_to_rest(), "cleared encounter becomes safe after projectile disappears")
	print("Exploration loot checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
