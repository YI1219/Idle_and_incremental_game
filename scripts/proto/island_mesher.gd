extends RefCounted
## Terraced top and a low-detail core for the island prototype.
## Top: marching-squares land mask (void cells stay empty) plus per-corner
## 0.25 m terraces. Idea adapted from Yūgen's Terrain Authoring Toolkit (MIT);
## this is a new implementation. Core underside: invert-and-stretch the coast
## heights, the idea from Flylands (MIT), also reimplemented.
## Vertices are not shared. Normals are face normals. No SurfaceTool.

const Heightfield := preload("res://scripts/world/heightfield.gd")

const ISO := 0.5
const SKIRT := 0.14
const BLUR_PASSES := 3

# Bit 0 SW, 1 SE, 2 NE, 3 NW. Local ids: 0 SW, 1 SE, 2 NE, 3 NW, 4 S, 5 E, 6 N, 7 W.
const LAND_POLYS := {
	1: [[0, 4, 7]],
	2: [[1, 5, 4]],
	3: [[0, 1, 5, 7]],
	4: [[2, 6, 5]],
	5: [[0, 4, 7], [2, 6, 5]],
	6: [[1, 2, 6, 4]],
	7: [[0, 1, 2, 6, 7]],
	8: [[3, 7, 6]],
	9: [[0, 4, 6, 3]],
	10: [[1, 5, 4], [3, 7, 6]],
	11: [[0, 1, 5, 6, 3]],
	12: [[2, 3, 7, 5]],
	13: [[0, 4, 5, 2, 3]],
	14: [[1, 2, 3, 7, 4]],
	15: [[0, 1, 2, 3]],
}
const BOUNDARY := {
	1: [[4, 7]],
	2: [[5, 4]],
	3: [[5, 7]],
	4: [[6, 5]],
	5: [[4, 7], [6, 5]],
	6: [[6, 4]],
	7: [[6, 7]],
	8: [[7, 6]],
	9: [[4, 6]],
	10: [[5, 4], [7, 6]],
	11: [[5, 6]],
	12: [[7, 5]],
	13: [[4, 5]],
	14: [[7, 4]],
}


static func prepare(field: Heightfield) -> Dictionary:
	var occ := _occupancy(field)
	var seams: Dictionary = {}
	var chunks_x := ceili(float(field.cells_x()) / float(Heightfield.CHUNK))
	var chunks_z := ceili(float(field.cells_z()) / float(Heightfield.CHUNK))
	var ctx := {
		"occ": occ,
		"seams": seams,
		"chunks_x": chunks_x,
		"chunks_z": chunks_z,
	}
	for cz in field.cells_z():
		for cx in field.cells_x():
			_emit_cell(field, occ, cx, cz, null, seams, false, ctx)
	ctx["loops"] = _trace_loops(field, seams)
	ctx["edge_buckets"] = _bucket_edges(field, ctx["loops"])
	return ctx


static func build_chunk(field: Heightfield, chunk: Vector2i, ctx: Dictionary) -> Dictionary:
	var buf := _Buf.new()
	var occ: PackedFloat32Array = ctx["occ"]
	var x0 := chunk.x * Heightfield.CHUNK
	var z0 := chunk.y * Heightfield.CHUNK
	var x1 := mini(x0 + Heightfield.CHUNK, field.cells_x())
	var z1 := mini(z0 + Heightfield.CHUNK, field.cells_z())
	var seams: Dictionary = ctx.get("seams", {})
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			# Void cells still emit when blur pulls a corner across the iso,
			# so the coast polyline stays connected.
			_emit_cell(field, occ, cx, cz, buf, seams, true, ctx)
	_emit_skirts(field, chunk, ctx, buf)
	return buf.payload()


static func collect_loops(field: Heightfield, ctx: Dictionary) -> Array:
	if ctx.has("loops"):
		return ctx["loops"]
	if (ctx["seams"] as Dictionary).is_empty():
		var occ: PackedFloat32Array = ctx["occ"]
		for cz in field.cells_z():
			for cx in field.cells_x():
				_emit_cell(field, occ, cx, cz, null, ctx["seams"], false, ctx)
	var loops: Array = _trace_loops(field, ctx["seams"])
	ctx["loops"] = loops
	return loops


