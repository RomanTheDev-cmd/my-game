extends RefCounted
# Rules shared by the undercroft echoes and the hanging bell.
const ECHO_RING := 120.0
const BELL_RING := 330.0
const RING_SPEED := 380.0
const RING_WIDTH := 14.0
const RINGING := 3.0
const MAX_MINIONS := 2
static func phase(health: float, maximum: float) -> int:
	if not is_finite(health) or not is_finite(maximum) or maximum <= 0 or health <= 0: return 0
	return 2 if health <= maximum * 0.5 else 1
static func attack(current_phase: int, index: int) -> Dictionary:
	var pattern := ["peal", "summon", "peal", "knell"] if current_phase == 2 else ["toll", "toll", "summon", "knell"]
	var kind: String = pattern[posmod(index, pattern.size())]
	match kind:
		"peal": return {"kind": kind, "windup": 0.9, "recovery": 1.1, "damage": 16.0, "rings": 2, "gap": 0.55}
		"summon": return {"kind": kind, "windup": 1.1, "recovery": 0.8, "damage": 0.0, "rings": 0}
		"knell": return {"kind": kind, "windup": 2.0 if current_phase == 2 else 2.4, "recovery": 3.0, "damage": 44.0, "rings": 0}
	return {"kind": kind, "windup": 1.0, "recovery": 1.0, "damage": 20.0, "rings": 1}
# A ring front sweeps outward; it strikes once when it passes the target's distance.
static func ring_crosses(previous_radius: float, radius: float, distance: float) -> bool:
	if not is_finite(previous_radius) or not is_finite(radius) or not is_finite(distance) or radius < previous_radius: return false
	return distance >= previous_radius - RING_WIDTH and distance <= radius + RING_WIDTH
static func bell_multiplier(state: String) -> float:
	return 1.6 if state == "exposed" else (0.7 if state == "windup" else 1.0)
static func echo_multiplier(state: String) -> float:
	return 0.0 if state == "fade" else (1.4 if state == "recover" else 1.0)
static func spell_multiplier(kind: String) -> float:
	return 1.6 if kind == "light" else 1.0
# Rings and the great knell pass only through open air; a pillar is real cover.
static func covered(navigation: RefCounted, origin: Vector2, target: Vector2) -> bool:
	return navigation != null and not navigation.segment_clear(origin, target)
static func blink_points(target: Vector2, distance: float = 80.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in 8:
		result.append(target + Vector2.from_angle(i * TAU / 8 + PI / 8) * distance)
	return result
