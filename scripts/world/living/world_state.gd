extends RefCounted
const Factions = preload("res://scripts/factions/faction_rules.gd")
const Commission = preload("res://scripts/quests/commission_rules.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const Schedule = preload("res://scripts/world/living/npc_schedule.gd")
const Encounters = preload("res://scripts/world/living/encounter_rules.gd")

static func defaults() -> Dictionary:
	return {"minutes": Clock.START, "seed": Clock.DEFAULT_SEED, "npcs": {}, "reputation": Factions.defaults(), "commission": Commission.defaults(),
		"seen": [], "next_event": Clock.START + 30, "active": {}}

static func number(value: Variant, minimum: float, maximum: float, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and (not integer or floorf(value) == value)

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not number(data.get("minutes"), 0, 1000000000) or not number(data.get("seed"), 0, 2147483647, true):
		return false
	# Optional per-playthrough seed of the generated hollows; older saves fall back to "seed".
	if data.has("delve_seed") and not number(data.delve_seed, 0, 2147483647, true):
		return false
	if not Schedule.valid_positions(data.get("npcs")) or not data.get("reputation") is Dictionary:
		return false
	if not Factions.valid(data.reputation) or not Commission.valid(data.get("commission")):
		return false
	if not data.get("seen") is Array or not number(data.get("next_event"), 0, 1000000000):
		return false
	var known := {}
	for id in data.seen:
		if not id is String or not Encounters.ENTRIES.has(id) or known.has(id):
			return false
		known[id] = true
	if not data.get("active") is Dictionary:
		return false
	if not data.active.is_empty():
		var active: Dictionary = data.active
		if not active.get("id") is String or not Encounters.ENTRIES.has(active.id) or active.id in data.seen:
			return false
		if not active.get("region") is String or active.region not in Encounters.ENTRIES[active.id].regions:
			return false
		if not Schedule.valid_point(active.get("position")):
			return false
	return true
