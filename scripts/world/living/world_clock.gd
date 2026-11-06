extends RefCounted
const START := 1020.0
const DEFAULT_SEED := 43119

static func advance(minutes: float, seconds: float) -> float:
	return minf(1000000000, minutes + maxf(0, seconds)) if is_finite(seconds) else minutes

static func hour(minutes: float) -> int:
	return floori(fposmod(minutes, 1440) / 60)

static func in_hours(value: int, start: int, finish: int) -> bool:
	return value >= start and value < finish if start < finish else value >= start or value < finish

static func until_morning(minutes: float) -> float:
	var today := fposmod(minutes, 1440)
	return 420 - today if today < 420 else 1860 - today

static func weather(minutes: float, seed_value: int) -> String:
	var index := posmod(seed_value + floori(minutes / 180), 7)
	return "rain" if index < 2 else ("fog" if index == 2 else "clear")

static func daylight(minutes: float) -> float:
	var time := fposmod(minutes, 1440) / 60
	return minf(smoothstep(5, 8, time), 1.0 - smoothstep(18, 21, time))

static func time_text(minutes: float) -> String:
	var time := floori(fposmod(minutes, 1440))
	return "%02d:%02d" % [time / 60, time % 60]
