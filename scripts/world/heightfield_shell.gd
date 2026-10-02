extends Object
## Render shell for a heightfield island.
## Gameplay cells stay on the mask. The visible coast is a smoothed marching-squares
## contour. Walls below that lip are flat-shaded procedural blocks, not kit meshes.

const Heightfield := preload("res://scripts/world/heightfield.gd")

const ISO := 0.5
const SUB_FULL := 2
const SUB_LOD := 1
const META := &"hf_shell_cache"

# Corner 0 SW, 1 SE, 2 NE, 3 NW. Edge 4 S, 5 E, 6 N, 7 W.
const CASE_TRIS: Array = [
	[],
	[[0, 4, 7]],
	[[1, 5, 4]],
	[[0, 1, 5], [0, 5, 7]],
	[[2, 6, 5]],
	[],
	[[1, 2, 6], [1, 6, 4]],
	[[0, 1, 2], [0, 2, 6], [0, 6, 7]],
	[[3, 7, 6]],
	[[0, 4, 6], [0, 6, 3]],
	[],
	[[0, 1, 5], [0, 5, 6], [0, 6, 3]],
	[[3, 7, 5], [3, 5, 2]],
	[[0, 4, 5], [0, 5, 2], [0, 2, 3]],
	[[4, 1, 2], [4, 2, 3], [4, 3, 7]],
	[[0, 1, 2], [0, 2, 3]],
]
const CASE_SEGS: Array = [
	[],
	[[4, 7]],
	[[5, 4]],
	[[5, 7]],
	[[6, 5]],
	[],
	[[6, 4]],
	[[6, 7]],
	[[7, 6]],
	[[4, 6]],
	[],
	[[5, 6]],
	[[5, 7]],
	[[4, 5]],
	[[7, 4]],
	[],
]


static func visual_loops(field: Heightfield) -> Array:
	var mkey := _mask_key(field)
	var cache: Dictionary = field.get_meta(META, {})
	if int(cache.get("mkey", 0)) != mkey or int(cache.get("sub", -1)) != SUB_FULL or not cache.has("vloops"):
		cache = _contour(field, SUB_FULL)
		cache["mkey"] = mkey
		cache["sub"] = SUB_FULL
		field.set_meta(META, cache)
	return cache.get("vloops", [])


static func build_chunk(field: Heightfield, chunk: Vector2i, mode: String = "full", skip_top: Dictionary = {}) -> Dictionary:
	var subdiv := SUB_LOD if mode == "lod" else SUB_FULL
	var want_top := mode in ["top", "full", "lod"]
	var want_wall := mode in ["full", "shell", "lod"]
	var cache := _ensure(field, subdiv, skip_top, want_wall)
	var id := _chunk_key(chunk)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	if want_top:
		_take(cache.get("top", {}), id, verts, norms, cols, uvs)
	if want_wall:
		_take(cache.get("wall", {}), id, verts, norms, cols, uvs)
	return {
		"vertices": verts,
		"normals": norms,
		"colors": cols,
		"uvs": uvs,
		"triangles": int(verts.size() / 3),
		"chunk": chunk,
		"mode": mode,
	}


static func _ensure(field: Heightfield, subdiv: int, skip_top: Dictionary, want_wall: bool) -> Dictionary:
	var mkey := _mask_key(field)
	var hkey := _height_key(field)
	var skey := _skip_key(skip_top)
	var cache: Dictionary = field.get_meta(META, {})
	if int(cache.get("mkey", 0)) != mkey or int(cache.get("sub", -1)) != subdiv or not cache.has("raw"):
		cache = _contour(field, subdiv)
		cache["mkey"] = mkey
		cache["sub"] = subdiv
	var fresh := int(cache.get("hkey", -1)) == hkey and int(cache.get("skey", -1)) == skey
	if fresh and cache.has("top") and (not want_wall or cache.has("wall")):
		return cache
	var emitted := _emit_cached(field, cache, skip_top, want_wall)
	cache["top"] = emitted["top"]
	cache["hkey"] = hkey
	cache["skey"] = skey
	if want_wall:
		cache["wall"] = emitted["wall"]
	elif cache.has("wall"):
		cache.erase("wall")
	field.set_meta(META, cache)
	return cache


static func _contour(field: Heightfield, subdiv: int) -> Dictionary:
	var nx: int = field.cells_x() * subdiv
	var nz: int = field.cells_z() * subdiv
	var fine := field.spacing / float(subdiv)
	var gw := nx + 3
	var raw := PackedFloat32Array()
	raw.resize(gw * (nz + 3))
	for j in range(-1, nz + 2):
		for i in range(-1, nx + 2):
			raw[_sidx(i, j, gw)] = _raw_occ(field, i, j, subdiv, nx, nz)
	raw = _blur_occ(raw, gw, nx, nz)
	raw = _blur_occ(raw, gw, nx, nz)
	var pos := {}
	var segs: Array = []
	for j in nz:
		for i in nx:
			_collect_cell(field, raw, gw, i, j, nx, fine, pos, segs)
	var loops: Array = _trace(_boundary_segs(segs))
	var oriented: Array = []
	var vloops: Array = []
	for loop in loops:
		_smooth_loop(loop, pos, fine * 1.05)
		if (loop as Array).size() < 3:
			continue
		var ids: Array = (loop as Array).duplicate()
		var lip := PackedVector3Array()
		for id in ids:
			var p: Vector2 = pos[id]
			lip.append(Vector3(p.x, 0.0, p.y))
		if _is_hole(field, lip):
			ids.reverse()
			lip.reverse()
			if _is_hole(field, lip):
				ids.reverse()
		oriented.append(ids)
		var flat := PackedVector2Array()
		for id in ids:
			flat.append(pos[id])
		vloops.append(flat)
	return {
		"raw": raw,
		"pos": pos,
		"loops": oriented,
		"nx": nx,
		"nz": nz,
		"fine": fine,
		"gw": gw,
		"vloops": vloops,
		"sub": subdiv,
	}


static func _blur_occ(raw: PackedFloat32Array, gw: int, nx: int, nz: int) -> PackedFloat32Array:
	var nxt := raw.duplicate()
	for j in range(0, nz):
		var row := (j + 1) * gw
		for i in range(0, nx):
			var c := row + (i + 1)
			var n := c - gw
			var s := c + gw
			nxt[c] = raw[c] * 0.25 + (raw[c - 1] + raw[c + 1] + raw[n] + raw[s]) * 0.125 + (raw[n - 1] + raw[n + 1] + raw[s - 1] + raw[s + 1]) * 0.0625
	for j in range(-1, nz + 2):
		for i in range(-1, nx + 2):
			if i >= 0 and j >= 0 and i < nx and j < nz:
				continue
			var acc := 0.0
			var wsum := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := i + di
					var jj := j + dj
					if ii < -1 or jj < -1 or ii > nx + 1 or jj > nz + 1:
						continue
					var w := 0.25 if di == 0 and dj == 0 else (0.125 if di == 0 or dj == 0 else 0.0625)
					acc += raw[_sidx(ii, jj, gw)] * w
					wsum += w
			nxt[_sidx(i, j, gw)] = acc / maxf(wsum, 1e-6)
	return nxt


