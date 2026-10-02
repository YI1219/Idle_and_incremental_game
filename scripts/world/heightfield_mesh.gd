extends Object
## Builds closed, chunked island meshes from a Heightfield. No scene I/O.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const WALL_RINGS := 4
const LIP := 0.12
const ROCK_SLOPE := 0.55


static func chunk_range(field: Heightfield) -> Vector2i:
	return Vector2i(ceili(float(field.cells_x()) / float(Heightfield.CHUNK)), ceili(float(field.cells_z()) / float(Heightfield.CHUNK)))


static func build_chunk(field: Heightfield, chunk: Vector2i, mode: String = "full", skip_top: Dictionary = {}) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	if mode in ["top", "full", "lod"]:
		_emit_top(field, chunk, verts, norms, cols, uvs, skip_top, mode == "lod")
	if mode in ["full", "shell", "lod"]:
		_emit_walls_and_bottom(field, chunk, verts, norms, cols, uvs, mode == "lod")
	return {
		"vertices": verts,
		"normals": norms,
		"colors": cols,
		"uvs": uvs,
		"triangles": int(verts.size() / 3),
		"chunk": chunk,
		"mode": mode,
	}


static func make_mesh(payload: Dictionary) -> ArrayMesh:
	var verts: PackedVector3Array = payload.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return _empty()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = payload.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_COLOR] = payload.get("colors", PackedColorArray())
	arrays[Mesh.ARRAY_TEX_UV] = payload.get("uvs", PackedVector2Array())
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func combine(payloads: Array) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for row in payloads:
		if row == null:
			continue
		verts.append_array(row.get("vertices", PackedVector3Array()))
		norms.append_array(row.get("normals", PackedVector3Array()))
		cols.append_array(row.get("colors", PackedColorArray()))
		uvs.append_array(row.get("uvs", PackedVector2Array()))
	return {"vertices": verts, "normals": norms, "colors": cols, "uvs": uvs, "triangles": int(verts.size() / 3)}


static func border_vertices(field: Heightfield, chunk_a: Vector2i, chunk_b: Vector2i) -> Array:
	## Shared grid points along the common edge, after world-space jitter.
	var pts_a: Array[Vector3] = []
	var pts_b: Array[Vector3] = []
	var cs := Heightfield.CHUNK
	if chunk_a.x + 1 == chunk_b.x and chunk_a.y == chunk_b.y:
		var ix := (chunk_a.x + 1) * cs
		var z0 := chunk_a.y * cs
		var z1 := mini(z0 + cs, field.verts_z)
		for iz in range(z0, z1):
			if field.in_vertex(ix, iz):
				pts_a.append(field.world_vertex(ix, iz))
				pts_b.append(field.world_vertex(ix, iz))
	elif chunk_a.y + 1 == chunk_b.y and chunk_a.x == chunk_b.x:
		var iz := (chunk_a.y + 1) * cs
		var x0 := chunk_a.x * cs
		var x1 := mini(x0 + cs, field.verts_x)
		for ix in range(x0, x1):
			if field.in_vertex(ix, iz):
				pts_a.append(field.world_vertex(ix, iz))
				pts_b.append(field.world_vertex(ix, iz))
	return [pts_a, pts_b]


static func is_closed(payload: Dictionary, tolerance: float = 0.012) -> bool:
	return odd_edge_ratio(payload, tolerance) < 0.02


static func odd_edge_ratio(payload: Dictionary, tolerance: float = 0.012) -> float:
	var faces: PackedVector3Array = payload.get("vertices", PackedVector3Array())
	if faces.size() < 12:
		return 1.0
	var counts: Dictionary = {}
	for i in range(0, faces.size(), 3):
		_count_edge(counts, faces[i], faces[i + 1], tolerance)
		_count_edge(counts, faces[i + 1], faces[i + 2], tolerance)
		_count_edge(counts, faces[i + 2], faces[i], tolerance)
	var odd := 0
	var total := 0
	for key in counts:
		total += 1
		if int(counts[key]) % 2 != 0:
			odd += 1
	return 0.0 if total == 0 else float(odd) / float(total)