static func build_core(field: Heightfield, loops: Array) -> Dictionary:
	var buf := _Buf.new()
	for loop in loops:
		if bool(loop.get("hole", false)):
			_emit_shaft(field, loop, buf)
		else:
			_emit_belly(field, loop, buf)
	return buf.payload()


static func chunk_of_cell(cx: int, cz: int) -> Vector2i:
	return Vector2i(int(float(cx) / float(Heightfield.CHUNK)), int(float(cz) / float(Heightfield.CHUNK)))


static func _occupancy(field: Heightfield) -> PackedFloat32Array:
	# Cell-centred mask, sampled twice per cell, blurred, then read back at
	# vertices. Outside samples stay 0, so the 0.5 iso is a curve around the
	# stair-step land mask instead of the grid itself.
	var subdiv := 2
	var nx := field.cells_x() * subdiv
	var nz := field.cells_z() * subdiv
	var gw := nx + 2
	var raw := PackedFloat32Array()
	raw.resize(gw * (nz + 2))
	for j in nz:
		for i in nx:
			var gx := int(float(i) / float(subdiv))
			var gz := int(float(j) / float(subdiv))
			raw[(j + 1) * gw + (i + 1)] = 1.0 if field.is_land(gx, gz) else 0.0
	for _pass in BLUR_PASSES:
		var nxt := raw.duplicate()
		for j in nz:
			for i in nx:
				var c := (j + 1) * gw + (i + 1)
				var acc := 0.0
				var wsum := 0.0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						var w := 0.25 if di == 0 and dj == 0 else (0.125 if di == 0 or dj == 0 else 0.0625)
						acc += raw[c + dj * gw + di] * w
						wsum += w
				nxt[c] = acc / wsum
		raw = nxt
	var occ := PackedFloat32Array()
	occ.resize(field.verts_x * field.verts_z)
	for iz in field.verts_z:
		for ix in field.verts_x:
			var i := ix * subdiv
			var j := iz * subdiv
			var v := 0.0
			if i >= 0 and j >= 0 and i < nx and j < nz:
				v = raw[(j + 1) * gw + (i + 1)]
			if not field._vertex_has_land(ix, iz):
				v = 0.0
			occ[iz * field.verts_x + ix] = v
	return occ


