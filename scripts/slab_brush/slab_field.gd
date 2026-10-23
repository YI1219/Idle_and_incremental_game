class_name SlabField
extends RefCounted
## Brush field for hard slabs. Empty until the player places the first piece.
## Nothing here writes the courtyard terrain or seed 7301 contour.

var modules: Array[Dictionary] = []
var _undo: Array[Dictionary] = []
var deck_polygon := PackedVector2Array()
var deck_y := 0.0

func clear() -> void:
	modules.clear()
	_undo.clear()
	deck_polygon = PackedVector2Array()
	deck_y = 0.0

func place_seed(origin: Vector3, yaw: float, kind: int, seed_value: int) -> int:
	var body := HardSlab.seed_module(kind, seed_value, yaw, origin)
	if not _readable(body):
		return -1
	modules.append(body)
	_undo.append({})
	return modules.size() - 1

func expand(module_index: int, face_index: int, kind: int, seed_value: int, turn_deg: float = 0.0) -> int:
	if module_index < 0 or module_index >= modules.size():
		return -1
	var host: Dictionary = modules[module_index]
	var faces: Array[Dictionary] = host["faces"]
	if face_index < 0 or face_index >= faces.size():
		return -1
	var face: Dictionary = faces[face_index]
	if face["role"] != "side" or face["welded"]:
		return -1
	var guest := HardSlab.attach_module(face, kind, seed_value, turn_deg)
	if not _chunky(guest):
		return -1
	if _overlaps_sibling(guest, module_index):
		return -1
	modules.append(guest)
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

func paint_one(seed_value: int = 7301) -> void:
	clear()
	place_seed(Vector3.ZERO, deg_to_rad(18.0), HardSlab.WALL, seed_value)

func paint_two(seed_value: int = 7301) -> void:
	clear()
	place_seed(Vector3(-4.15, 0.0, 0.05), deg_to_rad(4.0), HardSlab.WALL, seed_value)
	place_seed(Vector3(3.85, -0.7, 0.35), deg_to_rad(-6.0), HardSlab.WALL, seed_value + 19)

func paint_island(seed_value: int = 7301) -> void:
	clear()
	var count := 8
	var radius := 3.15
	for index in count:
		var angle := TAU * float(index) / float(count)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		place_seed(outward * radius, HardSlab.yaw_facing(outward), HardSlab.WALL, seed_value + index * 11)
	_cap_deck()

func paint_sample(seed_value: int = 7301) -> void:
	paint_island(seed_value)

func _cap_deck() -> void:
	var centroid := Vector3.ZERO
	for body: Dictionary in modules:
		centroid += HardSlab.aabb_of(body["vertices"]).get_center()
	if not modules.is_empty():
		centroid /= float(modules.size())
	var points := PackedVector2Array()
	var crown := 0.0
	for body: Dictionary in modules:
		var chunk_center: Vector3 = HardSlab.aabb_of(body["vertices"]).get_center()
		var outward := Vector3(chunk_center.x - centroid.x, 0.0, chunk_center.z - centroid.z)
		if outward.length_squared() < 0.01:
			outward = Vector3(0.0, 0.0, 1.0)
		outward = outward.normalized()
		for face: Dictionary in body["faces"]:
			if face["role"] == "top":
				crown = maxf(crown, float(face["center"].y))
				for point: Vector3 in face["polygon"]:
					points.append(Vector2(point.x, point.z))
				face["hidden"] = true
				continue
			if face["role"] == "bottom":
				face["hidden"] = true
				continue
			var flat_n := Vector3(face["normal"].x, 0.0, face["normal"].z)
			var facing_out := flat_n.length_squared() > 0.04 and flat_n.normalized().dot(outward) >= 0.2
			face["hidden"] = not facing_out
		body["mesh"] = HardSlab.render_mesh(body["faces"], int(body["seed"]), true)
	if points.size() < 3:
		return
	deck_polygon = Geometry2D.convex_hull(points)
	deck_y = crown + 0.16

func _chunky(body: Dictionary) -> bool:
	var box: AABB = HardSlab.aabb_of(body["vertices"])
	var flat := Vector2(box.size.x, box.size.z)
	if box.size.y < 5.2 or flat.x < 6.5 or flat.y < 6.5:
		return false
	if maxf(flat.x, flat.y) / minf(flat.x, flat.y) > 1.85:
		return false
	var top := 0.0
	for face: Dictionary in body["faces"]:
		if face["role"] == "top":
			top += float(face["area"])
	return top > 18.0

