class_name SlabField
extends RefCounted
## Brush field for hard slabs. Empty until the player places the first piece.
## Nothing here writes the courtyard terrain or seed 7301 contour.

var modules: Array[Dictionary] = []
var _undo: Array[Dictionary] = []

func clear() -> void:
	modules.clear()
	_undo.clear()

func place_seed(origin: Vector3, yaw: float, kind: int, seed_value: int) -> int:
	var body := HardSlab.seed_module(kind, seed_value, yaw, origin)
	if not _readable(body):
		return -1
	modules.append(body)
	_undo.append({})
	return modules.size() - 1

func expand(module_index: int, face_index: int, kind: int, seed_value: int) -> int:
	if module_index < 0 or module_index >= modules.size():
		return -1
	var host: Dictionary = modules[module_index]
	var faces: Array[Dictionary] = host["faces"]
	if face_index < 0 or face_index >= faces.size():
		return -1
	var face: Dictionary = faces[face_index]
	if face["role"] != "side" or face["welded"]:
		return -1
	var guest := HardSlab.expand_module(face, kind, seed_value)
	if not _acceptable_guest(guest):
		face["welded"] = false
		return -1
	if _overlaps_sibling(guest, module_index):
		face["welded"] = false
		return -1
	modules.append(guest)
	host["mesh"] = HardSlab.render_mesh(faces, int(host["seed"]))
	_undo.append({"module": module_index, "face": face_index})
	return modules.size() - 1

func undo() -> bool:
	if modules.is_empty():
		return false
	var action: Dictionary = _undo.pop_back()
	modules.pop_back()
	if action.has("module"):
		var host: Dictionary = modules[action["module"]]
		var faces: Array[Dictionary] = host["faces"]
		faces[action["face"]]["welded"] = false
		host["mesh"] = HardSlab.render_mesh(faces, int(host["seed"]))
	return true

func paint_sample(seed_value: int = 7301) -> void:
	clear()
	place_seed(Vector3.ZERO, deg_to_rad(18.0), HardSlab.WALL, seed_value)
	var steps: Array[Dictionary] = [
		{"direction": Vector3(0.05, 0.0, 1.0), "kind": HardSlab.SHOULDER, "salt": 11},
		{"direction": Vector3(-0.05, 0.0, -1.0), "kind": HardSlab.WALL, "salt": 29},
	]
	for step: Dictionary in steps:
		var chosen := _best_toward(step["direction"])
		if chosen.is_empty():
			continue
		expand(chosen["module"], chosen["face"], step["kind"], seed_value + int(step["salt"]))

func raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	var dir := direction.normalized()
	var best := {}
	var best_t := INF
	for module_index in modules.size():
		var faces: Array[Dictionary] = modules[module_index]["faces"]
		for face_index in faces.size():
			var face: Dictionary = faces[face_index]
			if face["welded"] or face["role"] == "bottom":
				continue
			var normal: Vector3 = face["normal"]
			var denom := normal.dot(dir)
			if absf(denom) < 0.00001:
				continue
			var t := normal.dot(face["center"] - origin) / denom
			if t < 0.05 or t >= best_t:
				continue
			var hit: Vector3 = origin + dir * t
			if not _point_in_face(hit, face):
				continue
			best_t = t
			best = {"module": module_index, "face": face_index, "point": hit, "role": face["role"], "normal": normal}
	return best

