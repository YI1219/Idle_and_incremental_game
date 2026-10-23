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
	var one := SlabField.new()
	one.paint_one(7301)
	check(one.modules.size() == 1, "one stone should be a single slab, got %d" % one.modules.size())
	if not one.modules.is_empty():
		_check_module(one.modules[0], 0)
	var strip := SlabField.new()
	strip.paint_strip(7301)
	check(strip.modules.size() >= 4, "continuous strip needs several welded slabs, got %d" % strip.modules.size())
	_check_chain(strip)
	var strip_box := strip.bounds().size
	check(maxf(strip_box.x, strip_box.z) / minf(strip_box.x, strip_box.z) >= 2.4, "strip should read longer than it is thick: %s" % strip_box)
	var island := SlabField.new()
	island.paint_island(7301)
	check(island.modules.size() >= 4, "island face needs a run of slabs, got %d" % island.modules.size())
	_check_chain(island)
	check(_turns(island) >= 35.0, "island wall should bend, heading change %.1f" % _turns(island))
	var before := island.modules.size()
	check(island.undo(), "undo should remove the last slab")
	check(island.modules.size() == before - 1, "undo did not pop one slab")
	_finish()

func _check_module(body: Dictionary, index: int) -> void:
	var big := 0
	var min_area := INF
	for face: Dictionary in body["faces"]:
		var area: float = face["area"]
		if face["role"] != "bottom":
			min_area = minf(min_area, area)
		if face["role"] == "side" and area >= 12.0:
			big += 1
		_check_planar(face)
	check(big >= 3, "slab %d needs at least three wall-panel faces, got %d" % [index, big])
	check(min_area >= 2.4, "slab %d has a sliver face %.2f" % [index, min_area])
	check(_watertight(body["faces"]), "slab %d is not closed" % index)

func _check_chain(field: SlabField) -> void:
	if field.modules.is_empty():
		return
	_check_module(field.modules[0], 0)
	for index in range(1, field.modules.size()):
		var guest: Dictionary = field.modules[index]
		check(_watertight(guest["faces"]), "expanded slab %d is not closed" % index)
		var welded := _welded_face(guest["faces"])
		check(not welded.is_empty(), "expansion %d did not weld to the host face" % index)
		var host_welded := {}
		var host_gap := INF
		for earlier in index:
			var candidate := _matching_weld(field.modules[earlier]["faces"], welded)
			if candidate.is_empty():
				continue
			var candidate_gap := _hausdorff(welded["polygon"], candidate["polygon"])
			if candidate_gap < host_gap:
				host_gap = candidate_gap
				host_welded = candidate
		check(not host_welded.is_empty(), "host face for expansion %d was not marked welded" % index)
		if not welded.is_empty() and not host_welded.is_empty():
			var gap := _hausdorff(welded["polygon"], host_welded["polygon"])
			check(gap < 0.02, "mating polygons of expansion %d diverge by %.3f m" % [index, gap])
			var dot: float = welded["normal"].dot(host_welded["normal"])
			check(dot < -0.96, "mating normals of expansion %d are not opposite" % index)

func _turns(field: SlabField) -> float:
	if field.modules.size() < 3:
		return 0.0
	var centers: Array[Vector3] = []
	for body: Dictionary in field.modules:
		centers.append(HardSlab.aabb_of(body["vertices"]).get_center())
	var turn := 0.0
	for index in range(1, centers.size() - 1):
		var a := Vector2(centers[index].x - centers[index - 1].x, centers[index].z - centers[index - 1].z)
		var b := Vector2(centers[index + 1].x - centers[index].x, centers[index + 1].z - centers[index].z)
		if a.length() < 0.5 or b.length() < 0.5:
			continue
		turn = maxf(turn, absf(rad_to_deg(a.angle_to(b))))
	return turn

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
