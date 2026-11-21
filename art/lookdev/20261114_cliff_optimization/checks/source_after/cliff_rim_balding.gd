class_name CliffRimBalding
extends RefCounted
## Deterministic world-anchored cliff-into-turf encroachment ("石壁反向露岩与稀疏秃草坪").
## Along ~35% of dry cliff rims (especially hard convex headland corners), cliff rock
## bites 0.4m–0.8m back into the lawn surrounded by a 0.6m–1.45m sparse balding turf halo.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Paths = preload("res://scripts/terrain_editor/terrain_paths.gd")
const STEP := 0.5
const MAX_INLAND := 2.1

static var _cached_sig: String = ""
static var _cached_result: Dictionary = {}

static func _hash2(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)

static func _noise2(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var ux := f.x * f.x * f.x * (f.x * (f.x * 6.0 - 15.0) + 10.0)
	var uy := f.y * f.y * f.y * (f.y * (f.y * 6.0 - 15.0) + 10.0)
	var a := _hash2(i.x, i.y)
	var b := _hash2(i.x + 1.0, i.y)
	var c := _hash2(i.x, i.y + 1.0)
	var d := _hash2(i.x + 1.0, i.y + 1.0)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)

static func _path_dist(p: Vector2) -> float:
	var best := 1000.0
	var pts: Array = Paths.POINTS
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best

## Smooth world-space envelope [0..1] selecting which stretches of cliff rim become
## wind-scoured balding / exposed-rock transitions (~35% of dry cliff perimeter).
static func bald_wave(p: Vector2) -> float:
	var r1 := Vector2(p.x * 0.80 + p.y * 0.60, -p.x * 0.60 + p.y * 0.80)
	var r2 := Vector2(-p.x * 0.44 + p.y * 0.90, -p.x * 0.90 - p.y * 0.44)
	var macro := _noise2(r1 * 0.145 + Vector2(5.7, 2.3)) * 0.66 + _noise2(r2 * 0.31 + Vector2(11.4, 7.9)) * 0.34
	var detail := _noise2(r1 * 0.68 + Vector2(2.1, 9.4)) * 0.60 + _noise2(r2 * 1.55 + Vector2(8.3, 3.6)) * 0.40
	return clampf(smoothstep(0.60, 0.79, macro + (detail - 0.5) * 0.18), 0.0, 1.0)

static func edge_baldness(p: Vector2) -> float:
	var path_keep := smoothstep(0.95, 1.65, _path_dist(p))
	return bald_wave(p) * path_keep

