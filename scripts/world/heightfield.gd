extends RefCounted
## Per-island height grid + land mask. No scene nodes, no booleans.
## Vertices store H; cells store M. Volume is the prism under each land cell.

const SPACING := 0.5
const CHUNK := 16
const DEFAULT_BOTTOM := -4.0
const MIN_THICKNESS := 0.6
const TERRACE := 0.25
const DEFAULT_SURFACE := 0.0
const JITTER_SCALE := 0.28
const WATER_GAP := 0.02
const HARDNESS := 0.42

var origin := Vector2.ZERO
var verts_x := 0
var verts_z := 0
var spacing := SPACING
var y_bottom := DEFAULT_BOTTOM
var min_thickness := MIN_THICKNESS
var terrace_step := TERRACE
var seed: int = 1
var heights := PackedFloat32Array()
var mask := PackedByteArray()
var rim_shift: Dictionary = {}
var visual_loops: Array = []
var _centroid_cache := Vector2.INF


func cells_x() -> int:
	return maxi(verts_x - 1, 0)


func cells_z() -> int:
	return maxi(verts_z - 1, 0)


func cell_area() -> float:
	return spacing * spacing


func configure(p_origin: Vector2, p_cells_x: int, p_cells_z: int, p_spacing: float = SPACING, p_bottom: float = DEFAULT_BOTTOM, p_seed: int = 1) -> void:
	origin = p_origin
	spacing = p_spacing
	y_bottom = p_bottom
	seed = p_seed
	verts_x = maxi(p_cells_x + 1, 2)
	verts_z = maxi(p_cells_z + 1, 2)
	var vcount := verts_x * verts_z
	heights.resize(vcount)
	heights.fill(DEFAULT_SURFACE)
	mask.resize(cells_x() * cells_z())
	mask.fill(0)


static func from_play_cells(cells: Dictionary, p_spacing: float = SPACING, p_bottom: float = DEFAULT_BOTTOM, p_seed: int = 1, pad: int = 2) -> RefCounted:
	var field := new()
	if cells.is_empty():
		field.configure(Vector2.ZERO, 2, 2, p_spacing, p_bottom, p_seed)
		return field
	var min_c := Vector2i(99999, 99999)
	var max_c := Vector2i(-99999, -99999)
	for cell: Vector2i in cells:
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	var play_w := max_c.x - min_c.x + 1 + pad * 2
	var play_h := max_c.y - min_c.y + 1 + pad * 2
	var step := 1.0 / p_spacing
	var cx := int(round(float(play_w) * step))
	var cz := int(round(float(play_h) * step))
	var org := Vector2(float(min_c.x - pad), float(min_c.y - pad))
	field.configure(org, cx, cz, p_spacing, p_bottom, p_seed)
	field.apply_play_cells(cells, true)
	return field


func duplicate_field() -> RefCounted:
	var copy := new()
	copy.origin = origin
	copy.verts_x = verts_x
	copy.verts_z = verts_z
	copy.spacing = spacing
	copy.y_bottom = y_bottom
	copy.min_thickness = min_thickness
	copy.terrace_step = terrace_step
	copy.seed = seed
	copy.heights = heights.duplicate()
	copy.mask = mask.duplicate()
	copy.rim_shift = rim_shift.duplicate()
	copy.visual_loops = visual_loops.duplicate(true)
	copy._centroid_cache = _centroid_cache
	return copy


func vertex_index(ix: int, iz: int) -> int:
	return iz * verts_x + ix


func cell_index(cx: int, cz: int) -> int:
	return cz * cells_x() + cx


func in_vertex(ix: int, iz: int) -> bool:
	return ix >= 0 and iz >= 0 and ix < verts_x and iz < verts_z


func in_cell(cx: int, cz: int) -> bool:
	return cx >= 0 and cz >= 0 and cx < cells_x() and cz < cells_z()


func height_at(ix: int, iz: int) -> float:
	return heights[vertex_index(ix, iz)]


func set_height(ix: int, iz: int, value: float) -> void:
	heights[vertex_index(ix, iz)] = value


func is_land(cx: int, cz: int) -> bool:
	return in_cell(cx, cz) and mask[cell_index(cx, cz)] != 0


func set_land(cx: int, cz: int, land: bool) -> void:
	if in_cell(cx, cz):
		mask[cell_index(cx, cz)] = 1 if land else 0
		_centroid_cache = Vector2.INF


func vertex_world(ix: int, iz: int) -> Vector2:
	return Vector2(origin.x + float(ix) * spacing, origin.y + float(iz) * spacing)


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x - origin.x) / spacing), floori((world.z - origin.y) / spacing))


func world_to_vertex(world: Vector3) -> Vector2:
	return Vector2((world.x - origin.x) / spacing, (world.z - origin.y) / spacing)


func play_cell_of_hf(cx: int, cz: int) -> Vector2i:
	var w := vertex_world(cx, cz)
	return Vector2i(floori(w.x), floori(w.y))


func min_surface() -> float:
	return y_bottom + min_thickness


func clamp_vertex(ix: int, iz: int) -> void:
	if not _vertex_has_land(ix, iz):
		return
	var floor_h := min_surface()
	if heights[vertex_index(ix, iz)] < floor_h:
		heights[vertex_index(ix, iz)] = floor_h


