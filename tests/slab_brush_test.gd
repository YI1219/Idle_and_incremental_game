extends SceneTree
## Structural checks for the hard-slab brush. Visual acceptance is a separate capture.

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var field: SlabField = SlabField.new()
	field.paint_sample(7301)
	check(field.modules.size() >= 2, "sample island needs a seed slab plus one welded neighbour, got %d" % field.modules.size())
	if field.modules.is_empty():
		_finish()
		return
	var seed: Dictionary = field.modules[0]
	var big := 0
	var min_area := INF
	for face: Dictionary in seed["faces"]:
		min_area = minf(min_area, float(face["area"]))
		if face["role"] == "side" and float(face["area"]) >= 12.0:
			big += 1
		_check_planar(face)
	check(big >= 3, "seed needs at least three wall-panel faces, got %d" % big)
	check(min_area >= 2.4, "seed has a sliver face %.2f" % min_area)
	check(_watertight(seed["faces"]), "seed slab is not closed")
	for index in range(1, field.modules.size()):
		var guest: Dictionary = field.modules[index]
		check(_watertight(guest["faces"]), "expanded slab %d is not closed" % index)
		var welded := _welded_face(guest["faces"])
		check(not welded.is_empty(), "expansion %d did not weld to the host face" % index)
		var host_welded := _matching_weld(seed["faces"], welded)
		check(not host_welded.is_empty(), "host face for expansion %d was not marked welded" % index)
		if not welded.is_empty() and not host_welded.is_empty():
			var gap := _hausdorff(welded["polygon"], host_welded["polygon"])
			check(gap < 0.02, "mating polygons of expansion %d diverge by %.3f m" % [index, gap])
			var dot: float = welded["normal"].dot(host_welded["normal"])
			check(dot < -0.96, "mating normals of expansion %d are not opposite" % index)
	var before := field.modules.size()
	check(field.undo(), "undo should remove the last slab")
	check(field.modules.size() == before - 1, "undo did not pop one slab")
	var box := field.bounds().size
	check(box.x > 8.0 and box.z > 8.0 and box.y > 4.5, "cluster bounds are not an island mass: %s" % box)
	check(maxf(box.x, box.z) / minf(box.x, box.z) < 2.4, "cluster is a strip rather than a compact start: %s" % box)
	_finish()

func _check_planar(face: Dictionary) -> void:
	var plane := Plane(face["normal"], face["center"])
	for point: Vector3 in face["polygon"]:
		if absf(plane.distance_to(point)) > 0.002:
			check(false, "face %s is not flat" % face["role"])
			return

func _matching_weld(faces: Array, guest_face: Dictionary) -> Dictionary:
	if guest_face.is_empty():
		return {}
	var best: Dictionary = {}
	var best_gap := INF
	for face: Dictionary in faces:
		if not face["welded"]:
			continue
		if float(face["normal"].dot(guest_face["normal"])) > -0.9:
			continue
		var gap := _hausdorff(face["polygon"], guest_face["polygon"])
		if gap < best_gap:
			best_gap = gap
			best = face
	return best

func _welded_face(faces: Array) -> Dictionary:
	for face: Dictionary in faces:
		if face["welded"]:
			return face
	return {}

func _hausdorff(a: PackedVector3Array, b: PackedVector3Array) -> float:
	return maxf(_directed(a, b), _directed(b, a))

func _directed(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := 0.0
	for point: Vector3 in a:
		var best := INF
		for other: Vector3 in b:
			best = minf(best, point.distance_to(other))
		worst = maxf(worst, best)
	return worst

func _watertight(faces: Array) -> bool:
	var edges: Dictionary = {}
	for face: Dictionary in faces:
		var polygon: PackedVector3Array = face["polygon"]
		for index in polygon.size():
			var a := _key(polygon[index])
			var b := _key(polygon[(index + 1) % polygon.size()])
			var key := a + "|" + b if a < b else b + "|" + a
			edges[key] = int(edges.get(key, 0)) + 1
	for key: String in edges:
		if int(edges[key]) != 2:
			return false
	return not edges.is_empty()

func _key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 10000.0), roundi(point.y * 10000.0), roundi(point.z * 10000.0)]

func _finish() -> void:
	print("SLAB BRUSH TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
