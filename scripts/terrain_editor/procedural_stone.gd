extends RefCounted
## Monolithic low-poly cliff blocks & stepped buttresses with broad quiet planes.
## Each block reads as one or two wide axe-cut faces (斧劈) over a short crown
## bevel and one under-taper; every quad is exactly planar (no accordion folds).

const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")

static func _hash(seed_value: int, salt: int) -> float:
	var v: int = (seed_value * 374761393 + salt * 668265263) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v) / 2147483647.0

static func _s(seed_value: int, salt: int, lo: float, hi: float) -> float:
	return lerpf(lo, hi, _hash(seed_value, salt))

static func _add_tri(builder: Geometry.Surface, a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3, uv_val: Vector2, custom_n: Vector3 = Vector3.ZERO) -> void:
	var n := -(b - a).cross(c - a)
	var v0 := a; var v1 := b; var v2 := c
	if n.dot(outward) < 0.0:
		v1 = c; v2 = b
		n = -n
	n = custom_n.normalized() if custom_n.length_squared() > 0.0001 else n.normalized()
	for v in [v0, v1, v2]:
		builder.vertices.append(v)
		builder.normals.append(n)
		builder.colors.append(color)
		builder.uv.append(uv_val)

static func _add_quad(builder: Geometry.Surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col1: Color, col2: Color, outward: Vector3, uv_val: Vector2, use_ac: bool, planar_blend: float) -> void:
	var t1_a := a; var t1_b := b; var t1_c := c if use_ac else d
	var t2_a := a if use_ac else b; var t2_b := c; var t2_c := d
	var n1 := -(t1_b - t1_a).cross(t1_c - t1_a)
	if n1.dot(outward) < 0.0:
		n1 = -n1
	n1 = n1.normalized()
	var n2 := -(t2_b - t2_a).cross(t2_c - t2_a)
	if n2.dot(outward) < 0.0:
		n2 = -n2
	n2 = n2.normalized()
	var n_quad := (n1 + n2).normalized()
	if n_quad.length_squared() < 0.0001:
		n_quad = n1
	var fn1 := (n_quad * planar_blend + n1 * (1.0 - planar_blend)).normalized()
	var fn2 := (n_quad * planar_blend + n2 * (1.0 - planar_blend)).normalized()
	_add_tri(builder, t1_a, t1_b, t1_c, col1, outward, uv_val, fn1)
	_add_tri(builder, t2_a, t2_b, t2_c, col2, outward, uv_val, fn2)

static func _facet_color(seed_value: int, salt: int, base_val: float = 0.714, spread: float = 0.010) -> Color:
	var v := clampf(base_val + (_hash(seed_value, salt) - 0.5) * 2.0 * spread, 0.64, 0.78)
	return Color(v, v, v, 1.0)

static func _ring_from(front: Array, y: float) -> Array:
	var ring: Array = []
	for p2: Vector2 in front:
		ring.append(Vector3(p2.x, y, p2.y))
	return ring

static func _scaled(ring: Array, s: float, y: float, dx: float = 0.0) -> Array:
	# Uniform XZ scale about the column axis plus a shared Y drop: every side
	# face between the two rings stays exactly planar (frustum faces).
	var out: Array = []
	for p: Vector3 in ring:
		out.append(Vector3(p.x * s + dx, y, p.z * s))
	return out

