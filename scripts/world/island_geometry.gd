extends Object
## Grid cells stay the play/cost unit. This file only builds the visible landmass.
## Outline is a simplified, large-radius smooth of the grid boundary — not local-normal spikes.

const COST_THICKNESS := 4.0
const COAST_WOBBLE := 1.35
const CHAIKIN_HIGH := 4
const CHAIKIN_LOW := 2
const CATMULL_HIGH := 3
const CATMULL_LOW := 2
const OVERHANG := 1.07

## y, radial scale from the 2D centroid, grass weight 1..0
const RINGS_HIGH := [
	[0.00, 1.06, 1.00],
	[-0.16, 1.13, 0.72],
	[-0.40, 1.04, 0.28],
	[-0.82, 0.92, 0.06],
	[-1.55, 0.78, 0.00],
	[-2.55, 0.58, 0.00],
	[-3.70, 0.40, 0.00],
	[-4.90, 0.26, 0.00],
	[-6.05, 0.18, 0.00],
]
const RINGS_LOW := [
	[0.00, 1.05, 1.00],
	[-0.45, 1.02, 0.22],
	[-2.40, 0.56, 0.00],
	[-6.00, 0.20, 0.00],
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


static func cell_quad(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cell.x, cell.y), Vector2(cell.x, cell.y + 1),
		Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x + 1, cell.y),
	])


static func build_island(cells: Dictionary, river_polygons: Array, high_detail: bool = true, water_cells: Dictionary = {}) -> Dictionary:
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
	var smooth_high := visual_outline(outline, true)
	var smooth_low := visual_outline(outline, false)
	var hole_cutters: Array = river_polygons.duplicate()
	for hole in holes:
		hole_cutters.append(visual_outline(hole, false))
	for cell: Vector2i in water_cells:
		if cells.has(cell):
			hole_cutters.append(cell_quad(cell))
	var top := build_top(scale_from_centroid(smooth_high, OVERHANG), hole_cutters)
	var volume := build_volume(smooth_high, RINGS_HIGH)
	var low := build_volume(smooth_low, RINGS_LOW)
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


static func visual_outline(raw: PackedVector2Array, high_detail: bool = true) -> PackedVector2Array:
	if raw.size() < 3:
		return raw
	var simple := simplify_colinear(raw)
	var radius := _corner_radius(simple)
	var rounded := round_corners(simple, radius)
	var iterations := CHAIKIN_HIGH if high_detail else CHAIKIN_LOW
	var samples := CATMULL_HIGH if high_detail else CATMULL_LOW
	var smooth := catmull_rom(chaikin(rounded, iterations), samples)
	return wobble_coast(smooth, COAST_WOBBLE if high_detail else COAST_WOBBLE * 0.55)


static func outline_from_cells(cells: Dictionary, high_detail: bool = true) -> PackedVector2Array:
	var loops := boundary_loops(cells)
	var best := PackedVector2Array()
	for loop in loops:
		if signed_area(loop) >= 0.0:
			best = loop if best.is_empty() else _largest(best, loop)
	if best.is_empty():
		return best
	return visual_outline(best, high_detail)


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


static func simplify_colinear(polygon: PackedVector2Array, turn_dot: float = 0.992) -> PackedVector2Array:
	if polygon.size() < 4:
		return polygon
	var kept := PackedVector2Array()
	for i in polygon.size():
		var prev := polygon[(i - 1 + polygon.size()) % polygon.size()]
		var curr := polygon[i]
		var next := polygon[(i + 1) % polygon.size()]
		var a := (curr - prev).normalized()
		var b := (next - curr).normalized()
		if a.dot(b) < turn_dot or a.length_squared() < 1e-8 or b.length_squared() < 1e-8:
			kept.append(curr)
	return kept if kept.size() >= 3 else polygon


static func round_corners(polygon: PackedVector2Array, radius: float) -> PackedVector2Array:
	if polygon.size() < 3 or radius <= 0.02:
		return polygon
	var grown: Array = Geometry2D.offset_polygon(polygon, radius, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		return polygon
	var outer: PackedVector2Array = grown[0]
	for extra in range(1, grown.size()):
		if extra < grown.size() and absf(signed_area(grown[extra])) > absf(signed_area(outer)):
			outer = grown[extra]
	var shrunk: Array = Geometry2D.offset_polygon(outer, -radius * 0.82, Geometry2D.JOIN_ROUND)
	if shrunk.is_empty():
		return outer
	var result: PackedVector2Array = shrunk[0]
	for extra in range(1, shrunk.size()):
		result = _largest(result, shrunk[extra])
	return result if result.size() >= 3 else polygon


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


static func catmull_rom(polygon: PackedVector2Array, samples: int) -> PackedVector2Array:
	if polygon.size() < 3 or samples <= 1:
		return polygon
	var n := polygon.size()
	var out := PackedVector2Array()
	for i in n:
		var p0 := polygon[(i - 1 + n) % n]
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % n]
		var p3 := polygon[(i + 2) % n]
		for s in samples:
			var t := float(s) / float(samples)
			out.append(_catmull_point(p0, p1, p2, p3, t))
	return out


