extends Node3D
## One independent floating island: heightfield data, chunked meshes, cheap far LOD.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")

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
var last_rock_count: int = 0
var last_rock_tris: int = 0
var last_tufts: int = 0
var water_info: Dictionary = {}
var rock_state: Dictionary = {}

var _chunks: Dictionary = {}
var _chunk_root: Node3D
var _water_node: MeshInstance3D
var _bank_node: MeshInstance3D
var _slab_node: MeshInstance3D
var _core_node: MeshInstance3D
var _fall_root: Node3D
var _rock_root: Node3D
var _dress_root: Node3D
var _material: ShaderMaterial
var _water_material: ShaderMaterial
var _fall_material: ShaderMaterial
var _tuft_mm: MultiMeshInstance3D
var _pebble_mm: MultiMeshInstance3D
var _flower_mm: MultiMeshInstance3D
var _kit_mms: Dictionary = {}
var _hang_mms: Dictionary = {}
var _root_mmi: MultiMeshInstance3D
var _top_dirty: Dictionary = {}
var _shell_dirty := false
var _rocks_deferred := false
var _last_outline := PackedVector2Array()
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
	_bank_node = MeshInstance3D.new()
	_bank_node.name = "LakeBank"
	_bank_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bank_node)
	_slab_node = MeshInstance3D.new()
	_slab_node.name = "GrassSlab"
	add_child(_slab_node)
	_core_node = MeshInstance3D.new()
	_core_node.name = "HiddenCore"
	_core_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core_node)
	_fall_root = Node3D.new()
	_fall_root.name = "Waterfalls"
	add_child(_fall_root)
	_rock_root = Node3D.new()
	_rock_root.name = "RockKit"
	add_child(_rock_root)
	_dress_root = Node3D.new()
	_dress_root.name = "Dressing"
	add_child(_dress_root)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/world/island_heightfield.gdshader")
	_water_material = _make_water_material()
	_fall_material = _make_fall_material()
	_water_node.material_override = _water_material
	_slab_node.material_override = _material
	RockKit.ensure()
	_core_node.material_override = RockKit.rock_material
	_bank_node.material_override = _material
	_tuft_mm = _make_mm("GrassTufts", _tuft_mesh(), _mat(Color("8fb56e")))
	_tuft_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pebble_mm = _make_mm("Pebbles", _pebble_mesh(), _mat(Color("8a7360")))
	_flower_mm = _make_mm("Flowers", _flower_mesh(), _mat(Color("d4c07a")))


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
		_rock_root.visible = true
		if _slab_node:
			_slab_node.visible = false
		if _bank_node:
			_bank_node.visible = false
		if _dress_root:
			_dress_root.visible = false
		rebuild_full(true)
	else:
		_water_node.visible = true
		_fall_root.visible = true
		_rock_root.visible = true
		if _slab_node:
			_slab_node.visible = true
		if _bank_node:
			_bank_node.visible = true
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
		_rocks_deferred = false
		rebuild_full(true)
		return
	if _rocks_deferred or rock_state.is_empty():
		_rocks_deferred = false
		_scatter_rocks()


func _process(delta: float) -> void:
	_finish_tasks()
	if _rocks_deferred:
		_rocks_deferred = false
		_scatter_rocks()
	if _top_dirty.is_empty() or _shell_dirty:
		return
	_top_wait -= delta
	if _top_wait <= 0.0:
		_rebuild_tops(false)
		_top_wait = 1.0 / TOP_HZ


func mark_stroke(rect: Rect2i) -> void:
	## Tops only. Kit rocks wait for stroke release so a dab stays under ~16 ms.
	var cs := Heightfield.CHUNK
	var x0 := int(floor(float(rect.position.x) / float(cs)))
	var z0 := int(floor(float(rect.position.y) / float(cs)))
	var x1 := int(floor(float(rect.position.x + rect.size.x) / float(cs)))
	var z1 := int(floor(float(rect.position.y + rect.size.y) / float(cs)))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_top_dirty[Vector2i(x, z)] = true
	if _top_wait <= 0.0:
		_top_wait = 1.0 / TOP_HZ


