extends Object
## Grid cells stay the play/cost unit. This file only builds the visible landmass.
## Outline comes from boundary edges (not a copied bank profile).

const COST_THICKNESS := 4.0
const COAST_NOISE := 0.18
const CHAIKIN_HIGH := 2
const CHAIKIN_LOW := 1

## y, outward offset in meters, grass weight 1..0
const RINGS_HIGH := [
	[0.00, 0.00, 1.00],
	[-0.08, 0.11, 0.82],
	[-0.22, 0.22, 0.40],
	[-0.55, 0.28, 0.10],
	[-1.25, 0.08, 0.00],
	[-2.40, -0.42, 0.00],
	[-3.80, -1.05, 0.00],
	[-5.20, -1.70, 0.00],
	[-6.40, -2.20, 0.00],
]
const RINGS_LOW := [
	[0.00, 0.00, 1.00],
	[-0.40, 0.22, 0.28],
	[-2.60, -0.55, 0.00],
	[-6.20, -2.00, 0.00],
]


static func cell_volume(thickness: float = COST_THICKNESS) -> float:
	return 1.0 * maxf(thickness, 0.0)


static func cells_hash(cells: Dictionary) -> int:
	var keys: Array = cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	var h := 17
	for cell: Vector2i in keys:
		h = h * 31 + cell.x
		h = h * 31 + cell.y
	return h


static func components(cells: Dictionary) -> Array[Dictionary]:
	var remaining: Dictionary = cells.duplicate()
	var groups: Array[Dictionary] = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var stack: Array[Vector2i] = [start]
		var group: Dictionary = {}
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			if not remaining.has(cell):
				continue
			remaining.erase(cell)
			group[cell] = true
			for d: Vector2i in dirs:
				var next := cell + d
				if remaining.has(next):
					stack.append(next)
		if not group.is_empty():
			groups.append(group)
	return groups


static func component_size_after_add(cells: Array, added: Vector2i) -> int:
	var land: Dictionary = {}
	for cell: Vector2i in cells:
		land[cell] = true
	land[added] = true
	for group in components(land):
		if group.has(added):
			return group.size()
	return 1


static func build_island(cells: Dictionary, river_polygons: Array, high_detail: bool = true) -> Dictionary:
	var empty := {
		"top": _empty_mesh(),
		"volume": _empty_mesh(),
		"low_volume": _empty_mesh(),
		"centroid": Vector3.ZERO,
		"bounds": AABB(),
		"cell_count": cells.size(),
		"outline": PackedVector2Array(),
	}
	if cells.is_empty():
		return empty
	var loops := boundary_loops(cells)
	if loops.is_empty():
		return empty
	var outers: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for loop in loops:
		if signed_area(loop) >= 0.0:
			outers.append(loop)
		else:
			holes.append(loop)
	if outers.is_empty():
		return empty
	var outline := outers[0]
	for extra in range(1, outers.size()):
		outline = _largest(outline, outers[extra])
	var smooth_high := noise_coast(chaikin(outline, CHAIKIN_HIGH), COAST_NOISE)
	var smooth_low := noise_coast(chaikin(outline, CHAIKIN_LOW), COAST_NOISE * 0.45)
	var hole_cutters: Array = river_polygons.duplicate()
	for hole in holes:
		hole_cutters.append(chaikin(hole, 1))
	var top := build_top(smooth_high, hole_cutters)
	var volume := build_volume(smooth_high, RINGS_HIGH, holes)
	var low := build_volume(smooth_low, RINGS_LOW, [])
	var centroid := _centroid3(cells)
	return {
		"top": top,
		"volume": volume,
		"low_volume": low,
		"centroid": centroid,
		"bounds": _bounds_of(volume),
		"cell_count": cells.size(),
		"outline": smooth_high,
	}