func face_near_point(point: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_score := INF
	for module_index in modules.size():
		var faces: Array[Dictionary] = modules[module_index]["faces"]
		for face_index in faces.size():
			var face: Dictionary = faces[face_index]
			if face["role"] != "side" or face["welded"] or float(face["area"]) < 8.0:
				continue
			var normal: Vector3 = face["normal"]
			var plane := Plane(normal, face["center"])
			var along := plane.distance_to(point)
			if along < -0.25 or along > radius:
				continue
			var closest := _closest_on_polygon(point - normal * along, face)
			var score: float = closest.distance_to(point)
			if score > radius or score >= best_score:
				continue
			best_score = score
			best = {"module": module_index, "face": face_index}
	return best

func bounds() -> AABB:
	var box := AABB()
	var started := false
	for body: Dictionary in modules:
		var next: AABB = HardSlab.aabb_of(body["vertices"])
		if not started:
			box = next
			started = true
		else:
			box = box.merge(next)
	return box

func _best_toward(direction: Vector3) -> Dictionary:
	direction = direction.normalized()
	var best := {}
	var best_score := -INF
	for module_index in modules.size():
		var faces: Array[Dictionary] = modules[module_index]["faces"]
		for face_index in faces.size():
			var face: Dictionary = faces[face_index]
			if face["role"] != "side" or face["welded"] or float(face["area"]) < 8.0:
				continue
			var align: float = face["normal"].dot(direction)
			if align < 0.45:
				continue
			var score := align * 4.0 + sqrt(float(face["area"])) * 0.08
			if score > best_score:
				best_score = score
				best = {"module": module_index, "face": face_index}
	return best

func _readable(body: Dictionary) -> bool:
	var faces: Array[Dictionary] = body["faces"]
	if faces.size() < 6:
		return false
	var big := 0
	for face: Dictionary in faces:
		if float(face["area"]) < 2.4:
			return false
		if face["role"] == "side" and float(face["area"]) >= 12.0:
			big += 1
	return big >= 3

func _acceptable_guest(body: Dictionary) -> bool:
	var faces: Array[Dictionary] = body["faces"]
	var vertices: PackedVector3Array = body["vertices"]
	if faces.size() < 6 or vertices.size() < 6:
		return false
	var side_max := 0.0
	var top_sum := 0.0
	var min_area := INF
	for face: Dictionary in faces:
		var area: float = face["area"]
		min_area = minf(min_area, area)
		if face["role"] == "side":
			side_max = maxf(side_max, area)
		elif face["role"] == "top":
			top_sum += area
	if side_max < 8.0 or top_sum < 6.0 or min_area < 2.4:
		return false
	var welded := false
	for face: Dictionary in faces:
		if face["welded"]:
			welded = true
			break
	return welded and HardSlab.aabb_of(vertices).size.y >= 4.5

func _overlaps_sibling(guest: Dictionary, host_index: int) -> bool:
	var guest_verts: PackedVector3Array = guest["vertices"]
	var guest_planes: Array[Plane] = guest["planes"]
	for index in modules.size():
		if index == host_index:
			continue
		var other: Dictionary = modules[index]
		if _separated(other["planes"], guest_verts) or _separated(guest_planes, other["vertices"]):
			continue
		for point: Vector3 in guest_verts:
			var inside := true
			for plane: Plane in other["planes"]:
				if plane.distance_to(point) >= -0.05:
					inside = false
					break
			if inside:
				return true
	return false

func _separated(planes: Array[Plane], points: PackedVector3Array) -> bool:
	for plane: Plane in planes:
		var outside := true
		for point: Vector3 in points:
			if plane.distance_to(point) <= 0.04:
				outside = false
				break
		if outside and not points.is_empty():
			return true
	return false

func _point_in_face(point: Vector3, face: Dictionary) -> bool:
	var normal: Vector3 = face["normal"]
	var center: Vector3 = face["center"]
	if absf(normal.dot(point - center)) > 0.04:
		return false
	var polygon: PackedVector3Array = face["polygon"]
	var axis := normal.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var other := normal.cross(axis)
	var flat := PackedVector2Array()
	for vertex: Vector3 in polygon:
		var delta := vertex - center
		flat.append(Vector2(delta.dot(axis), delta.dot(other)))
	var at := point - center
	return Geometry2D.is_point_in_polygon(Vector2(at.dot(axis), at.dot(other)), flat)

func _closest_on_polygon(point: Vector3, face: Dictionary) -> Vector3:
	var polygon: PackedVector3Array = face["polygon"]
	var best := polygon[0]
	var best_d := point.distance_squared_to(best)
	for index in polygon.size():
		var a: Vector3 = polygon[index]
		var b: Vector3 = polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var t := clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
		var closest := a + edge * t
		var score := point.distance_squared_to(closest)
		if score < best_d:
			best_d = score
			best = closest
	if _point_in_face(point, face):
		return point
	return best