func end_stroke() -> void:
	if field == null:
		return
	var t0 := Time.get_ticks_usec()
	field.apply_coast_smooth()
	if not _top_dirty.is_empty():
		_rebuild_tops(true)
	_rebuild_water()
	if _outline_moved():
		_rebuild_slab()
		_rocks_deferred = true
	last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_shell_dirty = false


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
		_rocks_deferred = false
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
		_rebuild_slab()
		_rebuild_water()
		_scatter_rocks()
		if not far:
			_scatter_dressing()
		elif _dress_root:
			_dress_root.visible = false
	last_triangles = tris + last_rock_tris
	last_chunks = _chunks.size()
	last_draw_calls = draws + (1 if _water_node.visible and _water_node.mesh else 0) + (1 if _slab_node and _slab_node.visible and _slab_node.mesh else 0) + (1 if _core_node and _core_node.visible and _core_node.mesh else 0) + (1 if _bank_node and _bank_node.visible and _bank_node.mesh else 0) + _fall_root.get_child_count() + _dress_draws()
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
	var banks: Array = []
	for lake in water_info.get("lakes", []):
		banks.append(HeightfieldMesh.build_lake_bank(field, lake))
	if _bank_node:
		_bank_node.mesh = HeightfieldMesh.make_mesh(HeightfieldMesh.combine(banks))
		_bank_node.material_override = _material
		_bank_node.visible = not far and not banks.is_empty()
	for child in _fall_root.get_children():
		child.free()
	if far:
		return
	for site in water_info.get("waterfalls", []):
		var mesh := MeshInstance3D.new()
		mesh.mesh = HeightfieldMesh.make_mesh(HeightfieldMesh.build_waterfall(site["origin"], site["outward"], SEA_Y + 0.35, 1.05))
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


func _rebuild_slab() -> void:
	if field == null or _slab_node == null:
		return
	var slab: Dictionary = HeightfieldMesh.build_slab(field, skip_top)
	_slab_node.mesh = HeightfieldMesh.make_mesh(slab)
	_slab_node.material_override = _material
	_slab_node.visible = not far
	if _core_node:
		var core: Dictionary = HeightfieldMesh.build_core(field)
		_core_node.mesh = HeightfieldMesh.make_mesh(core)
		RockKit.ensure()
		_core_node.material_override = RockKit.rock_material
		_core_node.visible = true


func _scatter_rocks() -> void:
	if field == null or _rock_root == null:
		return
	var outline := field.primary_loop()
	if outline.size() < 4:
		last_rock_count = 0
		last_rock_tris = 0
		return
	rock_state = RockUnderside.respace(rock_state, outline, field.seed, far)
	if RockUnderside.any_floating(rock_state, outline):
		rock_state = RockUnderside.assemble(outline, field.seed, far)
	_sync_hang_mms(rock_state)
	_last_outline = outline.duplicate()
	last_rock_count = int(rock_state.get("piece_count", 0))
	last_rock_tris = RockUnderside.triangle_count(rock_state)
	print("kit rocks=%d tris=%d far=%s" % [last_rock_count, last_rock_tris, far])


func _outline_moved() -> bool:
	if field == null:
		return false
	var outline := field.primary_loop()
	if outline.size() != _last_outline.size() or outline.size() < 4:
		return true
	for i in outline.size():
		if outline[i].distance_to(_last_outline[i]) > 0.08:
			return true
	return false


func _sync_hang_mms(state: Dictionary) -> void:
	RockKit.ensure()
	var grouped: Dictionary = {}
	for slot in state.get("slots", []):
		var name := String(slot["piece"])
		if not grouped.has(name):
			grouped[name] = []
		(grouped[name] as Array).append(slot)
	for name in RockKit.names:
		var rows: Array = grouped.get(name, [])
		var mmi := _hang_node(name)
		if mmi == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = RockKit.piece(name).get("mesh")
		multi.instance_count = rows.size()
		for i in rows.size():
			multi.set_instance_transform(i, rows[i]["xf"])
			multi.set_instance_color(i, Color(float(rows[i].get("jitter", 0.5)), 0.0, 0.0))
		mmi.multimesh = multi
		mmi.visible = rows.size() > 0
	if _root_mmi == null:
		_root_mmi = MultiMeshInstance3D.new()
		_root_mmi.name = "Roots"
		_root_mmi.material_override = RockKit.root_material
		_root_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rock_root.add_child(_root_mmi)
	var roots: Array = [] if far else state.get("roots", [])
	var root_multi := MultiMesh.new()
	root_multi.transform_format = MultiMesh.TRANSFORM_3D
	root_multi.mesh = RockKit.root_mesh
	root_multi.instance_count = roots.size()
	for i in roots.size():
		root_multi.set_instance_transform(i, roots[i])
	_root_mmi.multimesh = root_multi
	_root_mmi.visible = roots.size() > 0
	_rock_root.visible = true


