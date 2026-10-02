extends Node3D
## One independent floating island: heightfield data, chunked meshes, cheap far LOD.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")

const FAR_ENTER := 42.0
const FAR_LEAVE := 32.0
const TOP_HZ := 30.0
const SEA_Y := -6.15

var island_hash: int = 0
var cell_count: int = 0
var centroid := Vector3.ZERO
var far: bool = false
var last_settled_minutes: float = 0.0
var field: Heightfield
var skip_top: Dictionary = {}
var last_stroke_ms: float = 0.0
var last_full_ms: float = 0.0
var last_triangles: int = 0
var last_chunks: int = 0
var last_draw_calls: int = 0
var water_info: Dictionary = {}

var _chunks: Dictionary = {}
var _chunk_root: Node3D
var _water_node: MeshInstance3D
var _fall_root: Node3D
var _rock_root: Node3D
var _dress_root: Node3D
var _material: ShaderMaterial
var _water_material: ShaderMaterial
var _fall_material: ShaderMaterial
var _tuft_mm: MultiMeshInstance3D
var _pebble_mm: MultiMeshInstance3D
var _flower_mm: MultiMeshInstance3D
var _shore_mm: MultiMeshInstance3D
var _top_dirty: Dictionary = {}
var _shell_dirty := false
var _top_wait := 0.0
var _tasks: Array = []
var _job_box: Array = []
var _serial := 0
var _blocked: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	if _chunk_root != null:
		return
	_chunk_root = Node3D.new()
	_chunk_root.name = "Chunks"
	add_child(_chunk_root)
	_water_node = MeshInstance3D.new()
	_water_node.name = "Lakes"
	_water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water_node)
	_fall_root = Node3D.new()
	_fall_root.name = "Waterfalls"
	add_child(_fall_root)
	_rock_root = Node3D.new()
	_rock_root.name = "SlopeRocks"
	add_child(_rock_root)
	_dress_root = Node3D.new()
	_dress_root.name = "Dressing"
	add_child(_dress_root)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/world/island_heightfield.gdshader")
	_water_material = _make_water_material()
	_fall_material = _make_fall_material()
	_water_node.material_override = _water_material
	_tuft_mm = _make_mm("GrassTufts", _tuft_mesh(), _mat(Color("5d7a3a")))
	_pebble_mm = _make_mm("Pebbles", _pebble_mesh(), _mat(Color("7a7164")))
	_flower_mm = _make_mm("Flowers", _flower_mesh(), _mat(Color("d8c56a")))
	_shore_mm = _make_mm("ShoreRocks", _shore_mesh(), _mat(Color("6d6458")))


func configure(p_hash: int, p_centroid: Vector3, p_cells: int, p_field: Heightfield, p_skip: Dictionary = {}) -> void:
	_ensure_nodes()
	island_hash = p_hash
	centroid = p_centroid
	cell_count = p_cells
	field = p_field
	skip_top = p_skip.duplicate()
	rebuild_full(true)


func set_material(material: Material) -> void:
	if material is ShaderMaterial:
		_material = material
		_apply_material()


func set_blocked_cells(cells: Dictionary) -> void:
	_blocked = cells.duplicate()


func blocked_cells() -> Dictionary:
	return _blocked


func set_active(active: bool) -> void:
	if active:
		process_mode = Node.PROCESS_MODE_INHERIT
		return
	far = true
	process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED and not far


func update_lod(camera_origin: Vector3) -> bool:
	var distance := Vector2(camera_origin.x - centroid.x, camera_origin.z - centroid.z).length()
	var next_far := far
	if far and distance < FAR_LEAVE:
		next_far = false
	elif not far and distance > FAR_ENTER:
		next_far = true
	if next_far == far:
		return false
	far = next_far
	process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if far:
		_water_node.visible = false
		_fall_root.visible = false
		_rock_root.visible = false
		if _dress_root:
			_dress_root.visible = false
		rebuild_full(true)
	else:
		_water_node.visible = true
		_fall_root.visible = true
		_rock_root.visible = true
		if _dress_root:
			_dress_root.visible = true
		rebuild_full(true)
	return true


func settle(now_minutes: float) -> float:
	var dt := now_minutes - last_settled_minutes
	if dt < 0.0:
		dt = 0.0
	last_settled_minutes = now_minutes
	return dt


