extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Items = preload("res://scripts/items/inventory_rules.gd")
const Magic = preload("res://scripts/magic/magic_rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var ingredients := {"herb": 5, "coin": 12}
	var potion := Items.craft("potion", ingredients)
	check(potion.get("herb") == 2 and potion.get("potion") == 1, "recipe consumes exactly three herbs and creates one potion")
	check(ingredients == {"herb": 5, "coin": 12}, "craft does not partially mutate source")
	check(potion.get("coin") == 12, "craft preserves unrelated inventory")
	check(Items.craft("potion", {"herb": 2}).is_empty(), "insufficient ingredients cannot craft")
	check(Items.craft("unknown", ingredients).is_empty(), "unknown recipe rejected")
	check(Items.craft("potion", {"herb": 5, "potion": 999}).is_empty(), "full output stack cannot destroy ingredients")
	var consumed := Items.consume("potion", potion)
	check(consumed.get("potion") == 0 and potion.get("potion") == 1, "consume removes one item without mutating source")
	check(Items.consume("potion", consumed).is_empty(), "empty stack cannot go negative")
	check(Items.consume("lantern", {"lantern": 1}).is_empty(), "quest item cannot be consumed as potion")
	var healed := Magic.cast("heal", 80, 60, 0)
	check(healed.get("health") == 100 and healed.get("mana") == 25, "heal caps health and charges full cost")
	check(Magic.cast("heal", 100, 60, 0).is_empty(), "full health does not consume healing magic")
	check(Magic.cast("light", 100, 17, 0).is_empty(), "insufficient mana prevents attack spell")
	check(Magic.cast("light", 100, 50, 0.2).is_empty(), "cooldown prevents repeat casting")
	check(Magic.cast("light", 0, 50, 0).is_empty(), "dead actor cannot cast")
	var light := Magic.cast("light", 100, 50, 0)
	check(light.get("mana") == 32 and light.get("damage") == 24, "light bolt has consistent cost and damage")
	check(Magic.cast("unknown", 100, 100, 0).is_empty(), "unknown spell rejected")
	print("Items and magic rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
