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
	check(one.modules.size() == 1, "one stone should be a single chunk, got %d" % one.modules.size())
	if not one.modules.is_empty():
		_check_chunk(one.modules[0], 0)
	var pair := SlabField.new()
	pair.paint_two(7301)
	check(pair.modules.size() == 2, "two stones should be exactly two chunks, got %d" % pair.modules.size())
	if pair.modules.size() == 2:
		_check_chunk(pair.modules[0], 0)
		_check_chunk(pair.modules[1], 1)
		var a := HardSlab.aabb_of(pair.modules[0]["vertices"]).get_center()
		var b := HardSlab.aabb_of(pair.modules[1]["vertices"]).get_center()
		var apart := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		check(apart > 6.0 and apart < 14.0, "two stones should sit beside each other, centers %.2f m apart" % apart)
		check(absf(a.y - b.y) > 0.25, "two crowns should step, heights %.2f and %.2f" % [a.y, b.y])
	check(pair.undo(), "undo should remove the second stone")
	check(pair.modules.size() == 1, "undo should leave one stone")
	var grown := SlabField.new()
	grown.place_seed(Vector3.ZERO, 0.0, HardSlab.WALL, 7301)
	var side := _any_side(grown)
	check(not side.is_empty(), "a fresh chunk should expose a side to paint on")
	if not side.is_empty():
		var added := grown.expand(side["module"], side["face"], HardSlab.WALL, 7320, 4.0)
		check(added == 1, "clicking a side should add a second chunk, got %d" % added)
		if added == 1:
			_check_chunk(grown.modules[1], 1)
	var island := SlabField.new()
	island.paint_island(7301)
	check(island.modules.size() == 8, "small island should be eight chunks, got %d" % island.modules.size())
	check(island.deck_polygon.size() >= 6, "island needs a deck, verts %d" % island.deck_polygon.size())
	check(island.deck_y > 5.0, "deck should sit on the crowns, y %.2f" % island.deck_y)
	if island.modules.size() >= 3:
		var centroid := Vector3.ZERO
		for body: Dictionary in island.modules:
			centroid += HardSlab.aabb_of(body["vertices"]).get_center()
		centroid /= float(island.modules.size())
		var radii: Array[float] = []
		for body: Dictionary in island.modules:
			var center := HardSlab.aabb_of(body["vertices"]).get_center()
			radii.append(Vector2(center.x - centroid.x, center.z - centroid.z).length())
		var mean := 0.0
		for radius in radii:
			mean += radius
		mean /= float(radii.size())
		var ring := true
		for radius in radii:
			if absf(radius - mean) > 1.6:
				ring = false
		check(ring and mean > 2.0 and mean < 8.0, "island chunks should ring the deck, mean radius %.2f" % mean)
	_finish()

func _any_side(field: SlabField) -> Dictionary:
	if field.modules.is_empty():
		return {}
	var faces: Array[Dictionary] = field.modules[0]["faces"]
	for face_index in faces.size():
		var face: Dictionary = faces[face_index]
		if face["role"] == "side" and float(face["area"]) >= 12.0:
			return {"module": 0, "face": face_index}
	return {}

func _check_chunk(body: Dictionary, index: int) -> void:
	_check_module(body, index)
	var box := HardSlab.aabb_of(body["vertices"]).size
	var flat := Vector2(box.x, box.z)
	check(box.y >= 5.2 and flat.x >= 6.5 and flat.y >= 6.5, "chunk %d is not a thick mass %s" % [index, box])
	check(maxf(flat.x, flat.y) / minf(flat.x, flat.y) <= 1.85, "chunk %d is a ribbon %s" % [index, box])
	var top_y := -1.0
	for face: Dictionary in body["faces"]:
		if face["role"] == "top":
			top_y = maxf(top_y, float(face["normal"].y))
	check(top_y > 0.9, "chunk %d crown is not upright, ny %.2f" % [index, top_y])

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