func mark_settled(now_minutes: float) -> void:
	last_settled_minutes = now_minutes


func current_volume() -> ArrayMesh:
	var payloads: Array = []
	for key in _chunks:
		var node: MeshInstance3D = _chunks[key]
		if node and node.mesh:
			payloads.append({"mesh": node.mesh})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for key in _chunks:
		var node: MeshInstance3D = _chunks[key]
		if node and node.mesh and node.mesh.get_surface_count() > 0:
			st.append_from(node.mesh, 0, Transform3D.IDENTITY)
	return st.commit()


func flush_bake() -> void:
	flush_rebuild()


func flush_rebuild() -> void:
	_finish_tasks()
	if _shell_dirty or not _top_dirty.is_empty() or _chunks.is_empty():
		rebuild_full(true)


func _process(delta: float) -> void:
	_finish_tasks()
	if _top_dirty.is_empty() or _shell_dirty:
		return
	_top_wait -= delta
	if _top_wait <= 0.0:
		_rebuild_tops(false)
		_top_wait = 1.0 / TOP_HZ


func mark_stroke(rect: Rect2i) -> void:
	var cs := Heightfield.CHUNK
	var x0 := int(floor(float(rect.position.x) / float(cs)))
	var z0 := int(floor(float(rect.position.y) / float(cs)))
	var x1 := int(floor(float(rect.position.x + rect.size.x) / float(cs)))
	var z1 := int(floor(float(rect.position.y + rect.size.y) / float(cs)))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_top_dirty[Vector2i(x, z)] = true
	_shell_dirty = true
	if _top_wait <= 0.0:
		_top_wait = 1.0 / TOP_HZ


func end_stroke() -> void:
	rebuild_full(false)


func rebuild_full(sync: bool = false) -> void:
	if field == null:
		return
	field.apply_coast_smooth()
	_serial += 1
	var t0 := Time.get_ticks_usec()
	var span := HeightfieldMesh.chunk_range(field)
	var jobs: Array = []
	for z in span.y:
		for x in span.x:
			jobs.append(Vector2i(x, z))
	var mode := "lod" if far else "full"
	if sync or far:
		var payloads: Array = []
		for ch in jobs:
			payloads.append(HeightfieldMesh.build_chunk(field, ch, mode, skip_top))
		_apply_payloads(payloads, true)
		last_full_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_top_dirty.clear()
		_shell_dirty = false
		return
	var box := [{"serial": _serial, "jobs": jobs, "mode": mode, "skip": skip_top.duplicate(), "field": field.duplicate_field(), "result": []}]
	_job_box = box
	var task := WorkerThreadPool.add_task(_worker_build.bind(box), true)
	_tasks.append(task)


func _rebuild_tops(sync: bool) -> void:
	if field == null:
		return
	var t0 := Time.get_ticks_usec()
	var jobs: Array = _top_dirty.keys()
	if jobs.is_empty():
		return
	if sync:
		var payloads: Array = []
		for ch in jobs:
			payloads.append(HeightfieldMesh.build_chunk(field, ch, "top", skip_top))
		_apply_payloads(payloads, false)
		last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_top_dirty.clear()
		return
	var box := [{"serial": _serial, "jobs": jobs, "mode": "top", "skip": skip_top.duplicate(), "field": field.duplicate_field(), "result": []}]
	_job_box = box
	var task := WorkerThreadPool.add_task(_worker_build.bind(box), true)
	_tasks.append(task)
	_top_dirty.clear()


static func _worker_build(box: Array) -> void:
	var job: Dictionary = box[0]
	var f: Heightfield = job["field"]
	var skip: Dictionary = job["skip"]
	var mode: String = job["mode"]
	var out: Array = []
	for ch in job["jobs"]:
		out.append(HeightfieldMesh.build_chunk(f, ch, mode, skip))
	job["result"] = out


func _finish_tasks() -> void:
	var left: Array = []
	for task in _tasks:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			if _job_box.size() > 0:
				var job: Dictionary = _job_box[0]
				if int(job.get("serial", -1)) == _serial:
					_apply_payloads(job.get("result", []), String(job.get("mode", "")) != "top")
					if String(job.get("mode", "")) == "top":
						last_stroke_ms = 0.0
		else:
			left.append(task)
	_tasks = left