static func _emit_cell(field: Heightfield, occ: PackedFloat32Array, cx: int, cz: int, buf: RefCounted, seams: Dictionary, emit_faces: bool, ctx: Dictionary) -> void:
	var corner_i := [Vector2i(cx, cz), Vector2i(cx + 1, cz), Vector2i(cx + 1, cz + 1), Vector2i(cx, cz + 1)]
	var xz: Array[Vector2] = []
	var o := PackedFloat32Array()
	o.resize(4)
	var h := PackedFloat32Array()
	h.resize(4)
	var mask := 0
	var land_max := -1.0e9
	var land_n := 0
	for i in 4:
		var ix: int = corner_i[i].x
		var iz: int = corner_i[i].y
		xz.append(_corner_xz(field, ix, iz))
		var ov := occ[iz * field.verts_x + ix] if field.in_vertex(ix, iz) else 0.0
		o[i] = ov
		var hv := field.snap_height(field.height_at(ix, iz)) if field.in_vertex(ix, iz) else field.y_bottom
		h[i] = hv
		if ov >= ISO:
			mask |= 1 << i
			land_max = maxf(land_max, hv)
			land_n += 1
	if land_n == 0:
		return
	for i in 4:
		if o[i] < ISO:
			h[i] = land_max
	var pts: Array[Vector2] = []
	pts.resize(8)
	for i in 4:
		pts[i] = xz[i]
	pts[4] = _edge_pt(xz[0], xz[1], o[0], o[1])
	pts[5] = _edge_pt(xz[1], xz[2], o[1], o[2])
	pts[6] = _edge_pt(xz[2], xz[3], o[2], o[3])
	pts[7] = _edge_pt(xz[3], xz[0], o[3], o[0])
	if not emit_faces:
		_add_boundary(pts, mask, seams)
		return
	var loops: Array = ctx.get("loops", [])
	var cell_edges: Array = _cell_edges(ctx, cx, cz) if not loops.is_empty() else []
	var full := mask == 15
	if cell_edges.is_empty():
		if full or loops.is_empty():
			_emit_quadrants(buf, xz, h, PackedVector2Array(), true)
			_emit_quadrant_walls(buf, xz, h, PackedVector2Array(), true)
		else:
			var land_polys: Array[PackedVector2Array] = []
			var polys: Array = LAND_POLYS.get(mask, [])
			for poly_ids in polys:
				var poly := PackedVector2Array()
				for id in poly_ids:
					poly.append(pts[int(id)])
				poly = _ccw(poly)
				if poly.size() >= 3:
					land_polys.append(poly)
			_emit_quadrants(buf, xz, h, land_polys, false)
			_emit_quadrant_walls(buf, xz, h, land_polys, false)
	else:
		var clipped: Array[PackedVector2Array] = []
		var mid_s := (xz[0] + xz[1]) * 0.5
		var mid_e := (xz[1] + xz[2]) * 0.5
		var mid_n := (xz[2] + xz[3]) * 0.5
		var mid_w := (xz[3] + xz[0]) * 0.5
		var center := (xz[0] + xz[1] + xz[2] + xz[3]) * 0.25
		var quads: Array[PackedVector2Array] = [
			_quad(xz[0], mid_s, center, mid_w),
			_quad(xz[1], mid_e, center, mid_s),
			_quad(xz[2], mid_n, center, mid_e),
			_quad(xz[3], mid_w, center, mid_n),
		]
		for i in 4:
			if _quad_inside(quads[i], cell_edges):
				clipped.append(quads[i])
				_fan_y(buf, quads[i], h[i], Color(1.0, 0.55, 0.15))
				continue
			var cut := _clip_land(quads[i], cell_edges, loops)
			if cut.size() >= 3:
				clipped.append(cut)
				_fan_y(buf, cut, h[i], Color(1.0, 0.55, 0.15))
		_emit_quadrant_walls(buf, xz, h, clipped, false)
	_add_boundary(pts, mask, seams)


static func _emit_quadrants(buf: RefCounted, xz: Array[Vector2], h: PackedFloat32Array, land_polys: Array, full: bool) -> void:
	var mid_s := (xz[0] + xz[1]) * 0.5
	var mid_e := (xz[1] + xz[2]) * 0.5
	var mid_n := (xz[2] + xz[3]) * 0.5
	var mid_w := (xz[3] + xz[0]) * 0.5
	var center := (xz[0] + xz[1] + xz[2] + xz[3]) * 0.25
	var quads: Array[PackedVector2Array] = [
		_quad(xz[0], mid_s, center, mid_w),
		_quad(xz[1], mid_e, center, mid_s),
		_quad(xz[2], mid_n, center, mid_e),
		_quad(xz[3], mid_w, center, mid_n),
	]
	for i in 4:
		var poly := quads[i]
		if full:
			_fan_y(buf, poly, h[i], Color(1.0, 0.55, 0.15))
		else:
			for land in land_polys:
				var clipped := _clip_poly(poly, land)
				_fan_y(buf, clipped, h[i], Color(1.0, 0.55, 0.15))


static func _emit_quadrant_walls(buf: RefCounted, xz: Array[Vector2], h: PackedFloat32Array, land_polys: Array, full: bool) -> void:
	var mid_s := (xz[0] + xz[1]) * 0.5
	var mid_e := (xz[1] + xz[2]) * 0.5
	var mid_n := (xz[2] + xz[3]) * 0.5
	var mid_w := (xz[3] + xz[0]) * 0.5
	var center := (xz[0] + xz[1] + xz[2] + xz[3]) * 0.25
	var edges := [
		[0, 1, mid_s, center],
		[1, 2, mid_e, center],
		[2, 3, mid_n, center],
		[3, 0, mid_w, center],
	]
	var step := Heightfield.TERRACE
	for edge in edges:
		var ia: int = edge[0]
		var ib: int = edge[1]
		if absf(h[ia] - h[ib]) < step * 0.5:
			continue
		var a: Vector2 = edge[2]
		var b: Vector2 = edge[3]
		var side_pt: Vector2 = xz[ia] if h[ia] <= h[ib] else xz[ib]
		if full:
			_wall(buf, a, b, h[ia], h[ib], Color(0.55, 0.45, 0.2), side_pt)
		else:
			for land in land_polys:
				var seg := _clip_seg(a, b, land)
				if seg.size() == 2:
					_wall(buf, seg[0], seg[1], h[ia], h[ib], Color(0.55, 0.45, 0.2), side_pt)


