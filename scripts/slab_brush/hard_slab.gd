class_name HardSlab
extends RefCounted
## One convex cliff chunk: large flat side panels on a thick mass with a crown and a base.
## A second chunk abuts the first as its own volume. This path does not edit the seed island.

const WALL := 0
const SHOULDER := 1
const MIN_FACE := 3.2
const ROCK := Color(0.57, 0.55, 0.62)
const SAGE := Color(0.32, 0.58, 0.30)

static func build(planes: Array[Plane], salt: int) -> Dictionary:
	return _assemble(planes, salt, Plane(Vector3.UP, 0.0), PackedVector3Array())

static func _assemble(planes: Array[Plane], salt: int, snap_plane: Plane, snap_points: PackedVector3Array) -> Dictionary:
	var unique := _vertices(planes, snap_plane, snap_points)
	var faces: Array[Dictionary] = _faces(planes, unique)
	return {
		"planes": planes,
		"vertices": unique,
		"faces": faces,
		"mesh": _mesh(faces, salt, false),
	}

static func seed_module(kind: int, seed_value: int, yaw: float, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var planes := _transform(_slab_planes(kind, rng), yaw, origin)
	var body := prune(planes, [0, 1], seed_value)
	body["kind"] = kind
	body["seed"] = seed_value
	return body

static func expand_module(host_face: Dictionary, kind: int, seed_value: int, turn_deg: float = 0.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var planes := _expand_planes(host_face, kind, rng, turn_deg)
	var pruned := prune(planes, [0], seed_value)
	var snap := PackedVector3Array()
	var polygon: PackedVector3Array = host_face["polygon"]
	for point: Vector3 in polygon:
		snap.append(point)
	var mating := Plane(-host_face["normal"], host_face["center"])
	var body := _assemble(pruned["planes"], seed_value, mating, snap)
	_mark_mating(body["faces"], host_face)
	body["mesh"] = _mesh(body["faces"], seed_value, true)
	body["kind"] = kind
	body["seed"] = seed_value
	return body

static func prune(planes: Array[Plane], protect: Array[int], salt: int) -> Dictionary:
	var current: Array[Plane] = planes.duplicate()
	var protected: Array[int] = protect.duplicate()
	var body := build(current, salt)
	for _step in 5:
		var small := -1
		var small_area := INF
		for face: Dictionary in body["faces"]:
			var index: int = face["plane"]
			if protected.has(index):
				continue
			var area: float = face["area"]
			if area < MIN_FACE and area < small_area:
				small = index
				small_area = area
		if small < 0 or body["faces"].size() <= 7:
			return body
		var next: Array[Plane] = []
		for index in current.size():
			if index != small:
				next.append(current[index])
		var shifted: Array[int] = []
		for index in protected:
			shifted.append(index if index < small else index - 1)
		current = next
		protected = shifted
		body = build(current, salt)
	return body

static func _slab_planes(kind: int, rng: RandomNumberGenerator) -> Array[Plane]:
	# Irregular cliff mass. Local +Z is the broad cliff panel. Walls lean out toward the base.
	var height := 7.2 if kind == WALL else 6.2
	height *= rng.randf_range(0.98, 1.02)
	var crown := Vector3(0.03, 0.998, 0.04).normalized()
	var planes: Array[Plane] = [
		_through(crown, Vector3(0.0, height, 0.0)),
		Plane(Vector3.DOWN, 0.0),
	]
	# Six wall panels around a thick footprint. Tilt is only enough to show the base is wider.
	var specs: Array[Dictionary] = [
		{"normal": Vector3(0.00, 0.12, 1.00), "point": Vector3(0.10, height * 0.45, 5.35)},
		{"normal": Vector3(0.86, 0.11, 0.50), "point": Vector3(4.15, height * 0.45, 2.55)},
		{"normal": Vector3(0.92, 0.10, -0.38), "point": Vector3(4.55, height * 0.45, -1.85)},
		{"normal": Vector3(0.08, 0.12, -1.00), "point": Vector3(0.20, height * 0.45, -4.85)},
		{"normal": Vector3(-0.78, 0.11, -0.62), "point": Vector3(-3.85, height * 0.45, -2.65)},
		{"normal": Vector3(-0.88, 0.12, 0.46), "point": Vector3(-4.35, height * 0.45, 2.15)},
	]
	if kind == SHOULDER:
		specs[1] = {"normal": Vector3(0.62, 0.55, 0.56), "point": Vector3(3.4, height * 0.7, 2.2)}
	for spec: Dictionary in specs:
		var point: Vector3 = spec["point"]
		point += Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.12, 0.12))
		planes.append(_through(_jitter_normal(rng, spec["normal"]), point))
	return planes

