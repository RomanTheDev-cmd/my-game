extends RefCounted

# Events are emitted by gameplay; screens never assign quest state or inventory.
const GRAPH := {0: {"accept": 1}, 1: {"found": 2}, 2: {"turn_in": 3}, 3: {}}

static func transition(stage: int, inventory: Dictionary, event: String) -> Dictionary:
	if not GRAPH.has(stage) or not GRAPH[stage].has(event):
		return {}
	if event == "turn_in" and inventory.get("lantern", 0) != 1:
		return {}
	var next_inventory := inventory.duplicate(true)
	if event == "found":
		next_inventory["lantern"] = 1
	elif event == "turn_in":
		next_inventory.erase("lantern")
		next_inventory["coin"] = mini(999, int(next_inventory.get("coin", 0)) + 12)
	return {"stage": GRAPH[stage][event], "inventory": next_inventory}

const AID_GRAPH := {0: {"accept": 1}, 1: {"herbs": 2, "coins": 2, "magic": 2}, 2: {}}

static func aid_transition(stage: int, inventory: Dictionary, mana: float, event: String) -> Dictionary:
	if not AID_GRAPH.has(stage) or not AID_GRAPH[stage].has(event):
		return {}
	var result := inventory.duplicate(true)
	var remaining := mana
	if event == "herbs":
		if int(result.get("herb", 0)) < 3:
			return {}
		result["herb"] = int(result.herb) - 3
	elif event == "coins":
		if int(result.get("coin", 0)) < 8:
			return {}
		result["coin"] = int(result.coin) - 8
	elif event == "magic":
		if mana < 35:
			return {}
		remaining -= 35
	return {"stage": AID_GRAPH[stage][event], "inventory": result, "mana": remaining}
