extends Node
const Quests = preload("res://scripts/quests/quest_book.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Inputs = preload("res://scripts/systems/input_setup.gd")
const Store = preload("res://scripts/systems/save_store.gd")
signal notice(key: String)
signal changed
var difficulty := 1
const FULL_VITALS := {"health": 100.0, "stamina": 100.0, "mana": 100.0}
var vitals: Dictionary = FULL_VITALS.duplicate()
var region := "crossing"
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

func fresh() -> void:
	vitals = FULL_VITALS.duplicate()
	region = "crossing"
	quest = 0
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
		"quest": quest, "defeated": defeated.duplicate(), "inventory": inventory.duplicate(), "gathered": gathered.duplicate()}

func apply(data: Dictionary) -> void:
	vitals = data.vitals.duplicate()
	region = data.region
	difficulty = int(data.difficulty)
	quest = int(data.quest)
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
