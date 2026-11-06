extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/commission_rules.gd")
const Factions = preload("res://scripts/factions/faction_rules.gd")
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	var rep := Factions.defaults()
	check(Factions.valid(rep) and not Factions.trusted(rep, "wardens"), "neutral groups do not grant earned benefits")
	check(not Factions.valid({"roadfolk": 0, "wardens": 0.5, "tenders": 0}), "fractional relationship rejected")
	check(not Factions.valid({"roadfolk": 0, "wardens": INF, "tenders": 0}), "nonfinite relationship rejected")
	check(Factions.change({"roadfolk": 9, "wardens": -9, "tenders": 0}, {"roadfolk": 3, "wardens": -3}).get("roadfolk") == 10, "relationship changes clamp without overflowing")
	check(Factions.change(rep, {"unknown": 1}).is_empty(), "unknown relationship cannot be introduced")
	check(Rules.transition(Rules.defaults(), {}, 100, rep, "accept", 2, []).is_empty(), "next line cannot skip existing introductory task")
	var first := Rules.transition(Rules.defaults(), {}, 100, rep, "accept", 3, [])
	check(first.commission.stage == 1, "completed introduction unlocks new line")
	var survey := Rules.transition(first.commission, {}, 100, rep, "inspect_wheel", 3, [])
	check(survey.commission.stage == 1 and survey.commission.survey == ["wheel"], "one investigation cannot substitute for both sites")
	check(Rules.transition(survey.commission, {}, 100, rep, "inspect_wheel", 3, []).is_empty(), "revisiting same site does not advance progress")
	var ready := {"stage": 3, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "", "settlement": ""}
	check(Rules.valid(ready), "independent fixture describes complete preparation")
	for example in [["supply_purchase", {"coin": 8}, {"coin": 0}, []], ["supply_craft", {"scrap": 3}, {"scrap": 0}, []], ["supply_recover", {}, {}, ["workshop_1", "workshop_archer"]]]:
		var result := Rules.transition(ready, example[1], 100, rep, example[0], 3, example[3])
		check(not result.is_empty() and result.commission.stage == 4 and result.inventory == example[2], "alternative consumes only its required resources")
	check(ready.stage == 3 and ready.supply == "", "pure outcome leaves source state untouched")
	check(Rules.transition(ready, {"coin": 7}, 100, rep, "supply_purchase", 3, []).is_empty(), "partial payment does not grant resources")
	check(Rules.transition(ready, {"scrap": 2}, 100, rep, "supply_craft", 3, []).is_empty(), "incomplete assembly cannot consume partial materials")
	check(Rules.transition(ready, {}, 100, rep, "supply_recover", 3, ["workshop_1"]).is_empty(), "guarded supply requires all authored threats resolved")
	var prepared := ready.duplicate(true)
	prepared.stage = 4
	prepared.supply = "craft"
	for example in [["restore_shared", [2, 2, 2]], ["restore_wardens", [1, 3, -1]], ["restore_tenders", [1, -1, 3]]]:
		var result := Rules.transition(prepared, {}, 100, rep, example[0], 3, [])
		check(result.commission.stage == 5 and [result.reputation.roadfolk, result.reputation.wardens, result.reputation.tenders] == example[1], "selected settlement changes the actual three relationships")
		var report := Rules.transition(result.commission, {}, 100, result.reputation, "report", 3, [])
		check(report.commission.stage == 6 and report.inventory.coin == 16 and report.xp == 80, "report grants final reward once")
		check(Rules.transition(report.commission, report.inventory, 100, report.reputation, "report", 3, []).is_empty(), "completed line cannot repeat rewards")
	var final_state := prepared.duplicate(true)
	final_state.stage = 5
	final_state.settlement = "shared"
	check(Rules.transition(final_state, {"coin": 984}, 100, rep, "report", 3, []).is_empty(), "overflow rejects reward without completing or losing coins")
	check(Rules.transition(final_state, {"coin": 983}, 100, rep, "report", 3, []).get("inventory", {}).get("coin") == 999, "reward accepts exact purse capacity boundary")
	var distrusted := {"roadfolk": 0, "wardens": -10, "tenders": -10}
	check(Rules.transition(prepared, {}, 100, distrusted, "restore_shared", 3, []).is_empty(), "joint outcome respects relationship condition")
	check(not Rules.transition(prepared, {}, 100, distrusted, "restore_wardens", 3, []).is_empty(), "low trust still leaves a way to finish")
	for key in ["stage", "survey", "heard", "supply", "settlement"]:
		var bad := ready.duplicate(true)
		bad.erase(key)
		check(not Rules.valid(bad), "missing quest field rejected")
	var bad := prepared.duplicate(true)
	bad.survey = ["wheel", "wheel"]
	check(not Rules.valid(bad), "duplicate evidence cannot forge completed preparation")
	bad = Rules.defaults()
	bad.stage = 6
	check(not Rules.valid(bad), "completed stage without prerequisites rejected")
	# Explore all orders and alternatives with enough resources, independently expecting 2*2*3*3 endings.
	var queue := [{"state": Rules.defaults(), "items": {"coin": 100, "scrap": 3}, "rep": rep}]
	var visited := {}
	var endings := 0
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var signature := JSON.stringify(entry)
		if visited.has(signature):
			continue
		visited[signature] = true
		if entry.state.stage == 6:
			endings += 1
			continue
		var possible := 0
		for event in Rules.SITES:
			var result := Rules.transition(entry.state, entry.items, 100, entry.rep, event, 3, ["workshop_1", "workshop_archer"])
			if not result.is_empty():
				possible += 1
				queue.append({"state": result.commission, "items": result.inventory, "rep": result.reputation})
		if possible == 0:
			check(false, "reachable nonterminal state has no next action")
	check(endings == 36, "all investigation orders and resource/settlement alternatives reach completion")
	print("Commission rule checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
