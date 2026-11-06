extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Trade = preload("res://scripts/items/trade_rules.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	for merchant_trust in [-10, -3, -2, 0, 2, 3, 10]:
		for tender_trust in [2, 3, 10]:
			var inventory := {"coin": 100}
			for i in 2:
				inventory = Trade.buy("herb", inventory, [], merchant_trust).inventory
			inventory = Items.brew_with_tender(inventory, tender_trust)
			inventory = Trade.sell("potion", inventory, [], {}).inventory
			while int(inventory.get("herb", 0)) > 0:
				inventory = Trade.sell("herb", inventory, [], {}).inventory
			check(inventory.coin <= 100, "combined relationship perks cannot create unlimited money through buy-brew-resell loop")
	print("Faction economy checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
