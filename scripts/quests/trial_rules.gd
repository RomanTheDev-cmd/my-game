extends RefCounted
const PREFIX := "waterworks:"
const BOSS := "waterworks_guardian"
const REPORT := "waterworks_report"
const FLAGS := ["waterworks:charter", "waterworks:north", "waterworks:south", "waterworks:awakened"]
const COINS := 24
const SITES := {"accept": ["workshop", "wright"], "report": ["workshop", "wright"], "north": ["waterworks", "north"], "south": ["waterworks", "south"], "awaken": ["waterworks", "altar"]}
static func stage(gathered: Array, defeated: Array, opened: Array) -> int:
	if REPORT in opened: return 5
	if BOSS in defeated: return 4
	if FLAGS[3] in gathered: return 3
	if FLAGS[1] in gathered and FLAGS[2] in gathered: return 2
	return 1 if FLAGS[0] in gathered else 0
static func valid(gathered: Array, defeated: Array, opened: Array, commission_stage: int) -> bool:
	if defeated.count(BOSS) > 1 or opened.count(REPORT) > 1: return false
	for flag in FLAGS:
		if gathered.count(flag) > 1: return false
	var started := FLAGS[0] in gathered
	if not started:
		return FLAGS[1] not in gathered and FLAGS[2] not in gathered and FLAGS[3] not in gathered and BOSS not in defeated and REPORT not in opened
	if commission_stage != 6: return false
	if FLAGS[3] in gathered and (FLAGS[1] not in gathered or FLAGS[2] not in gathered): return false
	if BOSS in defeated and FLAGS[3] not in gathered: return false
	return REPORT not in opened or BOSS in defeated
static func transition(gathered: Array, defeated: Array, opened: Array, inventory: Dictionary, commission_stage: int, event: String) -> Dictionary:
	if not valid(gathered, defeated, opened, commission_stage): return {}
	var current := stage(gathered, defeated, opened)
	var flags := gathered.duplicate()
	var claimed := opened.duplicate()
	var items := inventory.duplicate()
	var xp := 0
	match event:
		"accept":
			if current != 0 or commission_stage != 6: return {}
			flags.append(FLAGS[0])
		"north", "south":
			var flag := PREFIX + event
			if current != 1 or flag in flags: return {}
			flags.append(flag)
		"awaken":
			if current != 2: return {}
			flags.append(FLAGS[3])
		"report":
			if current != 4 or int(items.get("coin", 0)) > 999 - COINS: return {}
			items["coin"] = int(items.get("coin", 0)) + COINS
			claimed.append(REPORT)
			xp = 60
		_: return {}
	return {"gathered": flags, "opened": claimed, "inventory": items, "xp": xp}
