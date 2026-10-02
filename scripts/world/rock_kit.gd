extends Object
## Load, flip, and recentre the CC0 rock kit once. Game code ignores source textures.

const PIECES := [
	{"name": "K_Rock_2_H", "path": "res://assets/rockkit/kaykit/Rock_2_H_Color1.gltf", "role": "block"},
	{"name": "K_Rock_2_E", "path": "res://assets/rockkit/kaykit/Rock_2_E_Color1.gltf", "role": "block"},
	{"name": "K_Rock_3_Q", "path": "res://assets/rockkit/kaykit/Rock_3_Q_Color1.gltf", "role": "round"},
	{"name": "Q_Rock_Medium_1", "path": "res://assets/rockkit/quaternius/Rock_Medium_1.gltf", "role": "round"},
	{"name": "Q_Rock_Medium_3", "path": "res://assets/rockkit/quaternius/Rock_Medium_3.gltf", "role": "round"},
	{"name": "K_Rock_3_O", "path": "res://assets/rockkit/kaykit/Rock_3_O_Color1.gltf", "role": "mid"},
	{"name": "K_Rock_3_K", "path": "res://assets/rockkit/kaykit/Rock_3_K_Color1.gltf", "role": "mid"},
	{"name": "K_Rock_3_G", "path": "res://assets/rockkit/kaykit/Rock_3_G_Color1.gltf", "role": "mid"},
	{"name": "K_Rock_1_K", "path": "res://assets/rockkit/kaykit/Rock_1_K_Color1.gltf", "role": "tip"},
	{"name": "K_Rock_1_O", "path": "res://assets/rockkit/kaykit/Rock_1_O_Color1.gltf", "role": "tip"},
]

static var _ready := false
static var catalog: Dictionary = {}
static var names: PackedStringArray = PackedStringArray()
static var root_mesh: ArrayMesh
static var rock_material: ShaderMaterial
static var root_material: ShaderMaterial


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	rock_material = ShaderMaterial.new()
	rock_material.shader = load("res://shaders/world/island_rock.gdshader")
	rock_material.set_shader_parameter("ground_y", -0.08)
	root_material = ShaderMaterial.new()
	root_material.shader = load("res://shaders/world/island_root.gdshader")
	for row in PIECES:
		var baked := _bake_piece(String(row["path"]))
		if baked.is_empty():
			push_error("Rock kit cannot load %s" % row["path"])
			continue
		baked["role"] = row["role"]
		catalog[row["name"]] = baked
		names.append(String(row["name"]))
	root_mesh = _make_root()


static func pool(spec: String) -> PackedStringArray:
	ensure()
	var out := PackedStringArray()
	for part in spec.split("+"):
		var role := part.strip_edges()
		if role == "rim":
			role = "round"
		for n in names:
			if String(catalog[n]["role"]) == role:
				out.append(n)
	return out


static func piece(name: String) -> Dictionary:
	ensure()
	return catalog.get(name, {})


static func _bake_piece(path: String) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return {}
	var scene := doc.generate_scene(state)
	if scene == null:
		return {}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_emit_node(st, scene, Transform3D.IDENTITY)
	var raw := st.commit()
	scene.free()
	if raw.get_surface_count() == 0:
		return {}
	var faces := raw.get_faces()
	if faces.is_empty():
		return {}
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	# Flip so the sitting base becomes the hanging top; origin = top-centre.
	var flip := Transform3D(Basis.from_euler(Vector3(PI, 0.0, 0.0)), Vector3.ZERO)
	var mid := box.position + box.size * 0.5
	var baked_st := SurfaceTool.new()
	baked_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y := -INF
	var min_xz := Vector2(INF, INF)
	var max_xz := Vector2(-INF, -INF)
	var min_y := INF
	for v in faces:
		var p: Vector3 = flip * (v - Vector3(mid.x, 0.0, mid.z))
		top_y = maxf(top_y, p.y)
		min_y = minf(min_y, p.y)
		min_xz.x = minf(min_xz.x, p.x)
		min_xz.y = minf(min_xz.y, p.z)
		max_xz.x = maxf(max_xz.x, p.x)
		max_xz.y = maxf(max_xz.y, p.z)
	for i in range(0, faces.size(), 3):
		var a: Vector3 = flip * (faces[i] - Vector3(mid.x, 0.0, mid.z)) - Vector3(0.0, top_y, 0.0)
		var b: Vector3 = flip * (faces[i + 1] - Vector3(mid.x, 0.0, mid.z)) - Vector3(0.0, top_y, 0.0)
		var c: Vector3 = flip * (faces[i + 2] - Vector3(mid.x, 0.0, mid.z)) - Vector3(0.0, top_y, 0.0)
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		for p in [a, b, c]:
			baked_st.set_normal(n)
			baked_st.set_color(Color(0.5, 0.0, 0.0))
			baked_st.add_vertex(p)
	var mesh := baked_st.commit()
	var width := maxf(max_xz.x - min_xz.x, max_xz.y - min_xz.y)
	return {
		"mesh": mesh,
		"hull": _convex_hull_mesh(mesh),
		"width": maxf(width, 0.2),
		"height": maxf(top_y - min_y, 0.2),
		"tris": int(faces.size() / 3),
	}


static func _convex_hull_mesh(src: ArrayMesh) -> ArrayMesh:
	var pts := PackedVector3Array()
	for v in src.get_faces():
		pts.append(v)
	if pts.size() < 4:
		return src
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var raw: ArrayMesh = shape.get_debug_mesh()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if raw:
		for s in raw.get_surface_count():
			if raw.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			st.append_from(raw, s, Transform3D.IDENTITY)
	var hull := st.commit()
	return hull if hull.get_surface_count() > 0 else src


static func _emit_node(st: SurfaceTool, node: Node, parent: Transform3D) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			st.append_from(mesh, s, xf)
	for child in node.get_children():
		_emit_node(st, child, xf)


static func _make_root() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var segs := 5
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := -0.04 - 2.35 * t0
		var y1 := -0.04 - 2.35 * t1
		var r0 := lerpf(0.17, 0.022, t0 * t0)
		var r1 := lerpf(0.17, 0.022, t1 * t1)
		var sway0 := sin(t0 * 2.1) * 0.28 + sin(t0 * 3.7) * 0.08
		var sway1 := sin(t1 * 2.1) * 0.28 + sin(t1 * 3.7) * 0.08
		for s in rings:
			var a0 := TAU * float(s) / float(rings)
			var a1 := TAU * float(s + 1) / float(rings)
			var p00 := Vector3(cos(a0) * r0 + sway0, y0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0 + sway0, y0, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1 + sway1, y1, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1 + sway1, y1, sin(a1) * r1)
			_tri(st, p00, p10, p11)
			_tri(st, p00, p11, p01)
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)
