extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/campaign_rules.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
const NatureFixture = preload("res://tests/support/nature_fixture.gd")
const PackFixture = preload("res://tests/support/pack_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func act(state: Dictionary, event: String) -> Dictionary:
	return Rules.resolve(state.nature, 3, state.gathered, state.opened, state.inventory, state.vitals, event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Regions.valid("terrace") and Regions.exits("lake").any(func(exit): return exit.destination == "terrace"), "campaign exploration region has a real connection")
	var session := root.get_node("Session")
	session.fresh()
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("story:lake:heard")
	check(not session.Store.validate(bad), "orphan campaign evidence cannot enter a valid save")
	Fixture.ready(session)
	var old: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(old) and session.Store.migrate(old) == old and session.opened.is_empty(), "main episode needs neither optional episodes nor a v9 reset")
	var state := {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate(), "vitals": {"health": 51.0, "mana": 70.0, "stamina": 100.0}}
	var met := act(state, "greet")
	check(met.inventory.story_tool == 1 and Rules.stage(met.gathered, met.opened) == 1 and not state.inventory.has("story_tool"), "first encounter grants a lasting tool without imposing a task or mutating input")
	check(act(met, "greet").is_empty() and act(state, "accept").is_empty(), "meeting and task cannot be duplicated or skipped")
	var accepted := act(met, "accept")
	var prepared := act(act(accepted, "hear"), "inspect")
	check(Rules.stage(prepared.gathered, prepared.opened) == 3 and not act(act(accepted, "inspect"), "hear").is_empty(), "two physical sources are accepted in either order")
	check(act(prepared, "manual").is_empty(), "unconfigured physical mechanism cannot grant evidence")
	var dial := act(prepared, "turn_b")
	check(Rules.positions(dial.gathered) == [0, 1, 0] and dial.vitals.stamina == 98, "a turn changes only its own retained dial and advertised stamina")
	dial = act(act(dial, "turn_b"), "turn_b")
	check(Rules.positions(dial.gathered) == [0, 0, 0] and not dial.gathered.any(func(flag): return flag.begins_with("story:dial:b:")), "dial wraps to canonical absent zero rather than accumulating incompatible flags")
	var solved := act(act(act(prepared, "turn_a"), "turn_b"), "turn_b")
	check(Rules.positions(solved.gathered) == [1, 2, 0] and solved.vitals.stamina == 94, "authored clue configuration is reachable with ordinary earned resources")
	var evidence := act(solved, "manual")
	check(Rules.stage(evidence.gathered, evidence.opened) == 4 and evidence.inventory.story_tool == 1 and evidence.vitals.health == 51, "ordinary confirmation preserves tool and wounds and completes evidence once")
	check(act(evidence, "manual").is_empty() and act(evidence, "turn_a").is_empty(), "confirmed evidence cannot be farmed or invalidated by later dial movement")
	var report := act(evidence, "report_provision")
	check(report.xp == 80 and report.inventory.coin == 27 and report.trust == 1 and Rules.stage(report.gathered, report.opened) == 5, "one report grants actual experience currency and relation consequence")
	check(act(report, "report_share").is_empty(), "second outcome cannot be claimed after reporting")
	evidence.inventory.coin = 999
	var shared := act(evidence, "report_share")
	check(act(evidence, "report_provision").is_empty() and shared.xp == 80 and shared.inventory.coin == 999 and shared.trust == 2, "full wallet retains an explained story completion alternative without destroying money")
	var tired := prepared.duplicate(true)
	tired.vitals.stamina = 1
	check(act(tired, "turn_a").is_empty(), "dial movement requires actual available stamina")
	for kind in ["vampire", "werewolf"]:
		if kind == "vampire": NatureFixture.vampire(session)
		else: PackFixture.wolf(session)
		state = {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate(), "vitals": {"health": 51.0, "mana": 70.0, "stamina": 100.0}}
		prepared = act(act(act(act(state, "greet"), "accept"), "hear"), "inspect")
		check(not act(prepared, "turn_a").is_empty(), "both supernatural natures retain the ordinary instrument approach")
		if kind == "vampire":
			check(act(prepared, "blood").is_empty(), "blood approach cannot skip the witness's actual recorded consent")
			var agreed := act(prepared, "consent")
			var blood := act(agreed, "blood")
			check(Rules.stage(blood.gathered, blood.opened) == 4 and blood.nature.blood == 60 and blood.vitals.mana == 55, "consented blood approach has distinct actual costs without requiring dial solution")
			agreed.nature.blood = 29
			check(act(agreed, "blood").is_empty(), "blood approach reserves the promised remaining hunger resource")
		else:
			check(act(prepared, "scent").is_empty(), "tracking requires the actual wolf body")
			prepared.nature.form = "wolf"
			var tracked := act(prepared, "scent")
			check(Rules.stage(tracked.gathered, tracked.opened) == 4 and tracked.nature.resolve == 60 and tracked.vitals.mana == 70, "tracking pays its own reserve and preserves magic")
	Fixture.ready(session)
	for field in ["gathered", "opened", "defeated"]:
		bad = session.snapshot(Vector2(410, 490))
		bad[field].append("story:unknown")
		check(not session.Store.validate(bad), "unknown campaign namespace is rejected across save collections")
	bad = session.snapshot(Vector2(410, 490))
	bad.inventory.story_tool = 1
	check(not session.Store.validate(bad), "orphan mandatory tool cannot enter a save")
	bad.gathered.append("story:met")
	bad.inventory.story_tool = 0
	check(not session.Store.validate(bad), "mandatory gift cannot disappear after its meeting")
	var coherent := act(act(act(act(state_for(session), "greet"), "accept"), "hear"), "inspect")
	for corruption in ["duplicate_dial", "premature_method", "two_methods", "orphan_report", "missing_report_flag", "wrong_opened", "wrong_defeated"]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered = coherent.gathered.duplicate()
		bad.inventory = coherent.inventory.duplicate()
		match corruption:
			"duplicate_dial": bad.gathered.append_array(["story:dial:a:1", "story:dial:a:2"])
			"premature_method": bad.gathered.append("story:lake:method:manual")
			"two_methods": bad.gathered.append_array(["story:lake:method:manual", "story:lake:method:scent"])
			"orphan_report": bad.opened.append(Rules.REPORT)
			"missing_report_flag": bad.gathered.append("story:lake:report:share")
			"wrong_opened": bad.opened.append("story:lake:heard")
			"wrong_defeated": bad.defeated.append(Rules.REPORT)
		check(not session.Store.validate(bad), "inconsistent campaign state rejected: " + corruption)
	print("Campaign rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
func state_for(session: Node) -> Dictionary:
	return {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "inventory": session.inventory.duplicate(), "vitals": {"health": 51.0, "mana": 70.0, "stamina": 100.0}}
