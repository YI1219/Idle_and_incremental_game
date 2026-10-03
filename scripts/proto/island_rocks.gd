extends RefCounted
## Seeded kit-rock shell for one island.
## Packing follows the rockkit study: coastline rings, overlap spacing, random
## yaw, inward tilt, per-slot scale, and a top snap so tilt cannot rise through
## the grass. The long tip stalk from that study is replaced by a blunt cluster.
## A brush restamps only the coast samples inside the dirty rectangle.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")

# s scales the coast about its centroid. drop is how far the true top sits under the lip.
# width is the target footprint. spacing < 1 overlaps neighbours.
# protrude pushes the outer face past the coast line (metres).
# Jitter matches the rockkit study (±25% of the step, ±0.18 m radial). Ring 0
# keeps vertical jitter at 0: the true top is snapped to the lip, and a lower
# terrace must not drag that top down.
# tuck is the fraction of half-width placed inland of the coast. The lip ring
# stays shallow so its top does not cross the grass. Deeper rings use 0.75.
const RINGS := [
	{"s": 1.0, "drop": 0.04, "width": 1.70, "s0": 0.88, "s1": 1.12, "z0": 0.85, "z1": 1.05, "tilt": 3.0, "spacing": 0.70, "pool": "rim", "protrude": 0.02, "arc": 0.10, "radial": 0.05, "zjit": 0.0, "guard": true, "tuck": 0.28, "keep": true},
	{"s": 0.94, "drop": 0.10, "width": 2.20, "s0": 0.80, "s1": 1.18, "z0": 0.92, "z1": 1.12, "tilt": 6.0, "spacing": 0.64, "pool": "rim", "protrude": 0.08, "arc": 0.22, "radial": 0.12, "zjit": 0.0, "guard": true, "tuck": 0.32, "keep": true},
	{"s": 0.78, "drop": 1.05, "width": 2.15, "s0": 0.78, "s1": 1.20, "z0": 1.00, "z1": 1.25, "tilt": 16.0, "spacing": 0.66, "pool": "rim+mid", "protrude": 0.0, "arc": 0.25, "radial": 0.18, "zjit": 0.12, "guard": false, "tuck": 0.75, "keep": false},
	{"s": 0.56, "drop": 2.00, "width": 1.90, "s0": 0.80, "s1": 1.15, "z0": 1.00, "z1": 1.28, "tilt": 20.0, "spacing": 0.70, "pool": "mid+rim", "protrude": 0.0, "arc": 0.22, "radial": 0.14, "zjit": 0.12, "guard": false, "tuck": 0.75, "keep": false},
	{"s": 0.36, "drop": 2.75, "width": 1.65, "s0": 0.82, "s1": 1.10, "z0": 0.95, "z1": 1.20, "tilt": 16.0, "spacing": 0.74, "pool": "mid", "protrude": 0.0, "arc": 0.18, "radial": 0.12, "zjit": 0.08, "guard": false, "tuck": 0.75, "keep": false},
]

const BOTTOM_RING := 80
const HANGER_RING := 81

var slots: Dictionary = {}
var rock_count := 0
var rock_tris := 0


func rebuild(field: Heightfield, loops: Array, dirty: Rect2, full: bool) -> void:
	RockKit.ensure()
	var outer := _outer_loop(loops)
	if outer.is_empty():
		slots.clear()
		rock_count = 0
		rock_tris = 0
		return
	var pts: PackedVector2Array = outer["pts"]
	var centroid: Vector2 = outer["centroid"]
	if full or slots.is_empty():
		slots.clear()
		dirty = Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6)
	else:
		dirty = dirty.grow(2.5)
		var drop: Array[Vector3i] = []
		for key in slots.keys():
			var slot: Dictionary = slots[key]
			var anchor: Vector2 = slot["anchor"]
			var ring := int(slot["ring"])
			if ring >= BOTTOM_RING:
				continue
			if dirty.has_point(anchor):
				drop.append(key)
		for key in drop:
			slots.erase(key)
	for ring_i in RINGS.size():
		_stamp_ring(field, pts, centroid, RINGS[ring_i], ring_i, dirty)
	if full or _hits_circle(dirty, centroid, 2.3) or not _has_bottom():
		_clear_bottom()
		_stamp_bottom(field, centroid, _lip_y(field, centroid))
	_cull(centroid, _mean_radius(pts, centroid))
	_recount()