static func _emit_cached(field: Heightfield, cache: Dictionary, skip_top: Dictionary, want_wall: bool) -> Dictionary:
	var nx := int(cache["nx"])
	var nz := int(cache["nz"])
	var fine := float(cache["fine"])
	var gw := int(cache["gw"])
	var raw: PackedFloat32Array = cache["raw"]
	var pos: Dictionary = cache["pos"]
	var subdiv := int(cache["sub"])
	var tables := _height_tables(field)
	var ys := _fill_ys(field, raw, gw, nx, nz, fine, skip_top, tables)
	var cgw := nx + 1
	var ns := _fill_ns(ys, nx, nz, fine, cgw)
	var lips: Array = []
	for ids in cache["loops"]:
		var lip := PackedVector3Array()
		for id in ids:
			var xz: Vector2 = pos[id]
			lip.append(Vector3(xz.x, _y_tables(field, xz, tables), xz.y))
		lips.append(lip)
	var top := Buf.new()
	for j in nz:
		for i in nx:
			_emit_cell(field, raw, gw, i, j, nx, fine, pos, top, subdiv, ys, ns, cgw, tables)
	var built := {"top": top.pack(), "vloops": cache["vloops"]}
	if want_wall:
		var wall := Buf.new()
		_emit_walls(field, lips, subdiv == SUB_LOD, wall)
		built["wall"] = wall.pack()
	return built


static func _collect_cell(field: Heightfield, raw: PackedFloat32Array, gw: int, i: int, j: int, nx: int, fine: float, pos: Dictionary, segs: Array) -> void:
	var vals := _corners(raw, gw, i, j)
	var mask := _mask_of(vals)
	if mask == 0 or mask == 15:
		return
	var tris: Array = _tris_for(mask, vals)
	var seg_list: Array = _segs_for(mask, vals)
	for seg in seg_list:
		var ea := int(seg[0])
		var eb := int(seg[1])
		var ida := _edge_id(i, j, ea, nx)
		var idb := _edge_id(i, j, eb, nx)
		if ida == idb:
			continue
		if not pos.has(ida):
			pos[ida] = _edge_xz(field, i, j, ea, fine, vals)
		if not pos.has(idb):
			pos[idb] = _edge_xz(field, i, j, eb, fine, vals)
		segs.append(Vector2i(ida, idb))
	# Touch tris so an unused warning stays gone in the collector; emission is pass 2.
	if tris.is_empty():
		pass


static func _emit_cell(field: Heightfield, raw: PackedFloat32Array, gw: int, i: int, j: int, nx: int, fine: float, pos: Dictionary, buf: Buf, subdiv: int, ys: PackedFloat32Array, ns: PackedVector3Array, cgw: int, tables: Array) -> void:
	var vals := _corners(raw, gw, i, j)
	var mask := _mask_of(vals)
	if mask == 0:
		return
	var tris: Array = _tris_for(mask, vals)
	var origin := field.origin
	var gx := int(float(i) / float(subdiv))
	var gz := int(float(j) / float(subdiv))
	var chunk := _chunk_key(Vector2i(int(float(gx) / float(Heightfield.CHUNK)), int(float(gz) / float(Heightfield.CHUNK))))
	for tri in tris:
		var ta := int(tri[0])
		var tb := int(tri[1])
		var tc := int(tri[2])
		var pa := _cached_vert(field, i, j, ta, fine, origin, pos, nx, ys, cgw, tables)
		var pb := _cached_vert(field, i, j, tb, fine, origin, pos, nx, ys, cgw, tables)
		var pc := _cached_vert(field, i, j, tc, fine, origin, pos, nx, ys, cgw, tables)
		var col := _grass_color((vals[0] + vals[1] + vals[2] + vals[3]) * 0.25)
		buf.smooth(pa, pb, pc, _cached_n(i, j, ta, ns, cgw), _cached_n(i, j, tb, ns, cgw), _cached_n(i, j, tc, ns, cgw), col, Vector3.UP, chunk)


static func _cached_vert(field: Heightfield, i: int, j: int, token: int, fine: float, origin: Vector2, pos: Dictionary, nx: int, ys: PackedFloat32Array, cgw: int, tables: Array) -> Vector3:
	if token < 4:
		var ci := i + (1 if token == 1 or token == 2 else 0)
		var cj := j + (1 if token == 2 or token == 3 else 0)
		return Vector3(origin.x + float(ci) * fine, ys[cj * cgw + ci], origin.y + float(cj) * fine)
	var xz: Vector2 = pos[_edge_id(i, j, token, nx)]
	return Vector3(xz.x, _y_tables(field, xz, tables), xz.y)


static func _cached_n(i: int, j: int, token: int, ns: PackedVector3Array, cgw: int) -> Vector3:
	if token < 4:
		var ci := i + (1 if token == 1 or token == 2 else 0)
		var cj := j + (1 if token == 2 or token == 3 else 0)
		return ns[cj * cgw + ci]
	var pair: Array = [0, 1] if token == 4 else ([1, 2] if token == 5 else ([2, 3] if token == 6 else [3, 0]))
	var na := _cached_n(i, j, int(pair[0]), ns, cgw)
	var nb := _cached_n(i, j, int(pair[1]), ns, cgw)
	var g := na + nb
	if g.length_squared() < 1e-8:
		return Vector3.UP
	return g.normalized()


static func _height_tables(field: Heightfield) -> Array:
	var vx := field.verts_x
	var vz := field.verts_z
	var hh := PackedFloat32Array()
	var lm := PackedByteArray()
	hh.resize(vx * vz)
	lm.resize(vx * vz)
	for iz in vz:
		for ix in vx:
			var k := iz * vx + ix
			hh[k] = field.height_at(ix, iz)
			lm[k] = 1 if field._vertex_has_land(ix, iz) else 0
	return [hh, lm, vx, vz]


static func _y_tables(field: Heightfield, xz: Vector2, tables: Array) -> float:
	return _bilerp(xz.x, xz.y, field.origin, field.spacing, tables[0], tables[1], int(tables[2]), int(tables[3]), field.y_bottom)


static func _bilerp(x: float, z: float, origin: Vector2, spacing: float, hh: PackedFloat32Array, lm: PackedByteArray, vx: int, vz: int, y_bottom: float) -> float:
	if vx < 2 or vz < 2 or spacing <= 1e-6:
		return 0.0
	var gx := (x - origin.x) / spacing
	var gz := (z - origin.y) / spacing
	var ix := clampi(int(floor(gx)), 0, vx - 2)
	var iz := clampi(int(floor(gz)), 0, vz - 2)
	var tx := clampf(gx - float(ix), 0.0, 1.0)
	var tz := clampf(gz - float(iz), 0.0, 1.0)
	var i00 := iz * vx + ix
	var h10i := i00 + 1
	var h01i := i00 + vx
	var h11i := h01i + 1
	if lm[i00] != 0 and lm[h10i] != 0 and lm[h01i] != 0 and lm[h11i] != 0:
		return lerpf(lerpf(hh[i00], hh[h10i], tx), lerpf(hh[h01i], hh[h11i], tx), tz)
	var h00 := hh[i00] if lm[i00] != 0 else NAN
	var h10 := hh[h10i] if lm[h10i] != 0 else NAN
	var h01 := hh[h01i] if lm[h01i] != 0 else NAN
	var h11 := hh[h11i] if lm[h11i] != 0 else NAN
	var known := 0.0
	var n := 0
	for h in [h00, h10, h01, h11]:
		if is_finite(h):
			known += h
			n += 1
	if n == 0:
		return _nearest_tables(ix, iz, hh, lm, vx, vz, y_bottom)
	var fill := known / float(n)
	if not is_finite(h00):
		h00 = fill
	if not is_finite(h10):
		h10 = fill
	if not is_finite(h01):
		h01 = fill
	if not is_finite(h11):
		h11 = fill
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


