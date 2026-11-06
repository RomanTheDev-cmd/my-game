extends Node
const Clock = preload("res://scripts/world/living/world_clock.gd")
const WorldState = preload("res://scripts/world/living/world_state.gd")
const Encounters = preload("res://scripts/world/living/encounter_rules.gd")
const Loot = preload("res://scripts/items/loot_rules.gd")
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
const Skills = preload("res://scripts/progression/skill_rules.gd")
const Preferences = preload("res://scripts/systems/preferences_store.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
const Quests = preload("res://scripts/quests/quest_book.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
const Inputs = preload("res://scripts/systems/input_setup.gd")
const Store = preload("res://scripts/systems/save_store.gd")
signal notice(key: String)
signal changed
var world_state: Dictionary = WorldState.defaults()
var difficulty := 1
var fullscreen := false
var audio: Dictionary = Preferences.DEFAULTS.audio.duplicate()
const FULL_VITALS := {"health": 100.0, "stamina": 100.0, "mana": 100.0}
var vitals: Dictionary = FULL_VITALS.duplicate()
var xp := 0
var skills: Dictionary = {}
var region := "crossing"
var aid_quest := 0
var quest := 0
var defeated: Array = []
var gear_owned: Array = Gear.DEFAULT_OWNED.duplicate()
var equipped: Dictionary = Gear.DEFAULT_EQUIPPED.duplicate()
var opened: Array = []
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
	audio = preferences.audio.duplicate()
	_apply_fullscreen()

func fresh() -> void:
	world_state = WorldState.defaults()
	xp = 0
	skills = {}
	vitals = FULL_VITALS.duplicate()
	region = "crossing"
	quest = 0
	aid_quest = 0
	defeated = []
	gear_owned = Gear.DEFAULT_OWNED.duplicate()
	equipped = Gear.DEFAULT_EQUIPPED.duplicate()
	opened = []
	gathered = []
	inventory = {"herb": 0}
	arrival = Vector2(410, 490)
	checkpoint = snapshot(arrival)
	running = true
	changed.emit()

func snapshot(position: Vector2, current_vitals: Dictionary = {}) -> Dictionary:
	return {"version": Store.VERSION, "world_state": world_state.duplicate(true), "region": region, "position": [position.x, position.y], "difficulty": difficulty,
		"vitals": (vitals if current_vitals.is_empty() else current_vitals).duplicate(),
		"gear_owned": gear_owned.duplicate(), "equipped": equipped.duplicate(), "opened": opened.duplicate(),
		"xp": xp, "skills": skills.duplicate(),
		"quest": quest, "aid_quest": aid_quest, "defeated": defeated.duplicate(), "inventory": inventory.duplicate(), "gathered": gathered.duplicate()}

func apply(data: Dictionary) -> void:
	world_state = data.world_state.duplicate(true)
	gear_owned = data.gear_owned.duplicate()
	equipped = data.equipped.duplicate()
	opened = data.opened.duplicate()
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
	var data := {"version": 1, "difficulty": value, "fullscreen": fullscreen, "audio": audio.duplicate()}
	if Preferences.write(data) != OK:
		notice.emit("PREFERENCES_FAILED")
		return false
	difficulty = value
	return true

func set_fullscreen(value: bool) -> bool:
	var data := {"version": 1, "difficulty": difficulty, "fullscreen": value, "audio": audio.duplicate()}
	if Preferences.write(data) != OK:
		notice.emit("PREFERENCES_FAILED")
		return false
	fullscreen = value
	_apply_fullscreen()
	return true

func set_volume(channel: String, value: float) -> bool:
	if not audio.has(channel):
		return false
	var levels := audio.duplicate()
	levels[channel] = value
	if Preferences.write({"version": 1, "difficulty": difficulty, "fullscreen": fullscreen, "audio": levels}) != OK:
		notice.emit("PREFERENCES_FAILED")
		return false
	audio = levels
	Sound.apply_volumes(audio)
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

func equip_item(id: String) -> bool:
	var result := Gear.equip(id, gear_owned, equipped)
	if result.is_empty():
		return false
	equipped = result
	changed.emit()
	return true

func unequip_slot(slot: String) -> void:
	if equipped.has(slot):
		equipped[slot] = ""
		changed.emit()

func trade_item(id: String, selling: bool, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Trade.sell(id, inventory, gear_owned, equipped, int(world_state.reputation.roadfolk)) if selling else Trade.buy(id, inventory, gear_owned, int(world_state.reputation.roadfolk))
	if result.is_empty():
		notice.emit("TRADE_FAILED")
		return false
	var data := snapshot(position, current_vitals)
	data.inventory = result.inventory
	data.gear_owned = result.owned
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("TRADE_DONE")
	return true

func claim_chest(chest: Dictionary, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Loot.claim(chest, inventory, gear_owned, opened, defeated)
	if result.is_empty():
		notice.emit("CHEST_UNAVAILABLE")
		return false
	var data := snapshot(position, current_vitals)
	data.inventory = result.inventory
	data.gear_owned = result.owned
	data.opened = result.opened
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("CHEST_OPENED")
	return true

func advance_world(seconds: float) -> void:
	if running:
		world_state.minutes = Clock.advance(world_state.minutes, seconds)

func wait_minutes(amount: float, position: Vector2) -> bool:
	if not is_finite(amount) or amount <= 0 or amount > 1440:
		return false
	var data := snapshot(position, FULL_VITALS)
	data.world_state.minutes = Clock.advance(world_state.minutes, amount)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("RESTED")
	return true

func resolve_encounter(choice: String, position: Vector2, current_vitals: Dictionary) -> bool:
	if world_state.active.is_empty():
		return false
	var id: String = world_state.active.id
	if id in world_state.seen:
		return false
	var outcome := Encounters.resolve(id, choice, inventory, current_vitals.mana, int(world_state.reputation.roadfolk))
	if outcome.is_empty():
		notice.emit("ENCOUNTER_UNAVAILABLE")
		return false
	var data := snapshot(position, current_vitals)
	data.inventory = outcome.inventory
	data.vitals.mana = outcome.mana
	data.world_state.reputation.roadfolk = outcome.trust
	data.world_state.seen.append(id)
	data.world_state.active = {}
	data.world_state.next_event = minf(1000000000, data.world_state.minutes + 180)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("ENCOUNTER_SAVED")
	return true