static func _emit_skirts(field: Heightfield, chunk: Vector2i, ctx: Dictionary, buf: RefCounted) -> void:
	## One continuous earth ribbon on the smoothed coast. It hangs onto the top rocks.
	var loops: Array = ctx.get("loops", [])
	for loop in loops:
		var pts: PackedVector2Array = loop["pts"]
		var n := pts.size()
		if n < 3:
			continue
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			var mid := (a + b) * 0.5
			if _chunk_of_world(field, mid) != chunk:
				continue
			var ya := _coast_y(field, a)
			var yb := _coast_y(field, b)
			var a0 := Vector3(a.x, ya, a.y)
			var b0 := Vector3(b.x, yb, b.y)
			var a1 := Vector3(a.x, ya - SKIRT, a.y)
			var b1 := Vector3(b.x, yb - SKIRT, b.y)
			var dir := b - a
			if dir.length_squared() < 1.0e-8:
				continue
			dir = dir.normalized()
			# Loops are oriented so the right side is outside (air).
			var outward := Vector2(dir.y, -dir.x)
			var prefer := Vector3(mid.x, (ya + yb) * 0.5 - SKIRT * 0.5, mid.y) + Vector3(outward.x, 0.0, outward.y)
			buf.quad(a0, b0, b1, a1, Color(0.0, 0.4, 0.2), prefer)


static func _chunk_of_world(field: Heightfield, p: Vector2) -> Vector2i:
	var local := p - field.origin
	var cx := int(floor(local.x / field.spacing))
	var cz := int(floor(local.y / field.spacing))
	return chunk_of_cell(cx, cz)


static func _bucket_edges(field: Heightfield, loops: Array) -> Dictionary:
	var buckets: Dictionary = {}
	for loop in loops:
		var pts: PackedVector2Array = loop["pts"]
		var n := pts.size()
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			var min_p := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(0.7, 0.7)
			var max_p := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(0.7, 0.7)
			var c0 := _cell_of(field, min_p)
			var c1 := _cell_of(field, max_p)
			for cz in range(c0.y, c1.y + 1):
				for cx in range(c0.x, c1.x + 1):
					var key := Vector2i(cx, cz)
					if not buckets.has(key):
						buckets[key] = []
					(buckets[key] as Array).append([a, b])
	return buckets


static func _cell_of(field: Heightfield, p: Vector2) -> Vector2i:
	var local := p - field.origin
	return Vector2i(int(floor(local.x / field.spacing)), int(floor(local.y / field.spacing)))


static func _cell_edges(ctx: Dictionary, cx: int, cz: int) -> Array:
	var buckets: Dictionary = ctx.get("edge_buckets", {})
	return buckets.get(Vector2i(cx, cz), [])


static func _quad_inside(poly: PackedVector2Array, edges: Array) -> bool:
	for edge in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		for p in poly:
			if not _left(a, b, p):
				return false
	return true


static func _clip_land(poly: PackedVector2Array, edges: Array, loops: Array) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	if edges.is_empty():
		var c := Vector2.ZERO
		for p in poly:
			c += p
		c /= float(poly.size())
		if _in_land(c, loops):
			return poly
		return PackedVector2Array()
	var cur := poly
	for edge in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		cur = _clip_edge(cur, a, b)
		if cur.size() < 3:
			return PackedVector2Array()
	return cur


