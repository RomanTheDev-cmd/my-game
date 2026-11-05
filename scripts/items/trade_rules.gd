extends RefCounted
const Gear = preload("res://scripts/items/equipment_rules.gd")
const CONSUMABLES := {"herb": {"price": 2, "sell": 1}, "potion": {"price": 5, "sell": 2}}

static func stock() -> Array:
	return Gear.ITEMS.keys() + CONSUMABLES.keys()

static func buy(id: String, inventory: Dictionary, owned: Array) -> Dictionary:
	var gear := Gear.ITEMS.has(id)
	var definition: Dictionary = Gear.ITEMS.get(id, CONSUMABLES.get(id, {}))
	if definition.is_empty() or int(inventory.get("coin", 0)) < definition.price:
		return {}
	if (gear and id in owned) or (not gear and int(inventory.get(id, 0)) >= 999):
		return {}
	var items := inventory.duplicate()
	var gear_owned := owned.duplicate()
	items["coin"] = int(items.get("coin", 0)) - definition.price
	if gear:
		gear_owned.append(id)
	else:
		items[id] = int(items.get(id, 0)) + 1
	return {"inventory": items, "owned": gear_owned}

static func sell(id: String, inventory: Dictionary, owned: Array, equipped: Dictionary) -> Dictionary:
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
