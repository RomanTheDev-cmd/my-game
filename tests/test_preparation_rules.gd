extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/preparation_rules.gd")
const Fixture = preload("res://tests/support/preparation_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session := root.get_node("Session")
	session.fresh()
	var data: Dictionary = session.snapshot(Vector2(410, 490))
	data.gathered.append("prep:tested")
	check(not session.Store.validate(data), "preparation proof without prior shared episode, consent or physical rehearsal is rejected")
	check(Fixture.ready(session), "actual ordinary regional/common routes produce valid predecessor history")
	var old: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(old) and session.Store.migrate(old) == old, "prior v9 needs no new fields or reset for preparation")
	var state := {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
	var missing := state.duplicate(true)
	missing.opened.erase("junction_report")
	check(act(missing, "accept").is_empty() and act(state, "invite_witness").is_empty(), "common result and separate preparation acceptance are real prerequisites")
	state = step(state, "accept")
	check(act(state, "accept").is_empty() and act(state, "layout_lake").is_empty() and act(state, "prove", true).is_empty(), "acceptance cannot repeat or skip consent/configuration/rehearsal")
	for who in ["witness", "crafter"]:
		state = step(state, "invite_" + who)
		check(act(state, "invite_" + who).is_empty(), "consent is separate and cannot duplicate: " + who)
	for chosen in ["lake", "city"]:
		var planned := step(state, "layout_" + chosen)
		check(Rules.layout(planned.flags) == chosen and Rules.layout(state.flags) == "", "each distribution commits without mutating previous state")
		var swapped := step(planned, "layout_" + ("city" if chosen == "lake" else "lake"))
		check(Rules.layout(swapped.flags) != chosen and Rules.valid(swapped.flags, swapped.opened), "distribution is revisable before proof without contradictory post assignments")
	state = step(state, "layout_lake")
	for side in ["north", "south"]:
		check(Rules.angle(state.flags, side) == 0 and Rules.target(state.flags, side) == 1, "open/shared history explains an initially unconfigured physical support")
		var cycled := state.duplicate(true)
		for turn in 3: cycled = step(cycled, "tune_" + side)
		check(Rules.angle(cycled.flags, side) == 0 and Rules.valid(cycled.flags, cycled.opened), "three physical turns wrap without accumulating contradictory settings")
		state = step(state, "tune_" + side)
	check(Rules.configured(state.flags) and act(state, "prove").is_empty(), "configured supports are not proof of an actual walked route")
	var proved := step(state, "prove", true)
	check(Rules.stage(proved.flags, proved.opened) == 3 and act(proved, "layout_city").is_empty() and act(proved, "tune_south").is_empty(), "proven support positions remain stable rather than invalidating retained evidence")
	var result := act(proved, "report")
	check(result.xp == 60 and result.trust == {"roadfolk": 1, "wardens": 1} and result.vitals == {"health": 64.0, "stamina": 100.0, "mana": 90.0}, "readiness rewards once and does not heal, fill mana or consume unstated resources")
	var done := step(proved, "report")
	check(Rules.stage(done.flags, done.opened) == 4 and act(done, "report").is_empty(), "final readiness is permanent and cannot farm experience")
	for corruption in ["unknown", "duplicate", "missing_acceptance", "early_layout", "two_layouts", "two_angles", "unconfigured_proof", "orphan_report", "wrong_opened", "wrong_defeated"]:
		data = old.duplicate(true)
		data.gathered.append("prep:accepted")
		match corruption:
			"unknown": data.gathered.append("prep:unused")
			"duplicate": data.gathered.append("prep:accepted")
			"missing_acceptance":
				data.gathered.erase("prep:accepted")
				data.gathered.append("prep:consent:witness")
			"early_layout": data.gathered.append("prep:layout:lake_north")
			"two_layouts": data.gathered.append_array(Rules.RECRUITS + Rules.LAYOUTS)
			"two_angles": data.gathered.append_array(["prep:north:1", "prep:north:2"])
			"unconfigured_proof": data.gathered.append("prep:tested")
			"orphan_report": data.opened.append("preparation_report")
			"wrong_opened": data.opened.append("prep:tested")
			"wrong_defeated": data.defeated.append("prep:tested")
		check(not session.Store.validate(data), "save rejects inconsistent/reserved preparation progress: " + corruption)
	for choice in ["public", "private"]:
		for city in ["shared", "release"]:
			check(Fixture.configured(session, "human", choice, city), "each actual prior choice combination reaches preparation")
			check(Rules.target(session.gathered, "north") == (1 if choice == "public" else 2) and Rules.target(session.gathered, "south") == (1 if city == "shared" else 2) and Rules.configured(session.gathered), "prior choices genuinely change required physical settings, not only text")
	for kind in ["vampire", "werewolf"]:
		check(Fixture.configured(session, kind), "ordinary preparation is available after each voluntary nature")
		state = {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
		check(not act(state, "prove", true).is_empty(), "ordinary body retains common safe route for every nature")
		state.nature.form = "battle" if kind == "vampire" else "wolf"
		check(act(state, "prove", true).is_empty(), "temporary body cannot manufacture a precise ordinary-body rehearsal")
	print("Preparation rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func act(state: Dictionary, event: String, rehearsed: bool = false) -> Dictionary:
	return Rules.resolve(state.nature, state.flags, state.opened, state.inventory, {"health": 64.0, "stamina": 100.0, "mana": 90.0}, event, rehearsed)
func step(state: Dictionary, event: String, rehearsed: bool = false) -> Dictionary:
	var result := act(state, event, rehearsed)
	check(not result.is_empty(), "valid preparation transition: " + event)
	var next := state.duplicate(true)
	if not result.is_empty():
		next.flags = result.gathered
		next.opened = result.opened
	return next
