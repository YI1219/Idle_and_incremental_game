extends Object
## Procedural shore stones. Render-only. Seeds come from a position hash so a
## local coastline edit does not reshuffle stones whose sample points stay put.

const Heightfield := preload("res://scripts/world/heightfield.gd")

const STEP := 0.90
const SKIP_P := 0.23
const JITTER := 0.15


static func meshes() -> Array:
	return [
		_solid(_slab()),
		_solid(_wedge()),
		_solid(_chunk()),
		_solid(_tooth()),
		_solid(_block()),
	]


static func place(field: Heightfield, loops: Array, lake: bool, falls: Array, blocked: Dictionary) -> Array:
	var buckets: Array = [[], [], [], [], []]
	for loop in loops:
		_place_loop(field, loop, lake, falls, blocked, buckets)
	return buckets


static func _place_loop(field: Heightfield, loop, lake: bool, falls: Array, blocked: Dictionary, buckets: Array) -> void:
	var pts: PackedVector2Array = _as_poly(loop)
	if pts.size() < 4:
		return
	var samples := _walk(pts, STEP)
	var clustered: Dictionary = {}
	for sample in samples:
		var p: Vector2 = sample["p"]
		var tangent: Vector2 = sample["t"]
		var away: Vector2 = _away_from_land(field, p, tangent)
		var key := _quant(p)
		var h := _hash(field, key.x, key.y, 1 if lake else 0)
		if h.x < SKIP_P:
			continue
		var jitter := Vector2((h.y - 0.5) * 2.0 * JITTER, (h.x - 0.5) * 2.0 * JITTER)
		var at := p + tangent * jitter.x + away * jitter.y
		if _blocked(field, at, blocked, falls):
			continue
		var variant := int(floor(h.y * 5.0)) % 5
		var bucket := Vector2i(floori(at.x / 6.0), floori(at.y / 6.0))
		var cluster := false
		if not clustered.has(bucket):
			var gate := _hash(field, bucket.x, bucket.y, 9 if lake else 8)
			# About one cluster per 6 m cell the shore crosses, with some cells left empty.
			if gate.x > 0.22:
				cluster = true
				clustered[bucket] = true
		_emit(field, buckets, variant, at, away, h, lake, cluster, 1.0)
		if cluster:
			var extra := 1 + int(floor(h.y * 1.99))
			for k in extra:
				var hs := _hash(field, key.x, key.y, 20 + k)
				var side := tangent * lerpf(0.28, 0.48, hs.x) * (1.0 if k == 0 else -1.0)
				side += away * (hs.y - 0.5) * 0.16
				var small_at := at + side
				if _blocked(field, small_at, blocked, falls):
					continue
				var sv := int(floor(hs.y * 5.0)) % 5
				_emit(field, buckets, sv, small_at, away, hs, lake, false, lerpf(0.42, 0.62, hs.x))


static func _emit(field: Heightfield, buckets: Array, variant: int, at: Vector2, away: Vector2, h: Vector2, lake: bool, cluster: bool, mul: float) -> void:
	var sx := lerpf(0.62, 0.92, h.x) * mul
	var sz := lerpf(0.58, 0.96, h.y) * mul
	# Rest meshes are short. This is the extra vertical scale (about 1.4–2.1×).
	var sy := lerpf(1.35, 2.05, _hash(field, int(at.x * 4.0), int(at.y * 4.0), variant + 3).x)
	if cluster:
		sx *= 1.12
		sz *= 1.08
		sy *= 1.08
	if lake:
		sx *= 0.52
		sz *= 0.52
		sy *= 0.60
	var yaw := h.y * TAU + away.angle()
	var tilt := (h.x - 0.5) * 0.12
	var roll := (_hash(field, int(at.x * 8.0), int(at.y * 8.0), 4).y - 0.5) * 0.10
	var basis := Basis.from_euler(Vector3(tilt, yaw, roll))
	basis = basis.scaled(Vector3(sx, sy, sz))
	# Keep the footprint on land. A center on the lip left the outer half hanging in the air.
	var inland := (0.08 if lake else 0.28) + maxf(sx, sz) * 0.34
	var placed := false
	for _step in 6:
		var try_at := at - away * inland
		if field.sample_land(Vector3(try_at.x, 0.0, try_at.y)):
			at = try_at
			placed = true
			break
		inland += 0.10
	if not placed:
		return
	var surface := field.sample_height(Vector3(at.x, 0.0, at.y))
	if not is_finite(surface):
		return
	# Rest height is about 0.15 m. Bury most of it so the crown sits in the grass.
	var world_h := 0.15 * sy
	var bury := world_h * (lerpf(0.52, 0.66, h.x) if lake else lerpf(0.62, 0.78, h.y))
	var y := surface - bury
	var gain := lerpf(0.90, 1.10, _hash(field, int(floor(at.x * 2.0)), int(floor(at.y * 2.0)), 6).x)
	(buckets[variant] as Array).append({"xf": Transform3D(basis, Vector3(at.x, y, at.y)), "gain": gain})