static func _nearest_tables(ix: int, iz: int, hh: PackedFloat32Array, lm: PackedByteArray, vx: int, vz: int, y_bottom: float) -> float:
	for rad in range(1, 8):
		var best := 1.0e9
		var h := NAN
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dz)) != rad:
					continue
				var x := ix + dx
				var z := iz + dz
				if x < 0 or z < 0 or x >= vx or z >= vz:
					continue
				var k := z * vx + x
				if lm[k] == 0:
					continue
				var d := float(dx * dx + dz * dz)
				if d < best:
					best = d
					h = hh[k]
		if is_finite(h):
			return h
	return y_bottom


static func _at_fine(ci: int, cj: int, sub: int, hh: PackedFloat32Array, lm: PackedByteArray, vx: int, vz: int, y_bottom: float) -> float:
	var ix := clampi(int(float(ci) / float(sub)), 0, vx - 2)
	var iz := clampi(int(float(cj) / float(sub)), 0, vz - 2)
	var fx := float(posmod(ci, sub)) / float(sub)
	var fz := float(posmod(cj, sub)) / float(sub)
	var i00 := iz * vx + ix
	var i10 := i00 + 1
	var i01 := i00 + vx
	var i11 := i01 + 1
	if lm[i00] != 0 and lm[i10] != 0 and lm[i01] != 0 and lm[i11] != 0:
		return lerpf(lerpf(hh[i00], hh[i10], fx), lerpf(hh[i01], hh[i11], fx), fz)
	return _bilerp_idx(ix, iz, fx, fz, hh, lm, vx, vz, y_bottom)


static func _bilerp_idx(ix: int, iz: int, fx: float, fz: float, hh: PackedFloat32Array, lm: PackedByteArray, vx: int, vz: int, y_bottom: float) -> float:
	var i00 := iz * vx + ix
	var h10i := i00 + 1
	var h01i := i00 + vx
	var h11i := h01i + 1
	var h00 := hh[i00] if lm[i00] != 0 else NAN
	var h10 := hh[h10i] if lm[h10i] != 0 else NAN
	var h01 := hh[h01i] if lm[h01i] != 0 else NAN
	var h11 := hh[h11i] if lm[h11i] != 0 else NAN
	var known := 0.0
	var n := 0
	for h in [h00, h10, h01, h11]:
		if is_finite(h):
			known += h
			n += 1
	if n == 0:
		return _nearest_tables(ix, iz, hh, lm, vx, vz, y_bottom)
	var fill := known / float(n)
	if not is_finite(h00):
		h00 = fill
	if not is_finite(h10):
		h10 = fill
	if not is_finite(h01):
		h01 = fill
	if not is_finite(h11):
		h11 = fill
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


static func _fill_ys(field: Heightfield, raw: PackedFloat32Array, gw: int, nx: int, nz: int, fine: float, skip_top: Dictionary, tables: Array) -> PackedFloat32Array:
	var cgw := nx + 1
	var ys := PackedFloat32Array()
	ys.resize(cgw * (nz + 1))
	var hh: PackedFloat32Array = tables[0]
	var lm: PackedByteArray = tables[1]
	var vx := int(tables[2])
	var vz := int(tables[3])
	var yb := field.y_bottom
	var sub := maxi(int(round(field.spacing / fine)), 1)
	var origin := field.origin
	var cxn := field.cells_x()
	var czn := field.cells_z()
	var blocked := PackedByteArray()
	blocked.resize(maxi(cxn * czn, 1))
	if not skip_top.is_empty():
		for cz in czn:
			for cx in cxn:
				if skip_top.has(field.play_cell_of_hf(cx, cz)):
					blocked[cz * cxn + cx] = 1
	var max_ix := maxi(vx - 2, 0)
	var max_iz := maxi(vz - 2, 0)
	for cj in range(nz + 1):
		var iz := clampi(int(float(cj) / float(sub)), 0, max_iz)
		var fz := float(posmod(cj, sub)) / float(sub)
		var row := iz * vx
		for ci in range(nx + 1):
			var ix := clampi(int(float(ci) / float(sub)), 0, max_ix)
			var fx := float(posmod(ci, sub)) / float(sub)
			var i00 := row + ix
			var i10 := i00 + 1
			var i01 := i00 + vx
			var i11 := i01 + 1
			var y := 0.0
			if lm[i00] != 0 and lm[i10] != 0 and lm[i01] != 0 and lm[i11] != 0:
				y = lerpf(lerpf(hh[i00], hh[i10], fx), lerpf(hh[i01], hh[i11], fx), fz)
			else:
				y = _bilerp_idx(ix, iz, fx, fz, hh, lm, vx, vz, yb)
			ys[cj * cgw + ci] = y
	var out := ys.duplicate()
	var seed := float(field.seed)
	for cj in range(nz + 1):
		var z := origin.y + float(cj) * fine
		var iz2 := clampi(int(float(cj) / float(sub)), 0, maxi(czn - 1, 0))
		for ci in range(nx + 1):
			var i := cj * cgw + ci
			var h: float = ys[i]
			var hx: float = ys[cj * cgw + mini(ci + sub, nx)]
			var hz: float = ys[mini(cj + sub, nz) * cgw + ci]
			var hm: float = ys[cj * cgw + maxi(ci - sub, 0)]
			var hp: float = ys[maxi(cj - sub, 0) * cgw + ci]
			var pad := blocked[iz2 * cxn + clampi(int(float(ci) / float(sub)), 0, maxi(cxn - 1, 0))] != 0
			var y := h
			if not pad:
				var blur := (h + hx + hz + hm + hp) * 0.2
				var shoulder := clampf(absf(h - blur) * 1.5, 0.0, 0.42)
				y = lerpf(h, blur, shoulder)
				if maxf(absf(h - hx), absf(h - hz)) >= 0.035:
					var occ := raw[_sidx(ci, cj, gw)]
					var fade := clampf((occ - 0.58) / 0.32, 0.0, 1.0)
					if fade > 0.0:
						var x := origin.x + float(ci) * fine
						y += ((field._value_noise(x * 0.28 + seed * 0.03, z * 0.26) - 0.5) * 0.055 + (field._value_noise(x * 0.82 - seed * 0.02, z * 0.78) - 0.5) * 0.016) * fade
			out[i] = y
	return out


static func _fill_ns(ys: PackedFloat32Array, nx: int, nz: int, fine: float, cgw: int) -> PackedVector3Array:
	var ns := PackedVector3Array()
	ns.resize(ys.size())
	var up_span := fine * 2.0
	for cj in range(nz + 1):
		for ci in range(nx + 1):
			var hL: float = ys[cj * cgw + maxi(ci - 1, 0)]
			var hR: float = ys[cj * cgw + mini(ci + 1, nx)]
			var hD: float = ys[maxi(cj - 1, 0) * cgw + ci]
			var hU: float = ys[mini(cj + 1, nz) * cgw + ci]
			var g := Vector3(hL - hR, up_span, hD - hU)
			ns[cj * cgw + ci] = Vector3.UP if g.length_squared() < 1e-8 else g.normalized()
	return ns