func _hang_node(piece_name: String) -> MultiMeshInstance3D:
	if _hang_mms.has(piece_name) and is_instance_valid(_hang_mms[piece_name]):
		return _hang_mms[piece_name]
	RockKit.ensure()
	var piece: Dictionary = RockKit.piece(piece_name)
	if piece.is_empty() or piece.get("mesh") == null:
		return null
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Hang_%s" % piece_name
	mmi.material_override = RockKit.rock_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rock_root.add_child(mmi)
	_hang_mms[piece_name] = mmi
	return mmi


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
	if _slab_node:
		_slab_node.material_override = _material
	if _core_node:
		RockKit.ensure()
		_core_node.material_override = RockKit.rock_material
	if _bank_node:
		_bank_node.material_override = _material


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
		"rock_instances": last_rock_count,
		"rock_tris": last_rock_tris,
		"tufts": last_tufts,
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
	for node in [_tuft_mm, _pebble_mm, _flower_mm]:
		if node and node.visible and node.multimesh and node.multimesh.instance_count > 0:
			n += 1
	for node in _kit_mms.values():
		if node and node.visible and node.multimesh and node.multimesh.instance_count > 0:
			n += 1
	for node in _hang_mms.values():
		if node and node.visible and node.multimesh and node.multimesh.instance_count > 0:
			n += 1
	if _root_mmi and _root_mmi.visible and _root_mmi.multimesh and _root_mmi.multimesh.instance_count > 0:
		n += 1
	if _dress_root:
		for child in _dress_root.get_children():
			if child is MeshInstance3D and child.visible:
				n += 1
	return n


func _salt() -> float:
	## Huge cells_hash seeds destroy sin() variation. Keep a small phase.
	return float(absi(field.seed) % 97) * 0.13


func _unit_hash(x: int, y: int, extra: int = 0) -> Vector2:
	var h := Heightfield._hash_int(x * 73856093 ^ y * 19349663 ^ extra * 83492791 ^ field.seed)
	return Vector2(float(h & 0xffff) / 65535.0, float((h >> 16) & 0xffff) / 65535.0)


func _density_at(world: Vector2) -> float:
	var salt := _salt()
	var wave := 0.5 + 0.5 * sin(world.x * 0.42 + salt) * sin(world.y * 0.35 - salt * 0.7)
	var nse := _unit_hash(int(floor(world.x * 3.0)), int(floor(world.y * 3.0)))
	var field_v := wave * 0.68 + nse.x * 0.32
	return clampf(0.05 + 0.26 * field_v, 0.04, 0.34)


