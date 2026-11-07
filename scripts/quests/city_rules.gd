extends RefCounted
const Nature = preload("res://scripts/nature/nature_rules.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const REPORT := "city_report"
const SUPPLIES := "courtyard_supplies"
const DRAFTS := ["city:draft:shared", "city:draft:release"]
const OUTCOMES := ["city:outcome:shared", "city:outcome:release"]
const SIGNATURES := ["city:signature:crafter", "city:signature:archivist"]
const WORK := ["city:work:manual", "city:work:strength"]
const SITES := {"accept": "crafter", "hear_crafter": "crafter", "hear_archivist": "archivist", "supply": "crafter", "sign_crafter": "crafter", "sign_archivist": "archivist",
	"draft_shared": "board", "draft_release": "board", "seal": "board", "work": "press", "strength": "press", "copy": "archive", "memory": "archive"}
static func draft(flags: Array) -> String:
	return "shared" if DRAFTS[0] in flags else ("release" if DRAFTS[1] in flags else "")
static func heard(flags: Array) -> bool:
	return "city:heard:crafter" in flags and "city:heard:archivist" in flags
static func agrees(flags: Array, role: String) -> bool:
	if not heard(flags) or draft(flags) == "": return false
	if role == "crafter": return flags.any(func(flag): return flag in WORK) or (draft(flags) == "shared" and "city:supply" in flags)
	if role == "archivist": return "city:copy" in flags or (draft(flags) == "shared" and "city:memory" in flags)
	return false
static func stage(flags: Array, opened: Array) -> int:
	if REPORT in opened: return 3
	if SIGNATURES.all(func(flag): return flag in flags): return 2
	return 1 if "city:accepted" in flags else 0
static func valid(nature: Dictionary, flags: Array, opened: Array) -> bool:
	var known := ["city:accepted", "city:heard:crafter", "city:heard:archivist", "city:copy", "city:memory", "city:supply"] + DRAFTS + OUTCOMES + SIGNATURES + WORK
	for flag in flags:
		if flag == SUPPLIES: return false
		if flag.begins_with("city_") or (flag.begins_with("city:") and (flag not in known or flags.count(flag) > 1)): return false
	for flag in opened:
		if flag.begins_with("city:") or (flag.begins_with("city_") and (flag != REPORT or opened.count(flag) > 1)): return false
	if opened.count(SUPPLIES) > 1 or (SUPPLIES in opened and REPORT not in opened): return false
	if not flags.any(func(flag): return flag in known) and REPORT not in opened: return true
	if "city:accepted" not in flags or "story:accepted" not in flags: return false
	if flags.filter(func(flag): return flag in DRAFTS).size() > 1 or flags.filter(func(flag): return flag in WORK).size() > 1: return false
	if (flags.any(func(flag): return flag in WORK) or "city:supply" in flags) and "city:heard:crafter" not in flags: return false
	if ("city:copy" in flags or "city:memory" in flags) and "city:heard:archivist" not in flags: return false
	if "city:memory" in flags and "vampire" not in nature.history: return false
	if WORK[1] in flags and ("werewolf" not in nature.history or "pack:mastery" not in flags): return false
	for role in ["crafter", "archivist"]:
		if "city:signature:" + role in flags and not agrees(flags, role): return false
	var outcomes := flags.filter(func(flag): return flag in OUTCOMES)
	if outcomes.size() > 1 or (REPORT in opened) != (outcomes.size() == 1): return false
	if not outcomes.is_empty():
		if not SIGNATURES.all(func(flag): return flag in flags) or "city:outcome:" + draft(flags) not in flags: return false
	return true
static func resolve(nature: Dictionary, flags: Array, opened: Array, inventory: Dictionary, vitals: Dictionary, minutes: float, event: String) -> Dictionary:
	if not Nature.valid(nature) or not valid(nature, flags, opened) or not SITES.has(event) or inventory.get("story_tool", 0) != 1: return {}
	if not is_finite(minutes) or minutes < 0 or minutes > 1000000000: return {}
	for key in ["health", "stamina", "mana"]:
		var value = vitals.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100 or (key == "health" and value == 0): return {}
	if nature.form != "human" and not (event == "strength" and nature.kind == "werewolf" and nature.form == "hybrid"): return {}
	if stage(flags, opened) == 3: return {}
	var next := nature.duplicate(true)
	var gathered := flags.duplicate()
	var claimed := opened.duplicate()
	var items := inventory.duplicate()
	var resources := vitals.duplicate()
	var elapsed := 0.0
	var xp := 0
	var trust := {}
	if event == "accept":
		if stage(flags, opened) != 0 or "story:accepted" not in flags: return {}
		gathered.append("city:accepted")
	else:
		if "city:accepted" not in flags: return {}
		match event:
			"hear_crafter", "hear_archivist":
				var flag := "city:heard:" + event.trim_prefix("hear_")
				if flag in flags: return {}
				gathered.append(flag)
			"draft_shared", "draft_release":
				var selected := event.trim_prefix("draft_")
				if draft(flags) == selected: return {}
				for old in DRAFTS + SIGNATURES: gathered.erase(old)
				gathered.append("city:draft:" + selected)
			"work", "strength", "supply":
				if "city:heard:crafter" not in flags: return {}
				if event == "supply":
					if "city:supply" in flags or int(items.get("potion", 0)) < 1: return {}
					items.potion -= 1
					gathered.append("city:supply")
				else:
					if flags.any(func(flag): return flag in WORK): return {}
					if event == "strength":
						if nature.kind != "werewolf" or nature.form != "hybrid" or nature.resolve < 28: return {}
						next.resolve -= 18
					else:
						if resources.stamina < 20: return {}
						resources.stamina -= 20
						elapsed = 20
					gathered.append("city:work:" + ("manual" if event == "work" else "strength"))
			"copy", "memory":
				if "city:heard:archivist" not in flags or "city:" + event in flags: return {}
				if event == "memory":
					if nature.kind != "vampire" or nature.blood < 30 or resources.mana < 10: return {}
					next.blood -= 20
					resources.mana -= 10
				else:
					if resources.stamina < 20: return {}
					resources.stamina -= 20
					elapsed = 10
				gathered.append("city:" + event)
			"sign_crafter", "sign_archivist":
				var role := event.trim_prefix("sign_")
				if "city:signature:" + role in flags or not agrees(flags, role): return {}
				gathered.append("city:signature:" + role)
			"seal":
				if stage(flags, opened) != 2: return {}
				gathered.append("city:outcome:" + draft(flags))
				claimed.append(REPORT)
				xp = 100
				trust = {"roadfolk": 2, "wardens": 1} if draft(flags) == "shared" else {"roadfolk": 1, "wardens": 2}
	if elapsed > 0:
		next = Nature.advance(nature, elapsed)
		minutes = Clock.advance(minutes, elapsed)
	if next.is_empty() or not valid(next, gathered, claimed): return {}
	return {"nature": next, "gathered": gathered, "opened": claimed, "inventory": items, "vitals": resources, "minutes": minutes, "elapsed": elapsed, "xp": xp, "trust": trust}