static func _walk(pts: PackedVector2Array, step: float) -> Array:
	var n := pts.size()
	var anchor := 0
	var best := pts[0].x
	for i in n:
		if pts[i].x > best + 0.001 or (absf(pts[i].x - best) <= 0.001 and pts[i].y > pts[anchor].y):
			best = pts[i].x
			anchor = i
	var acc := PackedFloat32Array()
	acc.resize(n + 1)
	for i in n:
		var a := pts[(anchor + i) % n]
		var b := pts[(anchor + i + 1) % n]
		acc[i + 1] = acc[i] + a.distance_to(b)
	var total: float = acc[n]
	if total < step * 0.5:
		return []
	var out: Array = []
	var cursor := step * 0.5
	while cursor < total - step * 0.25:
		var seg := 0
		for i in n:
			if acc[i + 1] >= cursor:
				seg = i
				break
		var a2 := pts[(anchor + seg) % n]
		var b2 := pts[(anchor + seg + 1) % n]
		var span := maxf(acc[seg + 1] - acc[seg], 0.0001)
		var u := clampf((cursor - acc[seg]) / span, 0.0, 1.0)
		var p := a2.lerp(b2, u)
		var t := b2 - a2
		if t.length_squared() < 1e-8:
			t = Vector2.RIGHT
		else:
			t = t.normalized()
		out.append({"p": p, "t": t})
		cursor += step
	return out


static func _away_from_land(field: Heightfield, p: Vector2, tangent: Vector2) -> Vector2:
	var right := Vector2(tangent.y, -tangent.x)
	var probe := p + right * 0.35
	if field.sample_land(Vector3(probe.x, 0.0, probe.y)):
		return -right
	return right


static func _blocked(field: Heightfield, p: Vector2, blocked: Dictionary, falls: Array) -> bool:
	var play := Vector2i(floori(p.x), floori(p.y))
	if blocked.has(play):
		return true
	for site in falls:
		var origin: Vector3 = site.get("origin", Vector3.ZERO)
		if Vector2(origin.x, origin.z).distance_to(p) < 1.35:
			return true
	return false


static func _quant(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x * 2.0)), int(round(p.y * 2.0)))


static func _hash(field: Heightfield, x: int, y: int, salt: int) -> Vector2:
	return Heightfield._hash2(float(x) * 0.17 + float(field.seed) * 0.013 + float(salt) * 1.7, float(y) * 0.19 + float(salt) * 0.37)


static func _as_poly(loop) -> PackedVector2Array:
	if loop is PackedVector2Array:
		return loop
	var out := PackedVector2Array()
	for p in loop:
		if p is Vector2:
			out.append(p)
		elif p is Vector3:
			out.append(Vector2(p.x, p.z))
	return out


