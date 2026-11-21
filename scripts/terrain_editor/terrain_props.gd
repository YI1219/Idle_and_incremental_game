class_name TerrainProps
extends Node3D
## Oriental floating-island signature landmarks anchored to authoritative editable terrain:
## 1. TaihuScholarRock  — Sculpted perforated Taihu limestone peak (太湖奇石立峰)
## 2. BambooGrove       — Slender segmented green bamboo cluster (潇湘疏竹)
## 3. InkStoneDaybed    — Sleek rounded-bevel dark ink-celadon stone daybed (乌石琴榻)
## 4. SongStoneLantern  — Low carved hexagonal Song-style garden stone lantern (宋式青石灯笼)
const TAIHU_GLB := "res://assets/props/taihu_scholar_rock.glb"
const DAYBED_GLB := "res://assets/props/ink_stone_daybed.glb"
const LANTERN_GLB := "res://assets/props/song_stone_lantern.glb"
const PAVILION_GLB := "res://assets/props/courtyard_pavilion_v2.glb"

var entries: Array = []
var _vertex_mat: ShaderMaterial
var _bamboo_mat: ShaderMaterial
var _taihu_mat: ShaderMaterial
var _daybed_mat: ShaderMaterial
var _pavilion_entry: Dictionary = {}

func _ready() -> void:
	_vertex_mat = ShaderMaterial.new()
	_vertex_mat.shader = preload("res://shaders/terrain_editor/decor_vertex_color.gdshader")
	_vertex_mat.set_shader_parameter("linear_vertex_color", false)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(_vertex_mat)

	_bamboo_mat = ShaderMaterial.new()
	_bamboo_mat.shader = preload("res://shaders/terrain_editor/decor_vertex_color.gdshader")
	_bamboo_mat.set_shader_parameter("linear_vertex_color", false)
	_bamboo_mat.set_shader_parameter("sway_strength", 0.085)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(_bamboo_mat)

	_taihu_mat = ShaderMaterial.new()
	_taihu_mat.shader = preload("res://shaders/terrain_editor/cliff_rock.gdshader")
	_taihu_mat.set_shader_parameter("bank_stone", 0.0)
	_taihu_mat.set_shader_parameter("prop_kind", 0.0)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(_taihu_mat)

	_daybed_mat = ShaderMaterial.new()
	_daybed_mat.shader = preload("res://shaders/terrain_editor/cliff_rock.gdshader")
	_daybed_mat.set_shader_parameter("bank_stone", 0.0)
	_daybed_mat.set_shader_parameter("prop_kind", 3.0)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(_daybed_mat)

	# 1. Upper-left focal landmark: Perforated Taihu Scholar's Rock (太湖奇石)
	var taihu := _spawn_glb_prop("TaihuScholarRock", TAIHU_GLB, _taihu_mat)
	taihu.rotation.y = 0.28
	taihu.scale = Vector3(1.28, 1.40, 1.28)
	entries.append({"node": taihu, "at": Vector2(-9.6, -5.4), "radius": 0.92})

	# 2. Upper-left companion: Graceful slender green Bamboo Grove (潇湘疏竹)
	var bamboo := _build_bamboo_grove()
	bamboo.rotation.y = 0.14
	entries.append({"node": bamboo, "at": Vector2(-7.2, -6.5), "radius": 0.86})

	# 3. Right waterside terrace: Carved Song-style celadon-limestone garden bench (宋式青白石琴榻)
	var daybed := _spawn_glb_prop("InkStoneDaybed", DAYBED_GLB, _daybed_mat)
	daybed.rotation.y = -0.28
	entries.append({"node": daybed, "at": Vector2(10.7, -2.0), "radius": 1.05})

	# 4. Right beside daybed: Low carved hexagonal Song Stone Lantern (宋式青石矮灯)
	var lantern := _spawn_glb_prop("SongStoneLantern", LANTERN_GLB, _vertex_mat)
	lantern.rotation.y = 0.26
	entries.append({"node": lantern, "at": Vector2(12.4, -2.35), "radius": 0.42})

