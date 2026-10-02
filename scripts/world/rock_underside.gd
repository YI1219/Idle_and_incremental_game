extends Object
## Rule-based rock-kit underside. Slot identity is (ring, slot); transforms snap to the current coast.

const RockKit := preload("res://scripts/world/rock_kit.gd")

## s, top y, target width, scale min/max, z-stretch min/max, tilt deg, spacing, pool, protrude
const GROUND_Y := 0.0
const RINGS := [
	[1.015, 0.58, 2.85, 0.78, 1.34, 0.62, 0.88, 8.0, 0.54, "rim", 0.36],
	[0.80, -0.95, 2.45, 0.80, 1.22, 0.95, 1.20, 14.0, 0.60, "rim+mid", 0.06],
	[0.58, -2.10, 2.15, 0.80, 1.16, 1.05, 1.32, 18.0, 0.64, "mid+rim", 0.0],
	[0.36, -3.15, 1.85, 0.80, 1.12, 1.10, 1.38, 22.0, 0.70, "mid", 0.0],
]
const JITTER_ARC := 0.28
const JITTER_RADIAL := 0.18
const JITTER_Y := 0.10
const FAR_RINGS := 2


static func assemble(outline: PackedVector2Array, seed: int, far: bool = false) -> Dictionary:
	return respace({"slots": [], "roots": [], "seed": seed}, outline, seed, far)


static func respace(prev: Dictionary, outline: PackedVector2Array, seed: int, far: bool = false) -> Dictionary:
	RockKit.ensure()
	var mid := _centroid(outline)
	var ring_limit := FAR_RINGS if far else RINGS.size()
	var boost := _size_boost(outline, mid)
	var old_slots: Array = prev.get("slots", [])
	var by_key: Dictionary = {}
	for slot in old_slots:
		by_key[_slot_key(int(slot["ring"]), int(slot["slot"]))] = slot
	var slots: Array = []
	var last_piece := ""
	for ri in ring_limit:
		var row: Array = RINGS[ri]
		var ring := _scaled(outline, mid, float(row[0]))
		var per := _perimeter(ring)
		var step := float(row[2]) * float(row[8])
		var count := maxi(3, int(round(per / maxf(step, 0.4))))
		var start := _unit(seed, ri, -1) * (per / float(count))
		var names := RockKit.pool(String(row[9]))
		if names.is_empty():
			continue
		for i in count:
			var key := _slot_key(ri, i)
			var slot: Dictionary = by_key.get(key, {"ring": ri, "slot": i, "piece": ""})
			slot["ring"] = ri
			slot["slot"] = i
			if String(slot.get("piece", "")) == "" or not RockKit.catalog.has(slot["piece"]):
				slot["piece"] = _pick_piece(names, last_piece, seed, ri, i)
			elif String(slot["piece"]) == last_piece and names.size() > 1:
				slot["piece"] = _pick_piece(names, last_piece, seed, ri, i)
			last_piece = String(slot["piece"])
			slot["xf"] = _ring_transform(slot, ring, mid, start, per, count, seed, row, boost)
			slot["jitter"] = _unit(seed, ri, i + 17)
			slots.append(slot)
	var tips := _tips(outline, mid, seed, far, _lowest_ring_top(ring_limit), boost)
	for tip in tips:
		slots.append(tip)
	var roots: Array = []
	if not far:
		roots = _roots(slots, seed)
	return {
		"slots": slots,
		"roots": roots,
		"seed": seed,
		"outline": outline,
		"centroid": mid,
		"piece_count": slots.size(),
		"lowest_y": _lowest_y(slots),
	}


static func any_floating(state: Dictionary, outline: PackedVector2Array, _slab_y: float = 0.12) -> bool:
	var mid := _centroid(outline)
	var reach := 0.0
	for p in outline:
		reach = maxf(reach, p.distance_to(mid))
	reach += 2.8
	for slot in state.get("slots", []):
		var xf: Transform3D = slot["xf"]
		if Vector2(xf.origin.x, xf.origin.z).distance_to(mid) > reach:
			return true
		var info: Dictionary = RockKit.piece(String(slot["piece"]))
		var bottom := xf.origin.y - float(info.get("height", 1.0)) * xf.basis.y.length()
		if bottom > GROUND_Y + 0.05:
			return true
	return false


