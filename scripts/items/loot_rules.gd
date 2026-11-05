extends RefCounted
const Gear = preload("res://scripts/items/equipment_rules.gd")

static func claim(chest: Dictionary, inventory: Dictionary, owned: Array, opened: Array, defeated: Array) -> Dictionary:
	if chest.get("id", "") == "" or chest.id in opened:
		return {}
	for required in chest.get("requires", []):
		if required not in defeated:
			return {}
	var items := inventory.duplicate()
	var gear := owned.duplicate()
	for id in chest.get("items", {}):
		var amount: int = int(chest.items[id])
		if amount < 0 or int(items.get(id, 0)) + amount > 999:
			return {}
		items[id] = int(items.get(id, 0)) + amount
	for id in chest.get("gear", []):
		if not Gear.ITEMS.has(id):
			return {}
		if id not in gear:
			gear.append(id)
	var claimed := opened.duplicate()
	claimed.append(chest.id)
	return {"inventory": items, "owned": gear, "opened": claimed}