static func _lerp_ring(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in a.size():
		out.append((a[i] as Vector3).lerp(b[i], t))
	return out

static func build(seed_value: int, root: bool = false) -> Dictionary:
	var builder := Geometry.Surface.new()
	var render_builder := Geometry.Surface.new()
	var variant: int = posmod(seed_value, 4)

	const FRONT_COLS := 5
	const BACK_COLS := 3
	const RING_SIZE := FRONT_COLS + BACK_COLS
	const NUM_RINGS := 6

	# Broad quiet planes (axe-cut 斧劈 faces): R0 crown section is unchanged for
	# rim_union. Below it each block has only three vertical bands: a short
	# crown bevel (R0->R1), one tall main face (R1->R3) and one under-taper
	# (R3->R5). R2/R4 are interpolated on those planes, so no accordion folds.
	# The front main face is one plane (v0/v1/v2) or two planes meeting on a
	# soft central prow (v3); shallow side bevels (~13% width each) let
	# neighbouring blocks merge into one continuous wall.
	var r0_front: Array = []
	var r1_front: Array = []
	var r0_y: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
	var y1 := -0.13
	var y2 := -0.415
	var y3 := -0.70
	var s12 := 1.0
	var s23 := 0.95
	var s35 := 0.58
	var t4 := 0.45
	var apex_bot_y := -1.15
	var apex_bot_z := -0.04
	var keel_x := _s(seed_value, 115, -0.03, 0.03)
	var ledge := false

	if not root:
		if variant == 0:
			# Broad face turned gently toward the left.
			r0_front = [Vector2(-0.52, 0.27), Vector2(-0.29, 0.46), Vector2(0.04, 0.49), Vector2(0.31, 0.45), Vector2(0.52, 0.27)]
			r1_front = [Vector2(-0.52, 0.40), Vector2(-0.38, 0.511), Vector2(0.04, 0.549), Vector2(0.38, 0.579), Vector2(0.52, 0.43)]
			# Upper face plumb, one quiet break into a leaning lower face.
			y2 = -0.36
			y3 = -0.62
			s12 = 1.0; s23 = 0.93
			s35 = 0.62
			apex_bot_y = -1.15
		elif variant == 1:
			# Mirror: broad face turned toward the right.
			r0_front = [Vector2(-0.52, 0.27), Vector2(-0.31, 0.45), Vector2(-0.04, 0.49), Vector2(0.29, 0.46), Vector2(0.52, 0.27)]
			r1_front = [Vector2(-0.52, 0.43), Vector2(-0.38, 0.579), Vector2(-0.04, 0.549), Vector2(0.38, 0.511), Vector2(0.52, 0.40)]
			y2 = -0.50
			y3 = -0.80
			s12 = 0.965; s23 = 0.985
			s35 = 0.54
			apex_bot_y = -1.14
		elif variant == 2:
			# Flat-fronted slab with one narrow stepped ledge (阶梯断层) that
			# catches a single horizontal line of light across the face.
			r0_front = [Vector2(-0.52, 0.27), Vector2(-0.30, 0.46), Vector2(-0.02, 0.48), Vector2(0.30, 0.45), Vector2(0.52, 0.27)]
			r1_front = [Vector2(-0.52, 0.42), Vector2(-0.38, 0.56), Vector2(-0.02, 0.56), Vector2(0.38, 0.56), Vector2(0.52, 0.42)]
			s12 = 0.99; s23 = 0.97
			y2 = -0.42
			ledge = true
			apex_bot_y = -1.08
		else:
			# Two broad planes meeting on a soft central prow (keel lobes).
			r0_front = [Vector2(-0.52, 0.27), Vector2(-0.30, 0.45), Vector2(0.02, 0.49), Vector2(0.30, 0.45), Vector2(0.52, 0.27)]
			r1_front = [Vector2(-0.52, 0.38), Vector2(-0.38, 0.50), Vector2(0.02, 0.605), Vector2(0.38, 0.50), Vector2(0.52, 0.38)]
			s12 = 0.98; s23 = 0.95
			s35 = 0.56
			apex_bot_y = -1.20
	else:
		# Stepped ledge buttress: proud flat bench top over one broad face and
		# a deep tapering wedge; mossy turf reads on its bench in the shader.
		var side_sign: float = 1.0 if (variant & 1) == 0 else -1.0
		r0_front = [Vector2(-0.48, 0.30), Vector2(-0.29, 0.47), Vector2(0.03 * side_sign, 0.52), Vector2(0.29, 0.47), Vector2(0.48, 0.30)]
		r0_y = [0.00, 0.02, 0.04, 0.02, 0.00]
		var lean := 0.05 * side_sign
		r1_front = [Vector2(-0.51, 0.33), Vector2(-0.37, 0.56 - lean * 0.37), Vector2(0.06 * side_sign, 0.56 + lean * 0.06 * side_sign), Vector2(0.37, 0.56 + lean * 0.37), Vector2(0.51, 0.33)]
		y1 = -0.12
		y2 = -0.42
		y3 = -0.74
		s12 = 0.98; s23 = 0.94
		s35 = 0.34
		t4 = 0.50
		apex_bot_y = -1.12
		apex_bot_z = -0.10

	var y5 := apex_bot_y + 0.09
	var front_rings: Array = []
	var r0: Array = []
	for k in FRONT_COLS:
		var p2: Vector2 = r0_front[k]
		r0.append(Vector3(p2.x, float(r0_y[k]), p2.y))
	front_rings.append(r0)
	var r1 := _ring_from(r1_front, y1)
	var r2 := _scaled(r1, s12, y2)
	if ledge:
		var r3l := _scaled(r2, 0.91, y2 - 0.035)
		var r4l := _scaled(r3l, s23, y3 - 0.06)
		var r5l := _scaled(r4l, s35 * 1.04, y5, keel_x)
		front_rings.append_array([r1, r2, r3l, r4l, r5l])
	else:
		var r3 := _scaled(r2, s23, y3)
		var r5 := _scaled(r3, s35, y5, keel_x)
		var r4 := _lerp_ring(r3, r5, t4)
		front_rings.append_array([r1, r2, r3, r4, r5])

	var back_scales: Array[float] = [1.0, 1.0, 1.0, 0.98, 0.90, 0.78]
	var rings: Array = []
	for r_idx in NUM_RINGS:
		var b_scale: float = back_scales[r_idx]
		var ring: Array[Vector3] = []
		for p: Vector3 in front_rings[r_idx]:
			ring.append(p)
		var yc_back: float = ring[0].y
		var back_w: float = 0.49 * b_scale
		var back_z: float = -0.44 * b_scale
		ring.append(Vector3(back_w, yc_back, -0.06 * b_scale))
		ring.append(Vector3(0.0, yc_back, back_z))
		ring.append(Vector3(-back_w, yc_back, -0.06 * b_scale))
		rings.append(ring)

	var r_first: Array[Vector3] = rings[0]
	var r_last: Array[Vector3] = rings[rings.size() - 1]
	var apex_top := Vector3(0.0, 0.08, 0.08) if root else Vector3(0.0, 0.0, 0.02)
	var apex_bot := Vector3(keel_x, apex_bot_y, apex_bot_z)
	var block_tone: float = [0.012, -0.018, 0.022, -0.008][variant] + _s(seed_value, 77, -0.006, 0.006)

	for target_idx in 2:
		var s: Geometry.Surface = builder if target_idx == 0 else render_builder
		var include_caps: bool = (target_idx == 0) or root

		if include_caps:
			for i in RING_SIZE:
				var ni := (i + 1) % RING_SIZE
				var out_top := ((r_first[i] + r_first[ni]) * 0.5 - apex_top).normalized() + Vector3.UP * 2.2
				var top_sh := 0.724 if root else 0.736
				var top_uv := Vector2(0.42, 0.04 if root else 0.0)
				var top_col := _facet_color(seed_value, 100, top_sh + block_tone, 0.0)
				_add_tri(s, apex_top, r_first[i], r_first[ni], top_col, out_top, top_uv)

		for r_idx in range(rings.size() - 1):
			var curr: Array[Vector3] = rings[r_idx]
			var next: Array[Vector3] = rings[r_idx + 1]
			for i in RING_SIZE:
				var ni := (i + 1) % RING_SIZE
				var a := curr[i]
				var b := curr[ni]
				var c := next[ni]
				var d := next[i]
				var mid := (a + b + c + d) * 0.25
				var outward := Vector3(mid.x * 0.32, 0.0, mid.z).normalized()
				if i >= FRONT_COLS - 1:
					outward = Vector3(mid.x, 0.0, mid.z).normalized()

				var is_side_bevel: bool = (i == 0 or i == FRONT_COLS - 2)
				var is_back: bool = i >= FRONT_COLS - 1
				var is_crown_band: bool = (r_idx == 0)
				var is_lower_taper: bool = (r_idx >= 3)

				# One tone per band so coplanar quads merge into a single broad face.
				var base_sh := 0.716
				if is_crown_band:
					base_sh = 0.728 if root else 0.736
				elif is_lower_taper:
					base_sh = 0.696
				if is_side_bevel or is_back:
					base_sh -= 0.030
				base_sh += block_tone
				var crease := 0.0
				if is_side_bevel and not is_crown_band:
					crease = 0.10
				elif root and is_lower_taper:
					crease = 0.12
				var uv_meta := Vector2(0.72 if is_crown_band else 0.30, crease)
				var col := _facet_color(seed_value, 500, base_sh, 0.0)

				var use_ac: bool = a.distance_squared_to(c) <= b.distance_squared_to(d)
				if is_side_bevel:
					use_ac = (i == 0)
				# Exactly planar quads: both triangles share one flat normal.
				_add_quad(s, a, b, c, d, col, col, outward, uv_meta, use_ac, 1.0)

		if include_caps:
			for i in RING_SIZE:
				var ni := (i + 1) % RING_SIZE
				var out_bot := ((r_last[i] + r_last[ni]) * 0.5 - apex_bot).normalized() + Vector3.DOWN * 2.0
				_add_tri(s, apex_bot, r_last[ni], r_last[i], _facet_color(seed_value, 800, 0.69 + block_tone, 0.0), out_bot, Vector2(0.18, 0.12))

	var mesh: ArrayMesh = builder.mesh()
	var render_mesh: ArrayMesh = render_builder.mesh()
	var box: AABB = mesh.get_aabb()
	var cap_poly := PackedVector2Array()
	for p3: Vector3 in r_first:
		cap_poly.append(Vector2(p3.x, p3.z))

	return {
		"mesh": mesh,
		"render_mesh": render_mesh,
		"height": 1.0,
		"geometry_height": box.size.y,
		"crown_z": 0.42,
		"span_x": box.size.x,
		"span_z": box.size.z,
		"cap_polygon": cap_poly,
	}