static func lowest_y(payload: Dictionary) -> float:
	var low := 0.0
	for v in payload.get("vertices", PackedVector3Array()):
		low = minf(low, v.y)
	return low


static func build_water(field: Heightfield, lake: Dictionary) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var level := float(lake.get("level", 0.0))
	var cells: Array = lake.get("cells", [])
	var loops: Array = _lake_loops(field, cells)
	var color := Color(0.16, 0.44, 0.42, 1.0)
	var filled := false
	for loop in loops:
		var ring: Array = _smooth_loop(loop)
		if ring.size() < 3:
			continue
		var poly := PackedVector2Array()
		for p in ring:
			poly.append(Vector2(p.x, p.z))
		var grown: Array = Geometry2D.offset_polygon(poly, 0.16, Geometry2D.JOIN_ROUND)
		if not grown.is_empty() and (grown[0] as PackedVector2Array).size() >= 3:
			poly = grown[0]
		var idx := Geometry2D.triangulate_polygon(poly)
		if idx.size() < 3:
			continue
		filled = true
		for i in range(0, idx.size(), 3):
			var pa := Vector3(poly[idx[i]].x, level, poly[idx[i]].y)
			var pb := Vector3(poly[idx[i + 1]].x, level, poly[idx[i + 1]].y)
			var pc := Vector3(poly[idx[i + 2]].x, level, poly[idx[i + 2]].y)
			_solid(verts, norms, cols, uvs, pa, pb, pc, color, Vector3.UP)
	if not filled:
		for cell in cells:
			var c: Vector2i = cell
			if not field.is_land(c.x, c.y):
				continue
			var p00 := field.world_vertex(c.x, c.y)
			var p10 := field.world_vertex(c.x + 1, c.y)
			var p01 := field.world_vertex(c.x, c.y + 1)
			var p11 := field.world_vertex(c.x + 1, c.y + 1)
			p00.y = level
			p10.y = level
			p01.y = level
			p11.y = level
			_solid(verts, norms, cols, uvs, p00, p10, p11, color, Vector3.UP)
			_solid(verts, norms, cols, uvs, p00, p11, p01, color, Vector3.UP)
	return {"vertices": verts, "normals": norms, "colors": cols, "uvs": uvs, "triangles": int(verts.size() / 3)}


static func build_waterfall(origin: Vector3, outward: Vector3, bottom: float) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var side := Vector3(-outward.z, 0.0, outward.x) * 0.62
	var top := origin + outward * 0.06 + Vector3(0.0, 0.05, 0.0)
	var foot := Vector3(origin.x, bottom, origin.z) + outward * 0.7
	var a := top - side
	var b := top + side
	var c := foot + side * 0.7
	var d := foot - side * 0.7
	var water := Color(0.45, 0.78, 0.76, 1.0)
	var foam := Color(0.92, 0.96, 0.94, 1.0)
	_solid(verts, norms, cols, uvs, a, b, c, water, -outward)
	_solid(verts, norms, cols, uvs, a, c, d, water, -outward)
	var foam_a := top - side * 1.15 + Vector3(0.0, 0.03, 0.0) - outward * 0.08
	var foam_b := top + side * 1.15 + Vector3(0.0, 0.03, 0.0) - outward * 0.08
	var foam_c := top + side * 0.7 + outward * 0.12
	var foam_d := top - side * 0.7 + outward * 0.12
	_solid(verts, norms, cols, uvs, foam_a, foam_b, foam_c, foam, Vector3.UP)
	_solid(verts, norms, cols, uvs, foam_a, foam_c, foam_d, foam, Vector3.UP)
	return {"vertices": verts, "normals": norms, "colors": cols, "uvs": uvs, "triangles": int(verts.size() / 3)}