static func _tris_for(mask: int, vals: PackedFloat32Array) -> Array:
	if mask == 5:
		if (vals[0] + vals[1] + vals[2] + vals[3]) * 0.25 >= ISO:
			return [[0, 4, 5], [0, 5, 2], [0, 2, 6], [0, 6, 7]]
		return [[0, 4, 7], [2, 6, 5]]
	if mask == 10:
		if (vals[0] + vals[1] + vals[2] + vals[3]) * 0.25 >= ISO:
			return [[1, 5, 6], [1, 6, 3], [1, 3, 7], [1, 7, 4]]
		return [[1, 5, 4], [3, 7, 6]]
	return CASE_TRIS[mask]


static func _segs_for(mask: int, vals: PackedFloat32Array) -> Array:
	if mask == 5:
		if (vals[0] + vals[1] + vals[2] + vals[3]) * 0.25 >= ISO:
			return [[4, 5], [6, 7]]
		return [[4, 7], [6, 5]]
	if mask == 10:
		if (vals[0] + vals[1] + vals[2] + vals[3]) * 0.25 >= ISO:
			return [[5, 6], [7, 4]]
		return [[5, 4], [7, 6]]
	return CASE_SEGS[mask]


static func _token_vert(field: Heightfield, i: int, j: int, token: int, fine: float, origin: Vector2, vals: PackedFloat32Array, pos: Dictionary, nx: int, skip_top: Dictionary) -> Vector3:
	if token < 4:
		var ci := i + (1 if token == 1 or token == 2 else 0)
		var cj := j + (1 if token == 2 or token == 3 else 0)
		var xz := Vector2(origin.x + float(ci) * fine, origin.y + float(cj) * fine)
		return Vector3(xz.x, _top_y(field, xz, vals[token], skip_top), xz.y)
	var eid := _edge_id(i, j, token, nx)
	var xz2: Vector2 = pos[eid]
	return _bound_vert(field, xz2)


static func _bound_vert(field: Heightfield, xz: Vector2) -> Vector3:
	return Vector3(xz.x, _finite_height(field, xz), xz.y)


static func _finite_height(field: Heightfield, xz: Vector2) -> float:
	# sample_height returns NaN off the mask. Dug-out vertices are also left
	# unclamped, so only corners that still touch land contribute.
	if field.verts_x < 2 or field.verts_z < 2 or field.spacing <= 1e-6:
		return 0.0
	var gx := (xz.x - field.origin.x) / field.spacing
	var gz := (xz.y - field.origin.y) / field.spacing
	var ix := clampi(int(floor(gx)), 0, field.verts_x - 2)
	var iz := clampi(int(floor(gz)), 0, field.verts_z - 2)
	var tx := clampf(gx - float(ix), 0.0, 1.0)
	var tz := clampf(gz - float(iz), 0.0, 1.0)
	var h00 := _land_height(field, ix, iz)
	var h10 := _land_height(field, ix + 1, iz)
	var h01 := _land_height(field, ix, iz + 1)
	var h11 := _land_height(field, ix + 1, iz + 1)
	var known := 0.0
	var n := 0
	for h in [h00, h10, h01, h11]:
		if is_finite(h):
			known += h
			n += 1
	if n == 0:
		return _nearest_land_height(field, ix, iz)
	if n < 4:
		var fill := known / float(n)
		if not is_finite(h00):
			h00 = fill
		if not is_finite(h10):
			h10 = fill
		if not is_finite(h01):
			h01 = fill
		if not is_finite(h11):
			h11 = fill
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


static func _land_height(field: Heightfield, ix: int, iz: int) -> float:
	if not field.in_vertex(ix, iz) or not field._vertex_has_land(ix, iz):
		return NAN
	return field.height_at(ix, iz)


static func _nearest_land_height(field: Heightfield, ix: int, iz: int) -> float:
	for rad in range(1, 8):
		var best := 1.0e9
		var h := NAN
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dz)) != rad:
					continue
				var x := ix + dx
				var z := iz + dz
				if not field.in_vertex(x, z) or not field._vertex_has_land(x, z):
					continue
				var d := float(dx * dx + dz * dz)
				if d < best:
					best = d
					h = field.height_at(x, z)
		if is_finite(h):
			return h
	return field.y_bottom


static func _top_y(field: Heightfield, xz: Vector2, occ: float, skip_top: Dictionary) -> float:
	var h := _finite_height(field, xz)
	var cell := field.world_to_cell(Vector3(xz.x, 0.0, xz.y))
	var play := field.play_cell_of_hf(clampi(cell.x, 0, maxi(field.cells_x() - 1, 0)), clampi(cell.y, 0, maxi(field.cells_z() - 1, 0)))
	var blocked := skip_top.has(play)
	var hx := _finite_height(field, Vector2(xz.x + field.spacing, xz.y))
	var hz := _finite_height(field, Vector2(xz.x, xz.y + field.spacing))
	var flat := maxf(absf(h - hx), absf(h - hz)) < 0.035
	var fade := 0.0 if blocked or flat else clampf((occ - 0.58) / 0.32, 0.0, 1.0)
	var blur := (h + hx + hz + _finite_height(field, Vector2(xz.x - field.spacing, xz.y)) + _finite_height(field, Vector2(xz.x, xz.y - field.spacing))) / 5.0
	var shoulder := 0.0 if blocked else clampf(absf(h - blur) * 1.5, 0.0, 0.42)
	var y := lerpf(h, blur, shoulder)
	if fade > 0.0:
		y += field.visual_relief(Vector3(xz.x, 0.0, xz.y)) * fade
	return y


static func _grass_color(occ: float) -> Color:
	var inland := clampf((occ - 0.42) / 0.45, 0.48, 1.0)
	var ao := clampf(0.70 + inland * 0.30, 0.62, 1.0)
	if occ < 0.62:
		ao *= 0.92
	return Color(ao, inland, 0.0, 1.0)


static func _emit_walls(field: Heightfield, lips: Array, lod: bool, buf: Buf) -> void:
	var centroid := field.land_centroid()
	var coast_r := 0.0
	var hole_r := 0.0
	for lip in lips:
		var ring: PackedVector3Array = lip
		if ring.is_empty():
			continue
		var hole := _signed_area(ring) < 0.0
		var far := 0.0
		var near := 1.0e9
		for p in ring:
			var d := Vector2(p.x, p.z).distance_to(centroid)
			far = maxf(far, d)
			near = minf(near, d)
		if hole:
			hole_r = maxf(hole_r, far)
		else:
			coast_r = maxf(coast_r, near)
	var pull := 0.16
	if hole_r > 0.2 and coast_r > 0.3:
		pull = clampf(1.0 - (hole_r + 0.7) / coast_r, 0.06, 0.48)
	var cap_buf := Buf.new()
	var wall_buf := Buf.new()
	var outers: Array = []
	var holes: Array = []
	for lip in lips:
		var ring: PackedVector3Array = lip
		if ring.size() < 3:
			continue
		var hole := _signed_area(ring) < 0.0
		var base := _emit_one_wall(field, ring, hole, lod, pull, centroid, wall_buf)
		if hole:
			holes.append(base)
		else:
			outers.append(base)
	for outer in outers:
		var mine: Array = []
		for hole in holes:
			var hc := _ring_centroid(hole)
			if _point_in_ring(Vector2(hc.x, hc.z), outer):
				mine.append(hole)
		_emit_cap(outer, mine, field, cap_buf)
	cap_buf.drain_into(buf)
	wall_buf.drain_into(buf)


