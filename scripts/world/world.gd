extends Node2D
const Player = preload("res://scripts/actors/player.gd")
const Enemy = preload("res://scripts/actors/enemy.gd")
const Landscape = preload("res://scripts/world/landscape.gd")
signal dialog_requested
signal player_died
var player: CharacterBody2D
var keeper: Sprite2D
var lantern: Sprite2D
var herbs: Array[Sprite2D] = []
var time := 0.0

func _ready() -> void:
	y_sort_enabled = true
	var land := Landscape.new()
	land.z_index = -2
	add_child(land)
	keeper = Sprite2D.new()
	keeper.texture = preload("res://assets/sprites/keeper.png")
	keeper.position = Vector2(520, 490)
	add_child(keeper)
	lantern = Sprite2D.new()
	lantern.texture = preload("res://assets/sprites/lantern.png")
	lantern.position = Vector2(1240, 420)
	lantern.visible = Session.quest < 2
	add_child(lantern)
	for point in [Vector2(650, 670), Vector2(930, 680), Vector2(1200, 700)]:
		var herb := Sprite2D.new()
		herb.texture = preload("res://assets/sprites/herb.png")
		herb.position = point
		herb.set_meta("id", "herb_%d_%d" % [point.x, point.y])
		herb.visible = herb.get_meta("id") not in Session.gathered
		add_child(herb)
		herbs.append(herb)
	player = Player.new()
	player.position = Session.arrival
	add_child(player)
	player.died.connect(func(): player_died.emit())
	player.strike.connect(_on_strike)
	for entry in [["road_1", Vector2(970, 550)], ["road_2", Vector2(1240, 530)], ["road_3", Vector2(1430, 640)]]:
		if entry[0] in Session.defeated:
			continue
		var enemy := Enemy.new()
		enemy.id = entry[0]
		enemy.position = entry[1]
		enemy.target = player
		enemy.defeated.connect(_on_defeated)
		add_child(enemy)

func _process(delta: float) -> void:
	time += delta
	lantern.position.y = 420 + sin(time * 2) * 2
	if Input.is_action_just_pressed("interact") and Session.running:
		interact()
	if Input.is_action_just_pressed("save_game"):
		save_safe()
	if Input.is_action_just_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func safe_to_rest() -> bool:
	for child in get_children():
		if child is Enemy and child.global_position.distance_to(player.global_position) < 230:
			return false
	return true

func save_safe() -> void:
	if safe_to_rest():
		Session.save_at(player.position)
	else:
		Session.notice.emit("CHECKPOINT_UNSAFE")

func nearby_key() -> String:
	if player.position.distance_to(keeper.position) < 50:
		return "KEEPER_NAME"
	if player.position.distance_to(Vector2(440, 470)) < 45:
		return "REST"
	if lantern.visible and player.position.distance_to(lantern.position) < 40:
		return "LANTERN"
	for herb in herbs:
		if herb.visible and player.position.distance_to(herb.position) < 30:
			return "HERB"
	return ""

func interact() -> void:
	match nearby_key():
		"KEEPER_NAME": dialog_requested.emit()
		"REST":
			if safe_to_rest():
				player.restore()
				Session.save_at(player.position)
			else:
				Session.notice.emit("CHECKPOINT_UNSAFE")
		"LANTERN":
			if Session.quest == 1:
				Session.quest = 2
				Session.inventory["lantern"] = 1
				lantern.hide()
				Session.notice.emit("LANTERN_FOUND")
				Session.changed.emit()
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
			if offset.length() < 49 and offset.normalized().dot(direction) > 0.15:
				child.receive_damage(28, direction)

func _on_defeated(id: String) -> void:
	if id not in Session.defeated:
		Session.defeated.append(id)
	Session.changed.emit()
