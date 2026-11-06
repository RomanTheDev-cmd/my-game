extends RefCounted
const GROUPS := ["roadfolk", "wardens", "tenders"]

static func defaults() -> Dictionary:
	return {"roadfolk": 0, "wardens": 0, "tenders": 0}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != GROUPS.size():
		return false
	for id in GROUPS:
		var value = data.get(id)
		if not (value is int or value is float) or not is_finite(float(value)) or value < -10 or value > 10 or floorf(value) != value:
			return false
	return true

static func change(previous: Dictionary, amounts: Dictionary) -> Dictionary:
	if not valid(previous):
		return {}
	var result := previous.duplicate()
	for id in amounts:
		if id not in GROUPS or not amounts[id] is int:
			return {}
		result[id] = clampi(int(result[id]) + amounts[id], -10, 10)
	return result

static func trusted(reputation: Dictionary, id: String) -> bool:
	return id in GROUPS and int(reputation.get(id, 0)) >= 2