static func cover_outline(outline: PackedVector2Array, state: Dictionary) -> PackedVector2Array:
	if outline.size() < 3:
		return outline
	var mid := _centroid(outline)
	var bins := 72
	var rad := PackedFloat32Array()
	rad.resize(bins)
	for p in outline:
		var i := _bin(p - mid, bins)
		rad[i] = maxf(rad[i], p.distance_to(mid))
	RockKit.ensure()
	for slot in state.get("slots", []):
		if int(slot.get("ring", 0)) > 0:
			continue
		var xf: Transform3D = slot["xf"]
		var info: Dictionary = RockKit.piece(String(slot["piece"]))
		var mesh: ArrayMesh = info.get("mesh")
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var w: Vector3 = xf * (box.position + box.size * Vector3(x, y, z))
					if w.y < -1.1:
						continue
					var q := Vector2(w.x, w.z)
					var i := _bin(q - mid, bins)
					rad[i] = maxf(rad[i], q.distance_to(mid) + 0.05)
	for i in bins:
		if rad[i] <= 0.01:
			var prev := rad[(i - 1 + bins) % bins]
			var nxt := rad[(i + 1) % bins]
			rad[i] = maxf(prev, nxt)
	var out := PackedVector2Array()
	out.resize(outline.size())
	for i in outline.size():
		var p := outline[i]
		var d := p - mid
		var r := d.length()
		var need := rad[_bin(d, bins)] + 0.04
		if r < 1e-4:
			out[i] = p
		else:
			out[i] = mid + d * (maxf(r, need) / r)
	return out


static func _bin(d: Vector2, bins: int) -> int:
	var ang := atan2(d.y, d.x)
	return posmod(int(floor((ang + PI) / TAU * float(bins))), bins)


static func triangle_count(state: Dictionary) -> int:
	RockKit.ensure()
	var total := 0
	for slot in state.get("slots", []):
		var row: Dictionary = RockKit.piece(String(slot["piece"]))
		total += int(row.get("tris", 0))
	return total


static func _ring_transform(slot: Dictionary, ring: PackedVector2Array, mid: Vector2, start: float, per: float, count: int, seed: int, row: Array, boost: float) -> Transform3D:
	var i := int(slot["slot"])
	var u0 := _unit(seed, int(slot["ring"]), i)
	var u1 := _unit(seed, int(slot["ring"]), i + 31)
	var u2 := _unit(seed, int(slot["ring"]), i + 53)
	var u3 := _unit(seed, int(slot["ring"]), i + 71)
	var u4 := _unit(seed, int(slot["ring"]), i + 97)
	var step := per / float(count)
	var d := start + float(i) * step + (u0 - 0.5) * 2.0 * JITTER_ARC * step
	var hit := _sample(ring, d)
	var p: Vector2 = hit[0]
	var nrm: Vector2 = hit[1]
	var tan: Vector2 = hit[2]
	var info: Dictionary = RockKit.piece(String(slot["piece"]))
	var pw := float(info.get("width", 1.0))
	var s := float(row[2]) * boost / maxf(pw, 0.2) * lerpf(float(row[3]), float(row[4]), u1)
	var zs := lerpf(float(row[5]), float(row[6]), u2)
	var half := pw * s * 0.5
	var inward := -nrm
	var pos2 := p + inward * (half * 0.75 - float(row[10])) + nrm * (u3 - 0.5) * 2.0 * JITTER_RADIAL
	var top_y := float(row[1]) + (u4 - 0.5) * 2.0 * JITTER_Y
	var yaw := u0 * TAU + (u3 - 0.5) * 1.4
	var tilt := float(row[7]) * lerpf(0.65, 1.25, u2)
	return _compose(info, Vector3(pos2.x, top_y, pos2.y), yaw, s, zs, Vector3(tan.x, 0.0, tan.y), tilt, Vector3(inward.x, 0.0, inward.y))


static func _tips(outline: PackedVector2Array, mid: Vector2, seed: int, far: bool, lowest_top: float, boost: float = 1.0) -> Array:
	if far:
		return []
	var pool := RockKit.pool("mid")
	if pool.is_empty():
		pool = RockKit.pool("tip")
	var extra := RockKit.pool("tip")
	var count := 1 + (1 if _unit(seed, 20, 0) > 0.62 else 0)
	var out: Array = []
	var last := ""
	for i in count:
		var u0 := _unit(seed, 21, i)
		var u1 := _unit(seed, 21, i + 11)
		var u2 := _unit(seed, 21, i + 23)
		var names := pool if i == 0 or extra.is_empty() else extra
		var name := _pick_piece(names, last, seed, 21, i)
		last = name
		var info: Dictionary = RockKit.piece(name)
		var ang := u0 * TAU
		var rad := lerpf(0.15, 0.55, u0) if i == 0 else lerpf(0.85, 1.85, u1)
		var pos := Vector3(mid.x + cos(ang) * rad, 0.0, mid.y + sin(ang) * rad)
		pos.y = lowest_top - (0.90 if i == 0 else lerpf(0.35, 1.15, u2))
		var width := lerpf(1.7, 2.35, u1) * boost * (1.0 if i == 0 else 0.68)
		var s := width / maxf(float(info.get("width", 1.0)), 0.2)
		var zs := lerpf(0.70, 0.92, u2) * (1.0 if i == 0 else 0.74)
		var out_dir := Vector3(cos(ang), 0.0, sin(ang))
		var axis := out_dir.cross(Vector3.UP)
		if axis.length_squared() < 1e-6:
			axis = Vector3.RIGHT
		var tilt := (11.0 if i == 0 else 18.0) * lerpf(0.7, 1.25, u0)
		var xf := _compose(info, pos, u0 * TAU, s, zs, axis.normalized(), tilt, out_dir)
		out.append({"piece": name, "ring": 8, "slot": i, "xf": xf, "jitter": u1})
	return out