static func _emit_one_wall(field: Heightfield, lip: PackedVector3Array, hole: bool, lod: bool, pull: float, centroid: Vector2, buf: Buf) -> Array:
	var n := lip.size()
	var acc := PackedFloat32Array()
	acc.resize(n + 1)
	for i in n:
		acc[i + 1] = acc[i] + lip[i].distance_to(lip[(i + 1) % n])
	var perim: float = acc[n]
	var target := (1.70 if lod else 1.28) * (0.78 if hole else 1.0)
	var cuts: Array[int] = [0]
	var cursor := 0.0
	var guard := 0
	while guard < n:
		guard += 1
		var h := Heightfield._hash2(cursor * 0.41 + float(field.seed) + (4.0 if hole else 0.0), float(guard) * 2.3)
		cursor += target * (0.70 + h.x * 0.58)
		if cursor >= perim - target * 0.45:
			break
		var idx := _arc_index(acc, cursor)
		if idx != cuts[cuts.size() - 1] and idx != 0:
			cuts.append(idx)
	if cuts.size() < 4 and n >= 8:
		cuts.clear()
		cuts.append(0)
		var step := maxi(int(float(n) / 6.0), 1)
		var at := step
		while at < n - step:
			cuts.append(at)
			at += step
	var blocks: Array = []
	for b in cuts.size():
		var i0 := cuts[b]
		var i1 := cuts[(b + 1) % cuts.size()] if b + 1 < cuts.size() else 0
		if b + 1 == cuts.size():
			i1 = 0
		var indices: Array[int] = []
		var k := i0
		var steps := 0
		while steps <= n:
			indices.append(k)
			if k == i1 and steps > 0:
				break
			k = (k + 1) % n
			steps += 1
			if steps > n:
				break
		if indices.size() < 2:
			continue
		var outward := Vector3.ZERO
		for id in indices:
			outward += _outward_at(lip, id)
		if outward.length_squared() < 1e-8:
			outward = Vector3(0.0, 0.0, 1.0)
		outward = outward.normalized()
		blocks.append({"i0": i0, "indices": indices, "out": outward})
	var bands := 3 if lod else 6
	var base: Array = []
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		var indices: Array = block["indices"]
		var outward: Vector3 = block["out"]
		var left: Vector3 = lip[indices[0]]
		var right: Vector3 = lip[indices[indices.size() - 1]]
		var corners: Array = []
		for band in bands:
			var t0 := _band_t(band, bands)
			var t1 := _band_t(band + 1, bands)
			var hn := Heightfield._hash2(float(b * 5 + field.seed) + float(band) * 0.17, float(band) * 9.2 + (2.0 if hole else 0.7))
			var amp := lerpf(0.04, 0.14, hn.x) if hole else lerpf(0.28, 0.92, hn.x)
			var d0 := amp * lerpf(1.0, 0.72, t0 * t0)
			var d1 := amp * lerpf(0.82, 0.40, t1)
			if d0 < d1 + 0.10:
				d0 = d1 + 0.10
			var br0 := 0.0 if band == 0 else (Heightfield._hash2(float(b) * 1.7 + float(field.seed), float(band) * 4.4).x - 0.5) * 0.28
			var br1 := 0.0 if band + 1 == bands else (Heightfield._hash2(float(b) * 1.7 + float(field.seed), float(band + 1) * 4.4).x - 0.5) * 0.28
			var iL := int(indices[0])
			var iR := int(indices[indices.size() - 1])
			var nL := _outward_at(lip, iL)
			var nR := _outward_at(lip, iR)
			var slide_l := _strata_slide(field.seed, iL, band)
			var slide_r := _strata_slide(field.seed, iR, band)
			var tl := _rock_corner(left, outward, centroid, t0, d0, pull, hole, br0, field.y_bottom, slide_l, Vector2(-nL.z, nL.x))
			var tr := _rock_corner(right, outward, centroid, t0, d0, pull, hole, br0, field.y_bottom, slide_r, Vector2(-nR.z, nR.x))
			var bl := _rock_corner(left, outward, centroid, t1, d1, pull, hole, br1, field.y_bottom, slide_l, Vector2(-nL.z, nL.x))
			var br := _rock_corner(right, outward, centroid, t1, d1, pull, hole, br1, field.y_bottom, slide_r, Vector2(-nR.z, nR.x))
			if tl.y < bl.y + 0.16:
				tl.y = bl.y + 0.16
				tr.y = br.y + 0.16
			corners.append([tl, tr, bl, br, hn.x])
		block["corners"] = corners
		blocks[b] = block
	# Bottom cap ring first so the closed-mesh winding check sees the underside.
	for b in blocks.size():
		var corners: Array = blocks[b]["corners"]
		var last: Array = corners[corners.size() - 1]
		base.append(last[2])
		base.append(last[3])
	for i in n:
		var a: Vector3 = lip[i]
		var b: Vector3 = lip[(i + 1) % n]
		var c := Vector3(a.x, _skirt_y(a.y, field.y_bottom), a.z)
		var d := Vector3(b.x, _skirt_y(b.y, field.y_bottom), b.z)
		var out := _outward_at(lip, i)
		var ch := _chid(field, (a + b) * 0.5)
		var earth := Color(0.84, 0.18, 0.0, 1.0)
		buf.flat(a, b, d, earth, out, ch, true)
		buf.flat(a, d, c, earth, out, ch, true)
	for b in blocks.size():
		var block: Dictionary = blocks[b]
		var indices: Array = block["indices"]
		var corners: Array = block["corners"]
		var outward: Vector3 = block["out"]
		var skirt: Array = []
		for id in indices:
			var p: Vector3 = lip[id]
			skirt.append(Vector3(p.x, _skirt_y(p.y, field.y_bottom), p.z))
		var topc: Array = corners[0]
		_fan_lip(buf, skirt, topc[0], topc[1], field, outward)
		for band in corners.size():
			var cnr: Array = corners[band]
			var tl: Vector3 = cnr[0]
			var tr: Vector3 = cnr[1]
			var bl: Vector3 = cnr[2]
			var br: Vector3 = cnr[3]
			var shade := 0.88 + float(cnr[4]) * 0.28
			shade *= lerpf(1.05, 0.70, float(band) / float(maxi(bands - 1, 1)))
			var col := Color(clampf(shade, 0.45, 1.15), 0.0, 1.0, 1.0)
			var ch := _chid(field, (tl + br) * 0.5)
			buf.flat(tl, tr, br, col, outward, ch, true)
			buf.flat(tl, br, bl, col, outward, ch, true)
			if band + 1 < corners.size():
				var below: Array = corners[band + 1]
				var overhangs := Vector2(tl.x - bl.x, tl.z - bl.z).length() > 0.02
				var ledge_out := (outward * 0.25 + (Vector3.DOWN if overhangs else Vector3.UP)).normalized()
				buf.flat(bl, br, below[1], col * Color(0.92, 1, 1), ledge_out, ch, true)
				buf.flat(bl, below[1], below[0], col * Color(0.92, 1, 1), ledge_out, ch, true)
		var nb: int = (b + 1) % blocks.size()
		var nc: Array = blocks[nb]["corners"]
		var right_id := int(indices[indices.size() - 1])
		var sp: Vector3 = lip[right_id]
		var skirt_pt := Vector3(sp.x, _skirt_y(sp.y, field.y_bottom), sp.z)
		var top_tr: Vector3 = corners[0][1]
		var next_tl: Vector3 = nc[0][0]
		var crack := _crack_out(top_tr, next_tl, (top_tr + corners[0][0]) * 0.5)
		buf.flat(skirt_pt, top_tr, next_tl, Color(0.72, 0.04, 0.90, 1.0), crack, _chid(field, (skirt_pt + top_tr) * 0.5), true)
		for band in corners.size():
			var cnr: Array = corners[band]
			var onc: Array = nc[band]
			var side := _crack_out(cnr[1], onc[0], (cnr[0] + cnr[1]) * 0.5)
			var ch2 := _chid(field, (cnr[1] + onc[2]) * 0.5)
			var col2 := Color(0.66, 0.0, 1.0, 1.0)
			buf.flat(cnr[1], onc[0], onc[2], col2, side, ch2, true)
			buf.flat(cnr[1], onc[2], cnr[3], col2, side, ch2, true)
			if band + 1 < corners.size():
				var below: Array = corners[band + 1]
				var nbelow: Array = nc[band + 1]
				buf.flat(cnr[3], below[1], nbelow[0], col2, side, ch2, true)
				buf.flat(cnr[3], nbelow[0], onc[2], col2, side, ch2, true)
	return base