static func _solid(tris: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := Vector3(0.0, 0.12, 0.0)
	for tri in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		# Squash the rest height so the 1.5–2.4× instance scale stays a chunk, not a spike.
		a.y *= 0.62
		b.y *= 0.62
		c.y *= 0.62
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		if n.dot((a + b + c) / 3.0 - inside) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		n = n.normalized()
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(b)
		st.set_normal(n)
		st.add_vertex(c)
	return st.commit()


# Wide low slab with a slanted top. About 10 tris.
static func _slab() -> Array:
	var b0 := Vector3(-0.28, 0.0, -0.18)
	var b1 := Vector3(0.30, 0.0, -0.16)
	var b2 := Vector3(0.24, 0.0, 0.20)
	var b3 := Vector3(-0.26, 0.0, 0.18)
	var t0 := Vector3(-0.18, 0.16, -0.10)
	var t1 := Vector3(0.20, 0.22, -0.08)
	var t2 := Vector3(0.14, 0.18, 0.12)
	var t3 := Vector3(-0.16, 0.14, 0.10)
	return _prism(b0, b1, b2, b3, t0, t1, t2, t3)


# Tall wedge, three big top facets.
static func _wedge() -> Array:
	var b0 := Vector3(-0.24, 0.0, -0.20)
	var b1 := Vector3(0.26, 0.0, -0.14)
	var b2 := Vector3(0.18, 0.0, 0.22)
	var b3 := Vector3(-0.20, 0.0, 0.16)
	var t0 := Vector3(-0.12, 0.20, -0.08)
	var t1 := Vector3(0.14, 0.26, -0.02)
	var t2 := Vector3(0.06, 0.22, 0.10)
	var t3 := Vector3(-0.10, 0.16, 0.08)
	return _prism(b0, b1, b2, b3, t0, t1, t2, t3)


# Chunky five-sided lump.
static func _chunk() -> Array:
	var b0 := Vector3(-0.22, 0.0, -0.18)
	var b1 := Vector3(0.20, 0.0, -0.16)
	var b2 := Vector3(0.24, 0.0, 0.10)
	var b3 := Vector3(0.04, 0.0, 0.22)
	var b4 := Vector3(-0.20, 0.0, 0.12)
	var t0 := Vector3(-0.12, 0.16, -0.08)
	var t1 := Vector3(0.12, 0.22, -0.06)
	var t2 := Vector3(0.14, 0.18, 0.06)
	var t3 := Vector3(0.00, 0.20, 0.12)
	var t4 := Vector3(-0.12, 0.14, 0.06)
	var tris: Array = []
	var bottom: Array = [b0, b1, b2, b3, b4]
	var crown: Array = [t0, t1, t2, t3, t4]
	for i in range(1, bottom.size() - 1):
		tris.append([b0, bottom[i + 1], bottom[i]])
	for i in range(1, crown.size() - 1):
		tris.append([t0, crown[i], crown[i + 1]])
	for i in bottom.size():
		var j := (i + 1) % bottom.size()
		tris.append([bottom[i], bottom[j], crown[j]])
		tris.append([bottom[i], crown[j], crown[i]])
	return tris


# Upright tooth, narrow and tall.
static func _tooth() -> Array:
	var b0 := Vector3(-0.18, 0.0, -0.16)
	var b1 := Vector3(0.20, 0.0, -0.12)
	var b2 := Vector3(0.16, 0.0, 0.18)
	var b3 := Vector3(-0.16, 0.0, 0.14)
	var t0 := Vector3(-0.08, 0.24, -0.06)
	var t1 := Vector3(0.10, 0.28, -0.04)
	var t2 := Vector3(0.06, 0.22, 0.08)
	var t3 := Vector3(-0.06, 0.18, 0.06)
	return _prism(b0, b1, b2, b3, t0, t1, t2, t3)


# Split block: offset crown.
static func _block() -> Array:
	var b0 := Vector3(-0.24, 0.0, -0.18)
	var b1 := Vector3(0.26, 0.0, -0.10)
	var b2 := Vector3(0.18, 0.0, 0.20)
	var b3 := Vector3(-0.20, 0.0, 0.16)
	var t0 := Vector3(-0.16, 0.14, -0.10)
	var t1 := Vector3(0.16, 0.24, -0.06)
	var t2 := Vector3(0.10, 0.20, 0.12)
	var t3 := Vector3(-0.12, 0.16, 0.10)
	return _prism(b0, b1, b2, b3, t0, t1, t2, t3)


static func _prism(b0: Vector3, b1: Vector3, b2: Vector3, b3: Vector3, t0: Vector3, t1: Vector3, t2: Vector3, t3: Vector3) -> Array:
	return [
		[b0, b2, b1], [b0, b3, b2],
		[t0, t1, t2], [t0, t2, t3],
		[b0, b1, t1], [b0, t1, t0],
		[b1, b2, t2], [b1, t2, t1],
		[b2, b3, t3], [b2, t3, t2],
		[b3, b0, t0], [b3, t0, t3],
	]