func _apply_payloads(payloads: Array, with_shell: bool) -> void:
	_ensure_nodes()
	var tris := 0
	var draws := 0
	for row in payloads:
		if row == null:
			continue
		var ch: Vector2i = row.get("chunk", Vector2i.ZERO)
		var node := _chunk_node(ch)
		node.mesh = HeightfieldMesh.make_mesh(row)
		node.material_override = _material
		node.visible = true
		tris += int(row.get("triangles", 0))
		if node.mesh and node.mesh.get_surface_count() > 0:
			draws += 1
	if with_shell:
		_rebuild_water()
		if not far:
			_scatter_rocks()
			_scatter_dressing()
		elif _dress_root:
			_dress_root.visible = false
	last_triangles = tris
	last_chunks = _chunks.size()
	last_draw_calls = draws + (1 if _water_node.visible and _water_node.mesh else 0) + _fall_root.get_child_count() + _dress_draws()
	centroid = _compute_centroid()


func _chunk_node(ch: Vector2i) -> MeshInstance3D:
	if _chunks.has(ch) and is_instance_valid(_chunks[ch]):
		return _chunks[ch]
	var node := MeshInstance3D.new()
	node.name = "Chunk_%d_%d" % [ch.x, ch.y]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_chunk_root.add_child(node)
	_chunks[ch] = node
	return node


func _rebuild_water() -> void:
	if field == null:
		return
	water_info = field.compute_water()
	var payloads: Array = []
	for lake in water_info.get("lakes", []):
		payloads.append(HeightfieldMesh.build_water(field, lake))
	_water_node.mesh = HeightfieldMesh.make_mesh(HeightfieldMesh.combine(payloads))
	_water_node.visible = not far and not payloads.is_empty()
	for child in _fall_root.get_children():
		child.free()
	if far:
		return
	for site in water_info.get("waterfalls", []):
		var mesh := MeshInstance3D.new()
		mesh.mesh = HeightfieldMesh.make_mesh(HeightfieldMesh.build_waterfall(site["origin"], site["outward"], SEA_Y + 0.35, 1.75))
		mesh.material_override = _fall_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fall_root.add_child(mesh)
		var dust := GPUParticles3D.new()
		dust.amount = 40
		dust.lifetime = 1.8
		dust.position = site["origin"]
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(site["outward"].x, -1.0, site["outward"].z)
		mat.initial_velocity_min = 1.6
		mat.initial_velocity_max = 2.8
		mat.gravity = Vector3(0.0, -7.0, 0.0)
		mat.scale_min = 0.05
		mat.scale_max = 0.12
		mat.color = Color(0.82, 0.92, 0.90, 0.75)
		dust.process_material = mat
		dust.draw_pass_1 = SphereMesh.new()
		(dust.draw_pass_1 as SphereMesh).radius = 0.06
		(dust.draw_pass_1 as SphereMesh).height = 0.12
		_fall_root.add_child(dust)
		var mist := GPUParticles3D.new()
		mist.amount = 36
		mist.lifetime = 2.2
		mist.position = Vector3(site["origin"].x, SEA_Y + 1.2, site["origin"].z) + site["outward"] * 0.4
		var mist_mat := ParticleProcessMaterial.new()
		mist_mat.direction = Vector3(0.0, 1.0, 0.0)
		mist_mat.initial_velocity_min = 0.15
		mist_mat.initial_velocity_max = 0.45
		mist_mat.gravity = Vector3(0.0, 0.15, 0.0)
		mist_mat.scale_min = 0.12
		mist_mat.scale_max = 0.28
		mist_mat.color = Color(0.90, 0.94, 0.96, 0.45)
		mist.process_material = mist_mat
		mist.draw_pass_1 = SphereMesh.new()
		(mist.draw_pass_1 as SphereMesh).radius = 0.16
		(mist.draw_pass_1 as SphereMesh).height = 0.32
		_fall_root.add_child(mist)
		# Still-frame mist so screenshots show a white veil at the plunge.
		for k in 3:
			var puff := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.28 + float(k) * 0.10
			sphere.height = sphere.radius * 1.15
			sphere.radial_segments = 8
			sphere.rings = 4
			puff.mesh = sphere
			puff.position = Vector3(site["origin"].x, SEA_Y + 0.95 + float(k) * 0.18, site["origin"].z) + site["outward"] * (0.35 + float(k) * 0.12)
			var puff_mat := StandardMaterial3D.new()
			puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			puff_mat.albedo_color = Color(0.95, 0.97, 0.98, 0.28)
			puff_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			puff.material_override = puff_mat
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fall_root.add_child(puff)