func _vertex_has_land(ix: int, iz: int) -> bool:
	for cz in range(iz - 1, iz + 1):
		for cx in range(ix - 1, ix + 1):
			if is_land(cx, cz):
				return true
	return false


func apply_play_cells(cells: Dictionary, reset_new: bool = false) -> void:
	if cells.is_empty():
		mask.fill(0)
		return
	var min_c := Vector2i(99999, 99999)
	var max_c := Vector2i(-99999, -99999)
	for cell: Vector2i in cells:
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	ensure_world_bounds(float(min_c.x), float(min_c.y), float(max_c.x + 1), float(max_c.y + 1), 1.0)
	var old := mask.duplicate()
	mask.fill(0)
	var step := int(round(1.0 / spacing))
	for cell: Vector2i in cells:
		var ix0 := int(round((float(cell.x) - origin.x) / spacing))
		var iz0 := int(round((float(cell.y) - origin.y) / spacing))
		for z in step:
			for x in step:
				var cx := ix0 + x
				var cz := iz0 + z
				if not in_cell(cx, cz):
					continue
				var was := old[cell_index(cx, cz)] if cx < cells_x() and cz < cells_z() and cell_index(cx, cz) < old.size() else 0
				set_land(cx, cz, true)
				if reset_new and was == 0:
					_raise_cell_to_surface(cx, cz)
	_clamp_all_land()
	rim_shift.clear()


func _raise_cell_to_surface(cx: int, cz: int) -> void:
	var floor_h := min_surface()
	var target := maxf(DEFAULT_SURFACE, floor_h)
	for iz in range(cz, cz + 2):
		for ix in range(cx, cx + 2):
			if in_vertex(ix, iz):
				set_height(ix, iz, target)


func _clamp_all_land() -> void:
	for iz in verts_z:
		for ix in verts_x:
			clamp_vertex(ix, iz)


func ensure_world_bounds(min_x: float, min_z: float, max_x: float, max_z: float, margin: float = 0.0) -> void:
	var need_min := Vector2(min_x - margin, min_z - margin)
	var need_max := Vector2(max_x + margin, max_z + margin)
	var cur_min := origin
	var cur_max := vertex_world(verts_x - 1, verts_z - 1)
	if need_min.x >= cur_min.x - 1e-6 and need_min.y >= cur_min.y - 1e-6 and need_max.x <= cur_max.x + 1e-6 and need_max.y <= cur_max.y + 1e-6:
		return
	var new_origin := Vector2(minf(cur_min.x, need_min.x), minf(cur_min.y, need_min.y))
	new_origin = Vector2(floor(new_origin.x / spacing) * spacing, floor(new_origin.y / spacing) * spacing)
	var new_max := Vector2(maxf(cur_max.x, need_max.x), maxf(cur_max.y, need_max.y))
	var new_vx := int(round((new_max.x - new_origin.x) / spacing)) + 1
	var new_vz := int(round((new_max.y - new_origin.y) / spacing)) + 1
	new_vx = maxi(new_vx, 2)
	new_vz = maxi(new_vz, 2)
	var dx := int(round((origin.x - new_origin.x) / spacing))
	var dz := int(round((origin.y - new_origin.y) / spacing))
	var new_h := PackedFloat32Array()
	new_h.resize(new_vx * new_vz)
	new_h.fill(DEFAULT_SURFACE)
	var new_m := PackedByteArray()
	new_m.resize((new_vx - 1) * (new_vz - 1))
	new_m.fill(0)
	for iz in verts_z:
		for ix in verts_x:
			var nix := ix + dx
			var niz := iz + dz
			if nix >= 0 and niz >= 0 and nix < new_vx and niz < new_vz:
				new_h[niz * new_vx + nix] = heights[vertex_index(ix, iz)]
	for cz in cells_z():
		for cx in cells_x():
			var ncx := cx + dx
			var ncz := cz + dz
			if ncx >= 0 and ncz >= 0 and ncx < new_vx - 1 and ncz < new_vz - 1:
				new_m[ncz * (new_vx - 1) + ncx] = mask[cell_index(cx, cz)]
	origin = new_origin
	verts_x = new_vx
	verts_z = new_vz
	heights = new_h
	mask = new_m
	rim_shift.clear()


func land_cell_count() -> int:
	var n := 0
	for i in mask.size():
		if mask[i] != 0:
			n += 1
	return n


func cell_mean_height(cx: int, cz: int) -> float:
	return 0.25 * (
		height_at(cx, cz) + height_at(cx + 1, cz) + height_at(cx, cz + 1) + height_at(cx + 1, cz + 1)
	)


func cell_column_volume(cx: int, cz: int) -> float:
	if not is_land(cx, cz):
		return 0.0
	return (cell_mean_height(cx, cz) - y_bottom) * cell_area()


func total_volume() -> float:
	var sum := 0.0
	for cz in cells_z():
		for cx in cells_x():
			sum += cell_column_volume(cx, cz)
	return sum


