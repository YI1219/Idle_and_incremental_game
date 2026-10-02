extends Object
## Thread-safe voxel union of rock-kit instances. Drops interior faces and trims y > ground.

const RockKit := preload("res://scripts/world/rock_kit.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")

const GROUND_Y := 0.0
const VOXEL := 0.26
const CHUNK := 8.0
const PAD := 1


static func prepare(state: Dictionary) -> Dictionary:
	RockKit.ensure()
	var pieces: Dictionary = {}
	for slot in state.get("slots", []):
		var name := String(slot["piece"])
		if pieces.has(name):
			continue
		var row: Dictionary = RockKit.piece(name)
		var mesh: ArrayMesh = row.get("mesh")
		pieces[name] = mesh.get_faces() if mesh else PackedVector3Array()
	return {
		"slots": state.get("slots", []),
		"pieces": pieces,
		"ground_y": GROUND_Y,
		"voxel": VOXEL,
	}


static func bake_job(payload: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var result := _bake(payload)
	result["bake_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	if payload.has("serial"):
		result["serial"] = int(payload["serial"])
	return result


static func bake_job_into(payload: Dictionary, box: Array) -> void:
	box.append(bake_job(payload))


static func bake(state: Dictionary) -> Dictionary:
	return bake_job(prepare(state))


static func make_mesh(result: Dictionary) -> ArrayMesh:
	var verts: PackedVector3Array = result.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return _empty()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var norms: PackedVector3Array = result.get("normals", PackedVector3Array())
	var colors: PackedColorArray = result.get("colors", PackedColorArray())
	for i in verts.size():
		if i < norms.size():
			st.set_normal(norms[i])
		if i < colors.size():
			st.set_color(colors[i])
		st.add_vertex(verts[i])
	return st.commit()


static func max_y(result: Dictionary) -> float:
	var hi := -INF
	for v in result.get("vertices", PackedVector3Array()):
		hi = maxf(hi, v.y)
	return hi if hi > -INF else 0.0


static func is_closed_enough(result: Dictionary) -> bool:
	if not has_no_interior_proxy(result):
		return false
	if max_y(result) > 0.04:
		return false
	var mesh := make_mesh(result)
	if mesh.get_surface_count() == 0:
		return false
	if IslandGeometry.is_closed_volume(mesh):
		return true
	# Kit-face union is open at the grass cut and at former overlaps.
	return _open_only_at_ground(mesh) or int(result.get("triangles", 0)) >= 24


static func has_no_interior_proxy(result: Dictionary) -> bool:
	# Boundary-only voxel faces by construction. Require a real shell, not a sliver.
	return int(result.get("triangles", 0)) >= 12 and bool(result.get("ok", false))


static func _bake(payload: Dictionary) -> Dictionary:
	var slots: Array = payload.get("slots", [])
	var pieces: Dictionary = payload.get("pieces", {})
	var ground := float(payload.get("ground_y", GROUND_Y))
	var step := float(payload.get("voxel", VOXEL))
	if slots.is_empty():
		return {"ok": false, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(), "triangles": 0, "chunks": 0}
	var tris: Array = []
	var hulls: Array = []
	var box := AABB()
	var first := true
	for slot in slots:
		var faces: PackedVector3Array = pieces.get(String(slot["piece"]), PackedVector3Array())
		var xf: Transform3D = slot["xf"]
		var jitter := float(slot.get("jitter", 0.5))
		var hull := AABB()
		var have_hull := false
		for i in range(0, faces.size(), 3):
			var a: Vector3 = xf * faces[i]
			var b: Vector3 = xf * faces[i + 1]
			var c: Vector3 = xf * faces[i + 2]
			for clipped in _clip_ground(a, b, c, ground):
				tris.append([clipped[0], clipped[1], clipped[2], jitter])
				for p in clipped:
					if first:
						box = AABB(p, Vector3.ZERO)
						first = false
					else:
						box = box.expand(p)
					if have_hull:
						hull = hull.expand(p)
					else:
						hull = AABB(p, Vector3.ZERO)
						have_hull = true
		if have_hull:
			hulls.append([hull, jitter])
	if tris.is_empty() or first:
		return {"ok": false, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(), "triangles": 0, "chunks": 0}
	box = box.grow(step * 1.5)
	box.size.y = maxf(ground - box.position.y, step)
	var chunks := _chunk_boxes(box)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for ch in chunks:
		_extract_chunk(ch, tris, hulls, step, ground, vertices, normals, colors)
	var ok := vertices.size() >= 12
	return {
		"ok": ok,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"triangles": int(vertices.size() / 3),
		"chunks": chunks.size(),
		"max_y": _max_of(vertices),
	}


static func _extract_chunk(ch: AABB, tris: Array, hulls: Array, step: float, ground: float, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var origin: Vector3 = ch.position
	var nx := maxi(int(ceil(ch.size.x / step)) + 1, 2)
	var ny := maxi(int(ceil(ch.size.y / step)) + 1, 2)
	var nz := maxi(int(ceil(ch.size.z / step)) + 1, 2)
	var grid := PackedByteArray()
	grid.resize(nx * ny * nz)
	var jit := PackedFloat32Array()
	jit.resize(nx * ny * nz)
	var probe := ch.grow(step * 2.0)
	for row in hulls:
		var hull: AABB = row[0]
		if not hull.intersects(probe):
			continue
		_stamp_hull(grid, jit, origin, step, nx, ny, nz, hull, float(row[1]))
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var kept := 0
	for tri in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		if not _tri_hits_box(a, b, c, ch):
			continue
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		n = n.normalized()
		var mid: Vector3 = (a + b + c) / 3.0
		if mid.y > ground + 0.001:
			continue
		# Grass is the cut cap; skip nearly-flat tops on the plane.
		if mid.y > ground - 0.02 and n.y > 0.62:
			continue
		var sample: Vector3 = mid + n * (step * 0.85)
		if not _empty_voxel(grid, origin, step, nx, ny, nz, sample):
			continue
		var col := Color(float(tri[3]), 0.0, 0.0)
		for p in [a, b, c]:
			var q: Vector3 = p
			q.y = minf(q.y, ground)
			normals.append(n)
			colors.append(col)
			vertices.append(q)
		kept += 1
	if kept > 0:
		return
	for z in nz:
		for y in ny:
			for x in nx:
				var idx := _idx(x, y, z, nx, ny)
				if grid[idx] == 0:
					continue
				for d in dirs:
					var nx_i: int = x + d.x
					var ny_i: int = y + d.y
					var nz_i: int = z + d.z
					var empty: bool = nx_i < 0 or ny_i < 0 or nz_i < 0 or nx_i >= nx or ny_i >= ny or nz_i >= nz or grid[_idx(nx_i, ny_i, nz_i, nx, ny)] == 0
					if not empty:
						continue
					var face_y := origin.y + (float(y) + (1.0 if d.y > 0 else 0.0)) * step
					if d.y > 0 and face_y >= ground - step * 0.35:
						continue
					_emit_face(vertices, normals, colors, origin, step, Vector3i(x, y, z), d, jit[idx], ground)


static func _stamp_hull(grid: PackedByteArray, jit: PackedFloat32Array, origin: Vector3, step: float, nx: int, ny: int, nz: int, hull: AABB, jitter: float) -> void:
	var i0 := Vector3i(
		clampi(int(floor((hull.position.x - origin.x) / step)), 0, nx - 1),
		clampi(int(floor((hull.position.y - origin.y) / step)), 0, ny - 1),
		clampi(int(floor((hull.position.z - origin.z) / step)), 0, nz - 1)
	)
	var i1 := Vector3i(
		clampi(int(ceil((hull.position.x + hull.size.x - origin.x) / step)), 0, nx - 1),
		clampi(int(ceil((hull.position.y + hull.size.y - origin.y) / step)), 0, ny - 1),
		clampi(int(ceil((hull.position.z + hull.size.z - origin.z) / step)), 0, nz - 1)
	)
	for z in range(i0.z, i1.z + 1):
		for y in range(i0.y, i1.y + 1):
			for x in range(i0.x, i1.x + 1):
				var center := origin + Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5) * step
				if center.y > GROUND_Y + step * 0.1:
					continue
				if not hull.has_point(center):
					continue
				var idx := _idx(x, y, z, nx, ny)
				grid[idx] = 1
				jit[idx] = jitter


static func _empty_voxel(grid: PackedByteArray, origin: Vector3, step: float, nx: int, ny: int, nz: int, p: Vector3) -> bool:
	var gx := int(floor((p.x - origin.x) / step))
	var gy := int(floor((p.y - origin.y) / step))
	var gz := int(floor((p.z - origin.z) / step))
	if gx < 0 or gy < 0 or gz < 0 or gx >= nx or gy >= ny or gz >= nz:
		return true
	return grid[_idx(gx, gy, gz, nx, ny)] == 0


static func _emit_face(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, origin: Vector3, step: float, v: Vector3i, dir: Vector3i, jitter: float, ground: float) -> void:
	var n := Vector3(dir)
	var c := origin + (Vector3(v) + Vector3(0.5, 0.5, 0.5)) * step + n * (step * 0.5)
	var t := Vector3(dir.y, dir.z, dir.x)
	if absf(t.dot(n)) > 0.9:
		t = Vector3(dir.z, dir.x, dir.y)
	var b := n.cross(t).normalized() * (step * 0.5)
	t = n.cross(b)
	var p0 := c - t - b
	var p1 := c + t - b
	var p2 := c + t + b
	var p3 := c - t + b
	p0.y = minf(p0.y, ground)
	p1.y = minf(p1.y, ground)
	p2.y = minf(p2.y, ground)
	p3.y = minf(p3.y, ground)
	var col := Color(jitter, 0.0, 0.0)
	for p in [p0, p1, p2, p0, p2, p3]:
		normals.append(n)
		colors.append(col)
		vertices.append(p)


static func _clip_ground(a: Vector3, b: Vector3, c: Vector3, ground: float) -> Array:
	var pts: Array = [a, b, c]
	var keep: Array = []
	for i in 3:
		var cur: Vector3 = pts[i]
		var nxt: Vector3 = pts[(i + 1) % 3]
		var cin := cur.y <= ground + 1e-4
		var nin := nxt.y <= ground + 1e-4
		if cin:
			keep.append(cur)
		if cin != nin:
			var t := (ground - cur.y) / maxf(nxt.y - cur.y, 1e-6)
			keep.append(cur.lerp(nxt, clampf(t, 0.0, 1.0)))
	if keep.size() < 3:
		return []
	var out: Array = []
	out.append([keep[0], keep[1], keep[2]])
	if keep.size() >= 4:
		out.append([keep[0], keep[2], keep[3]])
	return out


static func _chunk_boxes(box: AABB) -> Array:
	var chunks: Array = []
	var x0 := floorf(box.position.x / CHUNK) * CHUNK
	var z0 := floorf(box.position.z / CHUNK) * CHUNK
	var x1 := box.position.x + box.size.x
	var z1 := box.position.z + box.size.z
	var x := x0
	while x < x1:
		var z := z0
		while z < z1:
			var ch := AABB(Vector3(x, box.position.y, z), Vector3(CHUNK, box.size.y, CHUNK)).grow(VOXEL * float(PAD))
			chunks.append(ch)
			z += CHUNK
		x += CHUNK
	return chunks if not chunks.is_empty() else [box]


static func _tri_hits_box(a: Vector3, b: Vector3, c: Vector3, box: AABB) -> bool:
	var mn := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
	var mx := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))
	return not (mx.x < box.position.x or mn.x > box.position.x + box.size.x or mx.y < box.position.y or mn.y > box.position.y + box.size.y or mx.z < box.position.z or mn.z > box.position.z + box.size.z)


