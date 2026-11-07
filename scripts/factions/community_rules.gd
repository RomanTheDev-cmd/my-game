extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Factions = preload("res://scripts/factions/faction_rules.gd")
const REPORT := "community_report"
const GROUPS := {"watch": "wardens", "circle": "roadfolk", "pack": "tenders"}
const HOSTS := {"watch": "keeper", "circle": "wayfarer", "pack": "tracker"}
const JOINS := ["community:join:watch", "community:join:circle", "community:join:pack"]
const SEEN := ["community:seen:supply", "community:seen:route"]
const AIDS := ["community:aid:craft", "community:aid:blood", "community:aid:track"]
const REPORTS := ["community:report:share", "community:report:provision"]
const SITES := {"join_watch": ["crossing", "keeper"], "join_circle": ["lake", "wayfarer"], "join_pack": ["thicket", "tracker"],
	"seen_supply": ["haven", "supply"], "seen_route": ["haven", "route"],
	"aid_craft": ["haven", "host"], "aid_blood": ["haven", "host"], "aid_track": ["haven", "search"],
	"report_share": ["haven", "host"], "report_provision": ["haven", "host"]}
static func guild(flags: Array) -> String:
	for id in GROUPS:
		if "community:join:" + id in flags: return id
	return ""
static func stage(flags: Array) -> int:
	if flags.any(func(flag): return flag in REPORTS): return 4
	if flags.any(func(flag): return flag in AIDS): return 3
	if SEEN[0] in flags and SEEN[1] in flags: return 2
	return 1 if guild(flags) != "" else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	if REPORT in flags or opened.any(func(flag): return flag.begins_with("community:")): return false
	var known := JOINS + SEEN + AIDS + REPORTS
	for flag in flags:
		if flag.begins_with("community:") and (flag not in known or flags.count(flag) > 1): return false
	if opened.count(REPORT) > 1: return false
	var joins := flags.filter(func(flag): return flag in JOINS)
	var aids := flags.filter(func(flag): return flag in AIDS)
	var reports := flags.filter(func(flag): return flag in REPORTS)
	if joins.size() > 1 or aids.size() > 1 or reports.size() > 1: return false
	if joins.is_empty(): return not flags.any(func(flag): return flag in known) and REPORT not in opened
	if "waterworks_report" not in opened: return false
	if guild(flags) == "circle" and "vampire" not in nature.history: return false
	if guild(flags) == "pack" and "werewolf" not in nature.history: return false
	if AIDS[1] in flags and "vampire" not in nature.history: return false
	if AIDS[2] in flags and "werewolf" not in nature.history: return false
	if not aids.is_empty() and (SEEN[0] not in flags or SEEN[1] not in flags): return false
	if not reports.is_empty() and aids.is_empty(): return false
	return (REPORT in opened) == (not reports.is_empty())
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, owned: Array, reputation: Dictionary, mana: float, event: String) -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, flags, opened) or not Factions.valid(reputation) or not is_finite(mana) or mana < 0 or mana > 100 or not SITES.has(event): return {}
	var next := nature.duplicate(true)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var items := inventory.duplicate()
	var gear := owned.duplicate()
	var trust := reputation.duplicate()
	var xp := 0
	var current := stage(flags)
	if event.begins_with("join_"):
		var id := event.trim_prefix("join_")
		if current != 0 or "waterworks_report" not in opened or nature.form != "human": return {}
		if nature.kind != {"watch": "human", "circle": "vampire", "pack": "werewolf"}[id]: return {}
		gathered.append("community:join:" + id)
	elif event.begins_with("seen_"):
		var flag := "community:seen:" + event.trim_prefix("seen_")
		if current != 1 or flag in flags or nature.form != "human": return {}
		gathered.append(flag)
	elif event.begins_with("aid_"):
		if current != 2: return {}
		match event:
			"aid_craft":
				if nature.form != "human" or int(items.get("herb", 0)) < 2 or int(items.get("potion", 0)) < 1: return {}
				items.herb -= 2
				items.potion -= 1
			"aid_blood":
				if nature.kind != "vampire" or nature.form != "human" or nature.blood < 30 or mana < 15: return {}
				next.blood -= 20
				mana -= 15
			"aid_track":
				if nature.kind != "werewolf" or nature.form != "wolf" or nature.resolve < 30: return {}
				next.resolve -= 20
		gathered.append("community:aid:" + event.trim_prefix("aid_"))
	else:
		if current != 3 or nature.form != "human": return {}
		if event == "report_provision":
			if int(items.get("coin", 0)) > 987: return {}
			items["coin"] = int(items.get("coin", 0)) + 12
			trust = Factions.change(trust, {GROUPS[guild(flags)]: 1})
		else: trust = Factions.change(trust, {"roadfolk": 2, "wardens": 2, "tenders": 2})
		if "relay_cloak" not in gear: gear.append("relay_cloak")
		gathered.append("community:report:" + event.trim_prefix("report_"))
		claimed.append(REPORT)
		xp = 60
	if not Nature.valid(next) or not valid(next, gathered, claimed): return {}
	return {"nature": next, "gathered": gathered, "opened": claimed, "inventory": items, "owned": gear, "reputation": trust, "mana": mana, "xp": xp}