func batches() -> Dictionary:
	var out: Dictionary = {}
	for key in slots.keys():
		var slot: Dictionary = slots[key]
		var name := String(slot["piece"])
		if not out.has(name):
			out[name] = {"xf": [], "bright": PackedFloat32Array(), "tris": int(slot["tris"])}
		(out[name]["xf"] as Array).append(slot["xf"])
		var bright: PackedFloat32Array = out[name]["bright"]
		bright.append(float(slot["bright"]))
		out[name]["bright"] = bright
	return out


func _stamp_ring(field: Heightfield, pts: PackedVector2Array, centroid: Vector2, ring: Dictionary, ring_i: int, dirty: Rect2) -> void:
	var pool := RockKit.pool(String(ring["pool"]))
	if pool.is_empty() or pts.size() < 3:
		return
	var scaled := _scale_loop(pts, centroid, float(ring["s"]))
	var perim := _length(scaled)
	var step := maxf(float(ring["width"]) * float(ring["spacing"]), 0.55)
	var n := clampi(int(round(perim / step)), 4, 80)
	step = perim / float(n)
	var start := _hash4(float(ring_i) * 2.3, float(field.seed) * 0.01, 11).x * step
	var stale: Array[Vector3i] = []
	for key in slots.keys():
		var id: Vector3i = key
		if id.x == ring_i and id.y >= n and id.z == 0:
			stale.append(id)
	for id in stale:
		slots.erase(id)
	for i in n:
		var frame := _frame(scaled, centroid, start + float(i) * step)
		var p: Vector2 = frame["p"]
		if not dirty.has_point(p):
			continue
		var key := Vector3i(ring_i, i, 0)
		var h := _hash4(float(i) * 0.17 + float(ring_i) * 3.1, float(field.seed) * 0.01, field.seed + ring_i * 17)
		var h2 := _hash4(float(i) + 4.0, float(ring_i) * 1.7, field.seed * 3 + ring_i)
		var piece_name: String = pool[int(h.x * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var tangent: Vector2 = frame["tangent"]
		var outward: Vector2 = frame["outward"]
		var along := (h2.y - 0.5) * step * float(ring["arc"]) * 2.0
		var radial := (h2.z - 0.5) * 2.0 * float(ring["radial"])
		var sr := lerpf(float(ring["s0"]), float(ring["s1"]), h.y)
		var zs := lerpf(float(ring["z0"]), float(ring["z1"]), h.z)
		var s := float(ring["width"]) / float(piece["width"]) * sr
		var half := float(piece["width"]) * s * 0.5
		var tuck := float(ring.get("tuck", 0.75))
		var center := p - outward * (half * tuck - float(ring["protrude"])) + outward * radial + tangent * along
		var lip := _lip_y(field, p)
		var target_y := lip - float(ring["drop"]) + (h2.w - 0.5) * 2.0 * float(ring["zjit"])
		var tilt := deg_to_rad(float(ring["tilt"]) * lerpf(0.7, 1.2, h.w))
		var yaw := h2.x * TAU
		var basis := _basis(tangent, outward, yaw, tilt, s, zs)
		var pos := _snap_top(piece, basis, Vector3(center.x, target_y, center.y))
		pos = _seat(field, piece, basis, pos, outward, target_y, bool(ring["guard"]))
		var radius := maxf(half, float(piece["height"]) * s * zs * 0.5)
		var body := pos + basis * Vector3(0.0, -float(piece["height"]) * s * zs * 0.45, 0.0)
		slots[key] = {
			"piece": piece_name,
			"xf": Transform3D(basis, pos),
			"bright": lerpf(0.94, 1.06, h.z),
			"anchor": p,
			"ring": ring_i,
			"tris": int(piece["tris"]),
			"center": body,
			"radius": radius,
			"keep": bool(ring.get("keep", false)),
		}


func _stamp_bottom(field: Heightfield, centroid: Vector2, lip_y: float) -> void:
	var pool := RockKit.pool("mid+rim")
	if pool.is_empty():
		return
	var floor_y := field.y_bottom + 1.25
	for i in 9:
		var h := _hash4(centroid.x * 0.2 + float(i) * 1.7, centroid.y * 0.2, field.seed + 40 + i)
		var ang := h.x * TAU
		var rad := 0.0 if i == 0 else lerpf(0.35, 1.9, h.y)
		var p := centroid + Vector2(cos(ang), sin(ang)) * rad
		var piece_name: String = pool[int(h.z * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var width := lerpf(1.7, 2.45, h.w) * (1.15 if i == 0 else 1.0)
		var s := width / float(piece["width"])
		var zs := lerpf(0.48, 0.72, h.y)
		var outward := Vector2(cos(ang), sin(ang))
		if i == 0:
			outward = Vector2(1.0, 0.0)
		var tangent := Vector2(-outward.y, outward.x)
		var tilt := 0.0 if i == 0 else deg_to_rad(lerpf(6.0, 16.0, h.w))
		var basis := _basis(tangent, outward, h.z * TAU, tilt, s, zs, i > 0)
		var target_y := floor_y + lerpf(0.05, 0.7, h.x)
		var pos := _snap_top(piece, basis, Vector3(p.x, target_y, p.y))
		var radius := maxf(width * 0.5, float(piece["height"]) * s * zs * 0.5)
		var body := pos + basis * Vector3(0.0, -float(piece["height"]) * s * zs * 0.45, 0.0)
		var key := Vector3i(2000 + i, 0, BOTTOM_RING)
		slots[key] = {
			"piece": piece_name,
			"xf": Transform3D(basis, pos),
			"bright": lerpf(0.94, 1.04, h.w),
			"anchor": p,
			"ring": BOTTOM_RING,
			"tris": int(piece["tris"]),
			"center": body,
			"radius": radius,
		}
	_stamp_hangers(field, centroid, pool, floor_y, lip_y)


func _stamp_hangers(field: Heightfield, centroid: Vector2, pool: PackedStringArray, floor_y: float, _lip_y: float) -> void:
	for i in 4:
		var h := _hash4(float(i) * 2.2 + 8.0, centroid.x + centroid.y, field.seed + 90)
		var ang := h.x * TAU
		var rad := lerpf(0.25, 0.85, h.y)
		var p := centroid + Vector2(cos(ang), sin(ang)) * rad
		var piece_name: String = pool[int(h.w * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var want_h := lerpf(0.42, 0.75, h.z)
		var width := lerpf(0.7, 1.05, h.y)
		var s := width / float(piece["width"])
		var zs := clampf(want_h / maxf(float(piece["height"]) * s, 0.05), 0.15, 0.55)
		var outward := Vector2(cos(ang), sin(ang))
		var tangent := Vector2(-outward.y, outward.x)
		var basis := _basis(tangent, outward, h.x * TAU, deg_to_rad(14.0), s, zs, false)
		var pos := _snap_top(piece, basis, Vector3(p.x, floor_y - 0.15, p.y))
		var radius := maxf(width * 0.5, want_h * 0.5)
		var body := pos + basis * Vector3(0.0, -want_h * 0.45, 0.0)
		slots[Vector3i(3000 + i, 0, HANGER_RING)] = {
			"piece": piece_name,
			"xf": Transform3D(basis, pos),
			"bright": lerpf(0.92, 1.02, h.z),
			"anchor": p,
			"ring": HANGER_RING,
			"tris": int(piece["tris"]),
			"center": body,
			"radius": radius,
		}


func _cull(centroid: Vector2, coast_r: float) -> void:
	var keys: Array = slots.keys()
	var drop: Dictionary = {}
	for i in keys.size():
		var ka: Vector3i = keys[i]
		if drop.has(ka):
			continue
		var a: Dictionary = slots[ka]
		var ring_id := int(a["ring"])
		if bool(a.get("keep", false)) or ring_id >= BOTTOM_RING:
			continue
		var ca: Vector3 = a["center"]
		var ra := float(a["radius"])
		var radial := Vector2(ca.x, ca.z).distance_to(centroid)
		var depth := clampf((0.2 - ca.y) / 4.2, 0.0, 1.0)
		var core_r := coast_r * lerpf(0.42, 0.10, depth)
		if radial + ra < core_r * 0.96:
			drop[ka] = true
			continue
		for j in keys.size():
			if i == j:
				continue
			var kb: Vector3i = keys[j]
			var b: Dictionary = slots[kb]
			var rb := float(b["radius"])
			if rb <= ra * 1.05:
				continue
			var cb: Vector3 = b["center"]
			if ca.distance_to(cb) + ra < rb * 0.70:
				drop[ka] = true
				break
	for key in drop.keys():
		slots.erase(key)


func _recount() -> void:
	rock_count = slots.size()
	var tris := 0
	for key in slots.keys():
		tris += int(slots[key]["tris"])
	rock_tris = tris


func _has_bottom() -> bool:
	for key in slots.keys():
		if int(slots[key]["ring"]) >= BOTTOM_RING:
			return true
	return false


func _clear_bottom() -> void:
	var drop: Array[Vector3i] = []
	for key in slots.keys():
		if int(slots[key]["ring"]) >= BOTTOM_RING:
			drop.append(key)
	for key in drop:
		slots.erase(key)


func _basis(tangent: Vector2, outward: Vector2, yaw: float, tilt: float, s: float, zs: float, lean_in: bool = true) -> Basis:
	var tangent3 := Vector3(tangent.x, 0.0, tangent.y)
	if tangent3.length_squared() < 1.0e-8:
		tangent3 = Vector3(1.0, 0.0, 0.0)
	var want := Vector3(-outward.x, 0.0, -outward.y) if lean_in else Vector3(outward.x, 0.0, outward.y)
	var scale_b := Basis.from_scale(Vector3(s, s * zs, s))
	var yaw_b := Basis(Vector3.UP, yaw)
	var tilt_b := Basis(tangent3, -tilt)
	if (tilt_b * Vector3.DOWN).dot(want) < 0.0:
		tilt_b = Basis(tangent3, tilt)
	return tilt_b * yaw_b * scale_b


func _snap_top(piece: Dictionary, basis: Basis, pos: Vector3) -> Vector3:
	var pts := _samples(piece)
	var max_y := 0.0
	if not pts.is_empty():
		max_y = -1.0e9
		for i in pts.size():
			max_y = maxf(max_y, (basis * pts[i]).y)
	# Incoming pos.y is the lip target. Park the highest vertex on it.
	pos.y -= max_y
	return pos


func _seat(field: Heightfield, piece: Dictionary, basis: Basis, pos: Vector3, outward: Vector2, target_y: float, guard: bool) -> Vector3:
	## Park the highest vertex on the lip. A lower terrace must not drag the
	## whole rock down (that opens sky under the skirt). Slide it toward the
	## coast instead, and only sink the last couple of centimetres.
	if not guard:
		return pos
	var pts := _samples(piece)
	if pts.is_empty():
		return pos
	var step := maxi(int(pts.size() / 40), 1)
	var worst := 0.0
	for _attempt in 12:
		worst = 0.0
		for i in range(0, pts.size(), step):
			var w: Vector3 = pos + basis * pts[i]
			if w.y < target_y - 0.25:
				continue
			var at := Vector3(w.x, 0.0, w.z)
			if not field.sample_land(at):
				continue
			var hy := field.sample_height(at)
			if is_finite(hy):
				worst = maxf(worst, w.y - (hy - 0.04))
		if worst <= 0.04:
			return pos
		pos.x += outward.x * 0.28
		pos.z += outward.y * 0.28
		pos = _snap_top(piece, basis, Vector3(pos.x, target_y, pos.z))
	# The skirt can cover a small leftover. A full sink would open the lip again.
	if worst > 0.04:
		pos.y -= minf(worst, 0.28)
	return pos


func _samples(piece: Dictionary) -> PackedVector3Array:
	if piece.has("samples"):
		return piece["samples"]
	var mesh: ArrayMesh = piece["mesh"]
	var pts := mesh.get_faces() if mesh else PackedVector3Array()
	piece["samples"] = pts
	return pts


func _outer_loop(loops: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_len := -1.0
	for loop in loops:
		if bool(loop.get("hole", false)):
			continue
		var pts: PackedVector2Array = loop["pts"]
		var length := _length(pts)
		if length > best_len:
			best_len = length
			best = loop
	return best


func _scale_loop(pts: PackedVector2Array, centroid: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = centroid + (pts[i] - centroid) * s
	return out


func _mean_radius(pts: PackedVector2Array, centroid: Vector2) -> float:
	if pts.is_empty():
		return 1.0
	var sum := 0.0
	for p in pts:
		sum += p.distance_to(centroid)
	return maxf(sum / float(pts.size()), 0.5)


func _lip_y(field: Heightfield, p: Vector2) -> float:
	var y := field.sample_height(Vector3(p.x, 0.0, p.y))
	if not is_finite(y):
		y = 0.0
	return field.snap_height(y)


func _hits_circle(rect: Rect2, c: Vector2, rad: float) -> bool:
	if rect.size.x > 1.0e5:
		return true
	var x := clampf(c.x, rect.position.x, rect.position.x + rect.size.x)
	var y := clampf(c.y, rect.position.y, rect.position.y + rect.size.y)
	return Vector2(x, y).distance_squared_to(c) <= rad * rad


func _length(loop: PackedVector2Array) -> float:
	var total := 0.0
	var n := loop.size()
	for i in n:
		total += loop[i].distance_to(loop[(i + 1) % n])
	return total


func _frame(loop: PackedVector2Array, centroid: Vector2, distance: float) -> Dictionary:
	var n := loop.size()
	var total := _length(loop)
	if n == 0 or total < 1.0e-4:
		return {"p": centroid, "tangent": Vector2(1.0, 0.0), "outward": Vector2(0.0, 1.0)}
	var target := fposmod(distance, total)
	var walked := 0.0
	for i in n:
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % n]
		var seg := a.distance_to(b)
		if walked + seg >= target or i == n - 1:
			var u := 0.0 if seg < 1.0e-6 else clampf((target - walked) / seg, 0.0, 1.0)
			var p := a.lerp(b, u)
			var tangent := b - a
			if tangent.length_squared() < 1.0e-8:
				tangent = Vector2(1.0, 0.0)
			else:
				tangent = tangent.normalized()
			var outward := Vector2(tangent.y, -tangent.x)
			if outward.dot(p - centroid) < 0.0:
				outward = -outward
			return {"p": p, "tangent": tangent, "outward": outward}
		walked += seg
	return {"p": loop[0], "tangent": Vector2(1.0, 0.0), "outward": Vector2(0.0, 1.0)}


func _hash4(x: float, y: float, salt: int) -> Vector4:
	var a := Heightfield._hash2(x + float(salt) * 0.17, y + 19.2)
	var b := Heightfield._hash2(x * 1.7 - float(salt), y * 1.3 + 4.4)
	return Vector4(a.x, a.y, b.x, b.y)
