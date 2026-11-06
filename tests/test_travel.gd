extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
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
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var session := root.get_node("Session")
	var regions = load("res://scripts/world/region_catalog.gd")
	check(not session.travel("unknown", Vector2(100, 100)), "unknown destination cannot replace session")
	check(session.region == "crossing", "failed travel retains current region")
	game.world.player.position = Vector2(650, 670)
	game.world.interact()
	check(session.inventory.herb == 1, "first location resource collected")
	game.world.player.health = 60
	game.world.player.mana = 45
	game.world.player.position = Vector2(1800, 500)
	game.world.interact()
	await process_frame
	check(session.region == "lake", "interacting with sign enters second location")
	check(game.world.player.health == 60 and game.world.player.mana < 46, "travel preserves wounds and magic instead of granting free healing")
	check(game.world.definition.location == "LOCATION_LAKE", "second location actually instantiated")
	check(game.location_label.text == "Озерная терраса", "HUD reflects new location")
	check(session.checkpoint.region == "lake", "travel records destination checkpoint")
	check(not game.world.keeper.visible and not game.world.lantern.visible, "first location NPC and objective not duplicated")
	game.world.player.position = Vector2(600, 650)
	game.world.interact()
	check(session.inventory.herb == 2, "second location resource has independent identity")
	game.world.player.position = Vector2(135, 650)
	game.world.interact()
	await process_frame
	check(session.region == "crossing", "return sign returns to original location")
	check(not game.world.herbs[0].visible, "first location resource remains gathered after round trip")
	check(session.load_saved(), "travel checkpoint loads from disk")
	game._build_world()
	check(session.region == "crossing", "saved location restored")
	game.world.player.position = Vector2(1800, 500)
	game.world.interact()
	await process_frame
	check(not game.world.herbs[0].visible, "second location resource remains gathered on revisit")
	var checkpoint: Dictionary = session.checkpoint.duplicate(true)
	game.world.player.position = Vector2(800, 900)
	game.world.player.receive_damage(200)
	check(game.current_screen == "death", "death after travel still opens recovery")
	for child in game.screen.get_children():
		if child is Button:
			child.pressed.emit()
			break
	check(session.region == "lake" and game.world.player.position == Vector2(checkpoint.position[0], checkpoint.position[1]), "death restores correct region and arrival")
	check(regions.herb_id("lake", Vector2(650, 670)) != regions.herb_id("crossing", Vector2(650, 670)), "resource IDs cannot collide across locations")
	# A blocked save must not partially move the player or change the checkpoint.
	var old_region: String = session.region
	var old_checkpoint: Dictionary = session.checkpoint.duplicate(true)
	var saved_path := "user://save.json.tmp"
	DirAccess.make_dir_absolute(saved_path)
	check(not session.travel("crossing", Vector2(1730, 500)), "write failure blocks transition")
	check(session.region == old_region and session.checkpoint == old_checkpoint, "failed transition retains complete previous state")
	DirAccess.remove_absolute(saved_path)
	game.world.player.position = Vector2(900, 1000)
	for child in game.world.get_children():
		if child.get_script() == load("res://scripts/actors/enemy.gd"):
			child.position = Vector2(1150, 1000)
			child.home = child.position
	game.world._checkpoint_before_encounter()
	check(session.checkpoint.position[0] == 900 and session.checkpoint.position[1] == 1000, "approaching encounter creates a safe pre-battle checkpoint")
	print("Travel checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