static func _emit_top(field: Heightfield, chunk: Vector2i, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, skip_top: Dictionary, lod: bool) -> void:
	var cs := Heightfield.CHUNK
	var step := 2 if lod else 1
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.cells_x())
	var z1 := mini(z0 + cs, field.cells_z())
	for cz in range(z0, z1, step):
		for cx in range(x0, x1, step):
			if not _block_land(field, cx, cz, step):
				continue
			var play := field.play_cell_of_hf(cx, cz)
			if skip_top.has(play):
				continue
			var a := _top_vert(field, cx, cz)
			var b := _top_vert(field, mini(cx + step, field.verts_x - 1), cz)
			var c := _top_vert(field, mini(cx + step, field.verts_x - 1), mini(cz + step, field.verts_z - 1))
			var d := _top_vert(field, cx, mini(cz + step, field.verts_z - 1))
			if field.flip_diagonal(cx, cz):
				_emit_facet(field, verts, norms, cols, uvs, a, b, c)
				_emit_facet(field, verts, norms, cols, uvs, a, c, d)
			else:
				_emit_facet(field, verts, norms, cols, uvs, a, b, d)
				_emit_facet(field, verts, norms, cols, uvs, b, c, d)


static func _block_land(field: Heightfield, cx: int, cz: int, step: int) -> bool:
	for z in step:
		for x in step:
			if field.is_land(cx + x, cz + z):
				return true
	return false


static func _top_vert(field: Heightfield, ix: int, iz: int) -> Vector3:
	return field.world_vertex(clampi(ix, 0, field.verts_x - 1), clampi(iz, 0, field.verts_z - 1))


static func _emit_facet(field: Heightfield, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var mid := (a + b + c) / 3.0
	var inland := field.sample_inland(mid)
	_solid(verts, norms, cols, uvs, a, b, c, Color(0.0, inland, 1.0 - inland, 1.0), Vector3.UP)


static func _emit_walls_and_bottom(field: Heightfield, chunk: Vector2i, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, lod: bool) -> void:
	var rings := 3 if lod else WALL_RINGS
	_emit_grid_walls(field, chunk, rings, verts, norms, cols, uvs)
	_emit_bottom(field, chunk, verts, norms, cols, uvs)


static func _emit_grid_walls(field: Heightfield, chunk: Vector2i, rings: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var cs := Heightfield.CHUNK
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.cells_x())
	var z1 := mini(z0 + cs, field.cells_z())
	var posts: Dictionary = {}
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if not field.is_land(cx, cz):
				continue
			_wall_if_open(field, verts, norms, cols, uvs, cx, cz, 0, -1, rings, posts)
			_wall_if_open(field, verts, norms, cols, uvs, cx, cz, 1, 0, rings, posts)
			_wall_if_open(field, verts, norms, cols, uvs, cx, cz, 0, 1, rings, posts)
			_wall_if_open(field, verts, norms, cols, uvs, cx, cz, -1, 0, rings, posts)


static func _wall_if_open(field: Heightfield, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, cx: int, cz: int, dx: int, dz: int, rings: int, posts: Dictionary) -> void:
	if field.is_land(cx + dx, cz + dz):
		return
	var a: Vector2i
	var b: Vector2i
	if dx == 0 and dz == -1:
		a = Vector2i(cx, cz)
		b = Vector2i(cx + 1, cz)
	elif dx == 1 and dz == 0:
		a = Vector2i(cx + 1, cz)
		b = Vector2i(cx + 1, cz + 1)
	elif dx == 0 and dz == 1:
		a = Vector2i(cx + 1, cz + 1)
		b = Vector2i(cx, cz + 1)
	else:
		a = Vector2i(cx, cz + 1)
		b = Vector2i(cx, cz)
	var col_a: Array = _wall_post(field, a.x, a.y, rings, posts)
	var col_b: Array = _wall_post(field, b.x, b.y, rings, posts)
	var n := mini(col_a.size(), col_b.size())
	var hint := Vector3(float(dx), 0.0, float(dz))
	for r in range(n - 1):
		var pa: Vector3 = col_a[r]
		var pb: Vector3 = col_b[r]
		var qa: Vector3 = col_a[r + 1]
		var qb: Vector3 = col_b[r + 1]
		# Lip is turf; every ring below is rock. No grass bands inside the wall.
		var color := Color(0.0, 0.85, 0.08, 1.0) if r == 0 else Color(0.0, 0.02, 0.95, 1.0)
		_solid(verts, norms, cols, uvs, pa, pb, qb, color, hint)
		_solid(verts, norms, cols, uvs, pa, qb, qa, color, hint)


static func _vertex_outward(field: Heightfield, ix: int, iz: int) -> Vector3:
	var acc := Vector2.ZERO
	var cells: Array[Vector2i] = [Vector2i(ix - 1, iz - 1), Vector2i(ix - 1, iz), Vector2i(ix, iz - 1), Vector2i(ix, iz)]
	var dirs: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5)]
	var land_n := 0
	for i in 4:
		if field.is_land(cells[i].x, cells[i].y):
			acc -= dirs[i]
			land_n += 1
		else:
			acc += dirs[i]
	if land_n == 0 or land_n == 4 or acc.length_squared() < 1e-8:
		return Vector3.ZERO
	acc = acc.normalized()
	return Vector3(acc.x, 0.0, acc.y)