static func _in_land(p: Vector2, loops: Array) -> bool:
	var inside := false
	for loop in loops:
		var hole := bool(loop.get("hole", false))
		var hit := _point_in_poly(p, loop["pts"])
		if hole:
			if hit:
				return false
		elif hit:
			inside = true
	return inside


static func _point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	var inside := false
	var j := n - 1
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 1.0e-12) + a.x):
			inside = not inside
		j = i
	return inside


static func _add_boundary(pts: Array[Vector2], mask: int, seams: Dictionary) -> void:
	for seg in BOUNDARY.get(mask, []):
		var a: Vector2 = pts[int(seg[0])]
		var b: Vector2 = pts[int(seg[1])]
		if a.distance_squared_to(b) < 1.0e-8:
			continue
		var ka := _qkey(a)
		var kb := _qkey(b)
		if ka == kb:
			continue
		if not seams.has(ka):
			seams[ka] = {"p": _snap_pt(a), "n": []}
		if not seams.has(kb):
			seams[kb] = {"p": _snap_pt(b), "n": []}
		var na: Array = seams[ka]["n"]
		var nb: Array = seams[kb]["n"]
		if not na.has(kb):
			na.append(kb)
		if not nb.has(ka):
			nb.append(ka)


static func _trace_loops(field: Heightfield, seams: Dictionary) -> Array:
	var deg: Dictionary = {}
	for key in seams.keys():
		var d := (seams[key]["n"] as Array).size()
		deg[d] = int(deg.get(d, 0)) + 1
	var unused: Dictionary = {}
	for key in seams.keys():
		unused[key] = true
	var loops: Array = []
	for start in seams.keys():
		if not unused.has(start):
			continue
		var loop_keys: Array = []
		var cur = start
		var guard := 0
		while unused.has(cur) and guard < 8000:
			guard += 1
			unused.erase(cur)
			loop_keys.append(cur)
			var nxt = null
			for nb in seams[cur]["n"]:
				if unused.has(nb):
					nxt = nb
					break
			if nxt == null:
				break
			cur = nxt
		if loop_keys.size() < 6:
			continue
		var raw := PackedVector2Array()
		for key in loop_keys:
			raw.append(seams[key]["p"])
		var smooth := _smooth_coast(raw, field)
		if _poly_len(smooth) < 2.0:
			continue
		var c := _centroid(smooth)
		var hole := not field.sample_land(Vector3(c.x, 0.0, c.y))
		# Outer loops are CCW (land on the left). Holes are CW so land stays on the left.
		if hole:
			if _area(smooth) > 0.0:
				smooth.reverse()
		elif _area(smooth) < 0.0:
			smooth.reverse()
		c = _centroid(smooth)
		loops.append({"pts": smooth, "hole": hole, "centroid": c})
	return loops


static func _emit_belly(field: Heightfield, loop: Dictionary, buf: RefCounted) -> void:
	var pts: PackedVector2Array = loop["pts"]
	var perim := _poly_len(pts)
	var segs := clampi(int(round(perim / 1.7)), 16, 40)
	var ring_xz := _resample(pts, segs)
	var c2: Vector2 = loop["centroid"]
	var top_y := PackedFloat32Array()
	top_y.resize(segs)
	var min_top := 1.0e9
	for i in segs:
		var y := _coast_y(field, ring_xz[i])
		top_y[i] = y
		min_top = minf(min_top, y)
	# t, radial scale. A cone behind the rocks, ending in a short stalk.
	var profile := [
		[0.00, 0.70],
		[0.20, 0.52],
		[0.42, 0.34],
		[0.64, 0.18],
		[0.82, 0.07],
		[0.94, 0.035],
	]
	var rings: Array[PackedVector3Array] = []
	for row in profile:
		var t: float = row[0]
		var sc: float = row[1]
		var ring := PackedVector3Array()
		ring.resize(segs)
		for i in segs:
			var p: Vector2 = c2 + (ring_xz[i] - c2) * sc
			var depth: float = top_y[i] - field.y_bottom
			var y := top_y[i] - 0.05 - pow(t, 1.2) * depth
			var wob := Heightfield._hash2(p.x * 0.47 + float(field.seed), p.y * 0.39)
			var amp := 0.02 + t * 0.06
			var inward := (c2 - ring_xz[i])
			if inward.length_squared() > 1.0e-6:
				p += inward.normalized() * (wob.x - 0.5) * amp
			y += (wob.y - 0.5) * amp * 0.25
			y = clampf(y, field.y_bottom - 0.35, top_y[i] - 0.08)
			ring[i] = Vector3(p.x, y, p.y)
		rings.append(ring)
	var interior := Vector3(c2.x, (min_top + field.y_bottom) * 0.5, c2.y)
	for r in range(1, rings.size()):
		var upper: PackedVector3Array = rings[r - 1]
		var lower: PackedVector3Array = rings[r]
		for i in segs:
			var j := (i + 1) % segs
			buf.tri_out(upper[i], upper[j], lower[j], Color(0.5, 0.5, 0.5), interior)
			buf.tri_out(upper[i], lower[j], lower[i], Color(0.5, 0.5, 0.5), interior)
	var last: PackedVector3Array = rings[rings.size() - 1]
	var tip_y := field.y_bottom - 0.55
	var tip := Vector3(c2.x, tip_y, c2.y)
	for i in segs:
		var j := (i + 1) % segs
		buf.tri_out(last[i], last[j], tip, Color(0.5, 0.5, 0.5), interior)


