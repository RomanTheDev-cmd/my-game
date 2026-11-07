extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
const Fixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Skills = preload("res://scripts/progression/skill_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func button(game: Node, name: String) -> Button: return game.screen.find_child(name, true, false) as Button
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Skills.learn(40, {}, "mending").get("mending") == 1, "earned point can learn a healing specialization")
	var session := root.get_node("Session")
	session.fresh()
	session.xp = 40
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.learn_skill("light") and session.skills.is_empty(), "failed learning write neither grants a rank nor spends its point")
	DirAccess.remove_absolute("user://save.json.tmp")
	var heal := Magic.cast("heal", 20, 100, 0, {"mending": 2})
	check(heal.health == 90 and heal.mana == 55, "healing specialization has independent literal health and mana effects")
	check(Magic.cast("heal", 90, 44, 0, {"mending": 2}).is_empty() and Magic.cast("heal", 100, 100, 0, {"mending": 2}).is_empty(), "new price and full-health rules prevent failed spending")
	var frost := Magic.profile("frost", {"frost": 2})
	check(frost.damage == 24 and frost.cost == 28 and frost.slow_duration == 6 and is_equal_approx(frost.slow_multiplier, 0.45), "frost increases damage duration and slowing with its real price")
	var ward := Magic.cast("aegis", 100, 100, 0, {"aegis": 2, "ward": 2})
	check(ward.shield == 74 and ward.duration == 8 and ward.recharge == 8 and ward.mana == 64, "new shield mastery combines with existing defensive skill once")
	check(Magic.profile("light", {"light": 3}).damage == 42 and Magic.profile("aegis", {"ward": 2}).shield == 50, "old learned light and ward powers remain intact")
	for invalid in [-1, 3, NAN, INF, "2"]:
		check(Magic.profile("frost", {"frost": invalid}).is_empty(), "corrupt mastery rank cannot create a spell profile")
	check(not Skills.valid(40, {"mending": 2}) and not Skills.valid(100000, {"frost": 3}), "earned points and new rank cap are validated on save")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	session.xp = 840
	game.world.player.health = 20
	game.show_skills()
	await process_frame
	await process_frame
	var skill_scroll: ScrollContainer = button(game, "learn_mending").get_parent().get_parent()
	check(skill_scroll.scroll_horizontal == 0, "skill focus never horizontally clips the beginnings of descriptions")
	check(button(game, "learn_mending") != null and not button(game, "learn_mending").disabled, "skills UI exposes actual available training")
	var old_checkpoint: Dictionary = session.checkpoint.duplicate(true)
	DirAccess.make_dir_absolute("user://save.json.tmp")
	button(game, "learn_mending").pressed.emit()
	check(session.skills.is_empty() and session.checkpoint == old_checkpoint and Skills.points(session.xp, session.skills) == 6, "UI failure keeps earned points rank and checkpoint unchanged")
	DirAccess.remove_absolute("user://save.json.tmp")
	for id in ["mending", "mending", "frost", "aegis", "aegis"]:
		button(game, "learn_" + id).pressed.emit()
	check(session.skills == {"mending": 2, "frost": 1, "aegis": 2} and Skills.points(session.xp, session.skills) == 1, "actual buttons spend five earned points across three specializations")
	var saved: Dictionary = session.Store.load_game()
	check(session.load_saved() and session.skills.mending == 2 and session.skills.frost == 1 and session.skills.aegis == 2 and saved.vitals.health == 20 and session.Store.VERSION == 9, "training stores current wounds with ranks in compatible v9")
	game.show_spells()
	check(button(game, "cast_heal").text.contains("45") and button(game, "cast_frost").text.contains("26") and button(game, "cast_aegis").text.contains("36"), "book displays learned prices instead of obsolete base prices")
	game.resume()
	game.world.set_process(false)
	var player = game.world.player
	player.set_physics_process(false)
	for child in game.world.get_children():
		if child.has_method("receive_damage") and child != player: child.queue_free()
	await physics_frame
	await physics_frame
	player.position = Vector2(600, 550)
	player.mana = 100
	check(player.cast_magic("heal") and player.health == 90 and player.mana == 55, "learned healing reaches actual player health and mana")
	player.magic_cooldown = 0
	player.health = 20
	player.mana = 44
	check(not player.can_cast_magic("heal") and not player.cast_magic("heal") and player.health == 20 and player.mana == 44, "insufficient learned cost is enforced by actual cast and availability")
	player.health = 100
	player.mana = 100
	check(player.cast_magic("aegis") and player.shield_strength == 54 and player.shield_time == 8 and player.shield_recharge == 8 and player.mana == 64, "learned ward sets actual absorb duration recharge and mana")
	player.receive_damage(40)
	check(player.health == 100 and player.shield_strength == 14, "improved ward absorbs the actual first strike")
	player.hurt_time = 0
	player.receive_damage(40)
	check(player.health == 74 and player.shield_strength == 0, "improved ward has finite strength and passes excess damage")
	var enemy = load("res://scripts/actors/enemy.gd").new()
	enemy.position = Vector2(900, 550)
	enemy.target = player
	game.world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	player.magic_cooldown = 0
	player.mana = 100
	player.facing = Vector2.RIGHT
	check(player.cast_magic("frost") and player.mana == 74, "first learned frost pays its rank-one price")
	check(game.world.learn_skill("frost") and session.skills.frost == 2, "last earned point can be spent while a distant friendly spell is in flight")
	for frame in 65: await physics_frame
	check(enemy.health == 57 and enemy.slow_remaining == 5 and is_equal_approx(enemy.slow_multiplier, 0.5), "flying projectile keeps old damage and slow after actual later learning")
	player.magic_cooldown = 0
	player.mana = 100
	check(player.cast_magic("frost") and player.mana == 72, "next cast uses newly learned second-rank price")
	for frame in 65: await physics_frame
	check(enemy.health == 33 and enemy.slow_remaining == 6 and is_equal_approx(enemy.slow_multiplier, 0.45), "new frost rank changes real impact duration and movement strength")
	check(not game.world.learn_skill("frost") and Skills.points(session.xp, session.skills) == 0, "rank cap and exhausted points forbid another purchase")
	session.xp = 100000
	enemy.position = player.position + Vector2(150, 0)
	check(not game.world.can_learn_skill("sword") and not game.world.learn_skill("sword") and not session.skills.has("sword"), "nearby actual enemy prevents learning from replacing a safe checkpoint")
	Fixture.vampire(session)
	session.xp = 840
	session.skills = {"mending": 1, "light": 1}
	check(not session.can_learn_skill("mending") and not session.learn_skill("mending") and session.can_learn_skill("frost"), "vampire cannot learn forbidden healing but retains access to compatible study")
	check(not session.can_learn_skill("light") and not session.learn_skill("light") and session.skills.light == 1, "vampire cannot spend a new point on forbidden light training")
	player.health = 30
	player.magic_cooldown = 0
	player.mana = 100
	check(not player.cast_magic("heal") and session.skills.mending == 1, "vampire's former healing rank stays stored but inactive")
	var vitals := {"health": 30.0, "stamina": 80.0, "mana": 80.0}
	for event in ["cure_start", "release_water", "release_garden", "cure_finish"]:
		check(session.nature_event(event, player.position, vitals), "separate return keeps the learned build valid")
	check(session.skills.mending == 1 and session.can_learn_skill("mending") and session.load_saved(), "returned human recovers compatible use and learning without resetting spent ranks")
	check(player.cast_magic("heal") and player.health == 85 and player.mana == 60, "returned human uses the preserved real healing improvement")
	player.magic_cooldown = 0
	player.mana = 100
	check(player.cast_magic("light") and session.skills.light == 1, "returned human regains existing light training")
	for frame in 40: await physics_frame
	check(is_instance_valid(enemy) and enemy.health == 3, "old light rank contributes to actual projectile damage once")
	Fixture.vampire(session)
	session.nature.gift = "blood_mist"
	session.gathered.append_array(["flight:bat", "flight:mist"])
	session.opened.append("waterworks_flight")
	session.xp = 840
	for form in ["battle", "bat", "mist"]:
		player.shift_form(form)
		check(not session.can_learn_skill("frost") and not player.cast_magic("frost"), "temporary vampire shapes cannot bypass study or ordinary spell restrictions")
		player.shift_form()
	PackFixture.wolf(session)
	session.xp = 840
	player.shift_form("wolf")
	check(not session.can_learn_skill("aegis") and not player.cast_magic("aegis"), "wolf body cannot bypass learning and spell restrictions")
	player.shift_form()
	check(session.can_learn_skill("mending"), "werewolf in ordinary shape keeps ordinary healing study")
	print("Spell training checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
