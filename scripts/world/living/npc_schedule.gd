extends RefCounted
const Regions = preload("res://scripts/world/region_catalog.gd")
const Clock = preload("res://scripts/world/living/world_clock.gd")
const KINDS := ["merchant", "keeper", "wayfarer"]

static func shop_open(minutes: float) -> bool:
	return Clock.in_hours(Clock.hour(minutes), 7, 21)

static func destination(region: String, kind: String, minutes: float, aid_stage: int) -> Vector2:
	var definition: Dictionary = Regions.REGIONS.get(region, {})
	var point: Vector2 = definition.get(kind, Vector2.ZERO)
	var hour := Clock.hour(minutes)
	if region == "crossing":
		if kind == "merchant" and not shop_open(minutes):
			return Vector2(350, 440)
		if kind == "keeper" and not Clock.in_hours(hour, 7, 23):
			return Vector2(520, 470)
	elif region == "lake" and kind == "wayfarer" and aid_stage == 2 and Clock.in_hours(hour, 18, 7):
		return Vector2(420, 610)
	return point

static func valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)):
			return false
	return value[0] >= 8 and value[0] <= 1912 and value[1] >= 8 and value[1] <= 1272

static func valid_positions(positions: Variant) -> bool:
	if not positions is Dictionary:
		return false
	for key in positions:
		if not key is String:
			return false
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2 or not Regions.valid(parts[0]) or parts[1] not in KINDS:
			return false
		if not Regions.REGIONS[parts[0]].has(parts[1]) or not valid_point(positions[key]):
			return false
	return true

static func reserved(region: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for kind in KINDS:
		if Regions.REGIONS.get(region, {}).has(kind):
			result.append(destination(region, kind, 0, 2))
			result.append(destination(region, kind, 1020, 0))
			result.append(destination(region, kind, 1200, 2))
	return result
