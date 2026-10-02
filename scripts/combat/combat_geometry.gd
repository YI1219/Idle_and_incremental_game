extends RefCounted


static func aim_direction(origin: Vector3, raw_direction: Vector3, targets: Array, assist_cone: float = deg_to_rad(12.0), max_turn: float = deg_to_rad(6.0), max_distance: float = 2.0) -> Vector3:
	var raw := _horizontal_normalized(raw_direction, Vector3.FORWARD)
	if not _vector_is_finite(origin) or not is_finite(assist_cone) or not is_finite(max_turn) or not is_finite(max_distance):
		return raw
	var best := raw
	var best_angle := INF
	for target in targets:
		if not target is Vector3 or not _vector_is_finite(target):
			continue
		var offset := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
		var distance := offset.length()
		if distance <= 0.000001 or distance > maxf(0.0, max_distance):
			continue
		var candidate := offset / distance
		var angle := raw.angle_to(candidate)
		if angle <= maxf(0.0, assist_cone) and angle < best_angle:
			best = candidate
			best_angle = angle
	if best_angle == INF:
		return raw
	var turn := minf(best_angle, maxf(0.0, max_turn))
	return raw.slerp(best, turn / best_angle).normalized() if best_angle > 0.000001 else raw


static func pressure_from(origin: Vector3, source: Vector3, strength: float, radius: float = 2.2, inner_radius: float = 0.7) -> float:
	if not _vector_is_finite(origin) or not _vector_is_finite(source) or not is_finite(strength) or strength <= 0.0:
		return 0.0
	if not is_finite(radius) or not is_finite(inner_radius) or radius <= 0.0:
		return 0.0
	inner_radius = clampf(inner_radius, 0.0, radius)
	var distance := Vector2(origin.x - source.x, origin.z - source.z).length()
	if distance > radius:
		return 0.0
	if distance <= inner_radius or is_equal_approx(inner_radius, radius):
		return strength
	return strength * (radius - distance) / (radius - inner_radius)


static func pressure_total(receiver: Vector3, receiver_team: int, sources: Array) -> float:
	var total := 0.0
	for source in sources:
		if not source is Dictionary:
			continue
		if not source.get("active", true) or int(source.get("team", receiver_team)) == receiver_team:
			continue
		var position = source.get("position", null)
		if not position is Vector3:
			continue
		total += pressure_from(receiver, position, float(source.get("strength", 0.0)), float(source.get("radius", 2.2)), float(source.get("inner_radius", 0.7)))
	return total


static func in_attack(origin: Vector3, forward: Vector3, target: Vector3, kind: String) -> Dictionary:
	var result := {"core": false, "spirit": false}
	if not _vector_is_finite(origin) or not _vector_is_finite(forward) or not _vector_is_finite(target):
		return result
	var facing := _horizontal_normalized(forward, Vector3.ZERO)
	if facing == Vector3.ZERO:
		return result
	var offset := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	var distance := offset.length()
	var longitudinal := offset.dot(facing)
	var lateral := absf(offset.dot(Vector3(-facing.z, 0.0, facing.x)))
	match kind:
		"thrust":
			result.core = longitudinal >= 0.0 and longitudinal <= 1.8 and lateral <= 0.22
		"sweep":
			result.core = _sector_hit(offset, distance, facing, 1.6, deg_to_rad(65.0))
		"charged_slash":
			result.core = longitudinal >= 0.0 and longitudinal <= 2.0 and lateral <= 0.28
			result.spirit = _sector_hit(offset, distance, facing, 2.2, deg_to_rad(70.0))
	return result


static func direction_from_ray(ray_origin: Vector3, ray_direction: Vector3, actor_origin: Vector3, fallback: Vector3) -> Vector3:
	var safe_fallback := _horizontal_normalized(fallback, Vector3.FORWARD)
	if not _vector_is_finite(ray_origin) or not _vector_is_finite(ray_direction) or not _vector_is_finite(actor_origin):
		return safe_fallback
	if absf(ray_direction.y) <= 0.000001:
		return safe_fallback
	var distance := (actor_origin.y - ray_origin.y) / ray_direction.y
	if not is_finite(distance) or distance < 0.0:
		return safe_fallback
	var intersection := ray_origin + ray_direction * distance
	return _horizontal_normalized(intersection - actor_origin, safe_fallback)


static func _sector_hit(offset: Vector3, distance: float, facing: Vector3, radius: float, half_angle: float) -> bool:
	if distance <= 0.000001:
		return true
	return distance <= radius and facing.angle_to(offset / distance) <= half_angle


static func _horizontal_normalized(value: Vector3, fallback: Vector3) -> Vector3:
	if not _vector_is_finite(value):
		value = fallback
	var flat := Vector3(value.x, 0.0, value.z)
	if flat.length_squared() <= 0.000000000001:
		flat = Vector3(fallback.x, 0.0, fallback.z)
	return flat.normalized() if flat.length_squared() > 0.000000000001 else Vector3.ZERO


static func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
