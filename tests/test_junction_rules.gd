extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/junction_rules.gd")
const Fixture = preload("res://tests/support/junction_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Regions.valid("rotunda"), "common campaign node has an actual explorable location")
	var session := root.get_node("Session")
	session.fresh()
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("junction:proof")
	check(not session.Store.validate(bad), "unearned common evidence cannot enter a valid save")
	check(Fixture.ready(session), "three genuine regional reports form a valid common-node fixture")
	var old: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(old) and session.Store.migrate(old) == old, "old v9 needs no new common-node fields or reset")
	var state := {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
	for missing in ["story_lake_report", "forest_report", "city_report"]:
		var partial := state.duplicate(true)
		partial.opened.erase(missing)
		check(act(partial, "accept").is_empty(), "each actual regional report is independently required: " + missing)
	var accepted := step(state, "accept")
	check("junction:accepted" in accepted.flags and "junction:accepted" not in state.flags, "invitation is separate and does not mutate input")
	check(act(accepted, "accept").is_empty() and act(accepted, "map").is_empty(), "invitation cannot repeat or skip the living participant")
	var mapped := step(step(accepted, "hear"), "map")
	check(Rules.stage(mapped.flags, mapped.opened) == 2 and act(mapped, "prove", 3).is_empty(), "records alone cannot produce an unsafe or unprepared measurement")
	var manual := step(mapped, "manual")
	check(manual.vitals.stamina == 80 and manual.vitals.mana == 90 and manual.vitals.health == 64, "manual isolation spends only the advertised effort and preserves wounds")
	check(act(manual, "manual").is_empty() and act(manual, "aegis").is_empty(), "persistent isolation cannot be charged or replaced twice")
	check(act(manual, "prove", 2.99).is_empty() and act(manual, "prove", NAN).is_empty(), "short or invalid elapsed measurement cannot manufacture proof")
	var proof := step(manual, "prove", 3)
	check(Rules.stage(proof.flags, proof.opened) == 3 and act(proof, "prove", 3).is_empty(), "real threshold unlocks exactly one retained proof")
	check(act(proof, "public").is_empty(), "physical measurement cannot replace hearing the participant explain its common cause")
	proof = step(proof, "explain")
	for event in ["public", "private"]:
		var result := act(proof, event)
		check(result.xp == 80 and Rules.stage(result.gathered, result.opened) == 4 and result.trust == ({"roadfolk": 2} if event == "public" else {"wardens": 2}), "each reviewed information choice has one distinct relation consequence")
		var done := step(proof, event)
		check(act(done, "public").is_empty() and act(done, "private").is_empty(), "completion cannot duplicate experience or change to another outcome")
	var magic := act(mapped, "aegis")
	check(magic.vitals.mana == 62 and magic.vitals.stamina == 100 and magic.cooldown == 0.8 and magic.recharge == 10, "base magic isolation uses actual aegis resource and readiness prices")
	var learned := act(mapped, "aegis", 0, {"aegis": 2})
	check(learned.vitals.mana == 54 and learned.recharge == 8, "learned profile changes actual isolation cost and recharge")
	check(act(mapped, "aegis", 0, {}, 0.1).is_empty() and act(mapped, "aegis", 0, {}, 0, 0.1).is_empty(), "ordinary magic cooldown and recharge cannot be bypassed by external casting")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.ready(session, kind), "each voluntary nature retains valid regional history")
		state = {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
		mapped = step(step(step(state, "accept"), "hear"), "map")
		check(not act(mapped, "manual").is_empty() and not act(mapped, "aegis").is_empty(), "all natures retain both common preparation routes in ordinary body")
		mapped.nature.form = "battle" if kind == "vampire" else "wolf"
		check(act(mapped, "manual").is_empty() and act(mapped, "aegis").is_empty(), "temporary body cannot bypass precise safe preparation")
	check(Fixture.ready(session), "human save fixture remains valid")
	for corruption in ["unknown", "orphan_heard", "map_before_heard", "two_methods", "unprepared_proof", "early_choice", "orphan_report", "two_choices", "wrong_opened", "wrong_defeated", "duplicate", "unearned_explanation"]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered.append("junction:accepted")
		match corruption:
			"unknown": bad.gathered.append("junction:unknown")
			"orphan_heard":
				bad.gathered.erase("junction:accepted")
				bad.gathered.append("junction:heard")
			"map_before_heard": bad.gathered.append("junction:mapped")
			"two_methods": bad.gathered.append_array(["junction:heard", "junction:mapped"] + Rules.METHODS)
			"unprepared_proof": bad.gathered.append_array(["junction:heard", "junction:mapped", "junction:proof"])
			"early_choice": bad.gathered.append(Rules.CHOICES[0])
			"orphan_report": bad.opened.append(Rules.REPORT)
			"two_choices": bad.gathered.append_array(Rules.CHOICES)
			"wrong_opened": bad.opened.append("junction:accepted")
			"wrong_defeated": bad.defeated.append(Rules.REPORT)
			"duplicate": bad.gathered.append("junction:accepted")
			"unearned_explanation": bad.gathered.append("junction:explained")
		check(not session.Store.validate(bad), "unreachable common evidence state rejected: " + corruption)
	print("Junction rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func act(state: Dictionary, event: String, measured: float = 0, skills: Dictionary = {}, cooldown: float = 0, recharge: float = 0) -> Dictionary:
	return Rules.resolve(state.nature, skills, state.flags, state.opened, state.inventory, {"health": 64.0, "stamina": 100.0, "mana": 90.0}, event, cooldown, recharge, measured)
func step(state: Dictionary, event: String, measured: float = 0) -> Dictionary:
	var result := act(state, event, measured)
	return {"nature": state.nature.duplicate(true), "flags": result.gathered, "opened": result.opened, "inventory": state.inventory.duplicate(), "vitals": result.vitals}
