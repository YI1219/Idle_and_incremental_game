extends RefCounted

var max_health: float = 100.0
var max_ward: float = 100.0
var health: float = 100.0
var ward: float = 100.0
var realm: int = 0

const RECOVERY_DELAY := 3.0
const RECOVERY_RATE := 12.0

var _recovery_wait := 0.0


func reduction_against(attacker_realm: int) -> float:
	return clampf(0.80 + float(realm - attacker_realm) * 0.05, 0.60, 0.95)


func receive_attack(physical: float, spiritual: float, attacker_realm: int) -> Dictionary:
	physical = _valid_nonnegative(physical)
	spiritual = _valid_nonnegative(spiritual)
	var old_health := health
	var old_ward := ward
	var protected := ward > 0.0
	var blocked := physical * reduction_against(attacker_realm) if protected else 0.0
	var direct_health := physical - blocked
	health = maxf(0.0, health - direct_health)
	ward = maxf(0.0, ward - blocked)
	var spirit_to_ward := minf(ward, spiritual)
	ward -= spirit_to_ward
	health = maxf(0.0, health - (spiritual - spirit_to_ward))
	if physical > 0.0 or spiritual > 0.0:
		_recovery_wait = RECOVERY_DELAY
	return {
		"health_loss": old_health - health,
		"ward_loss": old_ward - ward,
	}


func advance(delta: float, pressure: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if not is_finite(pressure) or pressure < 0.0:
		return
	if pressure > 0.0:
		ward = maxf(0.0, ward - pressure * delta)
		_recovery_wait = RECOVERY_DELAY
		return
	var recovery_time := delta
	if _recovery_wait > 0.0:
		var waited := minf(_recovery_wait, recovery_time)
		_recovery_wait -= waited
		recovery_time -= waited
	if recovery_time > 0.0:
		ward = minf(max_ward, ward + RECOVERY_RATE * recovery_time)


func _valid_nonnegative(value: float) -> float:
	return value if is_finite(value) and value > 0.0 else 0.0
