extends Node2D
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Bolt = preload("res://scripts/magic/spell_bolt.gd")
const Player = preload("res://scripts/actors/player.gd")
const RangedEnemy = preload("res://scripts/actors/ranged_enemy.gd")
const HeavyEnemy = preload("res://scripts/actors/heavy_enemy.gd")
const Enemy = preload("res://scripts/actors/enemy.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Navigator = preload("res://scripts/world/navigation_grid.gd")
const Landscape = preload("res://scripts/world/landscape.gd")
signal dialog_requested(kind: String)
signal travel_requested(destination: String, position: Vector2)
signal player_died
var merchant: Sprite2D
var player: CharacterBody2D
var wayfarer: Sprite2D
var keeper: Sprite2D
var lantern: Sprite2D
var herbs: Array[Sprite2D] = []
var chests: Array[Sprite2D] = []
var time := 0.0
var definition: Dictionary = {}
var navigation: RefCounted
var encounter_timer := 0.0
var encounter_checkpoints: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	definition = Regions.get_region(Session.region)
	var land := Landscape.new()
	land.region = Session.region
	land.z_index = -2
	add_child(land)
	navigation = Navigator.new()
	navigation.configure(self)
	merchant = Sprite2D.new()
	merchant.texture = preload("res://assets/sprites/wayfarer.png")
	merchant.modulate = Color("c2ad9b")
	merchant.position = definition.get("merchant", Vector2.ZERO)
	merchant.visible = definition.has("merchant")
	add_child(merchant)
	keeper = Sprite2D.new()
	keeper.texture = preload("res://assets/sprites/keeper.png")
	keeper.position = definition.get("keeper", Vector2.ZERO)
	keeper.visible = definition.has("keeper")
	add_child(keeper)
	wayfarer = Sprite2D.new()
	wayfarer.texture = preload("res://assets/sprites/wayfarer.png")
	wayfarer.position = definition.get("wayfarer", Vector2.ZERO)
	wayfarer.visible = definition.has("wayfarer")
	add_child(wayfarer)
	lantern = Sprite2D.new()
	lantern.texture = preload("res://assets/sprites/lantern.png")
	lantern.position = Vector2(1240, 420)
	lantern.visible = Session.region == "crossing" and Session.quest < 2
	add_child(lantern)
	for point in definition.herbs:
		var herb := Sprite2D.new()
		herb.texture = preload("res://assets/sprites/herb.png")
		herb.position = point
		herb.set_meta("id", Regions.herb_id(Session.region, point))
		herb.visible = herb.get_meta("id") not in Session.gathered
		add_child(herb)
		herbs.append(herb)
	for entry in definition.get("chests", []):
		var chest := Sprite2D.new()
		chest.texture = preload("res://assets/sprites/chest.png")
		chest.position = entry.point
		chest.set_meta("definition", entry)
		chest.modulate = Color("6d7770") if entry.id in Session.opened else Color.WHITE
		add_child(chest)
		chests.append(chest)
	player = Player.new()
	player.position = Session.arrival
	player.health = Session.vitals.health
	player.stamina = Session.vitals.stamina
	player.mana = Session.vitals.mana
	add_child(player)
	player.died.connect(func(): player_died.emit())
	player.strike.connect(_on_strike)
	player.cast_spell.connect(_on_cast_spell)
	for entry in definition.enemies:
		if entry[0] in Session.defeated:
			continue
		var kind: String = entry[2] if entry.size() > 2 else "melee"
		var enemy = RangedEnemy.new() if kind == "ranged" else (HeavyEnemy.new() if kind == "heavy" else Enemy.new())
		enemy.id = entry[0]
		enemy.position = entry[1]
		enemy.target = player
		enemy.navigation = navigation
		enemy.defeated.connect(_on_defeated)
		add_child(enemy)

func _process(delta: float) -> void:
	time += delta
	encounter_timer -= delta
	if encounter_timer <= 0:
		encounter_timer = 0.1
		_checkpoint_before_encounter()
	lantern.position.y = 420 + sin(time * 2) * 2
	if Input.is_action_just_pressed("interact") and Session.running:
		interact()
	if Input.is_action_just_pressed("save_game"):
		save_safe()
	if Input.is_action_just_pressed("fullscreen"):
		Session.set_fullscreen(not Session.fullscreen)

func safe_to_rest() -> bool:
	for child in get_children():
		if child is Enemy and child.global_position.distance_to(player.global_position) < child.aggro_range + 20:
			return false
	for arrow in get_tree().get_nodes_in_group("hostile_projectiles"):
		if arrow.get_parent() == self:
			return false
	return true

func save_safe() -> void:
	if safe_to_rest():
		Session.save_at(player.position, player_vitals())
	else:
		Session.notice.emit("CHECKPOINT_UNSAFE")

func nearby_key() -> String:
	if merchant.visible and player.position.distance_to(merchant.position) < 45:
		return "MERCHANT_NAME"
	if keeper.visible and player.position.distance_to(keeper.position) < 50:
		return "KEEPER_NAME"
	if wayfarer.visible and player.position.distance_to(wayfarer.position) < 45:
		return "AID_NAME"
	if player.position.distance_to(definition.camp) < 45:
		return "REST"
	if lantern.visible and player.position.distance_to(lantern.position) < 40:
		return "LANTERN"
	for herb in herbs:
		if herb.visible and player.position.distance_to(herb.position) < 30:
			return "HERB"
	for chest in chests:
		if chest.get_meta("definition").id not in Session.opened and player.position.distance_to(chest.position) < 40:
			return "CHEST"
	for portal in Regions.exits(Session.region):
		if player.position.distance_to(portal.point) < 55:
			return portal.label
	return ""

func interact() -> void:
	var key := nearby_key()
	if key.begins_with("TO_"):
		for portal in Regions.exits(Session.region):
			if portal.label == key:
				travel_requested.emit(portal.destination, portal.arrival)
				return
	match key:
		"MERCHANT_NAME": dialog_requested.emit("merchant")
		"KEEPER_NAME": dialog_requested.emit("keeper")
		"AID_NAME": dialog_requested.emit("wayfarer")
		"REST":
			if safe_to_rest():
				player.restore()
				Session.save_at(player.position, player_vitals())
			else:
				Session.notice.emit("CHECKPOINT_UNSAFE")
		"LANTERN":
			if Session.advance_quest("found"):
				lantern.hide()
				Session.notice.emit("LANTERN_FOUND")
				Session.changed.emit()
		"CHEST":
			if not safe_to_rest():
				Session.notice.emit("CHECKPOINT_UNSAFE")
				return
			for chest in chests:
				if player.position.distance_to(chest.position) < 40 and chest.get_meta("definition").id not in Session.opened:
					if Session.claim_chest(chest.get_meta("definition"), player.position, player_vitals()):
						chest.modulate = Color("6d7770")
					return
		"HERB":
			for herb in herbs:
				if herb.visible and player.position.distance_to(herb.position) < 30:
					herb.hide()
					Session.gathered.append(herb.get_meta("id"))
					Session.collect("herb")
					Session.notice.emit("HERB_FOUND")
					break

func _on_strike(origin: Vector2, direction: Vector2) -> void:
	for child in get_children():
		if child is Enemy:
			var offset: Vector2 = child.global_position - origin
			if offset.length() < Gear.weapon(Session.equipped).reach and offset.normalized().dot(direction) > 0.15 and navigation.segment_clear(origin, child.global_position):
				child.receive_damage(Gear.weapon(Session.equipped).damage + 4 * int(Session.skills.get("sword", 0)), direction)

func _on_defeated(id: String) -> void:
	if id not in Session.defeated:
		Session.defeated.append(id)
		var reward := 20
		var coins := 3
		for child in get_children():
			if child is Enemy and child.id == id:
				reward = child.reward_xp
				coins = child.coin_reward
				break
		Session.award_xp(reward)
		Session.inventory["coin"] = mini(999, int(Session.inventory.get("coin", 0)) + coins)
	Session.changed.emit()

func _draw() -> void:
	if definition.is_empty():
		return
	for portal in Regions.exits(Session.region):
		var point: Vector2 = portal.point
		draw_rect(Rect2(point + Vector2(-2, -27), Vector2(4, 30)), Color("6c654e"))
		draw_rect(Rect2(point + Vector2(-18, -30), Vector2(36, 12)), Color("baaa7d"))
		var direction: int = portal.direction
		var tip := point + Vector2(direction * 12, -24)
		draw_line(point + Vector2(-direction * 12, -24), tip, Color("394d46"), 2)
		draw_line(tip, tip + Vector2(-direction * 5, -4), Color("394d46"), 2)
		draw_line(tip, tip + Vector2(-direction * 5, 4), Color("394d46"), 2)

func player_vitals() -> Dictionary:
	return {"health": player.health, "stamina": player.stamina, "mana": player.mana}

func _on_cast_spell(origin: Vector2, direction: Vector2, amount: float) -> void:
	var bolt := Bolt.new()
	bolt.position = origin
	bolt.direction = direction
	bolt.damage = amount
	add_child(bolt)

func _checkpoint_before_encounter() -> void:
	if player.health <= 0 or not safe_to_rest():
		return
	for child in get_children():
		if child is Enemy and not encounter_checkpoints.has(child.id):
			var distance: float = child.position.distance_to(player.position)
			if distance > child.aggro_range + 20 and distance < child.aggro_range + 80:
				if Session.save_at(player.position, player_vitals()):
					encounter_checkpoints[child.id] = true
				return

func aid_choice(event: String) -> bool:
	var result := Session.advance_aid(event, player.mana)
	if result.is_empty():
		return false
	player.mana = result.mana
	save_safe()
	return true

func trade(id: String, selling: bool) -> bool:
	if nearby_key() != "MERCHANT_NAME" or not safe_to_rest():
		return false
	return Session.trade_item(id, selling, player.position, player_vitals())
