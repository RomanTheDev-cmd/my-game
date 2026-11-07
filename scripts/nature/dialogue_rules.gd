extends RefCounted
const Factions = preload("res://scripts/factions/faction_rules.gd")
const GROUPS := {"keeper": "roadfolk", "merchant": "roadfolk", "wayfarer": "roadfolk", "wright": "roadfolk", "warden": "wardens", "tender": "tenders", "tracker": "tenders"}
const ANSWERS := {"vampire": ["honest", "distance"], "returned": ["explain", "silence"], "oath": ["pledge", "listen"], "werewolf": ["pack_word", "reserve"], "wild_returned": ["remember_pack", "leave_silence"]}
static func context(nature: Dictionary) -> String:
	if nature.form == "bat": return "bat_form"
	if nature.form == "mist": return "mist_form"
	if nature.form != "human": return "wild_form" if nature.kind == "werewolf" else "form"
	if nature.kind == "werewolf": return "werewolf"
	if "werewolf" in nature.history: return "wild_returned"
	if nature.kind == "vampire": return "vampire"
	if "vampire" in nature.history: return "returned"
	return "oath" if nature.gift in ["oath", "trail_oath"] else ""
static func memory(flags: Array, kind: String, current: String) -> String:
	for answer in ANSWERS.get(current, []):
		if "dialogue:%s:%s:%s" % [kind, current, answer] in flags: return answer
	return ""
static func valid(flags: Array) -> bool:
	var seen := {}
	for flag in flags:
		if not flag is String: return false
		if not flag.begins_with("dialogue:"): continue
		var parts: PackedStringArray = flag.split(":")
		if parts.size() != 4 or not GROUPS.has(parts[1]) or not ANSWERS.has(parts[2]) or parts[3] not in ANSWERS[parts[2]]: return false
		var key := parts[1] + ":" + parts[2]
		if seen.has(key): return false
		seen[key] = true
	return true
static func reaction(nature: Dictionary, kind: String) -> String:
	var current := context(nature)
	return "DIALOGUE_" + kind.to_upper() + "_" + current.to_upper() if GROUPS.has(kind) and current != "" else ""
static func resolve(nature: Dictionary, flags: Array, reputation: Dictionary, kind: String, answer: String) -> Dictionary:
	var current := context(nature)
	if not GROUPS.has(kind) or answer not in ANSWERS.get(current, []) or not memory(flags, kind, current).is_empty() or not valid(flags): return {}
	var next := flags.duplicate()
	next.append("dialogue:%s:%s:%s" % [kind, current, answer])
	var change := 1 if answer in ["honest", "explain", "pledge", "pack_word", "remember_pack"] else 0
	var trust := Factions.change(reputation, {GROUPS[kind]: change})
	return {} if trust.is_empty() else {"gathered": next, "reputation": trust}