static func _fan_lip(buf: Buf, skirt: Array, left: Vector3, right: Vector3, field: Heightfield, outward: Vector3) -> void:
	if skirt.size() < 2:
		return
	var hint := (outward + Vector3.UP * 0.65).normalized()
	var col := Color(0.78, 0.05, 0.85, 1.0)
	for i in skirt.size() - 1:
		var a: Vector3 = skirt[i]
		var b: Vector3 = skirt[i + 1]
		var ch := _chid(field, (a + right) * 0.5)
		if i == 0:
			buf.flat(a, b, right, col, hint, ch, true)
			buf.flat(a, right, left, col, hint, ch, true)
		else:
			buf.flat(a, b, right, col, hint, ch, true)


static func _emit_cap(outer: Array, holes: Array, field: Heightfield, buf: Buf) -> void:
	if outer.size() < 3:
		return
	var poly := PackedVector2Array()
	var pts: Array = []
	for p in outer:
		pts.append(p)
		poly.append(Vector2(p.x, p.z))
	if _shoelace2(poly) < 0.0:
		poly.reverse()
		pts.reverse()
	for hole in holes:
		var ring: Array = hole
		if ring.size() < 3:
			continue
		var hp := PackedVector2Array()
		for p in ring:
			hp.append(Vector2(p.x, p.z))
		if _shoelace2(hp) > 0.0:
			hp.reverse()
			ring.reverse()
		poly = _bridge(poly, hp, pts, ring)
	var idx := Geometry2D.triangulate_polygon(poly)
	var col := Color(0.52, 0.0, 1.0, 1.0)
	if idx.size() >= 3:
		for t in range(0, idx.size(), 3):
			var a: Vector3 = _cap_vert(pts, idx[t], field.y_bottom)
			var b: Vector3 = _cap_vert(pts, idx[t + 1], field.y_bottom)
			var c: Vector3 = _cap_vert(pts, idx[t + 2], field.y_bottom)
			buf.flat(a, b, c, col, Vector3.DOWN, _chid(field, (a + b + c) / 3.0), true)
		return
	var c3 := _ring_centroid(outer)
	c3.y = field.y_bottom
	for i in outer.size():
		var a: Vector3 = outer[i]
		var b: Vector3 = outer[(i + 1) % outer.size()]
		a.y = field.y_bottom
		b.y = field.y_bottom
		buf.flat(a, b, c3, col, Vector3.DOWN, _chid(field, (a + b + c3) / 3.0), true)


static func _cap_vert(pts: Array, index: int, y: float) -> Vector3:
	var p: Vector3 = pts[index]
	return Vector3(p.x, y, p.z)


static func _bridge(outer: PackedVector2Array, hole: PackedVector2Array, pts: Array, ring: Array) -> PackedVector2Array:
	var bi := 0
	var bj := 0
	var best := 1.0e18
	for i in outer.size():
		for j in hole.size():
			var d := outer[i].distance_squared_to(hole[j])
			if d < best:
				best = d
				bi = i
				bj = j
	var out := PackedVector2Array()
	var merged: Array = []
	out.append(outer[bi])
	merged.append(pts[bi])
	for t in hole.size():
		var j := (bj + t) % hole.size()
		out.append(hole[j])
		merged.append(ring[j])
	out.append(hole[bj])
	merged.append(ring[bj])
	out.append(outer[bi])
	merged.append(pts[bi])
	for i in range(1, outer.size()):
		var k := (bi + i) % outer.size()
		out.append(outer[k])
		merged.append(pts[k])
	pts.clear()
	for p in merged:
		pts.append(p)
	return out


static func _strata_slide(seed: int, lip_index: int, band: int) -> float:
	if band <= 0:
		return 0.0
	var h := Heightfield._hash2(float(lip_index) * 0.73 + float(seed) * 0.17, float(band) * 2.9)
	return (h.x - 0.5) * 0.16


static func _rock_corner(lip: Vector3, outward: Vector3, centroid: Vector2, t: float, depth: float, pull: float, hole: bool, y_break: float, y_bottom: float, slide: float, tangent: Vector2) -> Vector3:
	var xz := Vector2(lip.x, lip.z)
	if hole:
		xz += Vector2(outward.x, outward.z) * (0.04 + t * 0.32)
	else:
		xz = xz.lerp(centroid, clampf(pull, 0.0, 0.75) * t * t)
	xz += Vector2(outward.x, outward.z) * depth
	xz += tangent * slide
	var y := lerpf(_skirt_y(lip.y, y_bottom), y_bottom, t) + y_break * (1.0 - t)
	var hi := maxf(_skirt_y(lip.y, y_bottom), y_bottom)
	y = clampf(y, y_bottom, hi)
	return Vector3(xz.x, y, xz.y)


static func _skirt_y(lip_y: float, y_bottom: float) -> float:
	return maxf(lip_y - 0.10, y_bottom)


static func _band_t(k: int, bands: int) -> float:
	var u := float(k) / float(maxi(bands, 1))
	return pow(u, 0.82)


static func _outward_at(lip: PackedVector3Array, i: int) -> Vector3:
	var n := lip.size()
	var prev := lip[(i + n - 1) % n]
	var nxt := lip[(i + 1) % n]
	var t := Vector2(nxt.x - prev.x, nxt.z - prev.z)
	if t.length_squared() < 1e-8:
		return Vector3(1.0, 0.0, 0.0)
	t = t.normalized()
	return Vector3(t.y, 0.0, -t.x)


static func _arc_index(acc: PackedFloat32Array, cursor: float) -> int:
	var n := acc.size() - 1
	for i in n:
		if acc[i + 1] >= cursor:
			return i
	return maxi(n - 1, 0)


static func _signed_area(lip: PackedVector3Array) -> float:
	var a := 0.0
	for i in lip.size():
		var p := lip[i]
		var q := lip[(i + 1) % lip.size()]
		a += p.x * q.z - q.x * p.z
	return a * 0.5


