extends RefCounted
## Clumped opaque grass tufts. Render mesh only; never writes heightfield H.

const Heightfield := preload("res://scripts/world/heightfield.gd")

const BIN := 1.0
const ATTEMPTS := 36
const COAST_CLEAR := 0.20
const PATH_CLEAR := 0.42
const PERIOD_A := 2.85
const PERIOD_B := 3.55


static func coast_hash(loops: Array) -> int:
	var h := 17
	for loop in loops:
		h = (h * 33) ^ int(loop.size())
		if int(loop.size()) == 0:
			continue
		var p: Vector2 = loop[0]
		h ^= int(p.x * 25.0) * 131
		h ^= int(p.y * 25.0) * 719
	return h


static func signature(field: Heightfield, chunk: Vector2i, water: Dictionary, footprints: Dictionary, paths: PackedVector3Array, coast_id: int) -> int:
	var cs := Heightfield.CHUNK
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.cells_x())
	var z1 := mini(z0 + cs, field.cells_z())
	var h := int(field.seed) ^ (chunk.x * 734287) ^ (chunk.y * 912931) ^ coast_id
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if not field.is_land(cx, cz):
				h ^= cx * 131 + cz * 977
				continue
			var q := int(field.cell_mean_height(cx, cz) * 50.0)
			var flags := 0
			if water.has(Vector2i(cx, cz)):
				flags |= 1
			if footprints.has(field.play_cell_of_hf(cx, cz)):
				flags |= 2
			h = (h * 16777619) ^ q ^ (flags * 104729) ^ (cx * 19) ^ (cz * 53)
	h ^= _path_hash(field, chunk, paths)
	return h


static func build(field: Heightfield, chunk: Vector2i, water: Dictionary, footprints: Dictionary, paths: PackedVector3Array, coast: Array) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tufts := 0
	var rect := _chunk_rect(field, chunk)
	if rect.size.x < 0.05 or rect.size.y < 0.05:
		return {"mesh": st.commit(), "tufts": 0, "triangles": 0}
	var salt := float(absi(field.seed) % 4096) * 0.013
	var x := rect.position.x
	while x < rect.end.x - 0.02:
		var z := rect.position.y
		while z < rect.end.y - 0.02:
			for attempt in ATTEMPTS:
				var nse := Heightfield._hash2(x * 1.91 + float(attempt) * 0.37 + salt, z * 1.73 + float(attempt) * 0.17)
				if nse.x > _acceptance(Vector2(x + BIN * 0.5, z + BIN * 0.5), salt):
					continue
				var jitter := Heightfield._hash2(x * 2.41 + float(attempt + 3), z * 2.17 + float(attempt * 5))
				var at := Vector2(x + jitter.x * BIN, z + jitter.y * BIN)
				if not rect.has_point(at):
					continue
				if not _allow(field, at, water, footprints, paths, coast):
					continue
				var world := Vector3(at.x, 0.0, at.y)
				var ground := field.sample_height(world)
				if not is_finite(ground):
					continue
				ground += field.visual_relief(world)
				var tint := lerpf(0.85, 1.15, nse.y)
				var yaw := jitter.y * TAU
				var tall := lerpf(0.05, 0.13, Heightfield._hash2(at.x * 3.1, at.y * 2.7 + float(attempt)).x)
				_add_tuft(st, Vector3(at.x, ground - 0.006, at.y), yaw, tall, tint, attempt, salt)
				tufts += 1
			z += BIN
		x += BIN
	var mesh := st.commit()
	var tris := 0
	if mesh and mesh.get_surface_count() > 0:
		tris = int(mesh.surface_get_array_len(0) / 3)
	return {"mesh": mesh, "tufts": tufts, "triangles": tris}


static func _acceptance(world: Vector2, salt: float) -> float:
	var a := sin(world.x * TAU / PERIOD_A + salt)
	var b := sin(world.y * TAU / PERIOD_B - salt * 0.81)
	var clump := clampf(0.5 + 0.5 * a * b, 0.0, 1.0)
	return lerpf(0.10, 0.70, clump)