static func wobble_coast(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.size() < 3 or amount <= 0.0:
		return polygon
	var mid := centroid2(polygon)
	var reach := clampf(sqrt(maxf(absf(signed_area(polygon)), 0.25) / PI), 0.8, 8.0)
	var travel := minf(amount, reach * 0.28)
	var seed := mid.x * 0.19 + mid.y * 0.11
	var out := PackedVector2Array()
	out.resize(polygon.size())
	for i in polygon.size():
		var d := polygon[i] - mid
		var radial := d.length()
		if radial < 1e-4:
			out[i] = polygon[i]
			continue
		var ang := atan2(d.y, d.x)
		var n := sin(ang * 2.0 + seed) * 0.70 + sin(ang * 3.0 - seed * 1.4) * 0.38 + sin(ang * 1.0 + seed * 0.6) * 0.22
		out[i] = mid + d * ((radial + n * travel) / radial)
	return out


static func scale_from_centroid(polygon: PackedVector2Array, scale: float) -> PackedVector2Array:
	var mid := centroid2(polygon)
	var out := PackedVector2Array()
	out.resize(polygon.size())
	for i in polygon.size():
		out[i] = mid + (polygon[i] - mid) * scale
	return out


static func noise_coast(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	return wobble_coast(polygon, amount)


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
				if remain.size() >= 3 and signed_area(remain) > 0.0:
					clipped.append(remain)
		triangles = clipped
	for piece in triangles:
		if _centroid_in(piece, cutters):
			continue
		_emit_top(st, piece, cutters)
	st.generate_normals()
	return st.commit()


static func build_volume(outline: PackedVector2Array, rings: Array, _holes: Array = []) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if outline.size() < 3 or rings.size() < 2:
		return st.commit()
	var mid := centroid2(outline)
	var profiles: Array[PackedVector2Array] = []
	for r in rings.size():
		var bulge := 0.03 if r == rings.size() - 1 else 0.04
		if r == 0:
			bulge = 0.03
		profiles.append(_ring_scaled(outline, mid, float(rings[r][1]), bulge, float(r) * 0.55))
	var tris: Array = []
	for r in range(1, rings.size()):
		_stitch_rings(
			tris,
			profiles[r - 1], float(rings[r - 1][0]), float(rings[r - 1][2]),
			profiles[r], float(rings[r][0]), float(rings[r][2])
		)
	_emit_capped(tris, profiles[0], float(rings[0][0]), float(rings[0][2]), false)
	_emit_capped(tris, profiles[profiles.size() - 1], float(rings[rings.size() - 1][0]), 0.0, true)
	var interior := Vector3(mid.x, (float(rings[0][0]) + float(rings[rings.size() - 1][0])) * 0.5, mid.y)
	for item in tris:
		var a: Vector3 = item[0]
		var b: Vector3 = item[1]
		var c: Vector3 = item[2]
		var ta: float = item[3]
		var tb: float = item[4]
		var tc: float = item[5]
		var normal := (b - a).cross(c - a)
		if normal.dot((a + b + c) / 3.0 - interior) < 0.0:
			var swap_p := b
			b = c
			c = swap_p
			var swap_t := tb
			tb = tc
			tc = swap_t
		_tri(st, a, b, c, ta, tb, tc)
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


static func is_closed_volume(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var faces := mesh.get_faces()
	if faces.size() < 12:
		return false
	var counts: Dictionary = {}
	for i in range(0, faces.size(), 3):
		_count_edge(counts, faces[i], faces[i + 1])
		_count_edge(counts, faces[i + 1], faces[i + 2])
		_count_edge(counts, faces[i + 2], faces[i])
	var odd := 0
	var total := 0
	for key in counts.keys():
		var ends: PackedStringArray = String(key).split("|")
		if ends.size() == 2 and ends[0] == ends[1]:
			continue
		total += 1
		if int(counts[key]) % 2 != 0:
			odd += 1
	return total > 0 and float(odd) / float(total) < 0.01


static func outward_normal_ratio(mesh: ArrayMesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var faces := mesh.get_faces()
	var box := _bounds_of(mesh)
	var mid: Vector3 = box.position + box.size * 0.5
	var good := 0
	var total := 0
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 1e-10:
			continue
		var center := (a + b + c) / 3.0
		total += 1
		if normal.dot(center - mid) > 0.0:
			good += 1
	return float(good) / float(maxi(total, 1))


static func _centroid_in(piece: PackedVector2Array, cutters: Array) -> bool:
	var mid := Vector2.ZERO
	for p in piece:
		mid += p
	mid /= float(maxi(piece.size(), 1))
	for cutter in cutters:
		if cutter is PackedVector2Array and cutter.size() >= 3 and Geometry2D.is_point_in_polygon(mid, cutter):
			return true
	return false


static func signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


static func centroid2(polygon: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in polygon:
		sum += p
	return sum / float(maxi(polygon.size(), 1))


static func _emit_skirt(tris: Array, outline: PackedVector2Array, mid: Vector2, rings: Array) -> void:
	var prev := _ring_scaled(outline, mid, float(rings[0][1]), 0.03, 0.0)
	var prev_y := float(rings[0][0])
	var prev_turf := float(rings[0][2])
	for r in range(1, rings.size()):
		var y := float(rings[r][0])
		var turf := float(rings[r][2])
		var bulge := 0.04 if r < rings.size() - 1 else 0.03
		var curr := _ring_scaled(outline, mid, float(rings[r][1]), bulge, float(r) * 0.55)
		if curr.size() != prev.size():
			curr = _resample(curr, prev.size())
		_stitch_rings(tris, prev, prev_y, prev_turf, curr, y, turf)
		prev = curr
		prev_y = y
		prev_turf = turf


static func _ring_scaled(outline: PackedVector2Array, mid: Vector2, scale: float, bulge: float, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(outline.size())
	for i in outline.size():
		var d := outline[i] - mid
		if d.length_squared() < 1e-8:
			out[i] = mid
			continue
		var ang := atan2(d.y, d.x)
		var s := scale * (1.0 + bulge * sin(ang * 2.0 + phase) + bulge * 0.4 * sin(ang * 3.0 - phase * 0.65))
		out[i] = mid + d * s
	return out


static func _stitch_rings(tris: Array, a: PackedVector2Array, ay: float, at: float, b: PackedVector2Array, by: float, bt: float) -> void:
	var n := mini(a.size(), b.size())
	for i in n:
		var j := (i + 1) % n
		var p0 := Vector3(a[i].x, ay, a[i].y)
		var p1 := Vector3(a[j].x, ay, a[j].y)
		var p2 := Vector3(b[j].x, by, b[j].y)
		var p3 := Vector3(b[i].x, by, b[i].y)
		tris.append([p0, p1, p2, at, at, bt])
		tris.append([p0, p2, p3, at, bt, bt])


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


static func _emit_top(st: SurfaceTool, polygon: PackedVector2Array, cutters: Array = []) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	for i in range(0, indices.size(), 3):
		var tri := PackedVector2Array([polygon[indices[i]], polygon[indices[i + 1]], polygon[indices[i + 2]]])
		if _covers_cutter(tri, cutters) or signed_area(tri) <= 0.0:
			continue
		var top_tris: Array = []
		_emit_capped(top_tris, tri, 0.0, 1.0, false)
		for item in top_tris:
			_tri(st, item[0], item[1], item[2], item[3], item[4], item[5])


static func _covers_cutter(tri: PackedVector2Array, cutters: Array) -> bool:
	for cutter in cutters:
		if not (cutter is PackedVector2Array) or cutter.size() < 3:
			continue
		var mid := Vector2.ZERO
		for p: Vector2 in cutter:
			mid += p
		mid /= float(cutter.size())
		if Geometry2D.is_point_in_polygon(mid, tri):
			return true
	return false


static func _emit_capped(tris: Array, polygon: PackedVector2Array, y: float, turf: float, downward: bool) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return
	var n := indices.size()
	for i in range(0, n, 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		var area := signed_area(PackedVector2Array([polygon[ia], polygon[ib], polygon[ic]]))
		var want_positive := not downward
		if (want_positive and area < 0.0) or (not want_positive and area > 0.0):
			var tmp := ib
			ib = ic
			ic = tmp
		var pa := Vector3(polygon[ia].x, y, polygon[ia].y)
		var pb := Vector3(polygon[ib].x, y, polygon[ib].y)
		var pc := Vector3(polygon[ic].x, y, polygon[ic].y)
		tris.append([pa, pb, pc, turf, turf, turf])


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


static func vertex_outward(polygon: PackedVector2Array, i: int) -> Vector2:
	var inward := _vertex_normal(polygon, i)
	return -inward if signed_area(polygon) >= 0.0 else inward


static func _corner_radius(polygon: PackedVector2Array) -> float:
	var area := absf(signed_area(polygon))
	return clampf(sqrt(maxf(area, 0.25) / PI) * 0.48, 0.85, 2.65)


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


static func _count_edge(counts: Dictionary, a: Vector3, b: Vector3) -> void:
	var ka := _vert_key(a)
	var kb := _vert_key(b)
	var key := ka + "|" + kb if ka < kb else kb + "|" + ka
	counts[key] = int(counts.get(key, 0)) + 1


static func _vert_key(p: Vector3) -> String:
	return "%d,%d,%d" % [int(round(p.x * 250.0)), int(round(p.y * 250.0)), int(round(p.z * 250.0))]


static func _catmull_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


static func _empty_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st.commit()