static func _grad(field: Heightfield, xz: Vector2) -> Vector3:
	var e := field.spacing * 0.5
	var hL := _finite_height(field, Vector2(xz.x - e, xz.y))
	var hR := _finite_height(field, Vector2(xz.x + e, xz.y))
	var hD := _finite_height(field, Vector2(xz.x, xz.y - e))
	var hU := _finite_height(field, Vector2(xz.x, xz.y + e))
	var g := Vector3(hL - hR, e * 2.0, hD - hU)
	if not g.is_finite() or g.length_squared() < 1e-8:
		return Vector3.UP
	return g.normalized()


static func _crack_out(a: Vector3, b: Vector3, block_mid: Vector3) -> Vector3:
	var mid := (a + b) * 0.5
	var away := mid - block_mid
	away.y = 0.0
	if away.length_squared() < 1e-8:
		away = Vector3(-(b.z - a.z), 0.0, b.x - a.x)
	if away.length_squared() < 1e-8:
		return Vector3(1.0, 0.0, 0.0)
	return away.normalized()


static func _boundary_segs(segs: Array) -> Array:
	# A grid edge emitted by two cells is an interior seam, not the coastline.
	var counts := {}
	for seg in segs:
		var s: Vector2i = seg
		var key := Vector2i(mini(s.x, s.y), maxi(s.x, s.y))
		counts[key] = int(counts.get(key, 0)) + 1
	var out: Array = []
	var seen := {}
	for seg in segs:
		var s: Vector2i = seg
		var key := Vector2i(mini(s.x, s.y), maxi(s.x, s.y))
		if int(counts.get(key, 0)) != 1 or seen.has(key):
			continue
		seen[key] = true
		out.append(s)
	return out


static func _is_hole(field: Heightfield, lip: PackedVector3Array) -> bool:
	var land_left := 0
	var tests := 0
	var step := maxi(int(lip.size() / 10), 1)
	for i in range(0, lip.size(), step):
		var a := lip[i]
		var b := lip[(i + 1) % lip.size()]
		var t := Vector2(b.x - a.x, b.z - a.z)
		if t.length_squared() < 1e-8:
			continue
		t = t.normalized()
		var left := Vector2(-t.y, t.x)
		var probe := Vector2(a.x, a.z) + left * 0.28
		tests += 1
		if field.sample_land(Vector3(probe.x, 0.0, probe.y)):
			land_left += 1
	return tests > 0 and land_left * 2 < tests


static func _orient_land_left(field: Heightfield, lip: PackedVector3Array) -> PackedVector3Array:
	if not _is_hole(field, lip):
		return lip
	# _is_hole means land is NOT on the left. Reverse so land is on the left
	# and right-of-travel points out of the land (into the hole, or fixed below).
	var rev := PackedVector3Array()
	for i in range(lip.size() - 1, -1, -1):
		rev.append(lip[i])
	# After one reverse, retest. Outer loops that were already correct stay.
	if _is_hole(field, rev):
		return lip
	return rev


static func _ring_centroid(ring: Array) -> Vector3:
	var s := Vector3.ZERO
	if ring.is_empty():
		return s
	for p in ring:
		s += p
	return s / float(ring.size())


static func _point_in_ring(p: Vector2, ring: Array) -> bool:
	var inside := false
	var j := ring.size() - 1
	for i in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[j]
		var ay := a.z
		var by := b.z
		if ((ay > p.y) != (by > p.y)) and p.x < (b.x - a.x) * (p.y - ay) / maxf(by - ay, 1e-6) + a.x:
			inside = not inside
		j = i
	return inside


