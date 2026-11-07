extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/forest_rules.gd")
const ForestFixture = preload("res://tests/support/forest_fixture.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
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
	check(Regions.valid("woodroad"), "next campaign section exists as an actual region")
	var session := root.get_node("Session")
	Fixture.ready(session)
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("forest:step:0:work")
	check(not session.Store.validate(bad), "orphan forest road progress is rejected before adding a new episode")
	check(ForestFixture.ready(session, "human", false), "main commitment fixture is a valid real save without optional content")
	var before: Dictionary = session.snapshot(Vector2(410, 490))
	check(session.Store.validate(before) and session.Store.migrate(before) == before and "story_lake_report" not in session.opened, "regional order remains free and old v9 needs no new fields")
	var state := {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "vitals": {"health": 64.0, "mana": 90.0, "stamina": 100.0}}
	var started := act(state, session.inventory, "accept")
	check(Rules.stage(started.gathered, started.opened) == 1 and "forest:accepted" not in state.gathered, "separate acceptance preserves ordinary nature and does not mutate input")
	check(act(started, session.inventory, "accept").is_empty() and act(state, session.inventory, "work").is_empty(), "acceptance cannot be duplicated or skipped")
	var brief := act(started, session.inventory, "aid_brief")
	check(brief.vitals.stamina == 85 and brief.vitals.health == 64 and Rules.AIDS[0] in brief.gathered, "common optional orientation has a finite real price without healing")
	check(act(brief, session.inventory, "aid_brief").is_empty(), "optional orientation is one-time and cannot stack")
	var repaired := act(started, session.inventory, "work")
	check(Rules.progress(repaired.gathered) == 1 and repaired.vitals.stamina == 88 and Rules.PASSAGE not in repaired.opened, "one work step consumes its own stamina and does not open the road early")
	check(act(repaired, session.inventory, "aid_brief").is_empty() and act(repaired, session.inventory, "watch").is_empty(), "late briefing and early outcome cannot skip the walking sequence")
	for i in 2: repaired = act(repaired, session.inventory, "work")
	check(Rules.stage(repaired.gathered, repaired.opened) == 2 and repaired.vitals.stamina == 64 and Rules.PASSAGE in repaired.opened, "three sequential manual steps open the passage with finite stamina")
	check(act(repaired, session.inventory, "work").is_empty(), "finished shared work cannot be farmed")
	for event in ["commons", "watch"]:
		var report := act(repaired, session.inventory, event)
		check(report.xp == 90 and Rules.stage(report.gathered, report.opened) == 3 and "forest:outcome:" + event in report.gathered, "each reviewed outcome has one lasting result and reward")
		check(act(report, session.inventory, "commons").is_empty() and act(report, session.inventory, "watch").is_empty(), "outcome cannot be claimed or changed twice")
	for kind in ["vampire", "werewolf"]:
		check(ForestFixture.ready(session, kind), "nature history fixture remains valid")
		state = {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "vitals": {"health": 64.0, "mana": 90.0, "stamina": 100.0}}
		started = act(state, session.inventory, "accept")
		check(not act(started, session.inventory, "work").is_empty(), "all natures retain the common work route")
		if kind == "vampire":
			var aided := act(started, session.inventory, "aid_blood")
			check(aided.nature.blood == 65 and aided.vitals.mana == 80 and aided.vitals.stamina == 100, "voluntary blood aid has its own actual reserve and magic cost")
			check(act(aided, session.inventory, "aid_brief").is_empty(), "blood aid cannot be stacked with the equally useful common alternative")
			started.nature.blood = 24
			check(act(started, session.inventory, "aid_blood").is_empty(), "blood aid reserves the promised hunger minimum")
		else:
			check(act(started, session.inventory, "howl").is_empty(), "wolf approach requires the actual wolf body")
			started.nature.form = "wolf"
			var answered := act(started, session.inventory, "howl")
			check(answered.nature.resolve == 68 and answered.vitals.stamina == 100 and Rules.progress(answered.gathered) == 1, "actual wolf voice has a distinct price and persistent completed step")
			check(act(started, session.inventory, "work").is_empty(), "animal body cannot silently perform precise human work")
	check(ForestFixture.ready(session), "completed previous episode fixture is valid")
	for corruption in ["missing_accept", "orphan_step", "skipped_step", "double_method", "bad_history", "two_aids", "wrong_aid_history", "early_gate", "orphan_report", "double_outcome", "missing_gate", "unknown", "wrong_opened", "wrong_defeated"]:
		bad = session.snapshot(Vector2(410, 490))
		bad.gathered.append("forest:accepted")
		match corruption:
			"missing_accept": bad.gathered.erase("story:accepted")
			"orphan_step":
				bad.gathered.erase("forest:accepted")
				bad.gathered.append("forest:step:0:work")
			"skipped_step": bad.gathered.append("forest:step:1:work")
			"double_method": bad.gathered.append_array(["forest:step:0:work", "forest:step:0:howl"])
			"bad_history": bad.gathered.append("forest:step:0:howl")
			"two_aids": bad.gathered.append_array(Rules.AIDS)
			"wrong_aid_history": bad.gathered.append(Rules.AIDS[1])
			"early_gate": bad.opened.append(Rules.PASSAGE)
			"orphan_report": bad.opened.append(Rules.REPORT)
			"double_outcome": bad.gathered.append_array(Rules.OUTCOMES)
			"missing_gate": bad.gathered.append_array(["forest:step:0:work", "forest:step:1:work", "forest:step:2:work"])
			"unknown": bad.gathered.append("forest:unknown")
			"wrong_opened": bad.opened.append("forest:accepted")
			"wrong_defeated": bad.defeated.append(Rules.PASSAGE)
		check(not session.Store.validate(bad), "inconsistent forest save is rejected: " + corruption)
	print("Forest rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)

func act(state: Dictionary, inventory: Dictionary, event: String) -> Dictionary:
	return Rules.resolve(state.nature, state.gathered, state.opened, inventory, state.vitals, event)