static func _emit_shaft(field: Heightfield, loop: Dictionary, buf: RefCounted) -> void:
	var pts: PackedVector2Array = loop["pts"]
	var perim := _poly_len(pts)
	var segs := clampi(int(round(perim / 0.9)), 8, 24)
	var rim := _resample(pts, segs)
	var c2: Vector2 = loop["centroid"]
	var y0 := PackedFloat32Array()
	y0.resize(segs)
	for i in segs:
		y0[i] = _coast_y(field, rim[i]) - SKIRT
	var rings := 3
	var prev := PackedVector3Array()
	for r in rings + 1:
		var t := float(r) / float(rings)
		var ring := PackedVector3Array()
		ring.resize(segs)
		for i in segs:
			var y := lerpf(y0[i], field.y_bottom - 0.2, t)
			ring[i] = Vector3(rim[i].x, y, rim[i].y)
		if r > 0:
			for i in segs:
				var j := (i + 1) % segs
				# Normal toward the hole so the shaft is visible from above.
				var face_mid := (prev[i] + ring[j]) * 0.5
				var toward := Vector3(c2.x, face_mid.y, c2.y)
				buf.tri_toward(prev[j], prev[i], ring[i], Color(0.35, 0.4, 0.45), toward)
				buf.tri_toward(prev[j], ring[i], ring[j], Color(0.35, 0.4, 0.45), toward)
		prev = ring


static func _coast_y(field: Heightfield, p: Vector2) -> float:
	var y := field.sample_height(Vector3(p.x, 0.0, p.y))
	if not is_finite(y):
		y = 0.0
	return field.snap_height(y)


static func _corner_xz(field: Heightfield, ix: int, iz: int) -> Vector2:
	var p := field.vertex_world(ix, iz)
	if field._vertex_is_rim(ix, iz):
		return p
	return p + field.jitter_xz(p.x, p.y)


static func _edge_pt(a: Vector2, b: Vector2, oa: float, ob: float) -> Vector2:
	var d := ob - oa
	var t := 0.5 if absf(d) < 1.0e-6 else clampf((ISO - oa) / d, 0.0, 1.0)
	return a.lerp(b, t)


static func _nearest_h(p: Vector2, xz: Array[Vector2], h: PackedFloat32Array) -> float:
	var best := 0
	var best_d := 1.0e12
	for i in 4:
		var d := p.distance_squared_to(xz[i])
		if d < best_d:
			best_d = d
			best = i
	return h[best]


static func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	return _ccw(PackedVector2Array([a, b, c, d]))


static func _fan_y(buf: RefCounted, poly: PackedVector2Array, y: float, color: Color) -> void:
	if poly.size() < 3:
		return
	if absf(_area(poly)) < 1.0e-6:
		return
	var p0 := Vector3(poly[0].x, y, poly[0].y)
	for i in range(1, poly.size() - 1):
		var p1 := Vector3(poly[i].x, y, poly[i].y)
		var p2 := Vector3(poly[i + 1].x, y, poly[i + 1].y)
		buf.tri_up(p0, p1, p2, color)