static func _shoelace2(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func _trace(segs: Array) -> Array:
	var adj := {}
	for seg in segs:
		var s: Vector2i = seg
		if not adj.has(s.x):
			adj[s.x] = []
		if not adj.has(s.y):
			adj[s.y] = []
		(adj[s.x] as Array).append(s.y)
		(adj[s.y] as Array).append(s.x)
	var unused := {}
	for seg in segs:
		var s: Vector2i = seg
		unused[Vector2i(mini(s.x, s.y), maxi(s.x, s.y))] = true
	var loops: Array = []
	for seg in segs:
		var s: Vector2i = seg
		var key := Vector2i(mini(s.x, s.y), maxi(s.x, s.y))
		if not unused.has(key):
			continue
		var loop: Array = []
		var prev := -1
		var cur := s.x
		var guard := 0
		while guard < 100000:
			guard += 1
			loop.append(cur)
			var nxt := -1
			for opt in adj[cur]:
				var o := int(opt)
				if o == prev:
					continue
				var ek := Vector2i(mini(cur, o), maxi(cur, o))
				if unused.has(ek):
					nxt = o
					unused.erase(ek)
					break
			if nxt < 0:
				break
			prev = cur
			cur = nxt
			if cur == s.x:
				break
		if loop.size() >= 3:
			loops.append(loop)
	return loops


static func _smooth_loop(ids: Array, pos: Dictionary, limit: float) -> void:
	var n := ids.size()
	if n < 4:
		return
	var orig := PackedVector2Array()
	orig.resize(n)
	for i in n:
		orig[i] = pos[ids[i]]
	var cur := orig.duplicate()
	for _iter in 5:
		var nxt := PackedVector2Array()
		nxt.resize(n)
		for i in n:
			var p: Vector2 = cur[i]
			var a: Vector2 = cur[(i + n - 1) % n]
			var b: Vector2 = cur[(i + 1) % n]
			nxt[i] = p * 0.42 + a * 0.29 + b * 0.29
		cur = nxt
	for i in n:
		var d: Vector2 = cur[i] - orig[i]
		if d.length() > limit:
			d = d.normalized() * limit
		# Keep a hair of separation so a collapsed stair does not drop an edge.
		var prev: Vector2 = pos[ids[(i + n - 1) % n]] if i > 0 else orig[i]
		var moved: Vector2 = orig[i] + d
		if i > 0 and moved.distance_to(prev) < 0.012:
			var away := moved - prev
			if away.length_squared() < 1e-8:
				away = Vector2(0.012, 0.0)
			moved = prev + away.normalized() * 0.012
		pos[ids[i]] = moved


static func _corners(raw: PackedFloat32Array, gw: int, i: int, j: int) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	v.resize(4)
	v[0] = raw[_sidx(i, j, gw)]
	v[1] = raw[_sidx(i + 1, j, gw)]
	v[2] = raw[_sidx(i + 1, j + 1, gw)]
	v[3] = raw[_sidx(i, j + 1, gw)]
	return v


static func _mask_of(vals: PackedFloat32Array) -> int:
	var mask := 0
	if vals[0] >= ISO:
		mask |= 1
	if vals[1] >= ISO:
		mask |= 2
	if vals[2] >= ISO:
		mask |= 4
	if vals[3] >= ISO:
		mask |= 8
	return mask


static func _edge_xz(field: Heightfield, i: int, j: int, edge: int, fine: float, vals: PackedFloat32Array) -> Vector2:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var va := 0.0
	var vb := 0.0
	var origin := field.origin
	if edge == 4:
		a = Vector2(origin.x + float(i) * fine, origin.y + float(j) * fine)
		b = Vector2(origin.x + float(i + 1) * fine, origin.y + float(j) * fine)
		va = vals[0]
		vb = vals[1]
	elif edge == 5:
		a = Vector2(origin.x + float(i + 1) * fine, origin.y + float(j) * fine)
		b = Vector2(origin.x + float(i + 1) * fine, origin.y + float(j + 1) * fine)
		va = vals[1]
		vb = vals[2]
	elif edge == 6:
		a = Vector2(origin.x + float(i + 1) * fine, origin.y + float(j + 1) * fine)
		b = Vector2(origin.x + float(i) * fine, origin.y + float(j + 1) * fine)
		va = vals[2]
		vb = vals[3]
	else:
		a = Vector2(origin.x + float(i) * fine, origin.y + float(j + 1) * fine)
		b = Vector2(origin.x + float(i) * fine, origin.y + float(j) * fine)
		va = vals[3]
		vb = vals[0]
	var d := vb - va
	var t := 0.5 if absf(d) < 1e-6 else clampf((ISO - va) / d, 0.0, 1.0)
	return a.lerp(b, t)


static func _edge_id(i: int, j: int, edge: int, nx: int) -> int:
	# Canonical grid-edge id. North edge of cell (i,j) is the south edge of (i,j+1).
	var row := nx + 4
	if edge == 4:
		return ((j + 2) * row + (i + 2)) * 2
	if edge == 5:
		return ((j + 2) * row + (i + 3)) * 2 + 1
	if edge == 6:
		return ((j + 3) * row + (i + 2)) * 2
	return ((j + 2) * row + (i + 2)) * 2 + 1


static func _raw_occ(field: Heightfield, i: int, j: int, subdiv: int, nx: int, nz: int) -> float:
	if i < 0 or j < 0 or i >= nx or j >= nz:
		return 0.0
	var gx := int(float(i) / float(subdiv))
	var gz := int(float(j) / float(subdiv))
	return 1.0 if field.is_land(gx, gz) else 0.0


static func _sidx(i: int, j: int, gw: int) -> int:
	return (j + 1) * gw + (i + 1)


static func _chunk_key(chunk: Vector2i) -> int:
	return chunk.x * 1024 + chunk.y


static func _chid(field: Heightfield, p: Vector3) -> int:
	var c := field.world_to_cell(p)
	var cx := clampi(c.x, 0, maxi(field.cells_x() - 1, 0))
	var cz := clampi(c.y, 0, maxi(field.cells_z() - 1, 0))
	var hx := int(float(cx) / float(Heightfield.CHUNK))
	var hz := int(float(cz) / float(Heightfield.CHUNK))
	return _chunk_key(Vector2i(hx, hz))


static func _mask_key(field: Heightfield) -> int:
	var h := field.seed * 3 ^ field.verts_x * 734287 ^ field.verts_z * 912931 ^ int(field.origin.x * 10.0) * 17 ^ int(field.origin.y * 10.0)
	for i in field.mask.size():
		if field.mask[i] != 0:
			h = int((h * 16777619) ^ (i + 0x9e3779b9))
	return h


static func _height_key(field: Heightfield) -> int:
	var h := 216613626
	for i in field.heights.size():
		h = int((h ^ int(field.heights[i] * 200.0)) * 16777619)
	return h


static func _skip_key(skip_top: Dictionary) -> int:
	var h := 17
	for k in skip_top.keys():
		var c: Vector2i = k
		h = (h * 131) ^ (c.x * 734287) ^ (c.y * 912931)
	return h


static func _take(pack: Dictionary, id: int, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array) -> void:
	if not pack.has(id):
		return
	var slot: Array = pack[id]
	verts.append_array(slot[0])
	norms.append_array(slot[1])
	cols.append_array(slot[2])
	uvs.append_array(slot[3])


class Buf extends RefCounted:
	var v: Array = []
	var nrm: Array = []
	var col: Array = []
	var uv: Array = []
	var id: Array = []

	func flat(a: Vector3, b: Vector3, c: Vector3, color: Color, outside: Vector3, chunk: int, _wall: bool) -> void:
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			return
		var cr := (b - a).cross(c - a)
		if not cr.is_finite() or cr.length_squared() < 1e-12:
			return
		if not outside.is_finite() or outside.length_squared() < 1e-8:
			outside = Vector3.UP
		if cr.dot(outside) > 0.0:
			var tb := b
			b = c
			c = tb
			cr = -cr
		var lit := -cr.normalized()
		if not lit.is_finite():
			lit = outside.normalized()
		if lit.dot(outside) < 0.0:
			lit = -lit
		if lit.length_squared() < 0.25:
			lit = outside.normalized()
		var opaque := Color(color.r, color.g, color.b, 1.0)
		v.append(a)
		v.append(b)
		v.append(c)
		nrm.append(lit)
		nrm.append(lit)
		nrm.append(lit)
		col.append(opaque)
		col.append(opaque)
		col.append(opaque)
		uv.append(Vector2(a.x, a.z) * 0.12)
		uv.append(Vector2(b.x, b.z) * 0.12)
		uv.append(Vector2(c.x, c.z) * 0.12)
		id.append(chunk)

	func smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color, outside: Vector3, chunk: int) -> void:
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			return
		if not na.is_finite() or na.length_squared() < 1e-8:
			na = Vector3.UP
		if not nb.is_finite() or nb.length_squared() < 1e-8:
			nb = Vector3.UP
		if not nc.is_finite() or nc.length_squared() < 1e-8:
			nc = Vector3.UP
		var cr := (b - a).cross(c - a)
		if not cr.is_finite() or cr.length_squared() < 1e-12:
			return
		if not outside.is_finite() or outside.length_squared() < 1e-8:
			outside = Vector3.UP
		if cr.dot(outside) > 0.0:
			var tb := b
			b = c
			c = tb
			var tn := nb
			nb = nc
			nc = tn
		if na.dot(outside) < 0.0:
			na = -na
		if nb.dot(outside) < 0.0:
			nb = -nb
		if nc.dot(outside) < 0.0:
			nc = -nc
		var opaque := Color(color.r, color.g, color.b, 1.0)
		v.append(a)
		v.append(b)
		v.append(c)
		nrm.append(na)
		nrm.append(nb)
		nrm.append(nc)
		col.append(opaque)
		col.append(opaque)
		col.append(opaque)
		uv.append(Vector2(a.x, a.z) * 0.12)
		uv.append(Vector2(b.x, b.z) * 0.12)
		uv.append(Vector2(c.x, c.z) * 0.12)
		id.append(chunk)

	func drain_into(other: Buf) -> void:
		for i in v.size():
			other.v.append(v[i])
			other.nrm.append(nrm[i])
			other.col.append(col[i])
			other.uv.append(uv[i])
		for t in id:
			other.id.append(t)

	func pack() -> Dictionary:
		var lists := {}
		for t in id.size():
			var ch = id[t]
			if not lists.has(ch):
				lists[ch] = []
			(lists[ch] as Array).append(t)
		var out := {}
		for ch in lists:
			var ts: Array = lists[ch]
			var nv := ts.size() * 3
			var pv := PackedVector3Array()
			var pn := PackedVector3Array()
			var pc := PackedColorArray()
			var pu := PackedVector2Array()
			pv.resize(nv)
			pn.resize(nv)
			pc.resize(nv)
			pu.resize(nv)
			var at := 0
			for t in ts:
				var base := int(t) * 3
				for k in 3:
					pv[at] = v[base + k]
					pn[at] = nrm[base + k]
					pc[at] = col[base + k]
					pu[at] = uv[base + k]
					at += 1
			out[ch] = [pv, pn, pc, pu]
		return out