static func boundary_loops(cells: Dictionary) -> Array[PackedVector2Array]:
	var outgoing: Dictionary = {}
	for cell: Vector2i in cells:
		if not cells.has(cell + Vector2i(0, -1)):
			_push_edge(outgoing, Vector2(cell.x, cell.y), Vector2(cell.x + 1, cell.y))
		if not cells.has(cell + Vector2i(1, 0)):
			_push_edge(outgoing, Vector2(cell.x + 1, cell.y), Vector2(cell.x + 1, cell.y + 1))
		if not cells.has(cell + Vector2i(0, 1)):
			_push_edge(outgoing, Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x, cell.y + 1))
		if not cells.has(cell + Vector2i(-1, 0)):
			_push_edge(outgoing, Vector2(cell.x, cell.y + 1), Vector2(cell.x, cell.y))
	var loops: Array[PackedVector2Array] = []
	for start_key in outgoing.keys():
		while (outgoing[start_key] as Array).size() > 0:
			var parts := String(start_key).split(",")
			var curr := Vector2(int(parts[0]), int(parts[1]))
			var loop := PackedVector2Array()
			var guard := 0
			while guard < 20000:
				guard += 1
				loop.append(curr)
				var ck := "%d,%d" % [int(round(curr.x)), int(round(curr.y))]
				if not outgoing.has(ck) or (outgoing[ck] as Array).is_empty():
					break
				var nxt: Vector2 = (outgoing[ck] as Array).pop_back()
				curr = nxt
				if loop.size() > 2 and curr.is_equal_approx(loop[0]):
					break
			if loop.size() >= 3:
				if loop[0].is_equal_approx(loop[loop.size() - 1]):
					loop.remove_at(loop.size() - 1)
				loops.append(loop)
	return loops


