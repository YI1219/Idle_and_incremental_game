extends RefCounted
## Rule-placed CC0 rocks along the smoothed coast.
## One list of transforms per kit piece. Seeds come from a world-position hash
## so an edit elsewhere does not reshuffle a stretch that did not move.
## Pieces are the already-baked hanging meshes (origin at the top centre).

const Heightfield := preload("res://scripts/world/heightfield.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")

# s scales the coast about its centroid. drop is how far the rock top sits under the grass.
# height is the world height after scale, so tall pillar meshes get squashed.
# tuck is how much of the half-width sits inside the target radius (1 = fully under the lip).
# width is along the coast, depth is radially outward, height is vertical.
# The wide axis stays on the wall so a thin edge cannot stick out.
const RINGS := [
	{"s": 1.0, "inset": 0.0, "drop": 0.0, "width": 1.45, "depth": 0.95, "height": 0.70, "spacing": 0.46, "tilt": 10.0, "pool": "rim+mid", "stagger": 0.0},
	{"s": 0.78, "inset": 0.0, "drop": 0.52, "width": 1.55, "depth": 1.05, "height": 0.95, "spacing": 0.50, "tilt": 14.0, "pool": "rim+mid", "stagger": 0.41},
	{"s": 0.54, "inset": 0.0, "drop": 1.25, "width": 1.45, "depth": 1.05, "height": 1.05, "spacing": 0.52, "tilt": 16.0, "pool": "mid", "stagger": 0.17},
	{"s": 0.32, "inset": 0.0, "drop": 2.05, "width": 1.20, "depth": 0.95, "height": 1.00, "spacing": 0.56, "tilt": 12.0, "pool": "mid", "stagger": 0.63},
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
	var pool := _chunky_pool(String(ring["pool"]))
	if pool.is_empty() or perim < 2.0:
		return 0
	var width := float(ring["width"])
	var step := maxf(width * float(ring["spacing"]), 0.40)
	var n := clampi(int(round(perim / step)), 8, 240)
	var stagger := float(ring["stagger"])
	var used: Dictionary = {}
	var placed := 0
	for i in n:
		var t0 := fposmod((float(i) + stagger) / float(n), 1.0)
		var p0 := _at(pts, t0)
		var slot_h := _hash4(p0.x * 1.3 + float(ring_i) * 5.0, p0.y * 1.1 - float(ring_i), field.seed)
		var t := fposmod(t0 + (slot_h.x - 0.5) * 0.62 / float(n), 1.0)
		var p := _at(pts, t)
		var key := Vector2i(int(round(p0.x / 0.85)), int(round(p0.y / 0.85)))
		var slot := Vector3i(key.x, key.y, ring_i)
		if used.has(slot):
			continue
		used[slot] = true
		var h := _hash4(float(key.x) + float(ring_i) * 17.0, float(key.y) - float(ring_i) * 9.0, field.seed)
		var piece_name := pool[int(h.x * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var want_along := width * lerpf(0.82, 1.28, h.y)
		var want_out := float(ring["depth"]) * lerpf(0.88, 1.12, h.z)
		var want_h := float(ring["height"]) * lerpf(0.86, 1.16, h.w)
		# Local X runs along the coast, local Z points outward, local Y is up.
		var sx := want_along / float(piece["width"])
		var sz := want_out / float(piece["width"])
		var sy := want_h / float(piece["height"])
		if sy < sx * 0.45:
			sy = sx * 0.45
		var outward := p - centroid
		if outward.length_squared() < 1.0e-6:
			continue
		var rad := outward.length()
		outward = outward / rad
		var target_r := rad * float(ring["s"]) - float(ring["inset"])
		# The baked mesh is centred, so half of `want_out` reaches the coast.
		var center_r := maxf(target_r - want_out * 0.40, 0.2)
		var tangent := Vector2(-outward.y, outward.x)
		var along := (h.z - 0.5) * step * 0.28
		var center := centroid + outward * center_r + tangent * along
		var surface := _surface_y(field, p)
		var tilt := deg_to_rad(float(ring["tilt"]) * lerpf(0.7, 1.2, h.y))
		var yaw := (h.x - 0.5) * 0.5
		var outward3 := Vector3(outward.x, 0.0, outward.y)
		var tangent3 := Vector3(tangent.x, 0.0, tangent.y)
		var yaw_basis := Basis(Vector3.UP, yaw)
		outward3 = yaw_basis * outward3
		tangent3 = yaw_basis * tangent3
		var tilt_basis := Basis(tangent3, -tilt)
		var basis := Basis(tilt_basis * tangent3, tilt_basis * Vector3.UP, tilt_basis * outward3)
		basis = basis.scaled(Vector3(sx, sy, sz))
		var sink := sin(tilt) * want_out * 0.5 + 0.05
		var pos := Vector3(center.x, surface - float(ring["drop"]) - sink, center.y)
		var bright := lerpf(0.90, 1.10, h.z)
		_add(by_piece, piece_name, Transform3D(basis, pos), bright)
		placed += 1
	return placed


static func _chunky_pool(spec: String) -> PackedStringArray:
	var pool := RockKit.pool(spec)
	var wide := PackedStringArray()
	for n in pool:
		var piece: Dictionary = RockKit.piece(n)
		if piece.is_empty():
			continue
		if float(piece["height"]) <= float(piece["width"]) * 1.15:
			wide.append(n)
	if wide.size() >= 4:
		return wide
	return pool


static func _place_hanging(field: Heightfield, centroid: Vector2, _perim: float, by_piece: Dictionary) -> int:
	## Short stalk: a few tall icicles under the cone, not a wide bowl.
	var pool := RockKit.pool("tip")
	if pool.is_empty():
		pool = RockKit.pool("tip+mid")
	if pool.is_empty():
		return 0
	var placed := 0
	for k in 6:
		var h := _hash4(centroid.x * 0.17 + float(k) * 3.1, centroid.y * 0.13 + float(field.seed), 40 + k)
		var ang := h.x * TAU
		var rad := 0.0 if k == 0 else lerpf(0.18, 0.72, h.y)
		var p := centroid + Vector2(cos(ang), sin(ang)) * rad
		var piece_name := pool[int(h.z * float(pool.size())) % pool.size()]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty():
			continue
		var width := lerpf(0.55, 0.95, h.w) * (1.15 if k == 0 else 0.85)
		var sx := width / float(piece["width"])
		var sz := width / float(piece["width"]) * lerpf(0.85, 1.1, h.y)
		var sy := (width * lerpf(1.7, 2.6, h.x)) / float(piece["height"])
		var tilt := deg_to_rad(lerpf(4.0, 14.0, h.w))
		var outward := Vector2(cos(ang), sin(ang))
		var tangent3 := Vector3(-outward.y, 0.0, outward.x)
		var basis := Basis(tangent3, tilt) * Basis(Vector3.UP, h.z * TAU)
		basis = basis.scaled(Vector3(sx, sy, sz))
		var y := field.y_bottom + lerpf(-0.35, 0.55, h.y) - (0.45 if k == 0 else 0.0)
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
