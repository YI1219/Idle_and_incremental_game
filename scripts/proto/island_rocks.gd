extends RefCounted
## Rule-placed CC0 rocks along the smoothed coast.
## One list of transforms per kit piece. Seeds come from a world-position hash
## so an edit elsewhere does not reshuffle a stretch that did not move.
## Pieces are the already-baked hanging meshes (origin at the top centre).

const Heightfield := preload("res://scripts/world/heightfield.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")

# Outer face sits this far outside the grass line (negative = tucked inside).
# Lower rows are larger and further in, so they do not form a wide base.
const RINGS := [
	{"drop": 0.18, "width": 1.85, "spacing": 0.48, "tilt": 11.0, "protrude": -0.16, "ystretch": 1.45, "pool": "rim", "stagger": 0.0},
	{"drop_k": 0.18, "width": 2.05, "spacing": 0.52, "tilt": 14.0, "protrude": -0.40, "ystretch": 1.40, "pool": "rim+mid", "stagger": 0.48},
	{"drop_k": 0.36, "width": 2.20, "spacing": 0.58, "tilt": 16.0, "protrude": -0.85, "ystretch": 1.35, "pool": "mid", "stagger": 0.22},
]


static func place(field: Heightfield, loops: Array) -> Dictionary:
	RockKit.ensure()
	var by_piece: Dictionary = {}
	var count := 0
	var outer: Dictionary = {}
	var best := 0.0
	for loop in loops:
		if bool(loop.get("hole", false)):
			continue
		var pts: PackedVector2Array = loop["pts"]
		var perim := _length(pts)
		if perim > best:
			best = perim
			outer = loop
	if not outer.is_empty():
		var pts: PackedVector2Array = outer["pts"]
		var perim := _length(pts)
		var centroid: Vector2 = outer["centroid"]
		for ring_i in RINGS.size():
			count += _place_ring(field, pts, perim, centroid, RINGS[ring_i], ring_i, by_piece)
		count += _place_hanging(field, centroid, perim, by_piece)
	return {"by_piece": by_piece, "count": count}