func _scatter_rocks() -> void:
	for child in _rock_root.get_children():
		child.free()
	# Kit rocks stay off until they sit 0.3–0.8 m on steep faces, 30–50% embedded,
	# and never hang under y_bottom.


func _compute_centroid() -> Vector3:
	if field == null:
		return centroid
	var sum := Vector3.ZERO
	var n := 0
	for cz in field.cells_z():
		for cx in field.cells_x():
			if field.is_land(cx, cz):
				var p := field.vertex_world(cx, cz)
				sum += Vector3(p.x, 0.0, p.y)
				n += 1
	return sum / float(maxi(n, 1)) if n > 0 else centroid


func _apply_material() -> void:
	for key in _chunks:
		var node: MeshInstance3D = _chunks[key]
		if node:
			node.material_override = _material


func stats() -> Dictionary:
	return {
		"chunks": last_chunks,
		"triangles": last_triangles,
		"draw_calls": last_draw_calls,
		"stroke_ms": last_stroke_ms,
		"rebuild_ms": last_full_ms,
		"far": far,
		"cells": cell_count,
		"lakes": (water_info.get("lakes", []) as Array).size(),
		"falls": (water_info.get("waterfalls", []) as Array).size(),
	}


func _make_water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/island_lake.gdshader")
	return mat


