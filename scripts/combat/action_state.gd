extends RefCounted
## Input-independent action timing; one impact per attack, even over a long frame.
const DURATIONS := {"attack_1": 0.48, "attack_2": 0.62, "dodge": 0.36}
const IMPACTS := {"attack_1": 0.18, "attack_2": 0.25}
var action := "idle"
var elapsed := 0.0
var cooldown := 0.0
var combo_window := 0.0
var _next_attack := 1
var _hit := false

func attack() -> bool:
	if action != "idle":
		return false
	if combo_window <= 0.0:
		_next_attack = 1
	action = "attack_%d" % _next_attack
	_next_attack = 2 if _next_attack == 1 else 1
	elapsed = 0.0
	_hit = false
	return true

func dodge() -> bool:
	if action != "idle" or cooldown > 0.0:
		return false
	action = "dodge"
	elapsed = 0.0
	cooldown = 0.78
	return true

func advance(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if action == "idle":
		return false
	elapsed += delta
	var impact := false
	if IMPACTS.has(action) and not _hit and elapsed >= float(IMPACTS[action]):
		_hit = true
		impact = true
	if elapsed >= float(DURATIONS[action]):
		if action.begins_with("attack"):
			combo_window = 0.65
		action = "idle"
	return impact

func is_invulnerable() -> bool:
	return action == "dodge" and elapsed < 0.24

func cancel() -> void:
	action = "idle"
	elapsed = 0.0
	combo_window = 0.0
	_next_attack = 1
	_hit = false

static func in_range(origin: Vector3, forward: Vector3, target: Vector3) -> bool:
	var offset := target - origin
	offset.y = 0.0
	return offset.length() <= 1.5 and (offset.length() < 0.05 or forward.normalized().dot(offset.normalized()) >= 0.35)