static func chaikin(polygon: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result := polygon
	for _i in maxi(iterations, 0):
		if result.size() < 3:
			break
		var next := PackedVector2Array()
		for i in result.size():
			var a := result[i]
			var b := result[(i + 1) % result.size()]
			next.append(a * 0.75 + b * 0.25)
			next.append(a * 0.25 + b * 0.75)
		result = next
	return result


static func noise_coast(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.size() < 3 or amount <= 0.0:
		return polygon
	var out := PackedVector2Array()
	out.resize(polygon.size())
	for i in polygon.size():
		var normal := _vertex_normal(polygon, i)
		var n := _hash2(polygon[i])
		out[i] = polygon[i] + normal * ((n - 0.5) * 2.0 * amount)
	return out


static func build_top(outline: PackedVector2Array, cutters: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if outline.size() < 3:
		return st.commit()
	var indices := Geometry2D.triangulate_polygon(outline)
	var triangles: Array[PackedVector2Array] = []
	for i in range(0, indices.size(), 3):
		triangles.append(PackedVector2Array([
			outline[indices[i]], outline[indices[i + 1]], outline[indices[i + 2]]
		]))
	for cutter in cutters:
		if not (cutter is PackedVector2Array) or cutter.size() < 3:
			continue
		var clipped: Array[PackedVector2Array] = []
		for tri in triangles:
			for remain: PackedVector2Array in Geometry2D.clip_polygons(tri, cutter):
				if remain.size() >= 3:
					clipped.append(remain)
		triangles = clipped
	for piece in triangles:
		_emit_top(st, piece)
	st.generate_normals()
	return st.commit()


static func build_volume(outline: PackedVector2Array, rings: Array, holes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if outline.size() < 3 or rings.size() < 2:
		return st.commit()
	_emit_skirt(st, outline, rings, false)
	var tip: PackedVector2Array = _ring_at(outline, float(rings[rings.size() - 1][1]))
	_emit_top_colored(st, tip, float(rings[rings.size() - 1][0]), 0.0, Vector3.DOWN)
	for hole in holes:
		if hole.size() < 3:
			continue
		var inverted: Array = []
		for row in rings:
			inverted.append([row[0], -float(row[1]) * 0.65, row[2]])
		_emit_skirt(st, hole, inverted, true)
	st.generate_normals()
	return st.commit()


static func combine_meshes(meshes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mesh in meshes:
		if mesh is ArrayMesh and (mesh as ArrayMesh).get_surface_count() > 0:
			st.append_from(mesh, 0, Transform3D.IDENTITY)
	return st.commit()


static func has_rectangular_top(mesh: ArrayMesh, tolerance: float = 0.02) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return true
	var faces := mesh.get_faces()
	var axis := 0
	for vertex in faces:
		if absf(vertex.y) > 0.02:
			continue
		if absf(vertex.x - roundf(vertex.x)) > tolerance and absf(vertex.z - roundf(vertex.z)) > tolerance:
			axis += 1
	return axis < 8


static func lowest_y(mesh: ArrayMesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var lowest := 0.0
	for vertex in mesh.get_faces():
		lowest = minf(lowest, vertex.y)
	return lowest


static func signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


static func _emit_skirt(st: SurfaceTool, outline: PackedVector2Array, rings: Array, hole: bool) -> void:
	var prev := outline
	var prev_y := float(rings[0][0])
	var prev_turf := float(rings[0][2])
	var limit := _inset_limit(outline)
	for r in range(1, rings.size()):
		var y := float(rings[r][0])
		var offset := clampf(float(rings[r][1]), -limit, limit * 1.4)
		var turf := float(rings[r][2])
		var curr := _ring_at(outline, offset)
		if curr.size() != prev.size():
			curr = _resample(curr, prev.size())
		_stitch_rings(st, prev, prev_y, prev_turf, curr, y, turf, hole)
		prev = curr
		prev_y = y
		prev_turf = turf


static func _ring_at(outline: PackedVector2Array, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(outline.size())
	for i in outline.size():
		out[i] = outline[i] + _vertex_normal(outline, i) * offset
	return out


static func _stitch_rings(st: SurfaceTool, a: PackedVector2Array, ay: float, at: float, b: PackedVector2Array, by: float, bt: float, hole: bool) -> void:
	var n := mini(a.size(), b.size())
	for i in n:
		var j := (i + 1) % n
		var p0 := Vector3(a[i].x, ay, a[i].y)
		var p1 := Vector3(a[j].x, ay, a[j].y)
		var p2 := Vector3(b[j].x, by, b[j].y)
		var p3 := Vector3(b[i].x, by, b[i].y)
		if hole:
			_tri(st, p0, p3, p2, at, bt, bt)
			_tri(st, p0, p2, p1, at, bt, at)
		else:
			_tri(st, p0, p1, p2, at, at, bt)
			_tri(st, p0, p2, p3, at, bt, bt)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ta: float, tb: float, tc: float) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	for item in [[a, ta], [b, tb], [c, tc]]:
		var p: Vector3 = item[0]
		st.set_normal(normal)
		st.set_color(Color(float(item[1]), 0.18, 0.08))
		st.set_uv(Vector2(p.x, p.z) * 0.12)
		st.add_vertex(p)


static func _emit_top(st: SurfaceTool, polygon: PackedVector2Array) -> void:
	_emit_top_colored(st, polygon, 0.0, 1.0, Vector3.UP)


static func _emit_top_colored(st: SurfaceTool, polygon: PackedVector2Array, y: float, turf: float, normal: Vector3) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	for index: int in indices:
		var p := polygon[index]
		st.set_normal(normal)
		st.set_color(Color(turf, 0.12, 0.06))
		st.set_uv(p * 0.12)
		st.add_vertex(Vector3(p.x, y, p.y))


static func _vertex_normal(polygon: PackedVector2Array, i: int) -> Vector2:
	var n := polygon.size()
	var prev := polygon[(i - 1 + n) % n]
	var curr := polygon[i]
	var next := polygon[(i + 1) % n]
	var t1 := (curr - prev).normalized()
	var t2 := (next - curr).normalized()
	var normal := Vector2(-(t1.y + t2.y), t1.x + t2.x)
	if normal.length_squared() < 1e-8:
		normal = Vector2(-t1.y, t1.x)
	return normal.normalized()


static func _inset_limit(polygon: PackedVector2Array) -> float:
	var area := absf(signed_area(polygon))
	return maxf(0.22, minf(1.8, sqrt(maxf(area, 0.25) / PI) * 0.42))


static func _resample(polygon: PackedVector2Array, count: int) -> PackedVector2Array:
	if polygon.size() == count or polygon.is_empty() or count < 3:
		return polygon
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(count) * float(polygon.size())
		var a := int(floor(t)) % polygon.size()
		var b := (a + 1) % polygon.size()
		out[i] = polygon[a].lerp(polygon[b], t - floor(t))
	return out


static func _centroid3(cells: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	for cell: Vector2i in cells:
		sum += Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	return sum / float(maxi(cells.size(), 1))


static func _bounds_of(mesh: ArrayMesh) -> AABB:
	if mesh == null or mesh.get_surface_count() == 0:
		return AABB()
	var box := AABB()
	var first := true
	for vertex in mesh.get_faces():
		if first:
			box = AABB(vertex, Vector3.ZERO)
			first = false
		else:
			box = box.expand(vertex)
	return box


static func _largest(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	return a if absf(signed_area(a)) >= absf(signed_area(b)) else b


static func _push_edge(outgoing: Dictionary, a: Vector2, b: Vector2) -> void:
	var key := "%d,%d" % [int(round(a.x)), int(round(a.y))]
	if not outgoing.has(key):
		outgoing[key] = []
	(outgoing[key] as Array).append(b)


static func _hash2(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)


static func _empty_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st.commit()
