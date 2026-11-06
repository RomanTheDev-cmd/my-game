extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/combat/boss_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Rules.phase(420, 420) == 1 and Rules.phase(211, 420) == 1, "first phase remains above half health")
	check(Rules.phase(210, 420) == 2 and Rules.phase(1, 420) == 2, "half health switches the boss behavior")
	check(Rules.phase(0, 420) == 0 and Rules.phase(NAN, 420) == 0 and Rules.phase(10, 0) == 0, "invalid or defeated boss cannot select active phase")
	check(Rules.attack(1, 0).kind == "sweep" and Rules.attack(1, 1).kind == "charge", "first phase alternates close and committed directional attack")
	check(Rules.attack(2, 1).kind == "pulse" and Rules.attack(2, 2).kind == "charge" and Rules.attack(2, 3).kind == "sweep", "second phase adds radial pressure and cycles deterministically")
	check(Rules.attack(1, 0).windup >= 0.8 and Rules.attack(2, 1).windup >= 1.0, "both close and radial attacks leave visible warning time")
	check(Rules.attack(2, 2).recovery >= 1.0, "committed attack leaves a counterattack window")
	check(Rules.hits("sweep", Vector2(90, 0), Vector2.RIGHT), "sweep reaches target in front")
	check(not Rules.hits("sweep", Vector2(-20, 0), Vector2.RIGHT) and not Rules.hits("sweep", Vector2(110, 0), Vector2.RIGHT), "behind and outside reach evade the locked cone")
	check(Rules.hits("pulse", Vector2(0, -130), Vector2.RIGHT) and not Rules.hits("pulse", Vector2(141, 0), Vector2.RIGHT), "radial attack covers all angles but leaves an escape boundary")
	check(not Rules.hits("missing", Vector2.ZERO, Vector2.RIGHT), "unknown attacks do not deal damage")
	check(Rules.damage_multiplier("recover") > Rules.damage_multiplier("windup"), "recovery rewards a timed counterattack over attacking armor")
	print("Boss rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