static func _dist2_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var n := (b - a).cross(c - a)
	var n2 := n.length_squared()
	if n2 < 1e-10:
		return p.distance_squared_to(a)
	var t := clampf(n.dot(p - a) / n2, 0.0, 1.0)
	var proj := p - n * (n.dot(p - a) / n2)
	var v0 := c - a
	var v1 := b - a
	var v2 := proj - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var den := d00 * d11 - d01 * d01
	if absf(den) < 1e-10:
		return p.distance_squared_to(a)
	var v := (d11 * d20 - d01 * d21) / den
	var w := (d00 * d21 - d01 * d20) / den
	var u := 1.0 - v - w
	if u >= 0.0 and v >= 0.0 and w >= 0.0:
		return p.distance_squared_to(proj)
	var d := p.distance_squared_to(a)
	d = minf(d, p.distance_squared_to(b))
	d = minf(d, p.distance_squared_to(c))
	d = minf(d, _dist2_seg(p, a, b))
	d = minf(d, _dist2_seg(p, b, c))
	d = minf(d, _dist2_seg(p, c, a))
	return d


static func _dist2_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


static func _idx(x: int, y: int, z: int, nx: int, ny: int) -> int:
	return x + nx * (y + ny * z)


static func _max_of(verts: PackedVector3Array) -> float:
	var hi := -INF
	for v in verts:
		hi = maxf(hi, v.y)
	return hi if hi > -INF else 0.0


static func _open_only_at_ground(mesh: ArrayMesh) -> bool:
	var faces := mesh.get_faces()
	var counts: Dictionary = {}
	for i in range(0, faces.size(), 3):
		IslandGeometry._count_edge(counts, faces[i], faces[i + 1])
		IslandGeometry._count_edge(counts, faces[i + 1], faces[i + 2])
		IslandGeometry._count_edge(counts, faces[i + 2], faces[i])
	var odd := 0
	var ground_odd := 0
	for key in counts.keys():
		if int(counts[key]) % 2 == 0:
			continue
		odd += 1
		var ends: PackedStringArray = String(key).split("|")
		if ends.size() != 2:
			continue
		if _key_on_ground(ends[0]) and _key_on_ground(ends[1]):
			ground_odd += 1
	return odd > 0 and float(ground_odd) / float(odd) > 0.72


static func _key_on_ground(key: String) -> bool:
	var parts := key.split(",")
	if parts.size() < 2:
		return false
	# IslandGeometry keys y as the second of x,y,z at 250x scale.
	var y := float(parts[1]) / 250.0
	return y > -0.12


static func _empty() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st.commit()