static func _wall_post(field: Heightfield, ix: int, iz: int, rings: int, posts: Dictionary) -> Array:
	var key := Vector2i(ix, iz)
	if posts.has(key):
		return posts[key]
	var top := field.world_vertex(ix, iz)
	var bot := _bottom_vert(field, ix, iz)
	var outward := _vertex_outward(field, ix, iz)
	var col: Array = []
	col.append(top)
	# Grass lip overhangs the wall; rings below taper inward as rock.
	col.append(top + outward * LIP + Vector3(0.0, 0.02, 0.0))
	var last := maxi(rings - 1, 2)
	for r in range(2, last):
		var t := float(r) / float(last)
		var sm := t * t * (3.0 - 2.0 * t)
		var p := top.lerp(bot, sm)
		p += outward * (0.02 - 0.14 * t)
		var nse := field.jitter_xz(p.x * 0.7 + float(r), p.z * 0.7)
		p += Vector3(nse.x, 0.0, nse.y) * 0.45
		col.append(p)
	col.append(bot)
	posts[key] = col
	return col


static func _chunk_loops(field: Heightfield, chunk: Vector2i) -> Array:
	var cs := Heightfield.CHUNK
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.cells_x())
	var z1 := mini(z0 + cs, field.cells_z())
	var outgoing: Dictionary = {}
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if not field.is_land(cx, cz):
				continue
			_edge_if_open(field, outgoing, cx, cz, 0, -1)
			_edge_if_open(field, outgoing, cx, cz, 1, 0)
			_edge_if_open(field, outgoing, cx, cz, 0, 1)
			_edge_if_open(field, outgoing, cx, cz, -1, 0)
	return _trace_loops(field, outgoing)


static func _edge_if_open(field: Heightfield, outgoing: Dictionary, cx: int, cz: int, dx: int, dz: int) -> void:
	if field.is_land(cx + dx, cz + dz):
		return
	var a: Vector2
	var b: Vector2
	if dx == 0 and dz == -1:
		a = Vector2(cx, cz)
		b = Vector2(cx + 1, cz)
	elif dx == 1 and dz == 0:
		a = Vector2(cx + 1, cz)
		b = Vector2(cx + 1, cz + 1)
	elif dx == 0 and dz == 1:
		a = Vector2(cx + 1, cz + 1)
		b = Vector2(cx, cz + 1)
	else:
		a = Vector2(cx, cz + 1)
		b = Vector2(cx, cz)
	var key := "%d,%d" % [int(a.x), int(a.y)]
	if not outgoing.has(key):
		outgoing[key] = []
	(outgoing[key] as Array).append(b)