func _scatter_dressing() -> void:
	if field == null or _dress_root == null:
		return
	_dress_root.visible = not far
	for child in _dress_root.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var water_cells: Dictionary = {}
	for lake in water_info.get("lakes", []):
		for cell in lake.get("cells", []):
			water_cells[cell] = true
	var tufts: Array = []
	var pebbles: Array = []
	var flowers: Array = []
	var dmin := 99.0
	var dmax := -1.0
	for cz in field.cells_z():
		for cx in field.cells_x():
			if not field.is_land(cx, cz):
				continue
			var play := field.play_cell_of_hf(cx, cz)
			if skip_top.has(play) or _blocked.has(play) or water_cells.has(Vector2i(cx, cz)):
				continue
			if field.sample_inland(Vector3(field.vertex_world(cx, cz).x, 0.0, field.vertex_world(cx, cz).y)) < 0.18:
				continue
			var origin := field.vertex_world(cx, cz)
			var density := _density_at(origin)
			dmin = minf(dmin, density)
			dmax = maxf(dmax, density)
			for attempt in 3:
				var nse := _unit_hash(cx, cz, attempt + 11)
				if nse.x > density:
					continue
				var pos := _unit_hash(cx + 17, cz + 29, attempt + 53)
				var at := Vector3(origin.x + pos.x * field.spacing, 0.0, origin.y + pos.y * field.spacing)
				var h := field.sample_height(at) + field.visual_relief(at)
				var yaw := pos.y * TAU
				var tall := 0.85 + nse.x * 0.70
				if nse.y > 0.70 and density > 0.22:
					tall = 1.35 + nse.x * 0.70
				tufts.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.95 + pos.y * 0.35, tall, 0.95 + pos.x * 0.28)), Vector3(at.x, h + 0.008, at.z)))
				if nse.y > 0.70 and density > 0.20:
					var mate := _unit_hash(cx + 41, cz + 7, attempt + 71)
					tufts.append(Transform3D(Basis(Vector3.UP, yaw + 0.9).scaled(Vector3(0.80, tall * 0.72, 0.80)), Vector3(at.x + 0.10, h + 0.006, at.z - 0.08)))
					if mate.x > 0.55:
						tufts.append(Transform3D(Basis(Vector3.UP, yaw - 0.7).scaled(Vector3(0.70, tall * 0.58, 0.70)), Vector3(at.x - 0.08, h + 0.006, at.z + 0.11)))
				if nse.y > 0.93 and pos.x > 0.55:
					flowers.append(Transform3D(Basis(Vector3.UP, yaw + 1.2).scaled(Vector3.ONE * (1.0 + nse.x * 0.35)), Vector3(at.x + 0.05, h + 0.01, at.z - 0.04)))
			var clump := _unit_hash(cx + 3, cz + 5, 7)
			if clump.x > 0.70 and density > 0.30:
				var mid := origin + Vector2(field.spacing * 0.5, field.spacing * 0.5)
				var h2 := field.sample_height(Vector3(mid.x, 0.0, mid.y))
				pebbles.append(Transform3D(Basis(Vector3.UP, clump.y * TAU).scaled(Vector3(0.11, 0.07, 0.09)), Vector3(mid.x, h2 + 0.018, mid.y)))
				if clump.y > 0.45:
					pebbles.append(Transform3D(Basis(Vector3.UP, clump.x * 4.0).scaled(Vector3(0.07, 0.05, 0.06)), Vector3(mid.x + 0.12, h2 + 0.014, mid.y - 0.08)))
	_fill_mm(_tuft_mm, tufts)
	_fill_mm(_pebble_mm, pebbles)
	_fill_mm(_flower_mm, flowers)
	last_tufts = tufts.size()
	var rocks := _scatter_rim_rocks(water_cells)
	print("dress tufts=%d pebbles=%d flowers=%d lake_rocks=%d kit=%d d=%.2f..%.2f" % [
		tufts.size(), pebbles.size(), flowers.size(), rocks, last_rock_count, dmin, dmax
	])


func _scatter_rim_rocks(_water_cells: Dictionary) -> int:
	RockKit.ensure()
	var by_name: Dictionary = {}
	for n in RockKit.pool("rim"):
		by_name[n] = []
	if by_name.is_empty():
		return 0
	var names: PackedStringArray = PackedStringArray(by_name.keys())
	var lake_loops: Array = []
	for lake in water_info.get("lakes", []):
		var sdf: Array = field.water_visual_loops(lake.get("cells", []))
		if sdf.is_empty():
			for loop in HeightfieldMesh._lake_loops(field, lake.get("cells", [])):
				var ring: Array = []
				for p in HeightfieldMesh._smooth_loop(loop):
					ring.append(Vector2(p.x, p.z))
				if ring.size() >= 4:
					lake_loops.append(ring)
		else:
			for loop in sdf:
				if loop.size() >= 4:
					lake_loops.append(loop)
	_place_rock_chain(lake_loops, names, by_name, -0.12, true)
	var total := 0
	for n in by_name.keys():
		var node := _kit_node(String(n))
		if node:
			_fill_mm(node, by_name[n])
			total += (by_name[n] as Array).size()
	return total