static func yaw_facing(direction: Vector3) -> float:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	flat = flat.normalized()
	return atan2(flat.x, flat.z)

static func attach_module(host_face: Dictionary, kind: int, seed_value: int, yaw_deg: float = 0.0) -> Dictionary:
	# Keep the guest upright. Bite a little into the host, step the crown, slide along the seam.
	var host_n := Vector3(host_face["normal"].x, 0.0, host_face["normal"].z)
	if host_n.length_squared() < 0.04:
		host_n = Vector3(1.0, 0.0, 0.0)
	host_n = host_n.normalized()
	var probe := seed_module(kind, seed_value, 0.0, Vector3.ZERO)
	var mate := _side_facing(probe["faces"], -host_n)
	if mate.is_empty():
		return probe
	var mate_n := Vector3(mate["normal"].x, 0.0, mate["normal"].z).normalized()
	var yaw := atan2(-host_n.x, -host_n.z) - atan2(mate_n.x, mate_n.z) + deg_to_rad(yaw_deg)
	var guest := seed_module(kind, seed_value, yaw, Vector3.ZERO)
	mate = _side_facing(guest["faces"], -host_n)
	if mate.is_empty():
		return guest
	var tangent := host_n.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3(0.0, 0.0, 1.0)
	tangent = tangent.normalized()
	var dest: Vector3 = host_face["center"] + host_n * 0.22 + tangent * 0.35
	dest.y = float(mate["center"].y) - 0.72
	return _shift_body(guest, dest - mate["center"], seed_value)

static func _side_facing(faces: Array, direction: Vector3) -> Dictionary:
	var flat_dir := Vector3(direction.x, 0.0, direction.z)
	if flat_dir.length_squared() < 0.0001:
		flat_dir = Vector3(1.0, 0.0, 0.0)
	flat_dir = flat_dir.normalized()
	var best: Dictionary = {}
	var best_score := -INF
	for face: Dictionary in faces:
		if str(face["role"]) != "side":
			continue
		var flat := Vector3(face["normal"].x, 0.0, face["normal"].z)
		if flat.length_squared() < 0.04:
			continue
		var score: float = flat.normalized().dot(flat_dir) * 5.0 + float(face["area"]) * 0.012
		if score > best_score:
			best_score = score
			best = face
	return best

static func _shift_body(body: Dictionary, shift: Vector3, salt: int) -> Dictionary:
	var moved: Array[Plane] = []
	var planes: Array[Plane] = body["planes"]
	for plane: Plane in planes:
		var normal := plane.normal.normalized()
		var point: Vector3 = normal * plane.d + shift
		moved.append(Plane(normal, normal.dot(point)))
	var next := build(moved, salt)
	next["kind"] = body["kind"]
	next["seed"] = body["seed"]
	return next

static func _expand_planes(host_face: Dictionary, kind: int, rng: RandomNumberGenerator, turn_deg: float = 0.0) -> Array[Plane]:
	var normal: Vector3 = host_face["normal"].normalized()
	var polygon := _order(host_face["polygon"], normal)
	var center := _mean(polygon)
	var width := 0.0
	for index in polygon.size():
		var a: Vector3 = polygon[index]
		var b: Vector3 = polygon[(index + 1) % polygon.size()]
		width = maxf(width, Vector2(b.x - a.x, b.z - a.z).length())
	# A narrow host is a slab end. Continue with another full panel instead of a short stub.
	var along_end := width < 7.2
	var depth := clampf(width * (0.62 if kind == WALL else 0.70), 3.8, 5.4)
	if along_end:
		depth = rng.randf_range(8.1, 9.3)
	else:
		depth *= rng.randf_range(0.96, 1.04)
	var planes: Array[Plane] = [_through(-normal, center)]
	for index in polygon.size():
		var a: Vector3 = polygon[index]
		var b: Vector3 = polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var mid := (a + b) * 0.5
		var horizontal := absf(edge.y) < 0.38 * maxf(edge.length(), 0.000001)
		if horizontal and mid.y > center.y + 0.4:
			planes.append(_through(Vector3.UP, a))
			continue
		if horizontal and mid.y < center.y - 0.4:
			planes.append(_through(Vector3.DOWN, a))
			continue
		var e_hat := edge.normalized()
		var outward := normal.cross(edge).normalized()
		if outward.dot(mid - center) < 0.0:
			outward = -outward
		var n_perp := (normal - e_hat * normal.dot(e_hat)).normalized()
		var taper := rng.randf_range(0.05, 0.22) if kind == WALL else rng.randf_range(-0.12, 0.08)
		if along_end:
			taper = 0.0
		planes.append(_through(outward + n_perp * taper, a))
	var side := normal.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.04:
		side = Vector3.RIGHT
	var travel := Basis(Vector3.UP, deg_to_rad(turn_deg)) * normal
	var cap_swing := rng.randf_range(-0.05, 0.05) if along_end else rng.randf_range(-0.10, 0.10)
	var cap_n := (travel + side * cap_swing + Vector3.UP * (0.02 if kind == WALL else 0.0)).normalized()
	var cap_point := center + normal * depth
	for _push in 14:
		var clear := true
		var cap_d := cap_n.dot(cap_point)
		for point: Vector3 in polygon:
			if cap_n.dot(point) - cap_d >= -0.15:
				clear = false
				break
		if clear:
			break
		cap_point += normal * 0.45
	planes.append(_through(cap_n, cap_point))
	var swing := side if rng.randf() < 0.5 else -side
	var top_y := -INF
	for point: Vector3 in polygon:
		top_y = maxf(top_y, point.y)
	var shave_n: Vector3
	var shave_point: Vector3
	if kind == WALL:
		shave_n = (normal * 0.42 + swing * 0.88 + Vector3.UP * rng.randf_range(0.02, 0.22)).normalized()
		shave_point = center + normal * (depth * 0.52) + swing * (width * 0.28)
	else:
		shave_n = (normal * 0.48 + Vector3.UP * 0.55 + swing * 0.18).normalized()
		shave_point = center + normal * (depth * 0.46)
		shave_point.y = top_y - 0.35
	var cuts_mating := false
	var shave_d := shave_n.dot(shave_point)
	for point: Vector3 in polygon:
		if shave_n.dot(point) - shave_d >= -0.2:
			cuts_mating = true
			break
	if not along_end and not cuts_mating:
		planes.append(_through(shave_n, shave_point))
	return planes

