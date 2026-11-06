extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/nature/nature_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var human := Rules.defaults()
	check(human.kind == "human" and human.form == "human" and human.history.is_empty(), "new character starts ordinary and untransformed")
	check(Rules.transition(human, "vampire", true).is_empty(), "nature cannot change before informed invitation")
	var offered := Rules.transition(human, "invite", true)
	check(not offered.is_empty(), "completed prior episode can open a voluntary offer")
	var prepared := human.duplicate(true)
	prepared.stage = 2
	var accepted := Rules.transition(prepared, "vampire", true)
	check(accepted.get("kind") == "vampire" and accepted.get("history") == ["vampire"], "explicit completed choice records nature and lasting history")
	var pledge := Rules.transition(prepared, "human", true)
	check(pledge.get("gift") == "oath" and pledge.get("kind") == "human", "declining transformation grants a distinct human specialization")
	var vampire := {"kind": "vampire", "form": "human", "blood": 50.0, "resolve": 100.0, "stage": 3, "history": ["vampire"], "cure": 0, "gift": "blood"}
	check(Rules.valid(vampire), "coherent vampire state is valid")
	var invalid := vampire.duplicate(true)
	invalid.history = []
	check(not Rules.valid(invalid), "transformed nature requires its recorded history")
	invalid = vampire.duplicate(true)
	invalid.blood = NAN
	check(not Rules.valid(invalid), "resource rejects nonfinite input")
	var battle := Rules.shift(vampire)
	check(battle.get("form") == "battle" and battle.get("blood") == 30, "entering combat form spends blood once")
	vampire.blood = 1
	vampire.form = "battle"
	var drained := Rules.advance(vampire, 1)
	check(drained.form == "human" and drained.blood == 0, "empty resource always returns an accessible humanoid shape")
	vampire = drained
	check(Rules.sunlight(vampire, 1, false) > 1 and Rules.sunlight(vampire, 1, true) == 1 and Rules.sunlight(human, 1, false) == 1, "sunlight weakness depends on nature and outdoor exposure")
	check(not Rules.can_spell(vampire, "light") and not Rules.can_spell(vampire, "heal") and Rules.can_spell(vampire, "frost"), "first supernatural path trades sacred spells for its own capabilities")
	check(Rules.transition(vampire, "human", true).is_empty(), "permanent nature cannot be switched by reusing the initial choice")
	vampire.blood = 50
	check(Rules.regeneration(vampire, 1185) == 1.5, "vampire regeneration preserves its previous dusk boundary")
	print("Nature rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
