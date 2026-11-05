extends SceneTree
const Quests = preload("res://scripts/quests/quest_book.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var original := {"herb": 2}
	check(Quests.transition(0, original, "found").is_empty(), "cannot collect quest objective before acceptance")
	check(Quests.transition(0, original, "turn_in").is_empty(), "cannot complete before starting")
	var accepted := Quests.transition(0, original, "accept")
	check(accepted.get("stage") == 1, "accept starts quest")
	check(original == {"herb": 2}, "transition never mutates source inventory")
	check(Quests.transition(1, accepted.inventory, "accept").is_empty(), "accept cannot repeat")
	var found := Quests.transition(1, accepted.inventory, "found")
	check(found.get("stage") == 2 and found.inventory.get("lantern") == 1, "discovery records objective and stage together")
	check(Quests.transition(2, {}, "turn_in").is_empty(), "turn-in requires the actual objective item")
	var completed := Quests.transition(2, found.inventory, "turn_in")
	check(completed.get("stage") == 3 and not completed.inventory.has("lantern"), "turn-in consumes objective")
	check(completed.inventory.get("coin") == 12, "completion grants reward")
	check(completed.inventory.get("herb") == 2, "unrelated inventory retained")
	check(Quests.transition(3, completed.inventory, "turn_in").is_empty(), "completed quest cannot duplicate reward")
	check(Quests.transition(99, {}, "accept").is_empty(), "unknown state rejected")
	# Traverse the real event graph and require all authored stages to be reachable.
	var queue := [{"stage": 0, "inventory": {}}]
	var visited := {}
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		if visited.has(state.stage):
			continue
		visited[state.stage] = true
		for event in Quests.GRAPH[state.stage]:
			var next := Quests.transition(state.stage, state.inventory, event)
			check(not next.is_empty(), "reachable event has satisfiable conditions")
			if not next.is_empty():
				queue.append(next)
	check(visited.size() == Quests.GRAPH.size() and visited.has(3), "no unreachable authored stage or missing ending")
	print("Quest checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
