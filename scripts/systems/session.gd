extends Node
const Knell = preload("res://scripts/quests/knell_rules.gd")
const Accord = preload("res://scripts/quests/accord_rules.gd")
const Rescue = preload("res://scripts/quests/rescue_rules.gd")
const Preparation = preload("res://scripts/quests/preparation_rules.gd")
const Junction = preload("res://scripts/quests/junction_rules.gd")
const City = preload("res://scripts/quests/city_rules.gd")
const Forest = preload("res://scripts/quests/forest_rules.gd")
const Campaign = preload("res://scripts/quests/campaign_rules.gd")
const Field = preload("res://scripts/magic/field_rules.gd")
const Community = preload("res://scripts/factions/community_rules.gd")
const Dialogue = preload("res://scripts/nature/dialogue_rules.gd")
const Pack = preload("res://scripts/nature/pack_rules.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Trial = preload("res://scripts/quests/trial_rules.gd")
const Factions = preload("res://scripts/factions/faction_rules.gd")
const Commission = preload("res://scripts/quests/commission_rules.gd")
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
var nature: Dictionary = Nature.defaults()
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
	nature = Nature.defaults()
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
	return {"version": Store.VERSION, "nature": nature.duplicate(true), "world_state": world_state.duplicate(true), "region": region, "position": [position.x, position.y], "difficulty": difficulty,
		"vitals": (vitals if current_vitals.is_empty() else current_vitals).duplicate(),
		"gear_owned": gear_owned.duplicate(), "equipped": equipped.duplicate(), "opened": opened.duplicate(),
		"xp": xp, "skills": skills.duplicate(),
		"quest": quest, "aid_quest": aid_quest, "defeated": defeated.duplicate(), "inventory": inventory.duplicate(), "gathered": gathered.duplicate()}

func apply(data: Dictionary) -> void:
	nature = data.nature.duplicate(true)
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
	if destination == Knell.REGION and not Knell.can_enter(gathered):
		notice.emit("KNELL_DOOR_LOCKED")
		return false
	var data := snapshot(position, current_vitals)
	data.region = destination
	if data.nature.form in ["bat", "mist"] or not data.nature.landing.is_empty():
		data.nature.form = "human"
		data.nature.landing = {}
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

func can_learn_skill(id: String) -> bool:
	if nature.form != "human" or not Skills.SKILLS.has(id) or Skills.learn(xp, skills, id).is_empty(): return false
	var spell: String = Skills.SKILLS[id].get("spell", "")
	return spell == "" or Nature.can_spell(nature, spell)
func learn_skill(id: String, position: Vector2 = Vector2.INF, current_vitals: Dictionary = {}) -> bool:
	if not can_learn_skill(id): return false
	var result := Skills.learn(xp, skills, id)
	var data := snapshot(arrival if position == Vector2.INF else position, current_vitals)
	data.skills = result
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	return true

func advance_aid(event: String, mana: float) -> Dictionary:
	if event == "magic" and not Nature.can_spell(nature, "heal"): return {}
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

func trade_item(id: String, selling: bool, position: Vector2, current_vitals: Dictionary, group: String = "roadfolk") -> bool:
	if id not in Trade.stock(group) or (group == "wardens" and not Factions.trusted(world_state.reputation, group)):
		return false
	var trust := int(world_state.reputation[group])
	var result := Trade.sell(id, inventory, gear_owned, equipped, trust) if selling else Trade.buy(id, inventory, gear_owned, trust)
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
	if chest.has("required_form") and nature.form != chest.required_form: return false
	var result := Loot.claim(chest, inventory, gear_owned, opened, defeated)
	if result.is_empty():
		notice.emit("CHEST_UNAVAILABLE")
		return false
	var data := snapshot(position, current_vitals)
	data.inventory = result.inventory
	data.gear_owned = result.owned
	data.opened = result.opened
	_apply_pack_mastery(data)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("CHEST_OPENED")
	return true

func advance_world(seconds: float) -> void:
	if running and is_finite(seconds) and seconds >= 0:
		world_state.minutes = Clock.advance(world_state.minutes, seconds)
		nature = Nature.advance(nature, seconds)

func wait_minutes(amount: float, position: Vector2) -> bool:
	if not is_finite(amount) or amount <= 0 or amount > 1440:
		return false
	var data := snapshot(position, FULL_VITALS)
	data.world_state.minutes = Clock.advance(world_state.minutes, amount)
	data.nature = Nature.advance(nature, amount)
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

func commission_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var outcome := Commission.transition(world_state.commission, inventory, current_vitals.mana, world_state.reputation, event, quest, defeated)
	if outcome.is_empty():
		notice.emit("COMMISSION_UNAVAILABLE")
		return false
	var data := snapshot(position, current_vitals)
	data.world_state.commission = outcome.commission
	data.world_state.reputation = outcome.reputation
	data.inventory = outcome.inventory
	data.vitals.mana = outcome.mana
	data.xp = mini(100000, xp + int(outcome.xp))
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	var previous_level := Skills.level(xp)
	apply(data)
	if Skills.level(xp) > previous_level:
		notice.emit("LEVEL_UP")
	notice.emit("COMMISSION_UPDATED")
	return true

func collect_salvage(id: String, position: Vector2, current_vitals: Dictionary) -> bool:
	if region != "workshop" or id not in ["workshop:scrap_1", "workshop:scrap_2", "workshop:scrap_3"] or id in gathered or int(inventory.get("scrap", 0)) >= 999:
		return false
	var data := snapshot(position, current_vitals)
	data.inventory["scrap"] = int(data.inventory.get("scrap", 0)) + 1
	data.gathered.append(id)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("SALVAGE_FOUND")
	return true

func brew_with_tender(position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Items.brew_with_tender(inventory, int(world_state.reputation.tenders))
	if result.is_empty():
		return false
	var data := snapshot(position, current_vitals)
	data.inventory = result
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("POTION_CRAFTED")
	return true

func trial_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var outcome := Trial.transition(gathered, defeated, opened, inventory, int(world_state.commission.stage), event)
	if outcome.is_empty(): return false
	var data := snapshot(position, current_vitals)
	data.gathered = outcome.gathered
	data.opened = outcome.opened
	data.inventory = outcome.inventory
	data.xp = mini(100000, xp + int(outcome.xp))
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("TRIAL_UPDATED")
	return true

func finish_guardian(position: Vector2, current_vitals: Dictionary) -> bool:
	if region != "waterworks" or Trial.stage(gathered, defeated, opened) != 3 or not Trial.valid(gathered, defeated, opened, int(world_state.commission.stage)):
		return false
	var data := snapshot(position, current_vitals)
	data.defeated.append(Trial.BOSS)
	data.xp = mini(100000, xp + 120)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("TRIAL_VICTORY")
	return true

func nature_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Nature.resolve(nature, gathered, opened, inventory, float(current_vitals.mana), event)
	if result.is_empty(): return false
	var data := snapshot(position, current_vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.inventory = result.inventory
	data.vitals.mana = result.mana
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	data.xp = mini(100000, xp + int(result.xp))
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("NATURE_UPDATED")
	return true

func dialogue_event(kind: String, answer: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Dialogue.resolve(nature, gathered, world_state.reputation, kind, answer)
	if result.is_empty(): return false
	var data := snapshot(position, current_vitals)
	data.gathered = result.gathered
	data.world_state.reputation = result.reputation
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("DIALOGUE_SAVED")
	return true

func _apply_pack_mastery(data: Dictionary) -> void:
	var trained := Pack.mastery(data.nature, data.gathered, data.opened)
	data.nature = trained.nature
	data.gathered = trained.gathered
	data.xp = mini(100000, int(data.xp) + trained.xp)

func pack_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Pack.resolve(nature, gathered, opened, float(current_vitals.mana), event)
	if result.is_empty(): return false
	var data := snapshot(position, current_vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.vitals.mana = result.mana
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	data.xp = mini(100000, xp + result.xp)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("PACK_UPDATED")
	return true

func community_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Community.resolve(nature, gathered, opened, inventory, gear_owned, world_state.reputation, current_vitals.mana, event)
	if result.is_empty(): return false
	var data := snapshot(position, current_vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.inventory = result.inventory
	data.gear_owned = result.owned
	data.world_state.reputation = result.reputation
	data.vitals.mana = result.mana
	data.xp = mini(100000, xp + result.xp)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("COMMUNITY_SAVED")
	return true

func field_event(id: String, method: String, position: Vector2, current_vitals: Dictionary, cooldown: float = 0, recharge: float = 0) -> Dictionary:
	var result := Field.resolve(nature, skills, gathered, opened, current_vitals, world_state.minutes, id, method, cooldown, recharge)
	if result.is_empty(): return {}
	var data := snapshot(position, result.vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.world_state.minutes = result.minutes
	data.xp = mini(100000, xp + result.xp)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return {}
	apply(data)
	notice.emit("FIELD_SAVED")
	return result

func campaign_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Campaign.resolve(nature, quest, gathered, opened, inventory, current_vitals, event)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.inventory = result.inventory
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, {"roadfolk": result.trust})
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("STORY_SAVED")
	return true

func forest_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Forest.resolve(nature, gathered, opened, inventory, current_vitals, event)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("FOREST_SAVED")
	return true

func city_event(event: String, position: Vector2, current_vitals: Dictionary) -> Dictionary:
	var result := City.resolve(nature, gathered, opened, inventory, current_vitals, world_state.minutes, event)
	if result.is_empty(): return {}
	var data := snapshot(position, result.vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.inventory = result.inventory
	data.world_state.minutes = result.minutes
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return {}
	apply(data)
	notice.emit("CITY_SAVED")
	return result

func junction_event(event: String, position: Vector2, current_vitals: Dictionary, cooldown: float = 0, recharge: float = 0, measured: float = 0) -> Dictionary:
	var result := Junction.resolve(nature, skills, gathered, opened, inventory, current_vitals, event, cooldown, recharge, measured)
	if result.is_empty(): return {}
	var data := snapshot(position, result.vitals)
	data.gathered = result.gathered
	data.opened = result.opened
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return {}
	apply(data)
	notice.emit("JOINT_SAVED")
	return result

func preparation_event(event: String, position: Vector2, current_vitals: Dictionary, rehearsed: bool = false) -> bool:
	var result := Preparation.resolve(nature, gathered, opened, inventory, current_vitals, event, rehearsed)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.gathered = result.gathered
	data.opened = result.opened
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("PREP_SAVED")
	return true

func rescue_event(event: String, position: Vector2, current_vitals: Dictionary, calm: bool = false, impact: bool = false, arrived: bool = false) -> bool:
	var result := Rescue.resolve(nature, gathered, opened, inventory, current_vitals, event, calm, impact, arrived)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.nature = result.nature
	data.gathered = result.gathered
	data.opened = result.opened
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("RESCUE_SAVED")
	return true

func accord_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Accord.resolve(nature, gathered, opened, inventory, current_vitals, event)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.gathered = result.gathered
	data.opened = result.opened
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	apply(data)
	notice.emit("ACCORD_SAVED")
	return true

func knell_event(event: String, position: Vector2, current_vitals: Dictionary) -> bool:
	var result := Knell.resolve(nature, gathered, defeated, opened, inventory, gear_owned, current_vitals, event, region)
	if result.is_empty(): return false
	var data := snapshot(position, result.vitals)
	data.gathered = result.gathered
	data.defeated = result.defeated
	data.opened = result.opened
	data.inventory = result.inventory
	data.gear_owned = result.owned
	data.xp = mini(100000, xp + result.xp)
	data.world_state.reputation = Factions.change(world_state.reputation, result.trust)
	if Store.write_game(data) != OK:
		notice.emit("SAVE_FAILED")
		return false
	var previous_level := Skills.level(xp)
	apply(data)
	if Skills.level(xp) > previous_level: notice.emit("LEVEL_UP")
	notice.emit("KNELL_SAVED")
	return true
