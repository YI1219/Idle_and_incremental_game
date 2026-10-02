extends Object
## Tiny helpers for the 2-field → potion loop. No nodes.


static func stock_on(on: bool, available: float, projected: float, low: float, high: float) -> bool:
	if not (low < high) or available < 0.0 or projected < available:
		return on
	if on and projected >= high:
		return false
	if not on and available <= low:
		return projected < high
	return on


static func stage_time(remaining_work: float, speed: float) -> float:
	if speed <= 1e-12:
		return INF
	return maxf(0.0, remaining_work / speed)