func _make_fall_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/island_waterfall.gdshader")
	return mat


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _make_mm(p_name: String, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = p_name
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = material
	_dress_root.add_child(node)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 0
	node.multimesh = multi
	return node


func _fill_mm(node: MultiMeshInstance3D, xforms: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = node.multimesh.mesh
	multi.instance_count = xforms.size()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
	node.multimesh = multi
	node.visible = not xforms.is_empty() and not far


func _dress_draws() -> int:
	var n := 0
	for node in [_tuft_mm, _pebble_mm, _flower_mm, _shore_mm]:
		if node and node.visible and node.multimesh and node.multimesh.instance_count > 0:
			n += 1
	if _dress_root:
		for child in _dress_root.get_children():
			if child is MeshInstance3D and child.visible:
				n += 1
	return n


func _scatter_dressing() -> void:
	if field == null or _dress_root == null:
		return
	_dress_root.visible = not far
	for child in _dress_root.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var water_cells: Dictionary = {}
	var water_level: Dictionary = {}
	for lake in water_info.get("lakes", []):
		var lvl := float(lake.get("level", 0.0))
		for cell in lake.get("cells", []):
			water_cells[cell] = true
			water_level[cell] = lvl
	var tufts: Array = []
	var pebbles: Array = []
	var flowers: Array = []
	var shores: Array = []
	for cz in field.cells_z():
		for cx in field.cells_x():
			if not field.is_land(cx, cz):
				continue
			var play := field.play_cell_of_hf(cx, cz)
			if skip_top.has(play) or _blocked.has(play):
				continue
			var mid := field.vertex_world(cx, cz) + Vector2(field.spacing * 0.5, field.spacing * 0.5)
			var h := field.sample_height(Vector3(mid.x, 0.0, mid.y))
			var nse := Heightfield._hash2(float(cx) * 1.37 + float(field.seed), float(cz) * 1.91)
			var wet := water_cells.has(Vector2i(cx, cz))
			var shore := false
			if not wet:
				for pair in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
					if water_cells.has(Vector2i(cx + int(pair[0]), cz + int(pair[1]))):
						shore = true
						break
			var hole_rim := false
			if not wet:
				for pair in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
					var nx: int = cx + int(pair[0])
					var nz: int = cz + int(pair[1])
					if field.is_land(nx, nz):
						continue
					var around := 0
					for oz in range(-1, 2):
						for ox in range(-1, 2):
							if field.is_land(nx + ox, nz + oz):
								around += 1
					if around >= 5:
						hole_rim = true
			if wet:
				if nse.x > 0.72:
					var lvl := float(water_level.get(Vector2i(cx, cz), h + 0.04))
					_add_lily(Vector3(mid.x + (nse.y - 0.5) * 0.18, lvl + 0.015, mid.y + (nse.x - 0.5) * 0.18), 0.10 + nse.y * 0.05)
				continue
			if shore or hole_rim:
				var xf := Transform3D(Basis(Vector3.UP, nse.x * TAU).scaled(Vector3(0.22 + nse.y * 0.10, 0.16 + nse.x * 0.08, 0.20 + nse.y * 0.08)), Vector3(mid.x, h + 0.04, mid.y))
				shores.append(xf)
			if nse.x > 0.18:
				var gxf := Transform3D(Basis(Vector3.UP, nse.y * TAU).scaled(Vector3.ONE * (0.85 + nse.x * 0.35)), Vector3(mid.x + (nse.y - 0.5) * 0.16, h + 0.01, mid.y + (nse.x - 0.5) * 0.16))
				tufts.append(gxf)
			if nse.y > 0.78:
				pebbles.append(Transform3D(Basis(Vector3.UP, nse.x * 5.0).scaled(Vector3(0.10 + nse.x * 0.05, 0.06, 0.08 + nse.y * 0.04)), Vector3(mid.x - 0.12, h + 0.02, mid.y + 0.10)))
			if nse.x > 0.88 and nse.y > 0.40:
				flowers.append(Transform3D(Basis(Vector3.UP, nse.y * TAU).scaled(Vector3.ONE * 0.9), Vector3(mid.x + 0.08, h + 0.01, mid.y - 0.06)))
	_fill_mm(_tuft_mm, tufts)
	_fill_mm(_pebble_mm, pebbles)
	_fill_mm(_flower_mm, flowers)
	_fill_mm(_shore_mm, shores)
	_hang_roots()


func _add_lily(at: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius * 0.92
	disk.height = 0.018
	disk.radial_segments = 8
	disk.rings = 1
	mesh.mesh = disk
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4d7a3c")
	mat.roughness = 0.88
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dress_root.add_child(mesh)


func _hang_roots() -> void:
	if field == null:
		return
	var hung := 0
	for cz in range(0, field.cells_z(), 2):
		for cx in range(0, field.cells_x(), 2):
			if hung >= 10:
				return
			if not field.is_land(cx, cz):
				continue
			var mid := field.vertex_world(cx, cz)
			if field.sample_inland(Vector3(mid.x, 0.0, mid.y)) < 0.55:
				continue
			var nse := Heightfield._hash2(float(cx) * 0.71 + float(field.seed), float(cz) * 0.63)
			if nse.x < 0.62:
				continue
			var root := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.018
			cyl.bottom_radius = 0.006
			cyl.height = 0.45 + nse.y * 0.55
			cyl.radial_segments = 5
			cyl.rings = 1
			root.mesh = cyl
			var bot: Vector3 = HeightfieldMesh._bottom_vert(field, cx, cz)
			root.position = bot + Vector3((nse.x - 0.5) * 0.2, -cyl.height * 0.35, (nse.y - 0.5) * 0.2)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("4a3828")
			mat.roughness = 0.96
			root.material_override = mat
			root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_dress_root.add_child(root)
			hung += 1


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := [0.0, 1.15, 2.25]
	for yaw in blades:
		var b := Basis(Vector3.UP, yaw)
		var a := b * Vector3(-0.07, 0.0, 0.0)
		var c := b * Vector3(0.07, 0.0, 0.0)
		var tip := b * Vector3(0.0, 0.26, 0.02)
		st.set_normal(Vector3.UP)
		st.add_vertex(a)
		st.add_vertex(tip)
		st.add_vertex(c)
	st.generate_normals()
	return st.commit()


func _pebble_mesh() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.72
	s.radial_segments = 6
	s.rings = 3
	return s


func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3(0.0, 0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.16, 0.0))
	st.add_vertex(Vector3(0.02, 0.0, 0.02))
	st.add_vertex(Vector3(-0.05, 0.16, 0.0))
	st.add_vertex(Vector3(0.05, 0.16, 0.0))
	st.add_vertex(Vector3(0.0, 0.20, 0.0))
	st.generate_normals()
	return st.commit()


func _shore_mesh() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 0.70
	s.radial_segments = 6
	s.rings = 3
	return s


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for task in _tasks:
			if WorkerThreadPool.is_task_completed(task):
				WorkerThreadPool.wait_for_task_completion(task)
		_tasks.clear()
