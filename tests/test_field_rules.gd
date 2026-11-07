extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/magic/field_rules.gd")
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Fixture = preload("res://tests/support/field_fixture.gd")
const Regions = preload("res://scripts/world/region_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func act(state: Dictionary, id: String, method: String, skills: Dictionary = {}, cooldown: float = 0, recharge: float = 0) -> Dictionary:
	return Rules.resolve(state.nature, skills, state.gathered, state.opened, state.vitals, state.minutes, id, method, cooldown, recharge)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Regions.get_region("haven").get("field_sites", {}).size() == 3, "authored field magic targets exist in the actual region")
	var session := root.get_node("Session")
	session.fresh()
	var bad: Dictionary = session.snapshot(Vector2(410, 490))
	bad.gathered.append("field:sluice:step:1")
	check(not session.Store.validate(bad), "orphan field progress is rejected by the complete save boundary")
	Fixture.ready(session)
	var old: Dictionary = session.snapshot(Vector2(440, 600), {"health": 54.0, "stamina": 100.0, "mana": 100.0})
	check(session.Store.validate(old) and session.Store.migrate(old) == old and old.version == 9, "existing v9 needs no reset or extra fields for environmental work")
	var state := {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "vitals": old.vitals.duplicate(), "minutes": session.world_state.minutes}
	var accepted := act(state, "accept", "accept")
	check(not accepted.is_empty() and Rules.stage(accepted.gathered, accepted.opened) == 1 and Rules.stage(state.gathered, state.opened) == 0, "voluntary acceptance returns new progress without mutating caller")
	check(act(accepted, "accept", "accept").is_empty() and act(accepted, "report", "report").is_empty(), "acceptance and reward cannot be repeated or skipped")
	var frost := act(accepted, "sluice", "frost")
	check(Rules.progress(frost.gathered, "sluice") == 1 and frost.vitals.mana == 76 and "field_sluice" not in frost.opened, "base frost pays combat profile cost for partial physical work")
	check(act(frost, "sluice", "frost", {}, 0.2).is_empty(), "field cast respects the ordinary spell cooldown")
	var mixed := act(frost, "sluice", "manual")
	check(Rules.progress(mixed.gathered, "sluice") == 3 and mixed.vitals.stamina == 70 and mixed.vitals.health == 54 and mixed.vitals.mana == 76 and mixed.minutes == 610, "manual completion pays stamina and time without healing or mana refill")
	check("field:sluice:method:frost" in mixed.gathered and "field:sluice:method:manual" in mixed.gathered and "field_sluice" in mixed.opened and act(mixed, "sluice", "manual").is_empty(), "mixed methods retain history and cannot farm a completed mechanism")
	for rank in range(3):
		var skills := {"frost": rank, "mending": rank, "aegis": rank}
		var chilled := act(accepted, "sluice", "frost", skills)
		check(Rules.progress(chilled.gathered, "sluice") == rank + 1 and chilled.vitals.mana == [76, 74, 72][rank], "learned frost power and cost affect actual work")
		var healed := act(accepted, "garden", "heal", skills)
		check(Rules.progress(healed.gathered, "garden") == rank + 1 and healed.vitals.mana == [65, 60, 55][rank] and healed.vitals.health == 54, "learned healing targets the garden rather than caster health")
		var shielded := act(accepted, "relay", "aegis", skills)
		check(Rules.progress(shielded.gathered, "relay") == rank + 1 and shielded.vitals.mana == [72, 68, 64][rank] and shielded.recharge == [10, 9, 8][rank], "protective mastery changes work and consumes real ward recharge")
	check(Rules.power("relay", {"ward": 2}) == 2 and act(accepted, "relay", "aegis", {}, 0, 0.1).is_empty(), "existing defensive training contributes and ward recharge cannot be bypassed")
	var full := accepted.duplicate(true)
	full.vitals.health = 100
	check(not act(full, "garden", "heal").is_empty(), "full-health hero can heal an external target")
	var low := accepted.duplicate(true)
	low.vitals.mana = 23
	low.vitals.stamina = 29
	check(act(low, "sluice", "frost").is_empty() and act(low, "sluice", "manual").is_empty(), "both methods enforce advertised resources")
	check(act(accepted, "garden", "frost").is_empty() and act(accepted, "unknown", "manual").is_empty(), "wrong spell and unknown target cannot mutate progress")
	var all_done := accepted.duplicate(true)
	for id in Rules.SPELLS:
		all_done = act(all_done, id, "manual")
	check(Rules.stage(all_done.gathered, all_done.opened) == 2 and all_done.vitals.stamina == 10 and all_done.minutes == 630, "ordinary human can finish every required place without any supernatural spell")
	var report := act(all_done, "report", "report")
	check(report.xp == 80 and Rules.stage(report.gathered, report.opened) == 3 and act(report, "report", "report").is_empty(), "completed places grant one recorded report and experience")
	for kind in ["vampire", "werewolf"]:
		Fixture.ready(session, kind)
		state = {"nature": session.nature.duplicate(true), "gathered": session.gathered.duplicate(), "opened": session.opened.duplicate(), "vitals": old.vitals.duplicate(), "minutes": 600.0}
		accepted = act(state, "accept", "accept")
		var before := accepted.duplicate(true)
		var manual := act(accepted, "garden", "manual")
		check(not manual.is_empty() and accepted == before, "each nature can complete an ordinary alternative without mutating input")
		if kind == "vampire":
			check(act(accepted, "garden", "heal").is_empty() and is_equal_approx(manual.nature.blood, 79.6), "vampire cannot bypass holy restriction and manual time charges real hunger")
		else:
			check(manual.nature.resolve == 88 and not act(accepted, "garden", "heal").is_empty(), "ordinary wolf-path body follows its own timed recovery and ordinary casting")
		accepted.nature = Nature.shift(accepted.nature, "battle" if kind == "vampire" else "wolf")
		check(act(accepted, "sluice", "manual").is_empty() and act(accepted, "sluice", "frost").is_empty(), "temporary form blocks both precise hand work and ordinary magic")
	Fixture.ready(session)
	for flag in ["field:unknown", "field:reported", "field:sluice:step:2", "field_report"]:
		bad = session.snapshot(Vector2(440, 600))
		bad.gathered.append(flag)
		check(not session.Store.validate(bad), "unknown orphan out-of-order or misplaced progress rejects damaged save")
	for flag in ["field:accepted", "field_unknown", "field_sluice", "field_garden_supplies", "field_report"]:
		bad = session.snapshot(Vector2(440, 600))
		bad.opened.append(flag)
		check(not session.Store.validate(bad), "misplaced unopened or prerequisite-less result cannot enter a save")
	for flag in ["field:accepted", "field_unknown", "field_sluice"]:
		bad = session.snapshot(Vector2(440, 600))
		bad.defeated.append(flag)
		check(not session.Store.validate(bad), "reserved work flags cannot bypass validation in defeated enemies")
	bad = session.snapshot(Vector2(440, 600))
	bad.gathered.append_array(["field:accepted", "field:sluice:step:1", "field:sluice:method:manual"])
	check(not session.Store.validate(bad), "manual work cannot be recorded as incomplete progress")
	print("Field rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