static func _place_ring(field: Heightfield, pts: PackedVector2Array, perim: float, centroid: Vector2, ring: Dictionary, ring_i: int, by_piece: Dictionary) -> int:
	var pool := RockKit.pool(String(ring["pool"]))
	if pool.is_empty() or perim < 2.0:
		return 0
	var width := float(ring["width"])
	var step := maxf(width * float(ring["spacing"]), 0.45)
	var n := clampi(int(round(perim / step)), 8, 220)
	var stagger := float(ring["stagger"]) / float(n)
	var used: Dictionary = {}
	var placed := 0
	for i in n:
		var t := fposmod((float(i) / float(n)) + stagger, 1.0)
		var p := _at(pts, t)
		var key := Vector2i(int(round(p.x / 0.85)), int(round(p.y / 0.85)))
		var slot := Vector3i(key.x, key.y, ring_i)
		if used.has(slot):
			continue
		used[slot] = true
		var h := _hash4(float(key.x) + float(ring_i) * 17.0, float(key.y) - float(ring_i) * 9.0, field.seed)
		var piece_name := pool[int(h.x * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var sx := (width / float(piece["width"])) * lerpf(0.84, 1.16, h.y)
		var sz := (width / float(piece["width"])) * lerpf(0.84, 1.16, h.z)
		var sy := (width / float(piece["width"])) * float(ring["ystretch"]) * lerpf(0.90, 1.22, h.w)
		var outward := p - centroid
		if outward.length_squared() < 1.0e-6:
			continue
		outward = outward.normalized()
		var half := float(piece["width"]) * maxf(sx, sz) * 0.5
		var center := p - outward * (half * 0.58 - float(ring["protrude"]))
		var surface := _surface_y(field, p)
		var depth := maxf(surface - field.y_bottom, 1.0)
		var drop := float(ring.get("drop", 0.0))
		if ring.has("drop_k"):
			drop = depth * float(ring["drop_k"])
		var tilt := deg_to_rad(float(ring["tilt"]) * lerpf(0.72, 1.18, h.y))
		var yaw := h.x * TAU
		var tangent := Vector3(-outward.y, 0.0, outward.x)
		var basis := Basis(tangent, -tilt) * Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(sx, sy, sz))
		# Tilt lifts the outer lip. Sink so the mesh stays under the grass.
		var sink := sin(tilt) * half * 1.25 + 0.06
		var pos := Vector3(center.x, surface - drop - sink, center.y)
		var bright := lerpf(0.90, 1.10, h.z)
		_add(by_piece, piece_name, Transform3D(basis, pos), bright)
		placed += 1
	return placed


static func _place_hanging(field: Heightfield, centroid: Vector2, perim: float, by_piece: Dictionary) -> int:
	var pool := RockKit.pool("tip+mid")
	if pool.is_empty():
		return 0
	var placed := 0
	var reach := clampf(perim / TAU * 0.12, 0.45, 1.3)
	for k in 5:
		var h := _hash4(centroid.x * 0.17 + float(k) * 3.1, centroid.y * 0.13 + float(field.seed), 40 + k)
		var ang := h.x * TAU
		var rad := 0.0 if k == 0 else reach * lerpf(0.25, 1.0, h.y)
		var p := centroid + Vector2(cos(ang), sin(ang)) * rad
		var piece_name := pool[int(h.z * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var width := lerpf(1.15, 1.75, h.w) * (1.2 if k == 0 else 0.9)
		var sx := (width / float(piece["width"])) * lerpf(0.9, 1.1, h.y)
		var sy := (width / float(piece["width"])) * lerpf(0.85, 1.35, h.x)
		var sz := (width / float(piece["width"])) * lerpf(0.9, 1.1, h.z)
		var basis := Basis(Vector3.UP, h.w * TAU)
		basis = basis.scaled(Vector3(sx, sy, sz))
		var y := field.y_bottom + lerpf(0.15, 1.15, h.y)
		var pos := Vector3(p.x, y, p.y)
		_add(by_piece, piece_name, Transform3D(basis, pos), lerpf(0.90, 1.05, h.z))
		placed += 1
	return placed


static func _add(by_piece: Dictionary, piece_name: String, xf: Transform3D, bright: float) -> void:
	if not by_piece.has(piece_name):
		by_piece[piece_name] = {"xf": [], "bright": PackedFloat32Array()}
	(by_piece[piece_name]["xf"] as Array).append(xf)
	var bright_arr: PackedFloat32Array = by_piece[piece_name]["bright"]
	bright_arr.append(bright)
	by_piece[piece_name]["bright"] = bright_arr


static func _surface_y(field: Heightfield, p: Vector2) -> float:
	var y := field.sample_height(Vector3(p.x, 0.0, p.y))
	if not is_finite(y):
		y = 0.0
	return field.snap_height(y)


static func _hash4(x: float, y: float, salt: int) -> Vector4:
	var a := Heightfield._hash2(x + float(salt) * 0.17, y + 19.2)
	var b := Heightfield._hash2(x * 1.7 - float(salt), y * 1.3 + 4.4)
	return Vector4(a.x, a.y, b.x, b.y)


static func _length(loop: PackedVector2Array) -> float:
	var total := 0.0
	var n := loop.size()
	for i in n:
		total += loop[i].distance_to(loop[(i + 1) % n])
	return total


static func _at(loop: PackedVector2Array, t: float) -> Vector2:
	var n := loop.size()
	if n == 0:
		return Vector2.ZERO
	var total := _length(loop)
	var target := t * total
	var walked := 0.0
	for i in n:
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % n]
		var seg := a.distance_to(b)
		if walked + seg >= target:
			var u := 0.0 if seg < 1.0e-6 else (target - walked) / seg
			return a.lerp(b, clampf(u, 0.0, 1.0))
		walked += seg
	return loop[0]
