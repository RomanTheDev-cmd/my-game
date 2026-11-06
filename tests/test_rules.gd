extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	check(Rules.damage(20, 1, false, false) == 20, "normal incoming damage")
	check(Rules.damage(20, 1, true, false) == 5, "block absorbs 75 percent")
	check(Rules.damage(20, 1, false, true) == 0, "dodge invulnerability")
	check(Rules.damage(20, 0, false, false) == 12, "story reduces damage")
	check(Rules.damage(20, 2, false, false) == 27, "challenge increases damage")
	check(Rules.damage(-20, 1, false, false) == 0, "negative damage cannot heal")
	print("Checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