static func _allow(field: Heightfield, at: Vector2, water: Dictionary, footprints: Dictionary, paths: PackedVector3Array, coast: Array) -> bool:
	var cell := field.world_to_cell(Vector3(at.x, 0.0, at.y))
	if not field.is_land(cell.x, cell.y):
		return false
	if water.has(cell):
		return false
	if footprints.has(Vector2i(floori(at.x), floori(at.y))):
		return false
	if _near_path(at, paths):
		return false
	var inland := field.sample_inland(Vector3(at.x, 0.0, at.y))
	if inland < 0.999 and _coast_distance(at, coast, field) < COAST_CLEAR:
		return false
	return true


static func _chunk_rect(field: Heightfield, chunk: Vector2i) -> Rect2:
	var cs := Heightfield.CHUNK
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.verts_x - 1)
	var z1 := mini(z0 + cs, field.verts_z - 1)
	if x1 <= x0 or z1 <= z0:
		return Rect2()
	var a := field.vertex_world(x0, z0)
	var b := field.vertex_world(x1, z1)
	return Rect2(a, b - a)


static func _path_hash(field: Heightfield, chunk: Vector2i, paths: PackedVector3Array) -> int:
	var rect := _chunk_rect(field, chunk).grow(PATH_CLEAR + 0.2)
	var h := 0
	for i in maxi(paths.size() - 1, 0):
		var a := Vector2(paths[i].x, paths[i].z)
		var b := Vector2(paths[i + 1].x, paths[i + 1].z)
		if not _segment_hits_rect(a, b, rect):
			continue
		h = (h * 33) ^ int(a.x * 20.0) ^ int(a.y * 47.0) ^ int(b.x * 20.0) ^ int(b.y * 47.0)
	return h


static func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	return rect.intersects(Rect2(a, b - a).abs())


static func _near_path(at: Vector2, paths: PackedVector3Array) -> bool:
	for i in maxi(paths.size() - 1, 0):
		var a := Vector2(paths[i].x, paths[i].z)
		var b := Vector2(paths[i + 1].x, paths[i + 1].z)
		if _seg_dist(at, a, b) < PATH_CLEAR:
			return true
	return false


static func _coast_distance(at: Vector2, coast: Array, field: Heightfield) -> float:
	if coast.is_empty():
		for step in 8:
			var ang := float(step) * TAU / 8.0
			var q := at + Vector2(cos(ang), sin(ang)) * COAST_CLEAR
			if not field.sample_land(Vector3(q.x, 0.0, q.y)):
				return 0.0
		return 1.0
	var best := 99.0
	for loop in coast:
		var n := int(loop.size())
		if n < 2:
			continue
		for i in n:
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % n]
			best = minf(best, _seg_dist(at, a, b))
			if best < COAST_CLEAR:
				return best
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0 if denom < 1e-8 else clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _add_tuft(st: SurfaceTool, origin: Vector3, yaw: float, height: float, tint: float, extra: int, salt: float) -> void:
	for i in 4:
		var n := Heightfield._hash2(origin.x * 4.1 + float(i + extra) + salt, origin.z * 3.7 + float(i * 9))
		var ang := yaw + float(i) * TAU / 4.0 + (n.x - 0.5) * 0.5
		var blade_h := clampf(height * lerpf(0.78, 1.0, n.y), 0.05, 0.13)
		var width := lerpf(0.009, 0.018, n.x)
		var bend := lerpf(0.010, 0.026, n.y)
		_add_blade(st, origin, ang, blade_h, width, bend, tint)


static func _add_blade(st: SurfaceTool, origin: Vector3, ang: float, height: float, width: float, bend: float, tint: float) -> void:
	var fwd := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var rings := 4
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var tip: Array[float] = []
	for s in rings:
		var t := float(s) / float(rings - 1)
		var c := origin + Vector3(0.0, height * t, 0.0) + fwd * (bend * t * t)
		var w := width * (1.0 - t * 0.74)
		left.append(c - side * w)
		right.append(c + side * w)
		tip.append(t)
	for s in rings - 1:
		_tri(st, left[s], left[s + 1], right[s + 1], tip[s], tip[s + 1], tip[s + 1], tint)
		_tri(st, left[s], right[s + 1], right[s], tip[s], tip[s + 1], tip[s], tint)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ta: float, tb: float, tc: float, tint: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(Color(tint, tint, tint, ta))
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.set_color(Color(tint, tint, tint, tb))
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.set_color(Color(tint, tint, tint, tc))
	st.add_vertex(c)
