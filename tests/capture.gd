extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")

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
	game.resume()
	session_for_skills.region = "crossing"
	session_for_skills.arrival = Vector2(430, 490)
	session_for_skills.world_state.minutes = 1380
	game._build_world()
	game.resume()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/night.png")
	session_for_skills.world_state.minutes = 1440
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rain.png")
	session_for_skills.world_state.minutes = 1860
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/fog.png")
	game.world.player.position = game.world.definition.camp
	game.show_wait()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/wait.png")
	game.resume()
	game.world.player.restore()
	game.show_spells()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/spellbook.png")
	game.screen.find_child("cast_aegis", true, false).grab_focus()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/spellbook_focus.png")
	game.resume()
	game.world.player.cast_magic("aegis")
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/protection.png")
	print("CAPTURE_OK")
	await TestExit.finish(self)