static func _mark_mating(faces: Array[Dictionary], host_face: Dictionary) -> void:
	var normal: Vector3 = host_face["normal"].normalized()
	var center: Vector3 = host_face["center"]
	for face: Dictionary in faces:
		var face_normal: Vector3 = face["normal"]
		var face_center: Vector3 = face["center"]
		if face_normal.dot(-normal) > 0.96 and absf(face_normal.dot(face_center - center)) < 0.08:
			face["welded"] = true
			host_face["welded"] = true
			return

static func _transform(planes: Array[Plane], yaw: float, origin: Vector3) -> Array[Plane]:
	var basis := Basis(Vector3.UP, yaw)
	var moved: Array[Plane] = []
	for plane: Plane in planes:
		var normal := plane.normal.normalized()
		var point := basis * (normal * plane.d) + origin
		var turned := (basis * normal).normalized()
		moved.append(Plane(turned, turned.dot(point)))
	return moved

static func _through(normal: Vector3, point: Vector3) -> Plane:
	normal = normal.normalized()
	return Plane(normal, normal.dot(point))

static func _jitter_normal(rng: RandomNumberGenerator, normal: Vector3) -> Vector3:
	normal = normal.normalized()
	var axis := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := normal.cross(axis).normalized()
	return (normal + axis * sin(deg_to_rad(rng.randf_range(-1.6, 1.6))) + other * sin(deg_to_rad(rng.randf_range(-1.6, 1.6)))).normalized()

static func _vertices(planes: Array[Plane], snap_plane: Plane, snap_points: PackedVector3Array) -> PackedVector3Array:
	var found := PackedVector3Array()
	for a in planes.size():
		for b in range(a + 1, planes.size()):
			for c in range(b + 1, planes.size()):
				var point: Variant = planes[a].intersect_3(planes[b], planes[c])
				if point == null:
					continue
				var at: Vector3 = point
				var outside := false
				for plane: Plane in planes:
					if plane.distance_to(at) > 0.000015:
						outside = true
						break
				if outside:
					continue
				var duplicate := false
				for other: Vector3 in found:
					if other.distance_squared_to(at) < 1e-10:
						duplicate = true
						break
				if not duplicate:
					found.append(at)
	if snap_points.is_empty():
		return found
	for index in found.size():
		var at: Vector3 = found[index]
		if absf(snap_plane.distance_to(at)) > 0.03:
			continue
		var nearest := snap_points[0]
		var best := at.distance_squared_to(nearest)
		for candidate: Vector3 in snap_points:
			var score := at.distance_squared_to(candidate)
			if score < best:
				best = score
				nearest = candidate
		found[index] = nearest if best < 0.15 * 0.15 else snap_plane.project(at)
	var unique := PackedVector3Array()
	for at: Vector3 in found:
		var duplicate := false
		for other: Vector3 in unique:
			if other.distance_squared_to(at) < 1e-8:
				duplicate = true
				break
		if not duplicate:
			unique.append(at)
	return unique