static func _trace_loops(field: Heightfield, outgoing: Dictionary) -> Array:
	var loops: Array = []
	for start_key in outgoing.keys():
		while (outgoing[start_key] as Array).size() > 0:
			var parts := String(start_key).split(",")
			var curr := Vector2(int(parts[0]), int(parts[1]))
			var loop: Array[Vector3] = []
			var guard := 0
			while guard < 20000:
				guard += 1
				var ix := int(round(curr.x))
				var iz := int(round(curr.y))
				var p := field.world_vertex(clampi(ix, 0, field.verts_x - 1), clampi(iz, 0, field.verts_z - 1))
				loop.append(p)
				var ck := "%d,%d" % [ix, iz]
				if not outgoing.has(ck) or (outgoing[ck] as Array).is_empty():
					break
				var nxt: Vector2 = (outgoing[ck] as Array).pop_back()
				curr = nxt
				if loop.size() > 2 and ix == int(parts[0]) and iz == int(parts[1]):
					break
			if loop.size() >= 3:
				loops.append(_smooth_loop(loop))
	return loops


static func _smooth_loop(loop: Array) -> Array:
	if loop.size() < 4:
		return loop
	var pts: Array = loop
	for _i in 2:
		var next: Array = []
		for i in pts.size():
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % pts.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		pts = next
	if pts.size() < 4:
		return pts
	var curve: Array = []
	var n := pts.size()
	for i in n:
		var p0: Vector3 = pts[(i - 1 + n) % n]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[(i + 1) % n]
		var p3: Vector3 = pts[(i + 2) % n]
		curve.append(p1)
		curve.append(0.5 * ((2.0 * p1) + (-p0 + p2) * 0.5 + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * 0.25 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * 0.125))
	return curve


