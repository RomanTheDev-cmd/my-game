extends RefCounted
const SKILLS := {
	"sword": {"max": 3, "requires": "", "name": "SKILL_SWORD", "description": "SKILL_SWORD_DESC"},
	"light": {"max": 3, "requires": "", "name": "SKILL_LIGHT", "description": "SKILL_LIGHT_DESC"},
	"ward": {"max": 2, "requires": "sword", "name": "SKILL_WARD", "description": "SKILL_WARD_DESC"}
}

static func level(xp: int) -> int:
	var current := 1
	var remaining := maxi(0, xp)
	while current < 20 and remaining >= current * 40:
		remaining -= current * 40
		current += 1
	return current

static func points(xp: int, skills: Dictionary) -> int:
	var spent := 0
	for rank in skills.values():
		spent += int(rank)
	return level(xp) - 1 - spent

static func valid(xp: Variant, skills: Variant) -> bool:
	if not (xp is int or xp is float) or xp < 0 or xp > 100000 or floorf(xp) != xp or not skills is Dictionary:
		return false
	for id in skills:
		if not SKILLS.has(id):
			return false
		var rank = skills[id]
		if not (rank is int or rank is float) or rank < 0 or rank > SKILLS[id].max or floorf(rank) != rank:
			return false
		var required: String = SKILLS[id].requires
		if rank > 0 and required != "" and int(skills.get(required, 0)) < 1:
			return false
	return points(int(xp), skills) >= 0

static func learn(xp: int, skills: Dictionary, id: String) -> Dictionary:
	if not valid(xp, skills) or not SKILLS.has(id) or points(xp, skills) < 1:
		return {}
	var result := skills.duplicate()
	result[id] = int(result.get(id, 0)) + 1
	return result if valid(xp, result) else {}
