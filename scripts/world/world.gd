extends Node2D
const Bolt = preload("res://scripts/magic/spell_bolt.gd")
const Player = preload("res://scripts/actors/player.gd")
const Enemy = preload("res://scripts/actors/enemy.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Navigator = preload("res://scripts/world/navigation_grid.gd")
const Landscape = preload("res://scripts/world/landscape.gd")
signal dialog_requested(kind: String)
signal travel_requested(destination: String, position: Vector2)
signal player_died
var player: CharacterBody2D
var wayfarer: Sprite2D
var keeper: Sprite2D
var lantern: Sprite2D
var herbs: Array[Sprite2D] = []
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
		var enemy := Enemy.new()
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
		encounter_timer = 0.5
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
		if child is Enemy and child.global_position.distance_to(player.global_position) < 230:
			return false
	return true

func save_safe() -> void:
	if safe_to_rest():
		Session.save_at(player.position, player_vitals())
	else:
		Session.notice.emit("CHECKPOINT_UNSAFE")

func nearby_key() -> String:
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
	if player.position.distance_to(definition.exit) < 55:
		return definition.exit_label
	return ""

func interact() -> void:
	match nearby_key():
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
		"TO_LAKE", "TO_CROSSING":
			travel_requested.emit(definition.destination, definition.arrival)
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
			if offset.length() < 49 and offset.normalized().dot(direction) > 0.15 and navigation.segment_clear(origin, child.global_position):
				child.receive_damage(28 + 4 * int(Session.skills.get("sword", 0)), direction)

func _on_defeated(id: String) -> void:
	if id not in Session.defeated:
		Session.defeated.append(id)
		Session.award_xp(20)
	Session.changed.emit()

func _draw() -> void:
	if definition.is_empty():
		return
	var point: Vector2 = definition.exit
	draw_rect(Rect2(point + Vector2(-2, -27), Vector2(4, 30)), Color("6c654e"))
	draw_rect(Rect2(point + Vector2(-18, -30), Vector2(36, 12)), Color("baaa7d"))
	var direction := 1 if definition.destination == "lake" else -1
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
			if distance > 230 and distance < 290:
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
