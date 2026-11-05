extends SceneTree
const Gear = preload("res://scripts/items/equipment_rules.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var owned: Array = Gear.DEFAULT_OWNED.duplicate()
	var worn: Dictionary = Gear.DEFAULT_EQUIPPED.duplicate()
	var money := {"coin": 20, "herb": 3}
	check(Gear.valid(owned, worn), "starter equipment is valid")
	check(Gear.equip("iron_sword", owned, worn).is_empty(), "cannot equip unowned item")
	var bought := Trade.buy("iron_sword", money, owned)
	check(bought.get("inventory", {}).get("coin") == 5 and "iron_sword" in bought.get("owned", []), "purchase charges price and grants ownership")
	check(money.coin == 20 and owned == Gear.DEFAULT_OWNED, "trade never partially mutates source state")
	check(Trade.buy("iron_sword", {"coin": 14}, owned).is_empty(), "insufficient funds cannot buy")
	check(Trade.sell("road_sword", money, owned, worn).is_empty(), "cannot sell equipped item")
	check(Trade.sell("lantern", {"lantern": 1}, owned, worn).is_empty(), "quest item cannot be sold")
	check(Trade.sell("herb", {"coin": 999, "herb": 1}, owned, worn).is_empty(), "full purse does not destroy sold item")
	var potion := Trade.buy("potion", money, owned)
	check(potion.get("inventory", {}).get("potion") == 1 and potion.get("inventory", {}).get("coin") == 15, "consumable purchase changes both stacks")
	owned.append_array(["polearm", "iron_shield", "chain"])
	var polearm := Gear.equip("polearm", owned, worn)
	check(polearm.get("weapon") == "polearm" and polearm.get("shield") == "", "two-handed weapon removes shield without losing ownership")
	check(Gear.equip("iron_shield", owned, polearm).is_empty(), "shield cannot be equipped over a two-handed weapon")
	var wrong := worn.duplicate()
	wrong.weapon = "chain"
	check(not Gear.valid(owned, wrong), "item cannot occupy incompatible slot")
	check(Trade.buy("polearm", money, owned).is_empty(), "unique gear cannot be bought twice")
	var loose := Trade.sell("chain", money, owned, worn)
	check(loose.get("inventory", {}).get("coin") == 27 and "chain" not in loose.get("owned", []), "selling loose gear credits currency and removes ownership")
	var sold := Trade.sell("potion", potion.get("inventory", {}), owned, worn)
	check(sold.get("inventory", {}).get("coin") == 17, "buying and reselling cannot generate currency")
	print("Equipment and trade checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
