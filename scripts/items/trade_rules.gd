extends RefCounted
const Gear = preload("res://scripts/items/equipment_rules.gd")
const CONSUMABLES := {"herb": {"price": 2, "sell": 1}, "potion": {"price": 5, "sell": 2}}

static func stock(group: String = "roadfolk") -> Array:
	if group == "wardens":
		return ["watch_spear", "iron_shield", "potion"]
	if group != "roadfolk":
		return []
	return Gear.ITEMS.keys().filter(func(id): return Gear.ITEMS[id].get("vendor", "roadfolk") == "roadfolk") + CONSUMABLES.keys()

static func buy(id: String, inventory: Dictionary, owned: Array, trust: int = 0) -> Dictionary:
	var gear := Gear.ITEMS.has(id)
	var definition: Dictionary = Gear.ITEMS.get(id, CONSUMABLES.get(id, {}))
	var price := quote(id, false, trust)
	if definition.is_empty() or int(inventory.get("coin", 0)) < price:
		return {}
	if (gear and id in owned) or (not gear and int(inventory.get(id, 0)) >= 999):
		return {}
	var items := inventory.duplicate()
	var gear_owned := owned.duplicate()
	items["coin"] = int(items.get("coin", 0)) - price
	if gear:
		gear_owned.append(id)
	else:
		items[id] = int(items.get(id, 0)) + 1
	return {"inventory": items, "owned": gear_owned}

static func sell(id: String, inventory: Dictionary, owned: Array, equipped: Dictionary, trust: int = 0) -> Dictionary:
	var gear := Gear.ITEMS.has(id)
	var definition: Dictionary = Gear.ITEMS.get(id, CONSUMABLES.get(id, {}))
	if definition.is_empty() or int(inventory.get("coin", 0)) + definition.sell > 999:
		return {}
	if gear and (id not in owned or id in equipped.values()):
		return {}
	if not gear and int(inventory.get(id, 0)) < 1:
		return {}
	var items := inventory.duplicate()
	var gear_owned := owned.duplicate()
	items["coin"] = int(items.get("coin", 0)) + definition.sell
	if gear:
		gear_owned.erase(id)
	else:
		items[id] = int(items[id]) - 1
	return {"inventory": items, "owned": gear_owned}

static func quote(id: String, selling: bool, trust: int = 0) -> int:
	var definition: Dictionary = Gear.ITEMS.get(id, CONSUMABLES.get(id, {}))
	if definition.is_empty():
		return 0
	if selling:
		return definition.sell
	var modifier := -1 if trust >= 3 else (1 if trust <= -3 else 0)
	return maxi(1, int(definition.price) + modifier)