func apply_style_preset(_idx: int, p: Dictionary) -> void:
	for smat: ShaderMaterial in [_taihu_mat, _daybed_mat]:
		if smat == null:
			continue
		if p.has("stone_shadow"):
			smat.set_shader_parameter("stone_shadow_color", p["stone_shadow"])
		if p.has("stone_mid"):
			smat.set_shader_parameter("stone_mid_color", p["stone_mid"])
		if p.has("stone_lit"):
			smat.set_shader_parameter("stone_lit_color", p["stone_lit"])
		if p.has("stone_mist"):
			smat.set_shader_parameter("stone_mist_color", p["stone_mist"])
	for mat: ShaderMaterial in [_vertex_mat, _bamboo_mat]:
		if mat == null:
			continue
		if p.has("decor_shadow"):
			mat.set_shader_parameter("decor_sky_shadow", p["decor_shadow"])
		if p.has("decor_lit"):
			mat.set_shader_parameter("decor_sky_lit", p["decor_lit"])
		if p.has("lantern_glow"):
			mat.set_shader_parameter("lantern_glow_strength", float(p["lantern_glow"]))
		if p.has("lantern_color"):
			mat.set_shader_parameter("lantern_glow_color", p["lantern_color"])

func set_pavilion_enabled(enabled: bool, field = null) -> void:
	if enabled:
		if _pavilion_entry.is_empty():
			var pav := _spawn_glb_prop("CourtyardPavilion", PAVILION_GLB, _vertex_mat)
			pav.rotation.y = 0.20
			_pavilion_entry = {"node": pav, "at": Vector2(-10.8, -9.2), "radius": 1.85, "footprint": Vector2(1.85, 1.45)}
			entries.append(_pavilion_entry)
	else:
		if not _pavilion_entry.is_empty():
			entries.erase(_pavilion_entry)
			if is_instance_valid(_pavilion_entry.node):
				_pavilion_entry.node.free()
			_pavilion_entry = {}
	if field != null:
		sync(field)