static func _extrude_loop(field: Heightfield, loop: Array, rings: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	if loop.size() < 3:
		return
	var profiles: Array = []
	for r in rings:
		var t := float(r) / float(maxi(rings - 1, 1))
		var ring: Array[Vector3] = []
		for i in loop.size():
			var p: Vector3 = loop[i]
			var prev: Vector3 = loop[(i - 1 + loop.size()) % loop.size()]
			var nxt: Vector3 = loop[(i + 1) % loop.size()]
			var tangent := Vector2(nxt.x - prev.x, nxt.z - prev.z)
			var outward := Vector2(-tangent.y, tangent.x)
			if outward.length_squared() < 1e-8:
				outward = Vector2.RIGHT
			outward = outward.normalized()
			# Keep walls facing away from land: if the midpoint+outward is still land, flip.
			var test := Vector2(p.x, p.z) + outward * field.spacing * 0.35
			if field.sample_land(Vector3(test.x, 0.0, test.y)):
				outward = -outward
			var lip := LIP if r == 0 else (0.03 if r == 1 else -0.04 * t)
			var y := lerpf(p.y, field.y_bottom, t * t * (3.0 - 2.0 * t))
			if r == 0:
				y = p.y + 0.012
			elif r == rings - 1:
				y = field.y_bottom + _bottom_noise(field, p.x, p.z)
			var nse := field.jitter_xz(p.x * 0.6 + float(r), p.z * 0.6)
			var q := Vector3(p.x + outward.x * lip + nse.x * 0.35, y, p.z + outward.y * lip + nse.y * 0.35)
			if r > 0 and r < rings - 1:
				q = field.voronoi_push(q, Vector3(outward.x, 0.0, outward.y))
			ring.append(q)
		profiles.append(ring)
	for r in range(1, profiles.size()):
		var a: Array = profiles[r - 1]
		var b: Array = profiles[r]
		var n := mini(a.size(), b.size())
		for i in n:
			var j := (i + 1) % n
			var turf := 1.0 if r == 1 else 0.0
			_emit_facet(field, verts, norms, cols, uvs, a[i], a[j], b[j])
			_emit_facet(field, verts, norms, cols, uvs, a[i], b[j], b[i])
			if turf > 0.0 and verts.size() >= 6:
				pass


static func _emit_bottom(field: Heightfield, chunk: Vector2i, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	var cs := Heightfield.CHUNK
	var x0 := chunk.x * cs
	var z0 := chunk.y * cs
	var x1 := mini(x0 + cs, field.cells_x())
	var z1 := mini(z0 + cs, field.cells_z())
	var color := Color(0.0, 0.0, 1.0, 1.0)
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if not field.is_land(cx, cz):
				continue
			var p00 := _bottom_vert(field, cx, cz)
			var p10 := _bottom_vert(field, cx + 1, cz)
			var p01 := _bottom_vert(field, cx, cz + 1)
			var p11 := _bottom_vert(field, cx + 1, cz + 1)
			_solid(verts, norms, cols, uvs, p00, p10, p11, color, Vector3.DOWN)
			_solid(verts, norms, cols, uvs, p00, p11, p01, color, Vector3.DOWN)


static func _bottom_vert(field: Heightfield, ix: int, iz: int) -> Vector3:
	var clamped_x := clampi(ix, 0, field.verts_x - 1)
	var clamped_z := clampi(iz, 0, field.verts_z - 1)
	var p := field.vertex_world(clamped_x, clamped_z)
	var j := field.jitter_xz(p.x, p.y)
	var s := field.coast_shift(clamped_x, clamped_z)
	return Vector3(p.x + j.x + s.x, field.y_bottom + _bottom_noise(field, p.x, p.y), p.y + j.y + s.y)


static func _bottom_noise(field: Heightfield, x: float, z: float) -> float:
	var h := Heightfield._hash2(x * 0.31 + float(field.seed), z * 0.29)
	return (h.x - 0.5) * 0.07


static func _lake_loops(field: Heightfield, cells: Array) -> Array:
	var lake: Dictionary = {}
	for cell in cells:
		var c: Vector2i = cell
		if field.is_land(c.x, c.y):
			lake[c] = true
	if lake.size() < 3:
		return []
	var outgoing: Dictionary = {}
	for c: Vector2i in lake:
		for pair in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
			var nx: int = c.x + int(pair[0])
			var nz: int = c.y + int(pair[1])
			if lake.has(Vector2i(nx, nz)):
				continue
			_edge_if_open_set(outgoing, c.x, c.y, int(pair[0]), int(pair[1]))
	return _trace_loops(field, outgoing)


static func _edge_if_open_set(outgoing: Dictionary, cx: int, cz: int, dx: int, dz: int) -> void:
	var a: Vector2
	var b: Vector2
	if dx == 0 and dz == -1:
		a = Vector2(cx, cz)
		b = Vector2(cx + 1, cz)
	elif dx == 1 and dz == 0:
		a = Vector2(cx + 1, cz)
		b = Vector2(cx + 1, cz + 1)
	elif dx == 0 and dz == 1:
		a = Vector2(cx + 1, cz + 1)
		b = Vector2(cx, cz + 1)
	else:
		a = Vector2(cx, cz + 1)
		b = Vector2(cx, cz)
	var key := "%d,%d" % [int(a.x), int(a.y)]
	if not outgoing.has(key):
		outgoing[key] = []
	(outgoing[key] as Array).append(b)


static func _solid(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, color: Color, outside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	# Godot front faces are clockwise. A right-hand normal that agrees with
	# `outside` is therefore the back face; flip so the play camera sees tops.
	if n.dot(outside) > 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	# Light with the geometric slope, facing the outside hemisphere.
	var lit := -n.normalized()
	if lit.dot(outside) < 0.0:
		lit = -lit
	if lit.length_squared() < 0.25:
		lit = outside.normalized()
	var opaque := Color(color.r, color.g, color.b, 1.0)
	for p in [a, b, c]:
		verts.append(p)
		norms.append(lit)
		cols.append(opaque)
		uvs.append(Vector2(p.x, p.z) * 0.12)


static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3, color: Color, force_down: bool) -> void:
	var outside := Vector3.DOWN if force_down else Vector3.UP
	_solid(verts, norms, cols, uvs, a, b, c, color, outside)


static func _count_edge(counts: Dictionary, a: Vector3, b: Vector3, tol: float) -> void:
	var ka := _key(a, tol)
	var kb := _key(b, tol)
	if ka == kb:
		return
	var key := ka + "|" + kb if ka < kb else kb + "|" + ka
	counts[key] = int(counts.get(key, 0)) + 1


static func _key(p: Vector3, tol: float) -> String:
	var s := 1.0 / maxf(tol, 1e-5)
	return "%d,%d,%d" % [int(round(p.x * s)), int(round(p.y * s)), int(round(p.z * s))]


static func _empty() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st.commit()
