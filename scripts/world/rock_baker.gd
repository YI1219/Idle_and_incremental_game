extends Object
## Convex-hull CSG union of rock-kit instances, trimmed at the grass plane.
## CSG/Manifold is off-tree and main-thread only; a worker call deadlocks.

const RockKit := preload("res://scripts/world/rock_kit.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")

const GROUND_Y := 0.0
const CHUNK := 8.0
const GROUND_EPS := 0.08


static func prepare(state: Dictionary) -> Dictionary:
	RockKit.ensure()
	var hulls: Dictionary = {}
	for slot in state.get("slots", []):
		var name := String(slot["piece"])
		if hulls.has(name):
			continue
		var row: Dictionary = RockKit.piece(name)
		var hull: ArrayMesh = row.get("hull")
		if hull == null:
			hull = row.get("mesh")
		hulls[name] = hull
	return {
		"slots": state.get("slots", []),
		"hulls": hulls,
		"ground_y": GROUND_Y,
	}


static func bake_job(payload: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var result := _bake(payload)
	result["bake_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	if payload.has("serial"):
		result["serial"] = int(payload["serial"])
	return result


static func bake_job_into(payload: Dictionary, box: Array) -> void:
	box.append(bake_job(payload))


static func bake(state: Dictionary) -> Dictionary:
	return bake_job(prepare(state))


static func make_mesh(result: Dictionary) -> ArrayMesh:
	var verts: PackedVector3Array = result.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return _empty()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var norms: PackedVector3Array = result.get("normals", PackedVector3Array())
	var colors: PackedColorArray = result.get("colors", PackedColorArray())
	for i in verts.size():
		if i < norms.size():
			st.set_normal(norms[i])
		if i < colors.size():
			st.set_color(colors[i])
		st.add_vertex(verts[i])
	return st.commit()


static func max_y(result: Dictionary) -> float:
	var hi := -INF
	for v in result.get("vertices", PackedVector3Array()):
		hi = maxf(hi, v.y)
	return hi if hi > -INF else 0.0


static func boundary_report(result: Dictionary) -> Dictionary:
	var mesh := make_mesh(result)
	return _boundary_report(mesh)


static func is_valid_union(result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		return false
	if int(result.get("triangles", 0)) < 12:
		return false
	if max_y(result) > 0.04:
		return false
	var report := boundary_report(result)
	if int(report.get("nonmanifold", 1)) > 0:
		return false
	if int(report.get("odd_not_ground", 1)) > 0:
		return false
	return int(report.get("odd", 1)) == 0 or int(report.get("ground_odd", 0)) == int(report.get("odd", 0))


static func is_closed_enough(result: Dictionary) -> bool:
	return is_valid_union(result)


static func has_no_interior_proxy(result: Dictionary) -> bool:
	return is_valid_union(result)


static func _bake(payload: Dictionary) -> Dictionary:
	var slots: Array = payload.get("slots", [])
	var hulls: Dictionary = payload.get("hulls", {})
	var ground := float(payload.get("ground_y", GROUND_Y))
	var empty := {
		"ok": false, "vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "triangles": 0, "chunks": 0, "max_y": 0.0,
	}
	if slots.is_empty() or hulls.is_empty():
		return empty
	var world := AABB()
	var first := true
	var items: Array = []
	for slot in slots:
		var hull: ArrayMesh = hulls.get(String(slot["piece"]))
		if hull == null or hull.get_surface_count() == 0:
			continue
		var xf: Transform3D = slot["xf"]
		var box := hull.get_aabb()
		for x in 2:
			for y in 2:
				for z in 2:
					var corner: Vector3 = xf * (box.position + box.size * Vector3(x, y, z))
					if first:
						world = AABB(corner, Vector3.ZERO)
						first = false
					else:
						world = world.expand(corner)
		items.append({"mesh": hull, "xf": xf, "jitter": float(slot.get("jitter", 0.5))})
	if items.is_empty() or first:
		return empty
	var baked := _csg_union(items, world, ground)
	if baked == null or baked.get_surface_count() == 0:
		return empty
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	_emit_flat(baked, ground, vertices, normals, colors)
	var chunks := maxi(1, int(ceil(world.size.x / CHUNK)) * int(ceil(world.size.z / CHUNK)))
	var result := {
		"ok": vertices.size() >= 12,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"triangles": int(vertices.size() / 3),
		"chunks": chunks,
		"max_y": _max_of(vertices),
	}
	result["ok"] = is_valid_union(result)
	return result


static func _csg_union(items: Array, world: AABB, ground: float) -> ArrayMesh:
	var comb := CSGCombiner3D.new()
	for item in items:
		var node := CSGMesh3D.new()
		node.mesh = item["mesh"]
		node.transform = item["xf"]
		node.operation = CSGShape3D.OPERATION_UNION
		comb.add_child(node)
	var mid := world.position + world.size * 0.5
	var cut := CSGBox3D.new()
	cut.size = Vector3(world.size.x + 16.0, 24.0, world.size.z + 16.0)
	cut.position = Vector3(mid.x, ground + 12.0, mid.z)
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	comb.add_child(cut)
	comb._update_shape()
	var baked: ArrayMesh = comb.bake_static_mesh()
	comb.free()
	return baked


static func _emit_flat(mesh: ArrayMesh, ground: float, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		a.y = minf(a.y, ground)
		b.y = minf(b.y, ground)
		c.y = minf(c.y, ground)
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		n = n.normalized()
		var mid := (a + b + c) / 3.0
		# Grass is the visible cap; drop the CSG lid so it cannot z-fight.
		if mid.y > ground - 0.03 and n.y > 0.55:
			continue
		var jitter := fposmod(absf(mid.x * 12.9898 + mid.z * 78.233), 1.0)
		var col := Color(jitter, 0.0, 0.0)
		for p in [a, b, c]:
			normals.append(n)
			colors.append(col)
			vertices.append(p)


static func _boundary_report(mesh: ArrayMesh) -> Dictionary:
	var empty := {"odd": 1, "ground_odd": 0, "odd_not_ground": 1, "nonmanifold": 1, "edges": 0}
	if mesh == null or mesh.get_surface_count() == 0:
		return empty
	var faces := mesh.get_faces()
	if faces.size() < 12:
		return empty
	var counts: Dictionary = {}
	for i in range(0, faces.size(), 3):
		IslandGeometry._count_edge(counts, faces[i], faces[i + 1])
		IslandGeometry._count_edge(counts, faces[i + 1], faces[i + 2])
		IslandGeometry._count_edge(counts, faces[i + 2], faces[i])
	var odd := 0
	var ground_odd := 0
	var odd_not_ground := 0
	var nonmanifold := 0
	var edges := 0
	for key in counts.keys():
		var n := int(counts[key])
		if n == 2:
			edges += 1
			continue
		edges += 1
		if n > 2:
			nonmanifold += 1
			continue
		odd += 1
		var ends: PackedStringArray = String(key).split("|")
		if ends.size() == 2 and _key_on_ground(ends[0]) and _key_on_ground(ends[1]):
			ground_odd += 1
		else:
			odd_not_ground += 1
	return {
		"odd": odd,
		"ground_odd": ground_odd,
		"odd_not_ground": odd_not_ground,
		"nonmanifold": nonmanifold,
		"edges": edges,
	}


static func _key_on_ground(key: String) -> bool:
	var parts := key.split(",")
	if parts.size() < 2:
		return false
	var y := float(parts[1]) / 250.0
	return absf(y - GROUND_Y) <= GROUND_EPS


static func _max_of(verts: PackedVector3Array) -> float:
	var hi := -INF
	for v in verts:
		hi = maxf(hi, v.y)
	return hi if hi > -INF else 0.0


static func _empty() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st.commit()
