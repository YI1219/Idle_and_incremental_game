extends RefCounted

var action: String = "idle"
var elapsed: float = 0.0
var charges: int = 2

const MAX_CHARGES := 2
const CHARGE_RECOVERY := 2.4
const ACTION_TIMES := {
	"attack": Vector2(0.20, 0.55),
	"counter": Vector2(0.34, 0.80),
	"dodge": Vector2(-1.0, 0.38),
	"thrust": Vector2(0.65, 1.15),
	"sweep": Vector2(0.80, 1.35),
	"charged_slash": Vector2(1.20, 1.85),
}

var _impact_emitted := false
var _parry_used := false
var _charge_elapsed := 0.0


func start(kind: String) -> bool:
	if action != "idle" or not ACTION_TIMES.has(kind):
		return false
	if kind == "dodge":
		if charges <= 0:
			return false
		charges -= 1
	action = kind
	elapsed = 0.0
	_impact_emitted = false
	_parry_used = false
	return true


func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	_advance_charges(delta)
	if action == "idle":
		return false
	var times: Vector2 = ACTION_TIMES[action]
	var previous := elapsed
	elapsed += delta
	var emitted := false
	if not _impact_emitted and times.x >= 0.0 and previous < times.x and elapsed >= times.x:
		_impact_emitted = true
		emitted = true
	if elapsed >= times.y:
		action = "idle"
		elapsed = 0.0
	return emitted


func try_parry(forward: Vector3, attacker_offset: Vector3) -> bool:
	if action != "counter" or _parry_used or elapsed < 0.08 or elapsed > 0.28:
		return false
	var facing := _horizontal(forward)
	var incoming := _horizontal(attacker_offset)
	if facing == Vector3.ZERO or incoming == Vector3.ZERO or facing.angle_to(incoming) > deg_to_rad(55.0):
		return false
	_parry_used = true
	return true


func is_invulnerable() -> bool:
	return action == "dodge" and elapsed >= 0.04 and elapsed <= 0.22


func cancel() -> void:
	action = "idle"
	elapsed = 0.0
	_impact_emitted = false
	_parry_used = false


func _advance_charges(delta: float) -> void:
	if charges >= MAX_CHARGES:
		_charge_elapsed = 0.0
		return
	_charge_elapsed += delta
	while charges < MAX_CHARGES and _charge_elapsed >= CHARGE_RECOVERY:
		_charge_elapsed -= CHARGE_RECOVERY
		charges += 1
	if charges >= MAX_CHARGES:
		_charge_elapsed = 0.0


func _horizontal(value: Vector3) -> Vector3:
	if not is_finite(value.x) or not is_finite(value.y) or not is_finite(value.z):
		return Vector3.ZERO
	var flat := Vector3(value.x, 0.0, value.z)
	return flat.normalized() if flat.length_squared() > 0.000000000001 else Vector3.ZERO
