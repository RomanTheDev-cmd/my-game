extends RefCounted

static func damage(base: float, difficulty: int, blocking: bool, dodging: bool) -> float:
	if dodging:
		return 0.0
	var multipliers := [0.6, 1.0, 1.35]
	return maxf(0.0, base) * multipliers[clampi(difficulty, 0, 2)] * (0.25 if blocking else 1.0)
