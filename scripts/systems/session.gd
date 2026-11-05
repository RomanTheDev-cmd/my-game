extends Node
const Inputs = preload("res://scripts/systems/input_setup.gd")
const Store = preload("res://scripts/systems/save_store.gd")
signal notice(key: String)
signal changed
var difficulty := 1
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
	quest = 0
	defeated = []
	gathered = []
	inventory = {"herb": 0}
	arrival = Vector2(410, 490)
	checkpoint = snapshot(arrival)
	running = true
	changed.emit()

func snapshot(position: Vector2) -> Dictionary:
	return {"version": 1, "position": [position.x, position.y], "difficulty": difficulty,
		"quest": quest, "defeated": defeated.duplicate(), "inventory": inventory.duplicate(), "gathered": gathered.duplicate()}

func apply(data: Dictionary) -> void:
	difficulty = int(data.difficulty)
	quest = int(data.quest)
	defeated = data.defeated.duplicate()
	gathered = data.gathered.duplicate()
	inventory = data.inventory.duplicate()
	arrival = Vector2(data.position[0], data.position[1])
	checkpoint = data.duplicate(true)
	running = true
	changed.emit()

func save_at(position: Vector2) -> bool:
	var data := snapshot(position)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	checkpoint = data.duplicate(true)
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
