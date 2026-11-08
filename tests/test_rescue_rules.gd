extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/rescue_rules.gd")
const Fixture = preload("res://tests/support/rescue_fixture.gd")
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
	data.gathered.append("rescue:freed")
	check(not session.Store.validate(data), "saved release without completed preparation, chosen help and physical cut cannot be accepted")
	check(Fixture.ready(session), "genuine earlier episodes and preparation create a valid predecessor save")
	var old: Dictionary = session.snapshot(Vector2(650, 820))
	check(session.Store.validate(old) and session.Store.migrate(old) == old, "old v9 needs no new rescue fields or reset")
	var state := snapshot(session)
	var missing := state.duplicate(true)
	missing.opened.erase("preparation_report")
	check(act(missing, "accept").is_empty() and act(state, "tools").is_empty(), "preparation report and independent acceptance cannot be skipped")
	state = step(state, "accept")
	check(act(state, "accept").is_empty() and act(state, "blood").is_empty() and act(state, "scent").is_empty(), "human begins without forced nature and cannot fake special approaches")
	state = step(state, "tools")
	check(act(state, "tools").is_empty() and act(state, "manual_north").is_empty() and act(state, "light_north", true).is_empty(), "method cannot repeat and cuts require actual safe context/impact")
	var north := act(state, "manual_north", true)
	check(north.vitals.stamina == 82 and north.vitals.health == 64 and north.vitals.mana == 90, "ordinary work spends18 effort and never heals or fills magic")
	state = step(state, "manual_north", true)
	check(act(state, "manual_north", true).is_empty() and act(state, "free").is_empty(), "one cut cannot repeat or release a participant early")
	state = step(state, "light_south", true, true)
	check(Rules.disconnected(state.flags) and act(state, "light_north", true, true).is_empty(), "actual light impact may complete the other physical support exactly once")
	state = step(state, "free")
	check(act(state, "safe").is_empty() and act(state, "report").is_empty(), "release alone does not replace physical arrival or final report")
	state = step(state, "safe", false, false, true)
	var paid := act(state, "report")
	check(paid.xp == 120 and paid.trust == {"roadfolk": 2, "tenders": 1}, "successful ordinary rescue gets its one advertised experience/relation result")
	state = step(state, "report")
	check(act(state, "report").is_empty() and act(state, "keep").is_empty(), "no repeat reward or unchosen blood relationship after ordinary work")
	state = step(state, "rest")
	check(act(state, "rest").is_empty() and "rescue:rested" in state.flags, "ordinary aftermath saves a separate one-time conversation")
	check(Fixture.ready(session, "vampire"), "voluntary blood approach starts from actual prior nature")
	var before_blood: float = session.nature.blood
	check(session.rescue_event("accept", Vector2(650, 820), {"health": 64.0, "stamina": 100.0, "mana": 90.0}) and session.rescue_event("blood", Vector2(1440, 650), {"health": 64.0, "stamina": 100.0, "mana": 90.0}), "voluntary actual blood approach is available to its nature")
	state = snapshot(session)
	check(session.nature.blood == before_blood - 20 and "rescue:blood_consent" in session.gathered, "reviewed blood support costs20 actual blood and records explicit consent")
	var cut := act(state, "manual_south", true)
	check(cut.vitals.stamina == 90 and cut.nature.blood == before_blood - 20, "blood support genuinely eases ordinary work without repaying or recharging blood")
	for event in ["manual_south", "manual_north", "free", "safe", "report"]: state = step(state, event, true, false, true)
	for choice in ["keep", "release"]:
		var rested := step(state, choice)
		check("rescue:boundary:" + choice in rested.flags and "rescue:rested" in rested.flags and act(rested, "keep").is_empty() and act(rested, "release").is_empty(), "each reviewed boundary gives a distinct permanent aftermath without repeat choices")
	check(Fixture.selected(session, "werewolf", "scent"), "voluntary scent approach is available after its actual history")
	state = snapshot(session)
	state.nature.form = "wolf"
	check(act(state, "claw_north").is_empty() and act(state, "manual_north", true).is_empty(), "wild body cannot substitute menu work or a nonexistent directed strike")
	cut = act(state, "claw_north", false, true)
	check(not cut.is_empty() and cut.nature.resolve == state.nature.resolve - 12 and cut.vitals.stamina == 100, "actual close claw impact spends12 resolve independently of stamina")
	var exhausted := state.duplicate(true)
	exhausted.nature.resolve = 12.0
	var last := act(exhausted, "claw_north", false, true)
	check(not last.is_empty() and last.nature.resolve == 0 and last.nature.form == "human" and Rules.Nature.valid(last.nature), "spending final12 resolve finishes the cut and safely returns ordinary body")
	for form in ["wolf", "hybrid"]:
		check(Fixture.selected(session, "werewolf", "scent"), "last-resource save starts from genuine voluntary scent method")
		if form == "hybrid":
			session.nature.gift = "wild_master"
			session.gathered.append("pack:mastery")
			session.opened.append_array(["thicket_cache_0", "thicket_cache_1", "thicket_cache_2"])
		session.nature.form = form
		session.nature.resolve = 12.0
		check(session.rescue_event("claw_north", Vector2(980, 400), {"health": 64.0, "stamina": 100.0, "mana": 90.0}, false, true), "last12 resolve is a valid recordable strike for " + form)
		check(session.load_saved() and session.nature.form == "human" and session.nature.resolve == 0 and Rules.cut(session.gathered, "north") == "claw", "real JSON retains completed final-resource strike and safe ordinary body")
	state.nature.kind = "human"
	state.nature.form = "human"
	state.nature.gift = "wild_scar"
	state.nature.stage = 4
	state.nature.cure = 3
	state.nature.resolve = 100.0
	check(not act(state, "manual_north", true).is_empty(), "changed human keeps past special preparation and ordinary completion")
	check(Fixture.ready(session), "ordinary fixture remains valid after alternatives")
	for corruption in ["unknown", "duplicate", "missing_accept", "no_preparation", "two_methods", "unconsented_blood", "wrong_history", "orphan_cut", "two_cuts", "early_free", "early_safe", "early_report", "early_rest", "two_boundaries", "wrong_opened", "wrong_defeated"]:
		data = session.snapshot(Vector2(650, 820))
		data.gathered.append("rescue:accepted")
		match corruption:
			"unknown": data.gathered.append("rescue:unused")
			"duplicate": data.gathered.append("rescue:accepted")
			"missing_accept":
				data.gathered.erase("rescue:accepted")
				data.gathered.append("rescue:method:tools")
			"no_preparation": data.opened.erase("preparation_report")
			"two_methods": data.gathered.append_array(Rules.METHODS)
			"unconsented_blood": data.gathered.append("rescue:method:blood")
			"wrong_history": data.gathered.append("rescue:method:scent")
			"orphan_cut": data.gathered.append("rescue:cut:north:manual")
			"two_cuts": data.gathered.append_array(["rescue:method:tools", "rescue:cut:north:manual", "rescue:cut:north:light"])
			"early_free": data.gathered.append("rescue:freed")
			"early_safe": data.gathered.append("rescue:safe")
			"early_report": data.opened.append("rescue_report")
			"early_rest": data.gathered.append("rescue:rested")
			"two_boundaries": data.gathered.append_array(["rescue:boundary:keep", "rescue:boundary:release"])
			"wrong_opened": data.opened.append("rescue:freed")
			"wrong_defeated": data.defeated.append("rescue:freed")
		check(not session.Store.validate(data), "save rejects inconsistent progress: " + corruption)
	print("Rescue rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func snapshot(session: Node) -> Dictionary:
	return {"nature": session.nature.duplicate(true), "flags": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate()}
func act(state: Dictionary, event: String, calm: bool = false, impact: bool = false, arrived: bool = false) -> Dictionary:
	return Rules.resolve(state.nature, state.flags, state.opened, state.inventory, {"health": 64.0, "stamina": 100.0, "mana": 90.0}, event, calm, impact, arrived)
func step(state: Dictionary, event: String, calm: bool = false, impact: bool = false, arrived: bool = false) -> Dictionary:
	var result := act(state, event, calm, impact, arrived)
	check(not result.is_empty(), "valid rescue transition: " + event)
	var next := state.duplicate(true)
	if not result.is_empty():
		next.nature = result.nature
		next.flags = result.gathered
		next.opened = result.opened
	return next
