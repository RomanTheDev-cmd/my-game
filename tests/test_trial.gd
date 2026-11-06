extends SceneTree
const TestExit = preload("res://tests/support/test_exit.gd")
const Rules = preload("res://scripts/quests/trial_rules.gd")
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
	var invalid: Dictionary = session.snapshot(Vector2(400, 500))
	invalid.gathered.append("waterworks:awakened")
	check(not session.Store.validate(invalid), "save rejects an awakened encounter without its prerequisites")
	check(Rules.transition([], [], [], {}, 5, "accept").is_empty(), "new assignment waits for the previous completed line")
	var result := Rules.transition([], [], [], {}, 6, "accept")
	check(result.gathered == ["waterworks:charter"], "acceptance stores a persistent flag without requiring a new save format")
	check(Rules.transition(result.gathered, [], [], {}, 6, "awaken").is_empty(), "unprepared encounter cannot start")
	result = Rules.transition(result.gathered, [], [], {}, 6, "south")
	check(Rules.transition(result.gathered, [], [], {}, 6, "south").is_empty(), "repeated observation cannot replace the other required point")
	result = Rules.transition(result.gathered, [], [], {}, 6, "north")
	result = Rules.transition(result.gathered, [], [], {}, 6, "awaken")
	check(Rules.stage(result.gathered, [], []) == 3, "either observation order reaches the prepared encounter")
	check(not Rules.valid(result.gathered, ["waterworks_guardian", "waterworks_guardian"], [], 6), "duplicate victory flags are invalid input")
	check(not Rules.valid(result.gathered, ["waterworks_guardian"], ["waterworks_report", "waterworks_report"], 6), "duplicate report flags are invalid input")
	check(Rules.transition(result.gathered, [], [], {}, 6, "report").is_empty(), "assignment cannot be turned in before victory")
	check(Rules.transition(result.gathered, ["waterworks_guardian"], [], {"coin": 976}, 6, "report").is_empty(), "full purse leaves reward claim pending")
	result = Rules.transition(result.gathered, ["waterworks_guardian"], [], {"coin": 5}, 6, "report")
	check(result.inventory.coin == 29 and result.xp == 60 and result.opened == ["waterworks_report"], "turn-in grants currency and experience exactly once")
	check(Rules.transition(result.gathered, ["waterworks_guardian"], result.opened, result.inventory, 6, "report").is_empty(), "repeated turn-in does not mint rewards")
	session.quest = 3
	session.world_state.commission = {"stage": 6, "survey": ["wheel", "archive"], "heard": ["wardens", "tenders"], "supply": "craft", "settlement": "shared"}
	session.world_state.minutes = 1700
	session.inventory = {"coin": 7, "herb": 3}
	var position := Vector2(820, 650)
	var vitals := {"health": 71.0, "stamina": 42.0, "mana": 33.0}
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.trial_event("accept", position, vitals) and session.gathered.is_empty(), "failed acceptance write retains original progress")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.trial_event("accept", position, vitals) and session.world_state.minutes == 1700 and session.inventory.coin == 7, "new assignment preserves clock and old inventory")
	check(session.trial_event("north", position, vitals) and session.trial_event("south", position, vitals), "both observations commit through real disk")
	check(session.trial_event("awaken", position, vitals), "prepared start commits a retry checkpoint")
	session.region = "waterworks"
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.finish_guardian(position, vitals) and session.defeated.is_empty() and session.xp == 0, "failed victory write grants neither victory flag nor experience")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.finish_guardian(position, vitals) and session.xp == 120 and session.defeated == ["waterworks_guardian"], "victory commits experience and progress atomically")
	check(not session.finish_guardian(position, vitals) and session.xp == 120, "victory cannot be committed twice")
	check(session.load_saved() and session.vitals.health == 71 and session.region == "waterworks", "victory survives disk reload without healing")
	DirAccess.make_dir_absolute("user://save.json.tmp")
	check(not session.trial_event("report", position, vitals) and session.inventory.coin == 7 and session.xp == 120, "failed turn-in preserves all rewards for retry")
	DirAccess.remove_absolute("user://save.json.tmp")
	check(session.trial_event("report", position, vitals) and session.xp == 180 and session.inventory.coin == 31, "turn-in commits its separate final reward")
	check(session.load_saved() and Rules.stage(session.gathered, session.defeated, session.opened) == 5, "finished assignment survives reload")
	print("Trial state checks: %d; failures: %d" % [checks, failures])
	await TestExit.finish(self, 1 if failures else 0)