static func build(data: Data, field) -> Dictionary:
	if data == null or field == null or field.lawn_boundaries.is_empty():
		return {}
	var lo_cell := Vector2i(1025, 1025)
	var hi_cell := Vector2i(-1025, -1025)
	var sig_parts := PackedStringArray([str(data.seed)])
	for cell: Vector2i in data.cells:
		var rec: Dictionary = data.cells[cell]
		lo_cell = lo_cell.min(cell)
		hi_cell = hi_cell.max(cell)
		sig_parts.append("%d,%d:%.2f,%d" % [cell.x, cell.y, float(rec.height), int(rec.water)])
	if lo_cell.x > hi_cell.x:
		return {}
	var sig := "|".join(sig_parts)
	if sig == _cached_sig and not _cached_result.is_empty():
		return _cached_result

	# Collect dry cliff drop segments (exterior rims + dry interior cliffs >= 1.15m) in 4m buckets:
	var buckets: Dictionary = {}
	var segs: Array = []
	for key in field.lawn_boundaries:
		var h: float = float(key)
		var loops: Array = field.lawn_boundaries[key]
		for loop: PackedVector2Array in loops:
			var n := loop.size()
			if n < 3:
				continue
			# Signed area > 0 means outer boundary of this terrace level:
			var area := 0.0
			for i in n:
				area += loop[i].cross(loop[(i + 1) % n])
			if area <= 0.0:
				continue
			for i in n:
				var a: Vector2 = loop[i]
				var b: Vector2 = loop[(i + 1) % n]
				if a.distance_squared_to(b) < 0.0004:
					continue
				var seg_len := a.distance_to(b)
				var dir := (b - a) / seg_len
				var out := Vector2(dir.y, -dir.x)
				var mid := (a + b) * 0.5
				var probe: Dictionary = field.surface_at(mid + out * 0.42)
				if not probe.is_empty():
					continue
				# Convex corner sharpness boost at endpoints:
				var prev_p: Vector2 = loop[(i - 1 + n) % n]
				var next_p: Vector2 = loop[(i + 2) % n]
				var d_prev := (a - prev_p).normalized()
				var d_next := (next_p - b).normalized()
				var turn_a := maxf(0.0, d_prev.cross(dir))
				var turn_b := maxf(0.0, dir.cross(d_next))
				var corner := clampf(maxf(turn_a, turn_b) * 1.15, 0.0, 1.0)
				var idx := segs.size()
				segs.append([a, b, h, corner])
				var b_lo := Vector2i(floori((minf(a.x, b.x) - MAX_INLAND) / 4.0), floori((minf(a.y, b.y) - MAX_INLAND) / 4.0))
				var b_hi := Vector2i(floori((maxf(a.x, b.x) + MAX_INLAND) / 4.0), floori((maxf(a.y, b.y) + MAX_INLAND) / 4.0))
				for bz in range(b_lo.y, b_hi.y + 1):
					for bx in range(b_lo.x, b_hi.x + 1):
						var bk := Vector2i(bx, bz)
						if not buckets.has(bk):
							buckets[bk] = PackedInt32Array()
						buckets[bk].append(idx)

	var origin := Vector2(lo_cell.x - 2, lo_cell.y - 2)
	var extent := Vector2(hi_cell.x - lo_cell.x + 5, hi_cell.y - lo_cell.y + 5)
	var w_px := maxi(2, int(round(extent.x / STEP)))
	var h_px := maxi(2, int(round(extent.y / STEP)))
	var img := Image.create(w_px, h_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var sorted_levels: Array = field.lawn_boundaries.keys()
	sorted_levels.sort()
	sorted_levels.reverse()

	for py in h_px:
		var wz := origin.y + (float(py) + 0.5) * STEP
		for px in w_px:
			var wx := origin.x + (float(px) + 0.5) * STEP
			var p := Vector2(wx, wz)
			var bk := Vector2i(floori(wx / 4.0), floori(wz / 4.0))
			if not buckets.has(bk):
				continue
			var sh := NAN
			for h_k in sorted_levels:
				if Contours.contains(field.lawn_boundaries[h_k], p):
					sh = float(h_k)
					break
			var on_lip_outside := is_nan(sh)
			var best_d := MAX_INLAND
			var best_corner := 0.0
			var best_h := NAN
			for idx: int in buckets[bk]:
				var s: Array = segs[idx]
				var seg_h := float(s[2])
				if not on_lip_outside and absf(seg_h - sh) > 0.22:
					continue
				var cp := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
				var d := p.distance_to(cp)
				if on_lip_outside:
					if d > 1.55:
						continue
				if d < best_d:
					best_d = d
					best_corner = float(s[3])
					best_h = seg_h
			if best_d >= MAX_INLAND or is_nan(best_h):
				continue
			if on_lip_outside:
				sh = best_h
				best_d = 0.0
			# Suppress near water banks and footpath:
			var water_near := false
			for wl: int in field.water_regions:
				if absf(wl * 0.5 - sh) > 0.6:
					continue
				for wloop: PackedVector2Array in field.water_regions[wl]:
					for wi in wloop.size():
						if p.distance_to(Geometry2D.get_closest_point_to_segment(p, wloop[wi], wloop[(wi + 1) % wloop.size()])) < 1.35:
							water_near = true
							break
					if water_near:
						break
				if water_near:
					break
			if water_near:
				continue
			var prox := clampf(1.0 - best_d / MAX_INLAND, 0.0, 1.0)
			var path_keep := smoothstep(0.85, 1.55, _path_dist(p))
			prox *= path_keep
			if prox > 0.004:
				img.set_pixel(px, py, Color(prox, best_corner, 0.0, 1.0))

	_cached_sig = sig
	_cached_result = {"image": img, "origin": origin, "extent": extent, "w": w_px, "h": h_px}
	return _cached_result

static func sample_at(bald_data: Dictionary, p: Vector2) -> Vector2:
	# Returns Vector2(stone_bite, sparse_turf) in [0..1], matching ground.gdshader.
	if bald_data.is_empty() or not bald_data.has("image"):
		return Vector2.ZERO
	var origin: Vector2 = bald_data.origin
	var extent: Vector2 = bald_data.extent
	var uv := (p - origin) / extent
	if uv.x <= 0.0 or uv.y <= 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Vector2.ZERO
	var img: Image = bald_data.image
	var fx := clampf(uv.x * float(bald_data.w) - 0.5, 0.0, float(bald_data.w - 1))
	var fy := clampf(uv.y * float(bald_data.h) - 0.5, 0.0, float(bald_data.h - 1))
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var x1 := mini(x0 + 1, int(bald_data.w) - 1)
	var y1 := mini(y0 + 1, int(bald_data.h) - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var c00 := img.get_pixel(x0, y0)
	var c10 := img.get_pixel(x1, y0)
	var c01 := img.get_pixel(x0, y1)
	var c11 := img.get_pixel(x1, y1)
	var c := c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)
	var prox := c.r
	if prox <= 0.01:
		return Vector2.ZERO
	var corner := c.g
	var wave := bald_wave(p)
	var patch_drive := clampf(wave + corner * 0.16 * smoothstep(0.05, 0.35, wave), 0.0, 1.0)
	if patch_drive <= 0.14:
		return Vector2.ZERO
	var rag := _noise2(p * 1.35 + Vector2(4.2, 7.8)) * 0.62 + _noise2(p * 3.1 - Vector2(2.6, 5.1)) * 0.38
	var reach := prox * (0.60 + 0.62 * patch_drive) + (rag - 0.5) * 0.24
	var stone_bite := smoothstep(0.66, 0.84, reach) * smoothstep(0.26, 0.58, patch_drive)
	var sparse_turf := smoothstep(0.30, 0.66, reach) * smoothstep(0.16, 0.46, patch_drive)
	return Vector2(stone_bite, sparse_turf)

static func texture_of(result: Dictionary) -> Texture2D:
	if result.is_empty() or not result.has("image"):
		return null
	if not result.has("texture"):
		result["texture"] = ImageTexture.create_from_image(result.image)
	return result.texture
