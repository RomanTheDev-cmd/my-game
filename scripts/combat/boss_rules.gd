extends RefCounted
const SWEEP_REACH := 104.0
const PULSE_RADIUS := 140.0
static func phase(health: float, maximum: float) -> int:
	if not is_finite(health) or not is_finite(maximum) or maximum <= 0 or health <= 0:
		return 0
	return 2 if health <= maximum * 0.5 else 1
static func attack(current_phase: int, index: int) -> Dictionary:
	var pattern := ["sweep", "pulse", "charge"] if current_phase == 2 else ["sweep", "charge"]
	var kind: String = pattern[posmod(index, pattern.size())]
	match kind:
		"pulse": return {"kind": kind, "windup": 1.25, "recovery": 1.4, "damage": 24.0}
		"charge": return {"kind": kind, "windup": 1.1, "recovery": 1.3, "damage": 30.0}
	return {"kind": kind, "windup": 0.9, "recovery": 1.15, "damage": 26.0}
static func hits(kind: String, offset: Vector2, direction: Vector2) -> bool:
	if kind == "pulse":
		return offset.length() < PULSE_RADIUS
	return kind == "sweep" and offset.length() < SWEEP_REACH and offset.normalized().dot(direction.normalized()) > 0.15
static func damage_multiplier(state: String) -> float:
	return 1.35 if state == "recover" else (0.55 if state in ["windup", "charge"] else 1.0)