func _place_rock_chain(loops: Array, names: PackedStringArray, by_name: Dictionary, bury: float, lake: bool) -> void:
	if names.is_empty():
		return
	for loop in loops:
		if loop.size() < 4:
			continue
		var acc := 0.0
		var next_s := 0.0
		var placed := 0
		for i in loop.size():
			var a: Vector2 = loop[i]
			var b: Vector2 = loop[(i + 1) % loop.size()]
			var seg := a.distance_to(b)
			var t := 0.0
			while t < seg:
				if acc + t >= next_s:
					var u := t / maxf(seg, 0.001)
					var p := a.lerp(b, u)
					var nse := Heightfield._hash2(p.x * 1.9 + float(field.seed), p.y * 1.7)
					next_s += 1.55 + nse.x * 0.35
					if nse.y < 0.42:
						acc += t
						t += 0.20
						continue
					if _blocked_world(p):
						acc += t
						t += 0.20
						continue
					var name := names[int(nse.x * float(names.size())) % names.size()]
					var piece: Dictionary = RockKit.piece(name)
					var src_h := maxf(float(piece.get("height", 0.35)), 0.15)
					var src_w := maxf(float(piece.get("width", 0.40)), 0.15)
					var unit_h := 0.22 / src_h
					var unit_w := 0.30 / src_w
					var h := field.sample_height(Vector3(p.x, 0.0, p.y))
					var yaw := nse.x * TAU
					var tilt := (nse.y - 0.5) * 0.08
					var sx := unit_w * (0.85 + nse.x * 0.40)
					var sy := unit_h * ((1.20 + nse.y * 0.55) if not lake else (0.95 + nse.y * 0.40))
					var sz := unit_w * (0.90 + nse.y * 0.30)
					# Sitting mesh stands +Y from the origin. Bury the base into the shoulder.
					var basis := Basis.from_euler(Vector3(tilt, yaw, (nse.x - 0.5) * 0.08))
					basis = basis.scaled(Vector3(sx, sy, sz))
					var xf := Transform3D(basis, Vector3(p.x + (nse.y - 0.5) * 0.14, h + bury, p.y + (nse.x - 0.5) * 0.14))
					(by_name[name] as Array).append(xf)
					placed += 1
					if placed % 6 == 0 and names.size() > 1:
						var small := names[int(nse.y * float(names.size())) % names.size()]
						var sb := Basis.from_euler(Vector3(0.0, yaw + 0.8, 0.0)).scaled(Vector3(sx * 0.55, sy * 0.52, sz * 0.55))
						(by_name[small] as Array).append(Transform3D(sb, Vector3(p.x + 0.26, h + bury * 0.65, p.y - 0.14)))
				t += 0.18
			acc += seg


func _blocked_world(p: Vector2) -> bool:
	var play := Vector2i(floori(p.x), floori(p.y))
	return skip_top.has(play) or _blocked.has(play)


func _kit_node(p_name: String) -> MultiMeshInstance3D:
	if _kit_mms.has(p_name) and is_instance_valid(_kit_mms[p_name]):
		return _kit_mms[p_name]
	var piece: Dictionary = RockKit.piece(p_name)
	if piece.is_empty() or piece.get("mesh") == null:
		return null
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6e6258")
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := _make_mm("Kit_%s" % p_name, _sitting_mesh(piece["mesh"]), mat)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_kit_mms[p_name] = node
	return node


func _sitting_mesh(src: ArrayMesh) -> ArrayMesh:
	## Kit bake hangs -Y from the origin. Flip to a sitting stone with origin at the base.
	if src == null or src.get_surface_count() == 0:
		return src
	var faces := src.get_faces()
	if faces.is_empty():
		return src
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var a: Vector3 = Vector3(faces[i].x, -faces[i].y, faces[i].z)
		var b: Vector3 = Vector3(faces[i + 2].x, -faces[i + 2].y, faces[i + 2].z)
		var c: Vector3 = Vector3(faces[i + 1].x, -faces[i + 1].y, faces[i + 1].z)
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
	var out := st.commit()
	return out if out.get_surface_count() > 0 else src


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
	for i in 3:
		var b := Basis(Vector3.UP, float(i) * TAU / 3.0)
		var w := 0.048
		var lift := 0.13 + float(i % 2) * 0.03
		var bl := b * Vector3(-w, 0.0, 0.0)
		var br := b * Vector3(w, 0.0, 0.0)
		var tl := b * Vector3(-w * 0.28, lift, 0.012)
		var tr := b * Vector3(w * 0.28, lift, 0.012)
		var n := (Vector3.UP + b * Vector3(0.0, 0.0, 1.0)).normalized()
		for tri in [[bl, tl, tr], [bl, tr, br]]:
			for p in tri:
				st.set_normal(n)
				st.add_vertex(p)
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