static func _roots(slots: Array, seed: int) -> Array:
	var rim: Array = []
	for slot in slots:
		if int(slot["ring"]) <= 1:
			rim.append(slot)
	if rim.is_empty():
		return []
	var count := mini(6, maxi(3, int(round(float(rim.size()) * 0.08))))
	var out: Array = []
	for j in count:
		var pick: Dictionary = rim[int(_unit(seed, 30, j) * float(rim.size())) % rim.size()]
		var xf: Transform3D = pick["xf"]
		var yaw := _unit(seed, 30, j + 5) * TAU
		var scale := lerpf(0.85, 1.25, _unit(seed, 30, j + 9))
		var origin: Vector3 = xf.origin + Vector3(0.0, -0.15, 0.0) + xf.basis.z * 0.15
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		out.append(Transform3D(basis, origin))
	return out


static func _compose(info: Dictionary, pos: Vector3, yaw: float, s: float, zs: float, tilt_axis: Vector3, tilt_deg: float, inward: Vector3) -> Transform3D:
	var yaw_b := Basis(Vector3.UP, yaw)
	var tilt_b := Basis.IDENTITY
	if tilt_axis.length_squared() > 1e-8 and absf(tilt_deg) > 0.01:
		tilt_b = Basis(tilt_axis.normalized(), deg_to_rad(tilt_deg))
		if (tilt_b * Vector3.DOWN).dot(inward) < 0.0:
			tilt_b = Basis(tilt_axis.normalized(), -deg_to_rad(tilt_deg))
	var scale_b := Basis.from_scale(Vector3(s, s * zs, s))
	var basis := tilt_b * yaw_b * scale_b
	var lift := _transformed_top(info, basis)
	return Transform3D(basis, Vector3(pos.x, pos.y - lift, pos.z))


static func _transformed_top(info: Dictionary, basis: Basis) -> float:
	var mesh: ArrayMesh = info.get("mesh")
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var box := mesh.get_aabb()
	var top := -INF
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var p := box.position + box.size * Vector3(x, y, z)
				top = maxf(top, (basis * p).y)
	return top if top > -INF else 0.0


static func _pick_piece(names: PackedStringArray, last: String, seed: int, ring: int, slot: int) -> String:
	if names.is_empty():
		return ""
	var idx := int(_unit(seed, ring, slot + 3) * float(names.size())) % names.size()
	var name := names[idx]
	if name == last and names.size() > 1:
		name = names[(idx + 1) % names.size()]
	return name


static func _lowest_ring_top(ring_limit: int) -> float:
	var top := 0.0
	for i in mini(ring_limit, RINGS.size()):
		top = minf(top, float(RINGS[i][1]))
	return top


static func _lowest_y(slots: Array) -> float:
	var lo := 0.0
	for slot in slots:
		var xf: Transform3D = slot["xf"]
		var info: Dictionary = RockKit.piece(String(slot["piece"]))
		var h := float(info.get("height", 1.0))
		lo = minf(lo, xf.origin.y - h * xf.basis.y.length())
	return lo


static func _sample(poly: PackedVector2Array, d: float) -> Array:
	var per := _perimeter(poly)
	if per <= 1e-5:
		return [poly[0], Vector2.RIGHT, Vector2.UP]
	d = fposmod(d, per)
	var acc := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var L := a.distance_to(b)
		if acc + L >= d or i == poly.size() - 1:
			var t := (b - a).normalized() if L > 1e-6 else Vector2.RIGHT
			var p := a.lerp(b, clampf((d - acc) / maxf(L, 1e-5), 0.0, 1.0))
			var n := Vector2(t.y, -t.x)
			return [p, n, t]
		acc += L
	return [poly[0], Vector2.RIGHT, Vector2.UP]


static func _scaled(poly: PackedVector2Array, mid: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = mid + (poly[i] - mid) * s
	return out


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in poly:
		s += p
	return s / float(maxi(poly.size(), 1))


static func _size_boost(poly: PackedVector2Array, mid: Vector2) -> float:
	var reach := 0.0
	for p in poly:
		reach = maxf(reach, p.distance_to(mid))
	return clampf(reach / 6.5, 0.92, 2.15)


static func _perimeter(poly: PackedVector2Array) -> float:
	var L := 0.0
	for i in poly.size():
		L += poly[i].distance_to(poly[(i + 1) % poly.size()])
	return L


static func _slot_key(ring: int, slot: int) -> int:
	return ring * 10007 + slot


static func _unit(seed: int, ring: int, slot: int) -> float:
	var h := seed * 73856093
	h = h ^ (ring * 19349663)
	h = h ^ (slot * 83492791)
	h = (h * 1103515245 + 12345) & 0x7fffffff
	return float(h % 10000) / 10000.0
