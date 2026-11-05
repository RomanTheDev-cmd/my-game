extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/title.png")
	game.new_game()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/gameplay.png")
	var session := root.get_node("Session")
	session.region = "lake"
	session.arrival = Vector2(1100, 535)
	game._build_world()
	game.resume()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/lake.png")
	session.region = "crossing"
	session.arrival = Vector2(410, 490)
	game._build_world()
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/map.png")
	game.show_dialog()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialog.png")
	var session_for_skills := root.get_node("Session")
	session_for_skills.award_xp(120)
	game.show_skills()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/skills.png")
	session_for_skills.inventory = {"herb": 3, "coin": 12, "potion": 1}
	game.show_journal()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/journal.png")
	game.show_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/settings.png")
	game.resume()
	session_for_skills.inventory["coin"] = 50
	game.world.player.position = Vector2(235, 500)
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/shop.png")
	load("res://scripts/ui/equipment_screen.gd").shop(game, true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/shop_sell.png")
	session_for_skills.gear_owned.append_array(["iron_sword", "chain", "iron_shield"])
	session_for_skills.equip_item("iron_sword")
	session_for_skills.equip_item("chain")
	session_for_skills.equip_item("iron_shield")
	game.show_equipment()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/equipment.png")
	session_for_skills.region = "ruins"
	session_for_skills.arrival = Vector2(960, 700)
	game._build_world()
	game.resume()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ruins.png")
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ruins_map.png")
	game.show_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/pause.png")
	print("CAPTURE_OK")
	quit()
