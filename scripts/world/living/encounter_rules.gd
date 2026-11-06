extends RefCounted
const Clock = preload("res://scripts/world/living/world_clock.gd")
const ENTRIES := {
	"shelter": {"regions": ["crossing"], "weather": ["rain"], "hours": [7, 22], "rep_min": -2,
		"choices": {"herb": {"cost": {"herb": 1}, "rep": 1}, "magic": {"mana_cost": 25, "rep": 1}, "leave": {}}},
	"lost_pack": {"regions": ["crossing"], "weather": ["clear", "fog"], "hours": [6, 21],
		"choices": {"return": {"reward": {"coin": 1}, "rep": 2}, "keep": {"reward": {"coin": 4}, "rep": -1}, "leave": {}}},
	"fireflies": {"regions": ["lake"], "weather": ["clear", "fog"], "hours": [19, 5],
		"choices": {"observe": {"mana_gain": 15}, "leave": {}}},
	"camp_song": {"regions": ["crossing"], "weather": ["clear", "fog"], "hours": [18, 24],
		"choices": {"listen": {"mana_gain": 10}, "share": {"cost": {"coin": 1}, "rep": 1}, "leave": {}}}
}

static func eligible(region: String, minutes: float, weather: String, seen: Array, trust: int) -> Array[String]:
	var result: Array[String] = []
	for id in ENTRIES:
		var entry: Dictionary = ENTRIES[id]
		if id in seen or region not in entry.regions or weather not in entry.weather:
			continue
		if not Clock.in_hours(Clock.hour(minutes), entry.hours[0], entry.hours[1]) or trust < entry.get("rep_min", -10):
			continue
		result.append(id)
	return result

static func choose(region: String, minutes: float, seed_value: int, seen: Array, trust: int) -> String:
	var candidates := eligible(region, minutes, Clock.weather(minutes, seed_value), seen, trust)
	return "" if candidates.is_empty() else candidates[posmod(seed_value + floori(minutes / 60), candidates.size())]

static func resolve(id: String, choice: String, inventory: Dictionary, mana: float, trust: int) -> Dictionary:
	if not ENTRIES.has(id) or not ENTRIES[id].choices.has(choice):
		return {}
	var option: Dictionary = ENTRIES[id].choices[choice]
	if mana < option.get("mana_cost", 0):
		return {}
	var items := inventory.duplicate()
	for key in option.get("cost", {}):
		if int(items.get(key, 0)) < option.cost[key]:
			return {}
		items[key] = int(items[key]) - option.cost[key]
	for key in option.get("reward", {}):
		if int(items.get(key, 0)) + option.reward[key] > 999:
			return {}
		items[key] = int(items.get(key, 0)) + option.reward[key]
	return {"inventory": items, "mana": clampf(mana - option.get("mana_cost", 0) + option.get("mana_gain", 0), 0, 100),
		"trust": clampi(trust + int(option.get("rep", 0)), -10, 10)}