static func _faces(planes: Array[Plane], vertices: PackedVector3Array) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	if vertices.size() < 4:
		return faces
	for index in planes.size():
		var plane := planes[index]
		var on := PackedVector3Array()
		for point: Vector3 in vertices:
			if absf(plane.distance_to(point)) <= 0.0003:
				on.append(point)
		if on.size() < 3:
			continue
		var ordered := _order(on, plane.normal)
		var cleaned := PackedVector3Array()
		for point: Vector3 in ordered:
			cleaned.append(point)
			while cleaned.size() >= 3:
				var a: Vector3 = cleaned[cleaned.size() - 3]
				var b: Vector3 = cleaned[cleaned.size() - 2]
				var c: Vector3 = cleaned[cleaned.size() - 1]
				if (b - a).cross(c - a).length_squared() < 0.0000000004:
					cleaned.remove_at(cleaned.size() - 2)
				else:
					break
		if cleaned.size() < 3:
			continue
		var cross := Vector3.ZERO
		for corner in range(1, cleaned.size() - 1):
			cross += (cleaned[corner] - cleaned[0]).cross(cleaned[corner + 1] - cleaned[0])
		var area := cross.length() * 0.5
		if area < 0.08:
			continue
		var face_normal := cross.normalized()
		if face_normal.dot(plane.normal) < 0.0:
			face_normal = -face_normal
			cleaned.reverse()
		var role := "side"
		if face_normal.y > 0.82:
			role = "top"
		elif face_normal.y < -0.82:
			role = "bottom"
		faces.append({
			"plane": index,
			"normal": face_normal,
			"polygon": cleaned,
			"area": area,
			"center": _mean(cleaned),
			"role": role,
			"welded": false,
		})
	return faces

static func _order(points: PackedVector3Array, normal: Vector3) -> PackedVector3Array:
	var center := _mean(points)
	var axis := normal.cross(Vector3.UP)
	if axis.length_squared() < 0.00000001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var other := normal.cross(axis)
	var sortable: Array[Vector3] = []
	for point: Vector3 in points:
		sortable.append(point)
	sortable.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2((a - center).dot(other), (a - center).dot(axis)) < atan2((b - center).dot(other), (b - center).dot(axis))
	)
	if sortable.size() >= 3 and (sortable[1] - sortable[0]).cross(sortable[2] - sortable[0]).dot(normal) < 0.0:
		sortable.reverse()
	var ordered := PackedVector3Array()
	for point: Vector3 in sortable:
		ordered.append(point)
	return ordered

static func _mean(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for point: Vector3 in points:
		sum += point
	return sum / maxf(points.size(), 1)

static func render_mesh(faces: Array[Dictionary], salt: int, hide_top: bool = false) -> ArrayMesh:
	return _mesh(faces, salt, true, hide_top)

static func _mesh(faces: Array[Dictionary], salt: int, hide_welded: bool, hide_top: bool = false) -> ArrayMesh:
	var side_v := PackedVector3Array()
	var side_n := PackedVector3Array()
	var top_v := PackedVector3Array()
	var top_n := PackedVector3Array()
	for face: Dictionary in faces:
		if hide_welded and face["welded"]:
			continue
		if face.get("hidden", false):
			continue
		if hide_top and face["role"] == "top":
			continue
		var polygon: PackedVector3Array = face["polygon"]
		var normal: Vector3 = face["normal"]
		var into_top: bool = face["role"] == "top"
		for index in range(1, polygon.size() - 1):
			var tri := PackedVector3Array([polygon[0], polygon[index], polygon[index + 1]])
			# Godot treats clockwise as the front face. Keep the vertex normal pointing outward.
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0:
				var swap := tri[1]
				tri[1] = tri[2]
				tri[2] = swap
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() < 0.00000001:
				continue
			for point: Vector3 in tri:
				if into_top:
					top_v.append(point)
					top_n.append(normal)
				else:
					side_v.append(point)
					side_n.append(normal)
	var mesh := ArrayMesh.new()
	_add_surface(mesh, side_v, side_n)
	_add_surface(mesh, top_v, top_n)
	return mesh

static func _add_surface(mesh: ArrayMesh, vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func _tint(face: Dictionary, salt: int) -> Color:
	var shift := absf(sin(float(salt) * 0.17 + float(face["plane"]) * 1.7))
	var tint := ROCK * (0.94 + 0.08 * shift)
	if face["role"] == "top":
		tint = SAGE * (0.94 + 0.08 * shift)
	elif face["role"] == "bottom":
		tint = ROCK * 0.72
	tint.a = 1.0
	return tint

static func aabb_of(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var box := AABB(vertices[0], Vector3.ZERO)
	for point: Vector3 in vertices:
		box = box.expand(point)
	return box