func _grow(direction: Vector3, steps: int, kind: int, seed_value: int, turn_deg: float, start_tip: int = -1) -> void:
	var travel := Vector3(direction.x, 0.0, direction.z).normalized()
	if travel.length_squared() < 0.01:
		travel = Vector3(1.0, 0.0, 0.0)
	var tip := modules.size() - 1 if start_tip < 0 else start_tip
	for step in steps:
		var chosen := _tip_face(travel, tip)
		if chosen.is_empty():
			return
		var placed := false
		for attempt in 6:
			var salt := seed_value + 40 + step * 17 + attempt * 5
			var id := expand(chosen["module"], chosen["face"], kind, salt, turn_deg)
			if id < 0:
				continue
			tip = id
			var cap := _far_end(id)
			if not cap.is_empty():
				var normal: Vector3 = cap["normal"]
				var flat := Vector3(normal.x, 0.0, normal.z)
				if flat.length_squared() > 0.04:
					travel = flat.normalized()
			placed = true
			break
		if placed:
			continue
		modules[chosen["module"]]["faces"][chosen["face"]]["blocked"] = true
		var other := _tip_face(travel, tip)
		if other.is_empty():
			return
		var id_other := expand(other["module"], other["face"], kind, seed_value + 90 + step * 13, turn_deg)
		if id_other < 0:
			return
		tip = id_other

func _tip_face(direction: Vector3, module_index: int = -1) -> Dictionary:
	if modules.is_empty():
		return {}
	direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if module_index < 0:
		module_index = modules.size() - 1
	var faces: Array[Dictionary] = modules[module_index]["faces"]
	var best := {}
	var best_score := -INF
	for face_index in faces.size():
		var face: Dictionary = faces[face_index]
		if face["role"] != "side" or face["welded"] or face.get("blocked", false) or float(face["area"]) < 6.0:
			continue
		var flat := Vector3(face["normal"].x, 0.0, face["normal"].z)
		if flat.length_squared() < 0.04:
			continue
		if _face_width(face) > 7.2:
			continue
		var align: float = flat.normalized().dot(direction)
		if align < 0.35:
			continue
		var score := align * 8.0 - float(face["area"]) * 0.02
		if score > best_score:
			best_score = score
			best = {"module": module_index, "face": face_index}
	return best

func _face_width(face: Dictionary) -> float:
	var polygon: PackedVector3Array = face["polygon"]
	var width := 0.0
	for index in polygon.size():
		var a: Vector3 = polygon[index]
		var b: Vector3 = polygon[(index + 1) % polygon.size()]
		width = maxf(width, Vector2(b.x - a.x, b.z - a.z).length())
	return width

func _far_end(module_index: int) -> Dictionary:
	var faces: Array[Dictionary] = modules[module_index]["faces"]
	var origin := Vector3.ZERO
	var found := false
	for face: Dictionary in faces:
		if face["welded"]:
			origin = face["center"]
			found = true
			break
	if not found:
		return {}
	var best: Dictionary = {}
	var best_dist := 1.5
	for face: Dictionary in faces:
		if face["welded"] or face["role"] != "side" or _face_width(face) > 7.2:
			continue
		var dist: float = face["center"].distance_to(origin)
		if dist > best_dist:
			best_dist = dist
			best = face
	return best

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
			if face["role"] != "side" or face["welded"] or face.get("blocked", false) or float(face["area"]) < 8.0:
				continue
			var align: float = face["normal"].dot(direction)
			if align < 0.45:
				continue
			var score := align * 4.0 + sqrt(float(face["area"])) * 0.08 + float(module_index) * 0.35
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
	for face: Dictionary in faces:
		var area: float = face["area"]
		if face["role"] == "bottom":
			if area < 0.8:
				return false
		elif area < 2.4:
			return false
		if face["role"] == "side":
			side_max = maxf(side_max, area)
		elif face["role"] == "top":
			top_sum += area
	if side_max < 8.0 or top_sum < 6.0:
		return false
	var span := HardSlab.aabb_of(vertices).size
	if span.x > 16.0 or span.z > 16.0:
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
				if plane.distance_to(point) >= -0.9:
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
