extends RefCounted
## Per-island distance-to-waterline image. Render data only.

const RES := 256
const MAX_M := 2.2


static func bake(loops: Array) -> Dictionary:
	var lines: Array = []
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for loop in loops:
		var n := int(loop.size())
		if n < 3:
			continue
		for i in n:
			var a := _xz(loop[i])
			var b := _xz(loop[(i + 1) % n])
			lines.append([a, b])
			min_p.x = minf(min_p.x, minf(a.x, b.x))
			min_p.y = minf(min_p.y, minf(a.y, b.y))
			max_p.x = maxf(max_p.x, maxf(a.x, b.x))
			max_p.y = maxf(max_p.y, maxf(a.y, b.y))
	if lines.is_empty():
		return {}
	min_p -= Vector2(MAX_M, MAX_M)
	max_p += Vector2(MAX_M, MAX_M)
	var span := maxf(maxf(max_p.x - min_p.x, max_p.y - min_p.y), 1.0)
	var dist := PackedFloat32Array()
	dist.resize(RES * RES)
	dist.fill(MAX_M)
	var ppm := float(RES - 1) / span
	var band := int(ceil(MAX_M * ppm)) + 1
	for seg in lines:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var steps := maxi(int(ceil(a.distance_to(b) * ppm)), 1)
		for s in steps + 1:
			var p := a.lerp(b, float(s) / float(steps))
			var cx := int(round((p.x - min_p.x) * ppm))
			var cy := int(round((p.y - min_p.y) * ppm))
			var x0 := maxi(cx - band, 0)
			var x1 := mini(cx + band, RES - 1)
			var y0 := maxi(cy - band, 0)
			var y1 := mini(cy + band, RES - 1)
			for y in range(y0, y1 + 1):
				var row := y * RES
				var wy := min_p.y + float(y) / ppm
				for x in range(x0, x1 + 1):
					var wx := min_p.x + float(x) / ppm
					var d := _seg_dist(Vector2(wx, wy), a, b)
					var idx := row + x
					if d < dist[idx]:
						dist[idx] = d
	var bytes := PackedByteArray()
	bytes.resize(RES * RES)
	for i in dist.size():
		bytes[i] = int(clampf(dist[i] / MAX_M, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(RES, RES, false, Image.FORMAT_R8, bytes)
	return {"image": image, "origin": min_p, "span": span, "max_m": MAX_M}


static func sample(baked: Dictionary, world_xz: Vector2) -> float:
	var image: Image = baked.get("image")
	if image == null:
		return 99.0
	var origin: Vector2 = baked.get("origin", Vector2.ZERO)
	var span := float(baked.get("span", 1.0))
	var max_m := float(baked.get("max_m", MAX_M))
	var uv := (world_xz - origin) / maxf(span, 0.001)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return max_m
	var x := clampi(int(round(uv.x * float(image.get_width() - 1))), 0, image.get_width() - 1)
	var y := clampi(int(round(uv.y * float(image.get_height() - 1))), 0, image.get_height() - 1)
	return image.get_pixel(x, y).r * max_m


static func _xz(p) -> Vector2:
	if p is Vector3:
		return Vector2(p.x, p.z)
	return p


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0 if denom < 1e-8 else clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)