func volume_in_rect(rect: Rect2i) -> float:
	var sum := 0.0
	var x0 := clampi(rect.position.x, 0, cells_x())
	var z0 := clampi(rect.position.y, 0, cells_z())
	var x1 := clampi(rect.position.x + rect.size.x, 0, cells_x())
	var z1 := clampi(rect.position.y + rect.size.y, 0, cells_z())
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			sum += cell_column_volume(cx, cz)
	return sum


func sample_height(world: Vector3) -> float:
	var g := world_to_vertex(world)
	var ix := clampi(floori(g.x), 0, verts_x - 2)
	var iz := clampi(floori(g.y), 0, verts_z - 2)
	if not is_land(ix, iz) and not _vertex_has_land(ix, iz):
		return NAN
	var tx := clampf(g.x - float(ix), 0.0, 1.0)
	var tz := clampf(g.y - float(iz), 0.0, 1.0)
	var h00 := height_at(ix, iz)
	var h10 := height_at(ix + 1, iz)
	var h01 := height_at(ix, iz + 1)
	var h11 := height_at(ix + 1, iz + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func sample_land(world: Vector3) -> bool:
	var c := world_to_cell(world)
	return is_land(c.x, c.y)


func sample_inland(world: Vector3) -> float:
	var c := world_to_cell(world)
	var n := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if is_land(c.x + dx, c.y + dz):
				n += 1
	return float(n) / 9.0


func land_centroid() -> Vector2:
	if _centroid_cache != Vector2.INF:
		return _centroid_cache
	var sum := Vector2.ZERO
	var n := 0
	for cz in cells_z():
		for cx in cells_x():
			if not is_land(cx, cz):
				continue
			sum += vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
			n += 1
	_centroid_cache = sum / float(maxi(n, 1)) if n > 0 else origin
	return _centroid_cache


func organicize_coast() -> void:
	if cells_x() < 3 or cells_z() < 3:
		return
	var loops: Array = _mask_loops()
	if loops.is_empty():
		return
	var smoothed: Array = []
	for loop in loops:
		smoothed.append(_noise_loop(_catmull(_chaikin2(loop))))
	var keep := mask.duplicate()
	mask.fill(0)
	for cz in cells_z():
		for cx in cells_x():
			var idx := cell_index(cx, cz)
			if idx >= keep.size() or keep[idx] == 0:
				continue
			var mid := vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
			# Never grow past the play footprint; only round existing land away.
			if _inside_loops(mid, smoothed) or _interior_keep(keep, cx, cz):
				set_land(cx, cz, true)
	_clamp_all_land()
	apply_coast_smooth()


func stamp_rounded_blob() -> void:
	## Carve the current rectangle down to an ellipse + low-frequency wobble.
	## Only removes cells, so visible land stays inside the play footprint.
	if land_cell_count() < 6:
		return
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for cz in cells_z():
		for cx in cells_x():
			if not is_land(cx, cz):
				continue
			var mid := vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
			min_p.x = minf(min_p.x, mid.x)
			min_p.y = minf(min_p.y, mid.y)
			max_p.x = maxf(max_p.x, mid.x)
			max_p.y = maxf(max_p.y, mid.y)
	var center := (min_p + max_p) * 0.5
	var rx := maxf((max_p.x - min_p.x) * 0.5, spacing)
	var rz := maxf((max_p.y - min_p.y) * 0.5, spacing)
	if minf(rx, rz) < 1.75:
		return
	for cz in cells_z():
		for cx in cells_x():
			if not is_land(cx, cz):
				continue
			var mid := vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
			var nx := (mid.x - center.x) / rx
			var nz := (mid.y - center.y) / rz
			var nse := _hash2(mid.x * 0.27 + float(seed), mid.y * 0.31)
			var d := pow(absf(nx), 2.15) + pow(absf(nz), 2.15)
			if d > 0.56 + (nse.x - 0.5) * 0.34:
				set_land(cx, cz, false)
	_clamp_all_land()
	rim_shift.clear()


func apply_coast_smooth() -> void:
	## Pull rim vertices onto a Chaikin / Catmull loop so walls are not stairs.
	rim_shift.clear()
	visual_loops.clear()
	var loops: Array = _mask_loops()
	if loops.is_empty():
		return
	var smoothed: Array = []
	for loop in loops:
		smoothed.append(_low_freq_loop(_catmull(_chaikin2(loop))))
	visual_loops = smoothed
	for iz in verts_z:
		for ix in verts_x:
			if not _vertex_is_rim(ix, iz):
				continue
			var p := vertex_world(ix, iz)
			var best := p
			var best_d := 1.0e9
			for loop in smoothed:
				var q := _closest_on_loop(p, loop)
				var d := p.distance_to(q)
				if d < best_d:
					best_d = d
					best = q
			if best_d < spacing * 3.6:
				rim_shift[Vector2i(ix, iz)] = best - p


func coast_shift(ix: int, iz: int) -> Vector2:
	return rim_shift.get(Vector2i(ix, iz), Vector2.ZERO)


func _vertex_is_rim(ix: int, iz: int) -> bool:
	var land_n := 0
	for cz in range(iz - 1, iz + 1):
		for cx in range(ix - 1, ix + 1):
			if is_land(cx, cz):
				land_n += 1
	return land_n > 0 and land_n < 4


func _closest_on_loop(p: Vector2, loop: Array) -> Vector2:
	var best := p
	var best_d := 1.0e9
	if loop.size() < 2:
		return p
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var ab := b - a
		var t := 0.0 if ab.length_squared() < 1e-8 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a.lerp(b, t)
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


func _catmull(loop: Array) -> Array:
	if loop.size() < 4:
		return loop
	var out: Array = []
	var n := loop.size()
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


func stamp_gentle_hills() -> void:
	for iz in verts_z:
		for ix in verts_x:
			if not _vertex_has_land(ix, iz):
				continue
			var p := vertex_world(ix, iz)
			var nse := _hash2(p.x * 0.21 + float(seed), p.y * 0.19)
			var hill := sin(p.x * 0.46 + float(seed) * 0.07) * cos(p.y * 0.39 - float(seed) * 0.05)
			var add := hill * 0.42 + (nse.x - 0.5) * 0.28
			set_height(ix, iz, height_at(ix, iz) + add)
	_clamp_all_land()


func _interior_keep(keep: PackedByteArray, cx: int, cz: int) -> bool:
	if cx <= 0 or cz <= 0 or cx >= cells_x() - 1 or cz >= cells_z() - 1:
		return false
	var idx := cell_index(cx, cz)
	if idx >= keep.size() or keep[idx] == 0:
		return false
	# Keep only cells that were land and not an outer-ring corner.
	var land_n := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nidx := cell_index(cx + dx, cz + dz)
			if nidx >= 0 and nidx < keep.size() and keep[nidx] != 0:
				land_n += 1
	return land_n >= 8


func _mask_loops() -> Array:
	var outgoing: Dictionary = {}
	for cz in cells_z():
		for cx in cells_x():
			if not is_land(cx, cz):
				continue
			_mask_edge(outgoing, cx, cz, 0, -1)
			_mask_edge(outgoing, cx, cz, 1, 0)
			_mask_edge(outgoing, cx, cz, 0, 1)
			_mask_edge(outgoing, cx, cz, -1, 0)
	var loops: Array = []
	for start_key in outgoing.keys():
		while (outgoing[start_key] as Array).size() > 0:
			var parts := String(start_key).split(",")
			var curr := Vector2(float(parts[0]), float(parts[1]))
			var loop: Array[Vector2] = []
			var guard := 0
			while guard < 20000:
				guard += 1
				var ix := int(round(curr.x))
				var iz := int(round(curr.y))
				loop.append(vertex_world(clampi(ix, 0, verts_x - 1), clampi(iz, 0, verts_z - 1)))
				var ck := "%d,%d" % [ix, iz]
				if not outgoing.has(ck) or (outgoing[ck] as Array).is_empty():
					break
				var nxt: Vector2 = (outgoing[ck] as Array).pop_back()
				curr = nxt
				if loop.size() > 2 and ix == int(parts[0]) and iz == int(parts[1]):
					break
			if loop.size() >= 4:
				loops.append(loop)
	return loops


func _mask_edge(outgoing: Dictionary, cx: int, cz: int, dx: int, dz: int) -> void:
	if is_land(cx + dx, cz + dz):
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


func _chaikin2(loop: Array) -> Array:
	var pts: Array = loop
	for _i in 2:
		var next: Array = []
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		pts = next
	return pts


func _noise_loop(loop: Array) -> Array:
	if loop.is_empty():
		return loop
	var c := Vector2.ZERO
	for p in loop:
		c += p
	c /= float(loop.size())
	var out: Array = []
	for p in loop:
		var q: Vector2 = p
		var radial := q - c
		var nse := _hash2(q.x * 0.33 + float(seed), q.y * 0.29)
		if radial.length_squared() > 1e-6:
			q += radial.normalized() * (nse.x - 0.5) * 0.55
		out.append(q)
	return out


func _low_freq_loop(loop: Array) -> Array:
	## Visual coast only. Sparse sine along the ring — no per-vertex hash jitter.
	if loop.size() < 4:
		return loop
	var c := Vector2.ZERO
	for p in loop:
		c += p
	c /= float(loop.size())
	var out: Array = []
	var n := loop.size()
	for i in n:
		var q: Vector2 = loop[i]
		var radial := q - c
		if radial.length_squared() < 1e-6:
			out.append(q)
			continue
		var t := float(i) / float(n)
		var wobble := sin(t * TAU * 2.0 + float(seed) * 0.17) * 0.11
		wobble += sin(t * TAU * 3.0 - float(seed) * 0.09) * 0.06
		out.append(q + radial.normalized() * wobble)
	return out


func visual_relief(world: Vector3) -> float:
	## Render-only continuous noise. Never write this into heights.
	var n1 := _value_noise(world.x * 0.28 + float(seed) * 0.03, world.z * 0.26)
	var n2 := _value_noise(world.x * 0.82 - float(seed) * 0.02, world.z * 0.78)
	return (n1 - 0.5) * 0.055 + (n2 - 0.5) * 0.016


func _value_noise(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _hash2(ix, iz).x
	var b := _hash2(ix + 1.0, iz).x
	var c := _hash2(ix, iz + 1.0).x
	var d := _hash2(ix + 1.0, iz + 1.0).x
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func visual_bank_dip(ix: int, iz: int) -> float:
	## Render-only slope into pits. Does not change H or lakes.
	var h := height_at(clampi(ix, 0, verts_x - 1), clampi(iz, 0, verts_z - 1))
	var dip := 0.0
	for pair in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		var nx := ix + int(pair[0])
		var nz := iz + int(pair[1])
		if not in_vertex(nx, nz):
			continue
		var nh := height_at(nx, nz)
		if h - nh > 0.14:
			dip = maxf(dip, (h - nh) * 0.32)
	return dip


func _inside_loops(p: Vector2, loops: Array) -> bool:
	var inside := false
	for loop in loops:
		if _point_in_poly(p, loop):
			inside = not inside
	return inside


func _point_in_poly(p: Vector2, loop: Array) -> bool:
	var inside := false
	var j := loop.size() - 1
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[j]
		var cond := ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / maxf(b.y - a.y, 1e-6) + a.x)
		if cond:
			inside = not inside
		j = i
	return inside


func snap_height(value: float) -> float:
	if terrace_step <= 1e-6:
		return value
	return roundf(value / terrace_step) * terrace_step


func brush_weight(distance: float, radius: float, hardness: float = HARDNESS) -> float:
	if radius <= 1e-6 or distance >= radius:
		return 0.0
	var inner := radius * clampf(1.0 - hardness, 0.0, 1.0)
	if distance <= inner:
		return 1.0
	var t := clampf((distance - inner) / maxf(radius - inner, 1e-6), 0.0, 1.0)
	# smoothstep(1, 0, t)
	t = t * t * (3.0 - 2.0 * t)
	return 1.0 - t


func apply_brush(op: String, center: Vector3, radius: float, strength: float, free: bool = false, h_ref: float = NAN, scale: float = 1.0, blocked: Dictionary = {}) -> Dictionary:
	var before := total_volume()
	var before_cells := _snapshot_rect(_influence_rect(center, radius))
	var r := maxf(radius, spacing)
	var s := strength * scale
	var floor_h := min_surface()
	var target := h_ref
	if op == "flatten":
		if not is_finite(target):
			target = sample_height(center)
			if not is_finite(target):
				target = DEFAULT_SURFACE
		if not free:
			target = snap_height(target)
	var g0 := world_to_vertex(center)
	var ix0 := floori(g0.x - r / spacing - 1.0)
	var iz0 := floori(g0.y - r / spacing - 1.0)
	var ix1 := ceili(g0.x + r / spacing + 1.0)
	var iz1 := ceili(g0.y + r / spacing + 1.0)
	if op in ["add_land", "remove_land"]:
		ensure_world_bounds(center.x - r, center.z - r, center.x + r, center.z + r, spacing)
		g0 = world_to_vertex(center)
		ix0 = floori(g0.x - r / spacing - 1.0)
		iz0 = floori(g0.y - r / spacing - 1.0)
		ix1 = ceili(g0.x + r / spacing + 1.0)
		iz1 = ceili(g0.y + r / spacing + 1.0)
	var avg := PackedFloat32Array()
	if op == "smooth":
		avg = _box_average()
	var touched := {}
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			if not in_vertex(ix, iz):
				continue
			var wpos := vertex_world(ix, iz)
			if _vertex_blocked(ix, iz, blocked):
				continue
			var d := Vector2(wpos.x - center.x, wpos.y - center.z).length()
			var w := brush_weight(d, r) * s
			if w <= 1e-5:
				continue
			var i := vertex_index(ix, iz)
			var h := heights[i]
			match op:
				"raise":
					h += w
				"lower", "dig":
					h -= w
				"flatten":
					h = lerpf(h, target, clampf(w, 0.0, 1.0))
				"smooth":
					h = lerpf(h, avg[i], clampf(w, 0.0, 1.0))
				"add_land", "remove_land":
					pass
				_:
					h += w
			if not free and op in ["raise", "lower", "dig", "smooth"]:
				h = snap_height(h)
			heights[i] = h
			touched[Vector2i(ix, iz)] = true
	if op == "add_land":
		_brush_mask(center, r, s, true, blocked)
	elif op == "remove_land":
		_brush_mask(center, r, s, false, blocked)
	if op in ["lower", "dig"]:
		_dig_through(ix0 - 1, iz0 - 1, ix1 + 1, iz1 + 1, blocked)
	_clamp_touched(touched)
	var after := total_volume()
	var delta := after - before
	return {
		"delta_volume": delta,
		"before_volume": before,
		"after_volume": after,
		"rect": _influence_rect(center, radius),
		"snapshot": before_cells,
		"ok": true,
	}


func preview_brush(op: String, center: Vector3, radius: float, strength: float, free: bool = false, h_ref: float = NAN, blocked: Dictionary = {}) -> Dictionary:
	var scratch: RefCounted = duplicate_field()
	return scratch.apply_brush(op, center, radius, strength, free, h_ref, 1.0, blocked)


func scale_brush_to_budget(op: String, center: Vector3, radius: float, strength: float, free: bool, h_ref: float, positive_budget: float, blocked: Dictionary = {}) -> Dictionary:
	var full := preview_brush(op, center, radius, strength, free, h_ref, blocked)
	var d := float(full.get("delta_volume", 0.0))
	var scale := 1.0
	if d > 1e-8 and d > positive_budget + 1e-8:
		scale = clampf(positive_budget / d, 0.0, 1.0)
	var applied := apply_brush(op, center, radius, strength, free, h_ref, scale, blocked)
	applied["scale"] = scale
	applied["preview_delta"] = d
	return applied


func flatten_footprint(cells: Array, ramp: float = 1.25, free: bool = false, blocked: Dictionary = {}) -> Dictionary:
	if cells.is_empty():
		return {"delta_volume": 0.0, "target": 0.0, "ok": false}
	var sum := 0.0
	var n := 0
	for cell: Vector2i in cells:
		var p := Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
		var h := sample_height(p)
		if is_finite(h):
			sum += h
			n += 1
	if n == 0:
		return {"delta_volume": 0.0, "target": 0.0, "ok": false}
	var target := sum / float(n)
	if not free:
		target = snap_height(target)
	var before := total_volume()
	var min_x := 9999.0
	var min_z := 9999.0
	var max_x := -9999.0
	var max_z := -9999.0
	for cell: Vector2i in cells:
		min_x = minf(min_x, float(cell.x))
		min_z = minf(min_z, float(cell.y))
		max_x = maxf(max_x, float(cell.x) + 1.0)
		max_z = maxf(max_z, float(cell.y) + 1.0)
	var inner := Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	for iz in verts_z:
		for ix in verts_x:
			var w := vertex_world(ix, iz)
			var p := Vector2(w.x, w.y)
			var dist := _rect_distance(p, inner)
			if dist > ramp:
				continue
			if _vertex_blocked(ix, iz, blocked) and dist > 0.0:
				continue
			var t := 1.0 if dist <= 0.0 else brush_weight(dist, ramp, 0.25)
			var h := lerpf(height_at(ix, iz), target, t)
			if not free:
				h = snap_height(h)
			set_height(ix, iz, h)
	_clamp_all_land()
	var after := total_volume()
	return {
		"delta_volume": after - before,
		"target": target,
		"before_volume": before,
		"after_volume": after,
		"ok": true,
	}


func restore_rect(snapshot: Dictionary) -> void:
	var x0: int = snapshot.get("x0", 0)
	var z0: int = snapshot.get("z0", 0)
	var vx: int = snapshot.get("vx", 0)
	var vz: int = snapshot.get("vz", 0)
	var h: PackedFloat32Array = snapshot.get("heights", PackedFloat32Array())
	var m: PackedByteArray = snapshot.get("mask", PackedByteArray())
	var i := 0
	for iz in range(z0, z0 + vz):
		for ix in range(x0, x0 + vx):
			if in_vertex(ix, iz) and i < h.size():
				set_height(ix, iz, h[i])
			i += 1
	i = 0
	for cz in range(z0, z0 + maxi(vz - 1, 0)):
		for cx in range(x0, x0 + maxi(vx - 1, 0)):
			if in_cell(cx, cz) and i < m.size():
				mask[cell_index(cx, cz)] = m[i]
			i += 1


func compute_water() -> Dictionary:
	var cxn := cells_x()
	var czn := cells_z()
	if cxn == 0:
		return {"lakes": [], "waterfalls": [], "level": {}}
	var cell_h := PackedFloat32Array()
	cell_h.resize(cxn * czn)
	for cz in czn:
		for cx in cxn:
			cell_h[cell_index(cx, cz)] = cell_mean_height(cx, cz) if is_land(cx, cz) else y_bottom
	# Priority flood from every drain (coast / hole). fill[c] = lowest spill that can reach a drain.
	var fill := PackedFloat32Array()
	fill.resize(cxn * czn)
	fill.fill(1.0e9)
	var heap: Array = []
	for cz in czn:
		for cx in cxn:
			if not is_land(cx, cz):
				continue
			if _cell_touches_drain(cx, cz):
				fill[cell_index(cx, cz)] = cell_h[cell_index(cx, cz)]
				heap.append([fill[cell_index(cx, cz)], cx, cz])
	heap.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var cursor := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cursor < heap.size():
		var item: Array = heap[cursor]
		cursor += 1
		var cxi: int = item[1]
		var czi: int = item[2]
		var idx := cell_index(cxi, czi)
		if float(item[0]) > fill[idx] + 1e-6:
			continue
		for d: Vector2i in dirs:
			var nx: int = cxi + d.x
			var nz: int = czi + d.y
			if not is_land(nx, nz):
				continue
			var nidx := cell_index(nx, nz)
			var candidate := maxf(fill[idx], cell_h[nidx])
			if candidate + 1e-6 < fill[nidx]:
				fill[nidx] = candidate
				heap.append([candidate, nx, nz])
	var lakes: Array = []
	var seen: Dictionary = {}
	var levels: Dictionary = {}
	for cz in czn:
		for cx in cxn:
			if not is_land(cx, cz):
				continue
			var idx := cell_index(cx, cz)
			var depth := fill[idx] - cell_h[idx]
			if depth < WATER_GAP + 0.005:
				continue
			if seen.has(Vector2i(cx, cz)):
				continue
			var lake := _gather_lake(cx, cz, fill, cell_h, seen)
			if int(lake.get("cells", []).size()) >= 3:
				lakes.append(lake)
				for c: Vector2i in lake.get("cells", []):
					levels[c] = lake.get("level", 0.0)
	var falls: Array = _waterfall_sites(fill, cell_h)
	return {"lakes": lakes, "waterfalls": falls, "level": levels, "fill": fill, "cell_h": cell_h}


func jitter_xz(world_x: float, world_z: float) -> Vector2:
	var h := _hash2(world_x * 1.713 + float(seed) * 0.017, world_z * 1.371 - float(seed) * 0.013)
	return Vector2((h.x - 0.5) * spacing * JITTER_SCALE, (h.y - 0.5) * spacing * JITTER_SCALE)


func world_vertex(ix: int, iz: int) -> Vector3:
	var p := vertex_world(ix, iz)
	var j := jitter_xz(p.x, p.y)
	if _vertex_is_rim(ix, iz):
		j = Vector2.ZERO
	var s := coast_shift(ix, iz)
	return Vector3(p.x + j.x + s.x, height_at(ix, iz), p.y + j.y + s.y)


func flip_diagonal(cx: int, cz: int) -> bool:
	var n := _hash_int(cx * 73856093 ^ cz * 19349663 ^ seed * 83492791)
	return (n & 1) == 1


func voronoi_push(world: Vector3, outward: Vector3) -> Vector3:
	var cell := Vector2(floor(world.x * 1.15 + 20.0), floor(world.z * 1.15 + 17.0))
	var best := 99.0
	var dir := Vector2.ZERO
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var c := cell + Vector2(ox, oz)
			var rnd := _hash2(c.x * 0.37 + float(seed), c.y * 0.41)
			var site := c + rnd
			var d := Vector2(world.x * 1.15 + 20.0, world.z * 1.15 + 17.0) - site
			var l := d.length()
			if l < best:
				best = l
				dir = d
	var amp := clampf(0.10 + (1.0 - clampf(best, 0.0, 1.0)) * 0.20, 0.08, 0.30)
	var side := Vector3(outward.x, 0.0, outward.z)
	if side.length_squared() < 1e-6:
		side = Vector3(dir.x, 0.0, dir.y)
	if side.length_squared() < 1e-6:
		return world
	return world + side.normalized() * amp


func hash_color(world: Vector3, slope: float) -> Color:
	var ny := clampf(slope, 0.0, 1.0)
	var grass := 0.0
	var soil := 0.0
	var rock := 0.0
	if ny > 0.80:
		grass = 1.0
	elif ny > 0.55:
		soil = inverse_lerp(0.80, 0.55, ny)
		grass = 1.0 - soil
	else:
		rock = 1.0
		soil = clampf((ny - 0.28) / 0.27, 0.0, 1.0)
		rock = 1.0 - soil
	var band := fposmod(world.y * 1.7 + _hash2(world.x, world.z).x * 0.35, 1.0)
	return Color(grass, soil, rock, band)


func _brush_mask(center: Vector3, radius: float, strength: float, add: bool, blocked: Dictionary) -> void:
	var c0 := world_to_cell(center)
	var reach := ceili(radius / spacing) + 1
	for cz in range(c0.y - reach, c0.y + reach + 1):
		for cx in range(c0.x - reach, c0.x + reach + 1):
			if not in_cell(cx, cz):
				continue
			if _cell_blocked(cx, cz, blocked):
				continue
			var mid := vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
			var d := Vector2(mid.x - center.x, mid.y - center.z).length()
			var w := brush_weight(d, radius) * strength
			if w < 0.35:
				continue
			if add:
				if not is_land(cx, cz):
					set_land(cx, cz, true)
					_raise_cell_to_surface(cx, cz)
			else:
				set_land(cx, cz, false)


func punch_shaft(center: Vector3, half: float = 1.0, blocked: Dictionary = {}) -> void:
	var c0 := world_to_cell(center)
	var reach := maxi(ceili(half / spacing), 1)
	for cz in range(c0.y - reach, c0.y + reach + 1):
		for cx in range(c0.x - reach, c0.x + reach + 1):
			if not is_land(cx, cz):
				continue
			if _cell_blocked(cx, cz, blocked):
				continue
			set_land(cx, cz, false)
	_clamp_all_land()


func _dig_through(x0: int, z0: int, x1: int, z1: int, blocked: Dictionary) -> void:
	var floor_h := min_surface()
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if not is_land(cx, cz):
				continue
			if _cell_blocked(cx, cz, blocked):
				continue
			var mean := cell_mean_height(cx, cz)
			if mean <= floor_h + 0.02:
				set_land(cx, cz, false)


func _clamp_touched(touched: Dictionary) -> void:
	for key in touched:
		var p: Vector2i = key
		clamp_vertex(p.x, p.y)


func _box_average() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(heights.size())
	for iz in verts_z:
		for ix in verts_x:
			var sum := 0.0
			var n := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if in_vertex(ix + dx, iz + dz) and _vertex_has_land(ix + dx, iz + dz):
						sum += height_at(ix + dx, iz + dz)
						n += 1
			out[vertex_index(ix, iz)] = (sum / float(n)) if n > 0 else height_at(ix, iz)
	return out


func _influence_rect(center: Vector3, radius: float) -> Rect2i:
	var c := world_to_cell(center)
	var r := ceili(radius / spacing) + 2
	return Rect2i(c.x - r, c.y - r, r * 2 + 1, r * 2 + 1)


func _snapshot_rect(rect: Rect2i) -> Dictionary:
	var x0 := rect.position.x
	var z0 := rect.position.y
	var h := PackedFloat32Array()
	var m := PackedByteArray()
	for iz in range(z0, z0 + rect.size.y + 1):
		for ix in range(x0, x0 + rect.size.x + 1):
			h.append(height_at(ix, iz) if in_vertex(ix, iz) else 0.0)
	for cz in range(z0, z0 + rect.size.y):
		for cx in range(x0, x0 + rect.size.x):
			m.append(1 if is_land(cx, cz) else 0)
	return {"x0": x0, "z0": z0, "vx": rect.size.x + 1, "vz": rect.size.y + 1, "heights": h, "mask": m}


func _vertex_blocked(ix: int, iz: int, blocked: Dictionary) -> bool:
	if blocked.is_empty():
		return false
	var play := play_cell_of_hf(ix, iz)
	return blocked.has(play)


func _cell_blocked(cx: int, cz: int, blocked: Dictionary) -> bool:
	if blocked.is_empty():
		return false
	return blocked.has(play_cell_of_hf(cx, cz))


func _cell_touches_drain(cx: int, cz: int) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var nx: int = cx + d.x
		var nz: int = cz + d.y
		if not in_cell(nx, nz) or not is_land(nx, nz):
			return true
	return false


func _gather_lake(sx: int, sz: int, fill: PackedFloat32Array, cell_h: PackedFloat32Array, seen: Dictionary) -> Dictionary:
	var stack: Array[Vector2i] = [Vector2i(sx, sz)]
	var cells: Array[Vector2i] = []
	var level := fill[cell_index(sx, sz)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c) or not is_land(c.x, c.y):
			continue
		var idx := cell_index(c.x, c.y)
		if fill[idx] - cell_h[idx] < WATER_GAP + 0.005:
			continue
		if absf(fill[idx] - level) > 0.04:
			continue
		seen[c] = true
		cells.append(c)
		level = minf(level, fill[idx])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	return {"cells": cells, "level": level - WATER_GAP}


func _waterfall_sites(fill: PackedFloat32Array, cell_h: PackedFloat32Array) -> Array:
	var sites: Array = []
	for cz in cells_z():
		for cx in cells_x():
			if not is_land(cx, cz):
				continue
			if not _cell_touches_drain(cx, cz):
				continue
			var idx := cell_index(cx, cz)
			var inland := false
			var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for d: Vector2i in dirs:
				var n: Vector2i = Vector2i(cx, cz) + d
				if is_land(n.x, n.y):
					var nidx := cell_index(n.x, n.y)
					if fill[nidx] > cell_h[nidx] + 0.08:
						inland = true
			# A notch or hole-edge that a higher basin can spill through.
			var is_notch := false
			for d2: Vector2i in dirs:
				var n2: Vector2i = Vector2i(cx, cz) + d2
				if is_land(n2.x, n2.y) and cell_h[cell_index(n2.x, n2.y)] > cell_h[idx] + 0.20:
					is_notch = true
			if inland or is_notch:
				var mid := vertex_world(cx, cz) + Vector2(spacing * 0.5, spacing * 0.5)
				var outward := _drain_outward(cx, cz)
				var origin := Vector3(mid.x, cell_h[idx], mid.y)
				var crowded := false
				for prev in sites:
					if origin.distance_to(prev["origin"]) < spacing * 1.6:
						crowded = true
						break
				if crowded:
					continue
				sites.append({
					"cell": Vector2i(cx, cz),
					"origin": origin,
					"outward": outward,
				})
				if sites.size() >= 8:
					return sites
	return sites


func _drain_outward(cx: int, cz: int) -> Vector3:
	var acc := Vector2.ZERO
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		if not is_land(cx + d.x, cz + d.y):
			acc += Vector2(d.x, d.y)
	if acc.length_squared() < 1e-6:
		acc = Vector2(0, 1)
	return Vector3(acc.x, 0.0, acc.y).normalized()


func _rect_distance(p: Vector2, rect: Rect2) -> float:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	if p.x >= rect.position.x and p.x <= rect.end.x and p.y >= rect.position.y and p.y <= rect.end.y:
		return 0.0
	return p.distance_to(q)


static func _hash2(x: float, y: float) -> Vector2:
	var p := Vector2(x, y)
	var n := Vector2(
		fposmod(sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0),
		fposmod(sin(p.dot(Vector2(269.5, 183.3))) * 23421.631, 1.0)
	)
	return n


static func _hash_int(v: int) -> int:
	var n := v
	n = ((n >> 16) ^ n) * 0x45d9f3b
	n = ((n >> 16) ^ n) * 0x45d9f3b
	n = (n >> 16) ^ n
	return n
