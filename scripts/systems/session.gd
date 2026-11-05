extends Node
const Skills = preload("res://scripts/progression/skill_rules.gd")
const Preferences = preload("res://scripts/systems/preferences_store.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
const Quests = preload("res://scripts/quests/quest_book.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Inputs = preload("res://scripts/systems/input_setup.gd")
const Store = preload("res://scripts/systems/save_store.gd")
signal notice(key: String)
signal changed
var difficulty := 1
var fullscreen := false
const FULL_VITALS := {"health": 100.0, "stamina": 100.0, "mana": 100.0}
var vitals: Dictionary = FULL_VITALS.duplicate()
var xp := 0
var skills: Dictionary = {}
var region := "crossing"
var aid_quest := 0
var quest := 0
var defeated: Array = []
var inventory: Dictionary = {"herb": 0}
var gathered: Array = []
var checkpoint: Dictionary = {}
var running := false
var arrival := Vector2(410, 490)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Inputs.install()
	TranslationServer.set_locale("ru")
	var preferences := Preferences.read()
	difficulty = int(preferences.difficulty)
	fullscreen = preferences.fullscreen
	_apply_fullscreen()

func fresh() -> void:
	xp = 0
	skills = {}
	vitals = FULL_VITALS.duplicate()
	region = "crossing"
	quest = 0
	aid_quest = 0
	defeated = []
	gathered = []
	inventory = {"herb": 0}
	arrival = Vector2(410, 490)
	checkpoint = snapshot(arrival)
	running = true
	changed.emit()

func snapshot(position: Vector2, current_vitals: Dictionary = {}) -> Dictionary:
	return {"version": Store.VERSION, "region": region, "position": [position.x, position.y], "difficulty": difficulty,
		"vitals": (vitals if current_vitals.is_empty() else current_vitals).duplicate(),
		"xp": xp, "skills": skills.duplicate(),
		"quest": quest, "aid_quest": aid_quest, "defeated": defeated.duplicate(), "inventory": inventory.duplicate(), "gathered": gathered.duplicate()}

func apply(data: Dictionary) -> void:
	xp = int(data.xp)
	skills = data.skills.duplicate()
	vitals = data.vitals.duplicate()
	region = data.region
	difficulty = int(data.difficulty)
	quest = int(data.quest)
	aid_quest = int(data.aid_quest)
	defeated = data.defeated.duplicate()
	gathered = data.gathered.duplicate()
	inventory = data.inventory.duplicate()
	arrival = Vector2(data.position[0], data.position[1])
	checkpoint = data.duplicate(true)
	running = true
	changed.emit()

func save_at(position: Vector2, current_vitals: Dictionary = {}) -> bool:
	var data := snapshot(position, current_vitals)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	checkpoint = data.duplicate(true)
	vitals = data.vitals.duplicate()
	notice.emit("SAVED")
	return true

func load_saved() -> bool:
	var data := Store.load_game()
	if data.is_empty():
		notice.emit("LOAD_FAILED")
		return false
	apply(data)
	return true

func collect(id: String) -> void:
	inventory[id] = mini(999, int(inventory.get(id, 0)) + 1)
	changed.emit()

func advance_quest(event: String) -> bool:
	var result := Quests.transition(quest, inventory, event)
	if result.is_empty():
		return false
	quest = result.stage
	inventory = result.inventory
	if event == "turn_in":
		award_xp(40)
	changed.emit()
	return true

func travel(destination: String, position: Vector2, current_vitals: Dictionary = {}) -> bool:
	if not Regions.valid(destination):
		return false
	var data := snapshot(position, current_vitals)
	data.region = destination
	# Commit the destination only once its checkpoint is safely on disk.
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	return true

func restore_checkpoint() -> void:
	apply(checkpoint.duplicate(true))
	vitals = FULL_VITALS.duplicate()

func craft_item(id: String) -> bool:
	var result := Items.craft(id, inventory)
	if result.is_empty():
		notice.emit("CRAFT_UNAVAILABLE")
		return false
	inventory = result
	changed.emit()
	notice.emit("POTION_CRAFTED")
	return true

func consume_item(id: String) -> bool:
	var result := Items.consume(id, inventory)
	if result.is_empty():
		return false
	inventory = result
	changed.emit()
	return true

func set_difficulty(value: int) -> bool:
	var data := {"version": 1, "difficulty": value, "fullscreen": fullscreen}
	if Preferences.write(data) != OK:
		notice.emit("PREFERENCES_FAILED")
		return false
	difficulty = value
	return true

func set_fullscreen(value: bool) -> bool:
	var data := {"version": 1, "difficulty": difficulty, "fullscreen": value}
	if Preferences.write(data) != OK:
		notice.emit("PREFERENCES_FAILED")
		return false
	fullscreen = value
	_apply_fullscreen()
	return true

func _apply_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func award_xp(amount: int) -> void:
	var previous := Skills.level(xp)
	xp = mini(100000, xp + maxi(0, amount))
	if Skills.level(xp) > previous:
		notice.emit("LEVEL_UP")
	changed.emit()

func learn_skill(id: String) -> bool:
	var result := Skills.learn(xp, skills, id)
	if result.is_empty():
		return false
	skills = result
	changed.emit()
	return true

func advance_aid(event: String, mana: float) -> Dictionary:
	var result := Quests.aid_transition(aid_quest, inventory, mana, event)
	if result.is_empty():
		return {}
	aid_quest = result.stage
	inventory = result.inventory
	if aid_quest == 2:
		award_xp(30)
	changed.emit()
	return result
