extends SceneTree
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const FieldFixture = preload("res://tests/support/field_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const TestExit = preload("res://tests/support/test_exit.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var nature_screen = load("res://scripts/ui/nature_screen.gd")
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
	game.new_game()
	session_for_skills.quest = 3
	session_for_skills.xp = 120
	session_for_skills.region = "workshop"
	session_for_skills.arrival = Vector2(930, 600)
	session_for_skills.inventory = {"coin": 25, "herb": 4, "potion": 1}
	session_for_skills.world_state.commission = {"stage": 4, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "craft", "settlement": ""}
	game._build_world()
	game.resume()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/courtyard.png")
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/courtyard_map.png")
	game.resume()
	game.world.player.position = game.world.definition.commission_sites.wheel
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/commission_choice.png")
	if not game.world.commission_action("restore_shared"):
		printerr("ERROR: capture fixture cannot resolve action")
		await TestExit.finish(self, 1)
		return
	game.resume()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/courtyard_after.png")
	game.world.player.position = game.world.npcs.warden.position
	game.world.interact()
	game.screen.find_child("warden_shop", true, false).pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/faction_shop.png")
	game.show_journal()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/journal_factions.png")
	game.resume()
	game.world.player.position = game.world.npcs.tender.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/faction_service.png")
	session_for_skills.region = "crossing"
	session_for_skills.arrival = Vector2(520, 490)
	session_for_skills.inventory.coin = 984
	game._build_world()
	game.resume()
	game.show_commission("keeper")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/reward_capacity.png")
	session_for_skills.world_state.commission = {"stage": 6, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "craft", "settlement": "shared"}
	session_for_skills.gathered = ["waterworks:charter", "waterworks:north", "waterworks:south", "waterworks:awakened"]
	session_for_skills.region = "waterworks"
	session_for_skills.arrival = Vector2(1190, 650)
	session_for_skills.inventory.coin = 25
	game._build_world()
	game.resume()
	game.world.boss.set_physics_process(false)
	game.world.player.set_physics_process(false)
	for i in 20: await process_frame
	for kind in ["sweep", "charge", "pulse"]:
		var boss = game.world.boss
		boss.phase = 2 if kind == "pulse" else 1
		boss.health = 190 if kind == "pulse" else 420
		boss.attack_spec = boss.Rules.attack(boss.phase, {"sweep": 0, "charge": 1, "pulse": 1}[kind])
		boss.state = "windup"
		boss.timer = 0.7
		boss.attack_origin = boss.position
		boss.attack_direction = Vector2.LEFT
		boss.queue_redraw()
		game.update_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/boss_" + kind + ".png")
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/waterworks_map.png")
	game.resume()
	game.world.player.position = Vector2(820, 650)
	game.show_trial("altar")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/trial_dialog.png")
	game.resume()
	game.world.boss.awaiting_record = true
	game.world.boss.state = "yielded"
	game.world.boss.health = 0
	game.world.boss.queue_redraw()
	game.world.player.position = game.world.boss.position - Vector2(40, 0)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/boss_retry_record.png")
	NatureFixture.completed_episode(session_for_skills)
	session_for_skills.gathered.append_array(["nature:water", "nature:garden"])
	session_for_skills.nature.stage = 2
	session_for_skills.region = "lake"
	session_for_skills.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	nature_screen.show_page(game, "wayfarer", "vampire")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/nature_consent.png")
	NatureFixture.vampire(session_for_skills)
	session_for_skills.region = "waterworks"
	session_for_skills.arrival = Vector2(1200, 650)
	game._build_world()
	game.resume()
	game.world.player.shift_form()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/nature_form.png")
	game.show_nature()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/nature_status.png")
	game.screen.find_child("nature_shift", true, false).grab_focus()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/nature_status_focus.png")
	game.world.player.shift_form()
	session_for_skills.region = "crossing"
	session_for_skills.arrival = Vector2(520, 490)
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.keeper.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_vampire.png")
	game.screen.find_child("dialogue_honest", true, false).pressed.emit()
	session_for_skills.nature = {"kind": "human", "form": "human", "blood": 100.0, "landing": {}, "resolve": 100.0, "stage": 4, "history": ["vampire"], "cure": 3, "gift": "scar"}
	session_for_skills.gathered.append_array(["nature:release_water", "nature:release_garden"])
	game.world.player._update_nature_visuals()
	game.update_hud()
	game.show_dialog("keeper")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_returned.png")
	NatureFixture.completed_episode(session_for_skills)
	session_for_skills.gathered.append_array(["nature:water", "nature:garden"])
	session_for_skills.nature.stage = 3
	session_for_skills.nature.gift = "oath"
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.keeper.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_oath.png")
	var pack_screen = load("res://scripts/ui/pack_screen.gd")
	PackFixture.prepared(session_for_skills)
	session_for_skills.region = "thicket"
	session_for_skills.arrival = Vector2(450, 600)
	game._build_world()
	game.resume()
	pack_screen.show_page(game, "tracker", "accept")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/pack_consent.png")
	PackFixture.wolf(session_for_skills)
	session_for_skills.region = "thicket"
	session_for_skills.arrival = Vector2(340, 500)
	game._build_world()
	game.resume()
	game.world.player.shift_form()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/wolf_tracking.png")
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/thicket_map.png")
	PackFixture.wolf(session_for_skills, true)
	session_for_skills.region = "thicket"
	session_for_skills.arrival = Vector2(1120, 650)
	session_for_skills.world_state.minutes = 5760
	game._build_world()
	game.resume()
	game.world.player.shift_form("hybrid")
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hybrid_moon.png")
	game.show_nature()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/pack_status.png")
	game.resume()
	game.world.player.shift_form()
	game.world.player.position = game.world.npcs.tracker.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_werewolf.png")
	game.screen.find_child("dialogue_pack_word", true, false).pressed.emit()
	session_for_skills.nature = {"kind": "human", "form": "human", "blood": 100.0, "landing": {}, "resolve": 100.0, "stage": 4, "history": ["werewolf"], "cure": 3, "gift": "wild_scar"}
	session_for_skills.gathered.append_array(["pack:return_started", "pack:release_den", "pack:release_word", "pack:returned"])
	game.world.player._update_nature_visuals()
	game.update_hud()
	game.show_dialog("tracker")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_wild_returned.png")
	NatureFixture.vampire(session_for_skills)
	session_for_skills.region = "lake"
	session_for_skills.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.wayfarer.position
	game.show_nature("wayfarer")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/flight_training.png")
	game.resume()
	game.world.nature_action("learn_bat")
	session_for_skills.region = "waterworks"
	session_for_skills.arrival = Vector2(1640, 430)
	game._build_world()
	game.resume()
	for i in 3: await physics_frame
	game.world.player.shift_form("bat")
	game.world.player.position = Vector2(1640, 345)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/bat_chamber.png")
	game.world.interact()
	game.world.player.shift_form()
	session_for_skills.nature.gift = "blood_mist"
	session_for_skills.gathered.append("flight:mist")
	session_for_skills.nature.blood = 100
	session_for_skills.arrival = Vector2(740, 1011)
	game._build_world()
	game.resume()
	for i in 3: await physics_frame
	game.world.player.shift_form("mist")
	game.world.player.position = Vector2(790, 1011)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mist_passage.png")
	game.show_nature()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/flight_status.png")
	game.resume()
	game.world.player.shift_form()
	session_for_skills.region = "lake"
	session_for_skills.arrival = Vector2(480, 620)
	game._build_world()
	game.resume()
	for i in 3: await physics_frame
	game.world.player.position = game.world.npcs.wayfarer.position
	game.world.player.shift_form("mist")
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_mist.png")
	NatureFixture.vampire(session_for_skills)
	session_for_skills.nature.gift = "blood_mist"
	session_for_skills.gathered.append_array(["flight:bat", "flight:mist"])
	session_for_skills.opened.append("waterworks_flight")
	session_for_skills.region = "lake"
	session_for_skills.arrival = Vector2(760, 650)
	game._build_world()
	game.resume()
	for i in 3: await physics_frame
	game.world.player.shift_form("mist")
	var watcher = load("res://scripts/actors/enemy.gd").new()
	watcher.position = Vector2(910, 650)
	watcher.target = game.world.player
	game.world.add_child(watcher)
	watcher.set_physics_process(false)
	watcher._physics_process(0.016)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mist_unnoticed.png")
	game.world.player.shift_form()
	watcher._physics_process(0.016)
	game.world.player.shift_form("mist")
	watcher._physics_process(0.1)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mist_alert.png")
	NatureFixture.completed_episode(session_for_skills)
	session_for_skills.region = "crossing"
	session_for_skills.arrival = Vector2(520, 490)
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.keeper.position
	var community_page = load("res://scripts/ui/community_screen.gd")
	community_page.show_page(game, "keeper", "join_watch")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/community_consent.png")
	game.resume()
	game.world.community_action("join_watch")
	session_for_skills.region = "haven"
	session_for_skills.arrival = Vector2(520, 650)
	game._build_world()
	game.resume()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/haven_before.png")
	game.show_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/haven_map.png")
	game.resume()
	for site in ["supply", "route"]:
		game.world.player.position = game.world.definition.community_sites[site]
		game.world.community_action("seen_" + site)
	game.world.player.position = game.world.npcs.host.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/community_help.png")
	game.resume()
	game.world.community_action("aid_craft")
	game.world.interact()
	community_page.show_page(game, "host", "report_share")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/community_outcome.png")
	game.resume()
	game.world.community_action("report_share")
	game.world.player.position = Vector2(520, 650)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/haven_after.png")
	game.show_equipment()
	for i in 3: await process_frame
	game.screen.find_child("equip_relay_cloak", true, false).grab_focus()
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/community_equipment.png")
	NatureFixture.vampire(session_for_skills)
	session_for_skills.region = "haven"
	session_for_skills.arrival = Vector2(440, 600)
	game._build_world()
	game.resume()
	game.world.player.position = game.world.npcs.host.position
	game.world.interact()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dialogue_host_vampire.png")
	NatureFixture.completed_episode(session_for_skills)
	session_for_skills.region = "haven"
	session_for_skills.arrival = Vector2(520, 650)
	session_for_skills.xp = 840
	session_for_skills.skills = {"mending": 1, "frost": 1, "aegis": 1}
	game._build_world()
	game.resume()
	game.show_skills()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/spell_training.png")
	game.resume()
	for id in ["mending", "frost", "aegis"]: game.world.learn_skill(id)
	game.show_spells()
	for i in 3: await process_frame
	game.screen.find_child("cast_frost", true, false).grab_focus()
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/learned_frost_book.png")
	game.screen.find_child("cast_aegis", true, false).grab_focus()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/learned_aegis_book.png")
	game.resume()
	game.world.player.health = 30
	game.world.player.mana = 100
	game.world.player.cast_magic("heal")
	game.world.player.magic_cooldown = 0
	game.world.player.cast_magic("aegis")
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/learned_ward.png")
	FieldFixture.ready(session_for_skills)
	session_for_skills.region = "haven"
	session_for_skills.arrival = Vector2(440, 600)
	session_for_skills.xp = 840
	session_for_skills.skills = {"mending": 2, "aegis": 2}
	game._build_world()
	game.resume()
	for i in 3: await physics_frame
	var field_page = load("res://scripts/ui/field_screen.gd")
	game.world.player.position = game.world.npcs.host.position
	field_page.show_page(game, "host")
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_offer.png")
	game.resume()
	game.world.field_action("accept", "accept")
	game.world.player.position = game.world.definition.field_sites.sluice
	game.world.interact()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_device.png")
	game.resume()
	game.world.field_action("sluice", "frost")
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_partial.png")
	game.world.field_action("sluice", "manual")
	game.world.player.position = Vector2(980, 380)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_crossing.png")
	game.world.player.position = game.world.definition.field_sites.garden
	game.world.player.mana = 100
	game.world.field_action("garden", "heal")
	for i in 20: await process_frame
	while game.world.player.magic_cooldown > 0: await process_frame
	game.world.player.position = game.world.definition.field_sites.relay
	if not game.world.field_action("relay", "aegis"):
		printerr("CAPTURE_FIELD_RELAY_FAILED")
		await TestExit.finish(self, 1)
		return
	game.world.player.position = Vector2(1120, 860)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_camp.png")
	game.world.player.position = Vector2(1210, 860)
	game.show_map()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_map.png")
	game.resume()
	game.world.player.position = game.world.npcs.host.position
	game.world.field_action("report", "report")
	field_page.show_page(game, "host")
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/field_report.png")
	load("res://tests/support/campaign_fixture.gd").ready(session_for_skills)
	session_for_skills.region = "workshop"
	session_for_skills.arrival = Vector2(780, 700)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	await shot("campaign_offer")
	game.world.campaign_action("greet")
	game.world.campaign_action("accept")
	session_for_skills.region = "terrace"
	session_for_skills.arrival = Vector2(1040, 650)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	await shot("campaign_terrace")
	game.show_map()
	await shot("campaign_map")
	game.resume()
	game.world.player.position = game.world.npcs.witness.position
	game.world.interact()
	await shot("campaign_witness")
	game.world.campaign_action("hear")
	game.resume()
	game.world.player.position = game.world.definition.story_sites.marks
	game.world.interact()
	await shot("campaign_observation")
	game.world.campaign_action("inspect")
	game.resume()
	game.world.player.position = game.world.definition.story_sites.control
	game.world.interact()
	game.screen.find_child("story_turn_c", true, false).pressed.emit()
	await shot("campaign_controls")
	game.resume()
	await shot("campaign_device")
	var forest_fixture = load("res://tests/support/forest_fixture.gd")
	var forest_rules = load("res://scripts/quests/forest_rules.gd")
	forest_fixture.ready(session_for_skills)
	session_for_skills.region = "woodroad"
	session_for_skills.arrival = Vector2(430, 620)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.world.npcs.roadkeeper.set_physics_process(false)
	game.world.player.position = game.world.npcs.roadkeeper.position
	game.world.interact()
	await shot("forest_offer")
	game.world.forest_action("accept")
	game.resume()
	game.world.forest_action("aid_brief")
	game.world.player.position = Vector2(850, 620)
	await shot("forest_road", game.get_viewport().get_camera_2d())
	game.show_map()
	await shot("forest_map")
	game.resume()
	game.world.player.position = Vector2(1455, 645)
	await shot("forest_gate_closed", game.get_viewport().get_camera_2d())
	for i in 3:
		game.world.player.position = forest_rules.POINTS[i]
		game.world.npcs.roadkeeper.position = forest_rules.POINTS[i] - Vector2(70, 0)
		game.world.interact()
		if i == 0: await shot("forest_work")
		if not game.world.forest_action("work"):
			printerr("CAPTURE_FOREST_WORK_FAILED")
			await TestExit.finish(self, 1)
			return
		game.resume()
	game.world.player.position = Vector2(1455, 645)
	await shot("forest_gate_open", game.get_viewport().get_camera_2d())
	game.world.player.position = game.world.npcs.roadkeeper.position
	game.world.interact()
	game.screen.find_child("forest_watch", true, false).pressed.emit()
	await shot("forest_outcome_review")
	game.world.forest_action("watch")
	game.resume()
	game.world.interact()
	await shot("forest_outcome")
	forest_fixture.ready(session_for_skills, "vampire", true, "provision", "blood")
	session_for_skills.region = "woodroad"
	session_for_skills.arrival = Vector2(430, 620)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.world.npcs.roadkeeper.set_physics_process(false)
	game.world.player.position = game.world.npcs.roadkeeper.position
	game.world.interact()
	await shot("forest_nature_dialogue")
	game.screen.find_child("dialogue_honest", true, false).pressed.emit()
	game.screen.find_child("dialogue_continue", true, false).pressed.emit()
	await shot("forest_prior_history")
	game.world.forest_action("accept")
	game.resume()
	game.world.interact()
	game.screen.find_child("dialogue_continue", true, false).pressed.emit()
	game.screen.find_child("forest_aid_blood", true, false).pressed.emit()
	await shot("forest_blood_review")
	var city_fixture = load("res://tests/support/city_fixture.gd")
	city_fixture.ready(session_for_skills)
	session_for_skills.region = "velshof"
	session_for_skills.arrival = Vector2(850, 650)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	await shot("city_courtyard", game.get_viewport().get_camera_2d())
	game.show_map()
	await shot("city_map")
	game.resume()
	game.world.player.position = game.world.npcs.crafter.position
	game.world.interact()
	await shot("city_offer")
	game.world.city_action("accept")
	game.world.city_action("hear_crafter")
	game.resume()
	game.world.player.position = game.world.npcs.archivist.position
	game.world.interact()
	await shot("city_archivist")
	game.world.city_action("hear_archivist")
	game.resume()
	game.world.player.position = game.world.definition.city_sites.board
	game.world.interact()
	await shot("city_draft")
	game.world.city_action("draft_shared")
	game.resume()
	game.world.player.position = game.world.npcs.crafter.position
	game.world.interact()
	await shot("city_counteroffer")
	game.resume()
	game.world.player.position = game.world.definition.city_sites.press
	game.world.interact()
	await shot("city_work")
	game.world.city_action("work")
	game.resume()
	game.world.player.position = game.world.definition.city_sites.archive
	game.world.interact()
	game.world.city_action("copy")
	for role in ["crafter", "archivist"]:
		game.resume()
		game.world.player.position = game.world.npcs[role].position
		game.world.city_action("sign_" + role)
	game.resume()
	game.world.player.position = game.world.definition.city_sites.board
	game.world.interact()
	await shot("city_signed")
	game.screen.find_child("city_draft_release", true, false).pressed.emit()
	await shot("city_revision_review")
	game.world.city_action("draft_release")
	game.resume()
	await shot("city_revised_board", game.get_viewport().get_camera_2d())
	for role in ["crafter", "archivist"]:
		game.world.player.position = game.world.npcs[role].position
		game.world.city_action("sign_" + role)
	game.world.player.position = game.world.definition.city_sites.board
	game.world.interact()
	game.screen.find_child("city_seal", true, false).pressed.emit()
	await shot("city_seal_review")
	if not game.world.city_action("seal"):
		printerr("CAPTURE_CITY_SEAL_FAILED")
		await TestExit.finish(self, 1)
		return
	game.resume()
	await shot("city_final_board", game.get_viewport().get_camera_2d())
	game.world.interact()
	await shot("city_outcome")
	var junction_fixture = load("res://tests/support/junction_fixture.gd")
	junction_fixture.ready(session_for_skills)
	session_for_skills.region = "workshop"
	session_for_skills.arrival = Vector2(780, 700)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	await shot("joint_invitation")
	if not game.world.junction_action("accept"):
		printerr("CAPTURE_JOINT_INVITE_FAILED")
		await TestExit.finish(self, 1)
		return
	session_for_skills.region = "rotunda"
	session_for_skills.arrival = Vector2(1000, 650)
	game._build_world()
	game.resume()
	for i in 3: await process_frame
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	await shot("joint_rotunda", game.get_viewport().get_camera_2d())
	game.show_map()
	await shot("joint_map")
	game.resume()
	game.world.player.position = game.world.npcs.steward.position
	game.world.interact()
	await shot("joint_participant")
	game.world.junction_action("hear")
	game.resume()
	game.world.player.position = game.world.definition.junction_sites.table
	game.world.interact()
	await shot("joint_records")
	game.world.junction_action("map")
	game.resume()
	game.world.player.position = game.world.definition.junction_sites.console
	game.world.interact()
	await shot("joint_isolation")
	game.world.junction_action("manual")
	game.resume()
	Input.action_press("interact")
	game.world.interact()
	await create_timer(1.2).timeout
	await shot("joint_measure", game.get_viewport().get_camera_2d())
	Input.action_release("interact")
	for i in 3: await process_frame
	DirAccess.make_dir_absolute("user://save.json.tmp")
	Input.action_press("interact")
	game.world.interact()
	await create_timer(3.15).timeout
	Input.action_release("interact")
	await shot("joint_retry", game.get_viewport().get_camera_2d())
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.interact()
	if "junction:proof" not in session_for_skills.gathered:
		printerr("CAPTURE_JOINT_PROOF_FAILED")
		await TestExit.finish(self, 1)
		return
	await shot("joint_proved", game.get_viewport().get_camera_2d())
	game.world.player.position = game.world.npcs.steward.position
	game.world.junction_action("explain")
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	game.screen.find_child("joint_public", true, false).pressed.emit()
	await shot("joint_review")
	game.world.junction_action("public")
	game.resume()
	await shot("joint_result", game.get_viewport().get_camera_2d())
	var preparation_fixture = load("res://tests/support/preparation_fixture.gd")
	if not preparation_fixture.configured(session):
		printerr("CAPTURE_PREPARATION_FIXTURE_FAILED")
		await TestExit.finish(self, 1)
		return
	session.region = "rotunda"
	session.arrival = Vector2(1580, 650)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	var prep_frames := 0
	while not game.world.can_rehearse() and prep_frames < 1100:
		await physics_frame
		prep_frames += 1
	if not game.world.can_rehearse():
		printerr("CAPTURE_PREPARATION_POSTS_FAILED")
		await TestExit.finish(self, 1)
		return
	game.world.player.position = Vector2(1050, 430)
	await shot("preparation_support", game.get_viewport().get_camera_2d())
	game.show_map()
	await shot("preparation_map")
	game.resume()
	game.world.player.position = game.world.definition.junction_sites.table
	game.world.interact()
	await shot("preparation_plan")
	game.resume()
	game.world.player.position = Vector2(1580, 650)
	game.world.interact()
	await shot("preparation_gate")
	game.screen.find_child("prep_start", true, false).pressed.emit()
	game.world.player.set_physics_process(true)
	Input.action_press("move_left")
	while game.world.player.position.x > 1350: await physics_frame
	Input.action_release("move_left")
	game.world.player.set_physics_process(false)
	await shot("preparation_walk", game.get_viewport().get_camera_2d())
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.player.set_physics_process(true)
	Input.action_press("move_left")
	while game.world.player.position.x > 525: await physics_frame
	Input.action_release("move_left")
	game.world.player.set_physics_process(false)
	if not game.world.preparation_route.pending:
		printerr("CAPTURE_PREPARATION_RETRY_FAILED")
		await TestExit.finish(self, 1)
		return
	await shot("preparation_retry", game.get_viewport().get_camera_2d())
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.preparation_route.activate()
	if "prep:tested" not in session.gathered:
		printerr("CAPTURE_PREPARATION_PROOF_FAILED")
		await TestExit.finish(self, 1)
		return
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	game.screen.find_child("prep_report", true, false).pressed.emit()
	await shot("preparation_ready_review")
	game.screen.find_child("prep_confirm_report", true, false).pressed.emit()
	game.show_journal()
	await shot("preparation_journal")
	game.resume()
	await shot("preparation_result", game.get_viewport().get_camera_2d())
	var rescue_fixture = load("res://tests/support/rescue_fixture.gd")
	if not rescue_fixture.ready(session):
		printerr("CAPTURE_RESCUE_FIXTURE_FAILED")
		await TestExit.finish(self, 1)
		return
	session.region = "rotunda"
	session.arrival = Vector2(650, 820)
	game._build_world()
	game.resume()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.world.interact()
	await shot("rescue_invitation")
	game.world.rescue_action("accept")
	session.region = "underhall"
	session.arrival = Vector2(1440, 650)
	game._build_world()
	game.resume()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	for npc in game.world.npcs.values(): npc.set_physics_process(false)
	game.world.interact()
	await shot("rescue_approaches")
	game.world.rescue_action("tools")
	game.resume()
	game.world.player.position = Vector2(940, 400)
	session.world_state.minutes = 0
	await shot("rescue_warning", game.get_viewport().get_camera_2d())
	session.world_state.minutes = 1.5
	await shot("rescue_pulse", game.get_viewport().get_camera_2d())
	game.show_map()
	await shot("rescue_map")
	game.resume()
	session.world_state.minutes = 3
	game.world.rescue_action("manual_north")
	game.world.player.position = Vector2(850, 870)
	game.world.player.facing = Vector2.RIGHT
	game.world.player.aim_with_mouse = false
	game.world.player.magic_cooldown = 0
	session.world_state.minutes = 0
	game.world.player.cast_magic("light")
	await create_timer(0.6).timeout
	if not load("res://scripts/quests/rescue_rules.gd").disconnected(session.gathered):
		printerr("CAPTURE_RESCUE_CUT_FAILED")
		await TestExit.finish(self, 1)
		return
	await shot("rescue_opened", game.get_viewport().get_camera_2d())
	game.world.player.position = game.world.npcs.mentor.position
	game.world.interact()
	game.screen.find_child("rescue_free", true, false).pressed.emit()
	await shot("rescue_release_review")
	game.world.rescue_action("free")
	game.resume()
	game.world.player.position = Vector2(1380, 650)
	game.world.set_process(true)
	game.world.npcs.mentor.set_physics_process(true)
	game.world.player.set_physics_process(true)
	Input.action_press("block")
	Input.action_press("move_left")
	var rescue_frames := 0
	while game.world.player.position.x > 1000 and rescue_frames < 1800:
		await physics_frame
		rescue_frames += 1
	Input.action_release("move_left")
	game.world.player.set_physics_process(false)
	game.world.npcs.mentor.set_physics_process(false)
	await shot("rescue_guide", game.get_viewport().get_camera_2d())
	DirAccess.make_dir_absolute("user://save.json.tmp")
	game.world.player.set_physics_process(true)
	game.world.npcs.mentor.set_physics_process(true)
	Input.action_press("move_left")
	while game.world.player.position.x > 280 and rescue_frames < 1800:
		await physics_frame
		rescue_frames += 1
	Input.action_release("move_left")
	Input.action_release("block")
	game.world.player.set_physics_process(false)
	game.world.npcs.mentor.set_physics_process(false)
	game.world.set_process(false)
	if not game.world.rescue_engine.pending:
		printerr("CAPTURE_RESCUE_ARRIVAL_FAILED")
		await TestExit.finish(self, 1)
		return
	await shot("rescue_retry", game.get_viewport().get_camera_2d())
	DirAccess.remove_absolute("user://save.json.tmp")
	game.world.rescue_engine.retry()
	session.region = "rotunda"
	session.arrival = Vector2(650, 820)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	game.world.interact()
	game.screen.find_child("rescue_report", true, false).pressed.emit()
	await shot("rescue_report_review")
	game.world.rescue_action("report")
	session.region = "crossing"
	session.arrival = Vector2(600, 600)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	game.world.interact()
	await shot("rescue_aftermath")
	game.world.rescue_action("rest")
	game.resume()
	await shot("rescue_home", game.get_viewport().get_camera_2d())
	var accord_fixture = load("res://tests/support/accord_fixture.gd")
	if not accord_fixture.ready(session):
		printerr("CAPTURE_ACCORD_FIXTURE_FAILED")
		await TestExit.finish(self, 1)
		return
	session.region = "crossing"
	session.arrival = Vector2(600, 600)
	game._build_world()
	game.world.set_process(false)
	game.world.player.set_physics_process(false)
	game.resume()
	game.world.interact()
	await shot("accord_identity")
	game.screen.find_child("accord_affirm", true, false).pressed.emit()
	await shot("accord_identity_review")
	game.screen.find_child("accord_confirm_affirm", true, false).pressed.emit()
	for accord_choice in ["renewal", "release", "community"]:
		if not accord_fixture.accepted(session):
			printerr("CAPTURE_ACCORD_ACCEPTED_FAILED")
			await TestExit.finish(self, 1)
			return
		session.region = "rotunda"
		session.arrival = Vector2(620, 650)
		game._build_world()
		game.world.set_process(false)
		game.world.player.set_physics_process(false)
		game.resume()
		game.world.interact()
		await shot("accord_options_" + accord_choice)
		game.screen.find_child("accord_" + accord_choice, true, false).pressed.emit()
		await shot("accord_review_" + accord_choice)
		game.screen.find_child("accord_confirm_" + accord_choice, true, false).pressed.emit()
		await shot("accord_epilogue_" + accord_choice)
		game.resume()
		session.region = "velshof" if accord_choice == "release" else "woodroad"
		session.arrival = Vector2(780, 995) if accord_choice == "release" else Vector2(1190, 620)
		if accord_choice == "renewal": session.world_state.minutes = 1400
		game._build_world()
		game.world.set_process(false)
		game.world.player.set_physics_process(false)
		game.resume()
		await shot("accord_world_" + accord_choice, game.get_viewport().get_camera_2d())
		game.show_map()
		await shot("accord_map_" + accord_choice)
		game.resume()
	game.show_journal()
	await shot("accord_journal")
	print("CAPTURE_OK")
	await TestExit.finish(self)
func shot(file: String, camera: Camera2D = null) -> void:
	if camera != null:
		camera.reset_smoothing()
		camera.force_update_scroll()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + file + ".png")
