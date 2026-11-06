extends RefCounted
const TENDER_HERBS := 2
const RECIPES := {"potion": {"herb": 3}}

static func craft(id: String, inventory: Dictionary) -> Dictionary:
	if not RECIPES.has(id) or int(inventory.get(id, 0)) >= 999:
		return {}
	for ingredient in RECIPES[id]:
		if int(inventory.get(ingredient, 0)) < RECIPES[id][ingredient]:
			return {}
	var result := inventory.duplicate(true)
	for ingredient in RECIPES[id]:
		result[ingredient] = int(result[ingredient]) - RECIPES[id][ingredient]
	result[id] = int(result.get(id, 0)) + 1
	return result

static func consume(id: String, inventory: Dictionary) -> Dictionary:
	if id != "potion" or int(inventory.get(id, 0)) < 1:
		return {}
	var result := inventory.duplicate(true)
	result[id] = int(result[id]) - 1
	return result

static func brew_with_tender(inventory: Dictionary, trust: int) -> Dictionary:
	if trust < 2 or int(inventory.get("potion", 0)) >= 999:
		return {}
	var cost := TENDER_HERBS
	if int(inventory.get("herb", 0)) < cost:
		return {}
	var result := inventory.duplicate()
	result["herb"] = int(result.herb) - cost
	result["potion"] = int(result.get("potion", 0)) + 1
	return result