func _spawn_glb_prop(node_name: String, glb_path: String, override_mat: Material = null) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	var root_inst: Node = null
	var abs_path := ProjectSettings.globalize_path(glb_path)
	if node_name == "InkStoneDaybed" and FileAccess.file_exists(abs_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(abs_path, state) == OK:
			root_inst = doc.generate_scene(state)
	if root_inst == null and ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			root_inst = packed.instantiate()
	if root_inst == null:
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(abs_path, state) == OK:
				root_inst = doc.generate_scene(state)
	if root_inst != null:
		var mesh_inst := _find_first_mesh(root_inst)
		if mesh_inst != null and mesh_inst.mesh != null:
			var single := MeshInstance3D.new()
			single.name = "Mesh"
			var built_mesh: Mesh = mesh_inst.mesh.duplicate()
			if node_name in ["SongStoneLantern", "TaihuScholarRock", "InkStoneDaybed"]:
				built_mesh = _bake_prop_vertex_attributes(node_name, built_mesh)
			single.mesh = built_mesh
			var use_mat: Material = override_mat if override_mat != null else _vertex_mat
			for s in single.mesh.get_surface_count():
				single.mesh.surface_set_material(s, use_mat)
			holder.add_child(single)
		root_inst.free()
	return holder

static func _bake_prop_vertex_attributes(node_name: String, src_mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var arrays: Array = src_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array()
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		cols.resize(verts.size())
		uvs.resize(verts.size())
		if node_name == "SongStoneLantern":
			for i in verts.size():
				var v: Vector3 = verts[i]
				var r_xz := Vector2(v.x, v.z).length()
				var is_core: bool = v.y >= 0.43 and v.y <= 0.69 and r_xz < 0.145
				if is_core:
					cols[i] = Color(0.96, 0.87, 0.66, 1.0)
					uvs[i] = Vector2(clampf(v.y, 0.0, 1.0), 0.96)
				else:
					var shade := clampf(0.88 + 0.16 * clampf(v.y / 1.05, 0.0, 1.0), 0.84, 1.04)
					cols[i] = Color(0.55 * shade, 0.57 * shade, 0.54 * shade, 1.0)
					uvs[i] = Vector2(clampf(v.y, 0.0, 1.0), 0.10)
		elif node_name == "InkStoneDaybed":
			for i in verts.size():
				var v: Vector3 = verts[i]
				var ny: float = nrms[i].y if i < nrms.size() else 0.0
				var is_slab: bool = v.y >= 0.37
				var is_waist: bool = v.y >= 0.30 and v.y < 0.37
				var cav := 0.04 if is_slab else (0.38 if is_waist else lerpf(0.28, 0.14, clampf(v.y / 0.30, 0.0, 1.0)))
				if ny < -0.35:
					cav = clampf(cav + 0.24, 0.0, 0.72)
				var val := 0.66 if is_slab else (0.52 if is_waist else lerpf(0.50, 0.60, clampf(v.y / 0.30, 0.0, 1.0)))
				cols[i] = Color(val, val, val, 1.0)
				uvs[i] = Vector2(clampf(v.y / 0.51, 0.0, 1.0), cav)
		else:
			# TaihuScholarRock: grounded weathered celadon-grey limestone + deep chiseled cavities (瘦皱漏透苍青奇石)
			var holes := [Vector3(0.06, 0.78, 0.0), Vector3(-0.09, 1.54, 0.0), Vector3(-0.18, 1.16, -0.18)]
			for i in verts.size():
				var v: Vector3 = verts[i]
				var cav := 1.0
				for hc: Vector3 in holes:
					var d := Vector2(v.x - hc.x, (v.y - hc.y) * 0.82).length()
					cav = minf(cav, smoothstep(0.05, 0.36, d))
				var plinth_dark := 0.84 if v.y < 0.22 else 1.0
				var val := lerpf(0.32, 0.58, cav) * plinth_dark
				cols[i] = Color(val, val, val, 1.0)
				uvs[i] = Vector2(clampf(v.y / 2.3, 0.0, 1.0), (1.0 - cav) * 0.76)
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null

func sync(field) -> void:
	for entry: Dictionary in entries:
		var at: Vector2 = entry.at
		var sample: Dictionary = field.surface_at(at)
		var supported: bool = not sample.is_empty() and sample.water < 0
		if supported:
			var radius: float = entry.radius
			var footprint: Vector2 = entry.get("footprint", Vector2.ONE * radius)
			var steps := ceili(maxf(footprint.x, footprint.y) * 4)
			for z in range(steps + 1):
				for x in range(steps + 1):
					var point := at + Vector2(lerpf(-footprint.x, footprint.x, float(x) / steps), lerpf(-footprint.y, footprint.y, float(z) / steps))
					var support: Dictionary = field.surface_at(point)
					if support.is_empty() or support.water >= 0 or absf(support.height - sample.height) > .01:
						supported = false
						break
				if not supported:
					break
		entry.node.visible = supported
		if supported:
			entry.node.position = Vector3(at.x, sample.height, at.y)

func _build_bamboo_grove() -> Node3D:
	# Poetic 11-culm Oriental Bamboo Grove (潇湘疏竹): slender segmented jade-green culms
	# gently arcing outward, adorned with airy wind-swaying lanceolate bamboo leaf sprays.
	var holder := Node3D.new()
	holder.name = "BambooGrove"
	add_child(holder)
	var builder = preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()

	var culm_specs: Array = [
		[Vector2( 0.00,  0.00), 4.25, 0.027, Vector2(-0.14,  0.08)],
		[Vector2(-0.34,  0.16), 3.95, 0.025, Vector2(-0.32,  0.16)],
		[Vector2( 0.36,  0.12), 4.10, 0.026, Vector2( 0.30,  0.12)],
		[Vector2(-0.18, -0.32), 3.65, 0.023, Vector2(-0.22, -0.24)],
		[Vector2( 0.24, -0.28), 3.80, 0.024, Vector2( 0.26, -0.22)],
		[Vector2(-0.56, -0.08), 3.35, 0.021, Vector2(-0.42, -0.06)],
		[Vector2( 0.58, -0.04), 3.45, 0.022, Vector2( 0.44, -0.04)],
		[Vector2(-0.42,  0.44), 3.15, 0.020, Vector2(-0.34,  0.34)],
		[Vector2( 0.12,  0.46), 3.55, 0.022, Vector2( 0.14,  0.36)],
		[Vector2( 0.48,  0.38), 2.95, 0.019, Vector2( 0.38,  0.30)],
		[Vector2(-0.08, -0.54), 3.05, 0.019, Vector2(-0.10, -0.38)],
	]

	var c_culm_low := Color(0.22, 0.34, 0.18)
	var c_culm_high := Color(0.33, 0.46, 0.23)
	var c_node_ring := Color(0.17, 0.27, 0.14)
	var c_leaf_dark := Color(0.18, 0.30, 0.16)
	var c_leaf_lit := Color(0.35, 0.47, 0.24)

	const SIDES := 7
	const NODES := 10
	for c_idx in culm_specs.size():
		var spec: Array = culm_specs[c_idx]
		var base2: Vector2 = spec[0]
		var h_max: float = float(spec[1])
		var r_base: float = float(spec[2])
		var lean2: Vector2 = spec[3]

		var prev_ring: Array[Vector3] = []
		var prev_n: Array[Vector3] = []
		var prev_col := c_culm_low
		var prev_uv := Vector2(0.0, 0.1)

		for n_i in range(NODES + 1):
			var t := float(n_i) / float(NODES)
			var bend := pow(t, 1.85)
			var center := Vector3(base2.x + lean2.x * bend, h_max * t, base2.y + lean2.y * bend)
			var r := lerpf(r_base, r_base * 0.38, pow(t, 0.82))
			var ring: Array[Vector3] = []
			var norms: Array[Vector3] = []
			for s in SIDES:
				var a := TAU * float(s) / float(SIDES) + float(c_idx) * 0.5
				var n_dir := Vector3(cos(a), 0.0, sin(a))
				ring.append(center + n_dir * r)
				norms.append(n_dir)
			var col := c_culm_low.lerp(c_culm_high, t)
			var uv_cur := Vector2(clampf(center.y / 4.3, 0.0, 1.0), 0.20)
			if n_i > 0:
				for s in SIDES:
					var ns := (s + 1) % SIDES
					_emit_bamboo_quad(builder, prev_ring[s], prev_ring[ns], ring[ns], ring[s], prev_n[s], prev_n[ns], norms[ns], norms[s], prev_col, col, prev_uv, uv_cur)
				# Subtle raised bamboo node collar
				if n_i < NODES:
					var nr := r * 1.18
					for s in SIDES:
						var ns := (s + 1) % SIDES
						var a0 := TAU * float(s) / float(SIDES) + float(c_idx) * 0.5
						var a1 := TAU * float(ns) / float(SIDES) + float(c_idx) * 0.5
						var d0 := Vector3(cos(a0), 0.15, sin(a0)).normalized()
						var d1 := Vector3(cos(a1), 0.15, sin(a1)).normalized()
						var p0 := center + Vector3(cos(a0) * nr, 0.0, sin(a0) * nr)
						var p1 := center + Vector3(cos(a1) * nr, 0.0, sin(a1) * nr)
						_emit_bamboo_quad(builder, ring[s], ring[ns], p1, p0, d0, d1, d1, d0, c_node_ring, c_node_ring, uv_cur, uv_cur)

			# Radiating graceful bamboo leaf sprays on upper half (t >= 0.42)
			if n_i >= 4:
				var twigs := 2 if n_i < NODES else 3
				for tw in twigs:
					var ta := float(c_idx) * 2.1 + float(n_i) * 2.35 + float(tw) * 2.65
					var t_dir := Vector3(cos(ta), 0.24 - 0.08 * float(tw), sin(ta)).normalized()
					var twig_end := center + t_dir * lerpf(0.28, 0.44, float((n_i + tw) % 3) * 0.5)
					for lf in 4:
						var fan := (float(lf) - 1.5) * 0.46
						var l_dir := (Basis(Vector3.UP, fan) * t_dir + Vector3(0.0, -0.18 - 0.06 * absf(fan), 0.0)).normalized()
						var l_side := l_dir.cross(Vector3.UP).normalized()
						if l_side.length_squared() < 1e-4:
							l_side = Vector3.RIGHT
						var l_len := lerpf(0.28, 0.40, float((c_idx + lf) % 3) * 0.5)
						var l_wid := 0.042
						var root_p := center.lerp(twig_end, 0.55 + 0.15 * float(lf % 2))
						var mid_p := root_p + l_dir * (l_len * 0.46) + Vector3(0.0, 0.015, 0.0)
						var tip_p := root_p + l_dir * l_len - Vector3(0.0, 0.035, 0.0)
						var p_l := mid_p - l_side * l_wid
						var p_r := mid_p + l_side * l_wid
						var up_n := (Vector3.UP * 0.78 + t_dir * 0.22).normalized()
						var l_col := c_leaf_dark.lerp(c_leaf_lit, clampf(t * 0.75 + 0.25 * float(lf % 2), 0.0, 1.0))
						var l_uv := Vector2(clampf(tip_p.y / 4.3, 0.0, 1.0), 0.65)
						_emit_bamboo_leaf(builder, root_p, p_l, p_r, tip_p, up_n, l_col, l_uv)

			prev_ring = ring
			prev_n = norms
			prev_col = col
			prev_uv = uv_cur

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var m: ArrayMesh = builder.mesh()
	m.surface_set_material(0, _bamboo_mat)
	mesh_inst.mesh = m
	holder.add_child(mesh_inst)
	return holder

static func _emit_bamboo_quad(builder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, col0: Color, col1: Color, uv0: Vector2, uv1: Vector2) -> void:
	var fn := -(b - a).cross(c - a)
	if fn.dot(na + nb + nc + nd) < 0.0:
		for item: Array in [[a, na, col0, uv0], [c, nc, col1, uv1], [b, nb, col0, uv0], [a, na, col0, uv0], [d, nd, col1, uv1], [c, nc, col1, uv1]]:
			builder.vertices.append(item[0]); builder.normals.append(item[1]); builder.colors.append(item[2]); builder.uv.append(item[3])
	else:
		for item: Array in [[a, na, col0, uv0], [b, nb, col0, uv0], [c, nc, col1, uv1], [a, na, col0, uv0], [c, nc, col1, uv1], [d, nd, col1, uv1]]:
			builder.vertices.append(item[0]); builder.normals.append(item[1]); builder.colors.append(item[2]); builder.uv.append(item[3])

static func _emit_bamboo_leaf(builder, root_p: Vector3, p_l: Vector3, p_r: Vector3, tip_p: Vector3, up_n: Vector3, col: Color, uv: Vector2) -> void:
	# Double-sided slender bamboo blade with soft sky-biased normal
	for tri: Array in [[root_p, p_l, tip_p], [root_p, tip_p, p_r], [root_p, tip_p, p_l], [root_p, p_r, tip_p]]:
		for v: Vector3 in tri:
			builder.vertices.append(v)
			builder.normals.append(up_n)
			builder.colors.append(col)
			builder.uv.append(uv)