static func _wall(buf: RefCounted, a: Vector2, b: Vector2, ha: float, hb: float, color: Color, side_pt: Vector2) -> void:
	if a.distance_squared_to(b) < 1.0e-8:
		return
	var hi := maxf(ha, hb)
	var lo := minf(ha, hb)
	var a0 := Vector3(a.x, hi, a.y)
	var b0 := Vector3(b.x, hi, b.y)
	var a1 := Vector3(a.x, lo, a.y)
	var b1 := Vector3(b.x, lo, b.y)
	# side_pt is the lower terrace corner, off the riser, so the face looks that way.
	var prefer := Vector3(side_pt.x, (hi + lo) * 0.5, side_pt.y)
	buf.quad(a0, b0, b1, a1, color, prefer)


static func _clip_poly(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var out := subject
	if clip.size() < 3:
		return PackedVector2Array()
	for i in clip.size():
		if out.size() < 3:
			return PackedVector2Array()
		out = _clip_edge(out, clip[i], clip[(i + 1) % clip.size()])
	return out


static func _clip_edge(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.is_empty():
		return out
	var prev: Vector2 = poly[poly.size() - 1]
	var prev_in := _left(a, b, prev)
	for i in poly.size():
		var cur: Vector2 = poly[i]
		var cur_in := _left(a, b, cur)
		if cur_in:
			if not prev_in:
				out.append(_intersect(prev, cur, a, b))
			out.append(cur)
		elif prev_in:
			out.append(_intersect(prev, cur, a, b))
		prev = cur
		prev_in = cur_in
	return out


static func _clip_seg(a: Vector2, b: Vector2, poly: PackedVector2Array) -> PackedVector2Array:
	var s := a
	var e := b
	for i in poly.size():
		var c: Vector2 = poly[i]
		var d: Vector2 = poly[(i + 1) % poly.size()]
		var in_s := _left(c, d, s)
		var in_e := _left(c, d, e)
		if in_s and in_e:
			continue
		if not in_s and not in_e:
			return PackedVector2Array()
		var hit := _intersect(s, e, c, d)
		if in_s:
			e = hit
		else:
			s = hit
	if s.distance_squared_to(e) < 1.0e-8:
		return PackedVector2Array()
	return PackedVector2Array([s, e])


static func _left(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= -1.0e-7


static func _intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var d1 := p2 - p1
	var d2 := p4 - p3
	var den := d1.x * d2.y - d1.y * d2.x
	if absf(den) < 1.0e-12:
		return (p1 + p2) * 0.5
	var t := ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / den
	return p1 + d1 * clampf(t, 0.0, 1.0)


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func _ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if _area(poly) < 0.0:
		poly.reverse()
	return poly


static func _qkey(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x * 80.0)), int(round(p.y * 80.0)))


static func _snap_pt(p: Vector2) -> Vector2:
	return Vector2(round(p.x * 80.0) / 80.0, round(p.y * 80.0) / 80.0)


static func _smooth_coast(raw: PackedVector2Array, field: Heightfield) -> PackedVector2Array:
	## Same idea as Heightfield.apply_coast_smooth: Chaikin, Catmull, low-frequency wobble.
	var pts := raw
	for _i in 2:
		pts = _chaikin(pts)
	pts = _catmull(pts)
	pts = _low_freq(pts, field.seed)
	var count := clampi(int(round(_poly_len(pts) / 0.22)), 36, 220)
	return _resample(pts, count)


static func _catmull(loop: PackedVector2Array) -> PackedVector2Array:
	var n := loop.size()
	if n < 4:
		return loop
	var out := PackedVector2Array()
	for i in n:
		var p0: Vector2 = loop[(i - 1 + n) % n]
		var p1: Vector2 = loop[i]
		var p2: Vector2 = loop[(i + 1) % n]
		var p3: Vector2 = loop[(i + 2) % n]
		out.append(p1)
		var t := 0.5
		var t2 := t * t
		var t3 := t2 * t
		out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


static func _low_freq(loop: PackedVector2Array, seed: int) -> PackedVector2Array:
	var n := loop.size()
	if n < 4:
		return loop
	var c := _centroid(loop)
	var out := PackedVector2Array()
	for i in n:
		var q: Vector2 = loop[i]
		var radial := q - c
		if radial.length_squared() < 1.0e-6:
			out.append(q)
			continue
		var t := float(i) / float(n)
		var wobble := sin(t * TAU * 2.0 + float(seed) * 0.17) * 0.16
		wobble += sin(t * TAU * 3.0 - float(seed) * 0.09) * 0.08
		out.append(q + radial.normalized() * wobble)
	return out


static func _chaikin(loop: PackedVector2Array) -> PackedVector2Array:
	var n := loop.size()
	if n < 4:
		return loop
	var out := PackedVector2Array()
	for i in n:
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % n]
		out.append(a * 0.75 + b * 0.25)
		out.append(a * 0.25 + b * 0.75)
	return out


static func _poly_len(loop: PackedVector2Array) -> float:
	var n := loop.size()
	if n < 2:
		return 0.0
	var total := 0.0
	for i in n:
		total += loop[i].distance_to(loop[(i + 1) % n])
	return total


static func _centroid(loop: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	if loop.is_empty():
		return c
	for p in loop:
		c += p
	return c / float(loop.size())


static func _resample(loop: PackedVector2Array, count: int) -> PackedVector2Array:
	var n := loop.size()
	var out := PackedVector2Array()
	out.resize(count)
	if n < 2 or count < 3:
		return loop
	var acc := PackedFloat32Array()
	acc.resize(n + 1)
	for i in n:
		acc[i + 1] = acc[i] + loop[i].distance_to(loop[(i + 1) % n])
	var total := acc[n]
	if total < 1.0e-4:
		return loop
	var seg := 0
	for i in count:
		var target := total * float(i) / float(count)
		while seg < n - 1 and acc[seg + 1] < target:
			seg += 1
		var span := maxf(acc[seg + 1] - acc[seg], 1.0e-6)
		var t := clampf((target - acc[seg]) / span, 0.0, 1.0)
		out[i] = loop[seg].lerp(loop[(seg + 1) % n], t)
	return out


class _Buf:
	extends RefCounted
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()

	func payload() -> Dictionary:
		return {
			"vertices": verts,
			"normals": norms,
			"colors": cols,
			"triangles": int(verts.size() / 3),
		}

	func tri_up(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-12:
			return
		if n.y < 0.0:
			var s := b
			b = c
			c = s
			n = -n
		_push(a, b, c, n.normalized(), color)

	func tri_toward(a: Vector3, b: Vector3, c: Vector3, color: Color, toward: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-12:
			return
		var mid := (a + b + c) / 3.0
		if n.dot(toward - mid) < 0.0:
			var s := b
			b = c
			c = s
			n = -n
		_push(a, b, c, n.normalized(), color)

	func tri_out(a: Vector3, b: Vector3, c: Vector3, color: Color, interior: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-12:
			return
		var mid := (a + b + c) / 3.0
		if n.dot(mid - interior) < 0.0:
			var s := b
			b = c
			c = s
			n = -n
		_push(a, b, c, n.normalized(), color)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, prefer: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-10:
			return
		var mid := (a + c) * 0.5
		if n.dot(prefer - mid) < 0.0:
			_push(a, d, c, (-n).normalized(), color)
			_push(a, c, b, (-n).normalized(), color)
		else:
			_push(a, b, c, n.normalized(), color)
			_push(a, c, d, n.normalized(), color)

	func _push(a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
		# Callers pass a right-hand winding whose cross is `n` (the lit outside).
		# Godot front faces are clockwise, so that winding is the back face.
		# Swap so the play camera sees tops and the outer wall.
		verts.append(a)
		verts.append(c)
		verts.append(b)
		norms.append(n)
		norms.append(n)
		norms.append(n)
		cols.append(color)
		cols.append(color)
		cols.append(color)
