extends Node3D
## Standalone floating-island prototype. Does not touch the play scene.
## Source of truth is scripts/world/heightfield.gd (H, land mask, 0.25 m snap).

const Heightfield := preload("res://scripts/world/heightfield.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const Mesher := preload("res://scripts/proto/island_mesher.gd")
const Rocks := preload("res://scripts/proto/island_rocks.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")

var field: Heightfield
var last_full_ms := 0.0
var last_stroke_ms := 0.0
var last_dress_ms := 0.0
var last_top_tris := 0
var last_core_tris := 0
var last_rock_tris := 0
var last_rock_count := 0
var last_draws := 0
var last_chunks := 0

var _ctx: Dictionary = {}
var _loops: Array = []
var _mask_key := 0
var _chunk_nodes: Dictionary = {}
var _top_root: Node3D
var _core: MeshInstance3D
var _rock_root: Node3D
var _rocks: Dictionary = {}
var _body: StaticBody3D
var _shape: CollisionShape3D
var _top_mat: ShaderMaterial
var _rock_mat: ShaderMaterial
var _defer_dress := false
var _dress_core := false


func _ready() -> void:
	_build_stage()
	build_playable()
	rebuild_full(true)


func _process(_delta: float) -> void:
	if _defer_dress:
		_defer_dress = false
		var t0 := Time.get_ticks_usec()
		if _dress_core:
			_apply_core()
		_apply_rocks()
		last_dress_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_dress_core = false
		_recount()


func build_playable() -> void:
	var cells: Dictionary = {}
	for cell in IslandGeometry.courtyard_yard_cells():
		cells[cell] = true
	var seed := IslandGeometry.cells_hash(cells)
	field = Heightfield.from_play_cells(cells, Heightfield.SPACING, Heightfield.DEFAULT_BOTTOM, seed, 2)
	field.apply_coast_smooth()
	field.stamp_gentle_hills()
	var lake: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(2, 1), Vector2i(5, 1), Vector2i(3, -1), Vector2i(4, -1),
	]
	for cell in lake:
		if not cells.has(cell):
			continue
		field.apply_brush("lower", Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5), 0.95, 0.48, true)
	field.apply_coast_smooth()
	# A dug shaft so the same mask pass has to cut a hole rim.
	field.punch_shaft(Vector3(-2.2, 0.0, 1.6), 0.9)
	_mask_key = _hash_mask()


func rebuild_full(_sync_dress: bool = true) -> float:
	## The playable island is small enough that a worker does not pay for itself.
	## Rocks still wait until the next frame on brush strokes.
	var t0 := Time.get_ticks_usec()
	var built := _build_payload(field)
	_apply_full(built)
	_apply_core()
	_apply_rocks()
	last_full_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_recount()
	return last_full_ms


func stroke(op: String, center: Vector3, radius: float, strength: float) -> float:
	## Sync cost is dirty chunks plus the heightmap shape. Rocks wait one frame.
	var t0 := Time.get_ticks_usec()
	var before := _hash_mask()
	var applied: Dictionary = field.apply_brush(op, center, radius, strength, false)
	var mask_changed := _hash_mask() != before
	var rect: Rect2i = applied.get("rect", Rect2i())
	if mask_changed or _ctx.is_empty():
		_rebuild_tops_all()
		_dress_core = true
	else:
		_rebuild_tops_rect(rect)
		_dress_core = _rect_hits_rim(rect)
	_update_collision()
	_defer_dress = true
	last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return last_stroke_ms


func flush_dress() -> float:
	var t0 := Time.get_ticks_usec()
	if _dress_core or _loops.is_empty():
		_apply_core()
	_apply_rocks()
	_defer_dress = false
	_dress_core = false
	last_dress_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_recount()
	return last_dress_ms


func bounds() -> AABB:
	var box := AABB()
	var started := false
	for cz in field.cells_z():
		for cx in field.cells_x():
			if not field.is_land(cx, cz):
				continue
			var p := field.vertex_world(cx, cz)
			var y := field.height_at(cx, cz)
			var v := Vector3(p.x, y, p.y)
			if not started:
				box = AABB(v, Vector3.ZERO)
				started = true
			else:
				box = box.expand(v)
	box = box.expand(box.position + Vector3(0.0, field.y_bottom, 0.0))
	return box


func stats() -> Dictionary:
	return {
		"chunks": last_chunks,
		"top_tris": last_top_tris,
		"core_tris": last_core_tris,
		"rock_tris": last_rock_tris,
		"triangles": last_top_tris + last_core_tris + last_rock_tris,
		"rocks": last_rock_count,
		"draw_calls": last_draws,
		"full_ms": last_full_ms,
		"stroke_ms": last_stroke_ms,
		"dress_ms": last_dress_ms,
		"land_cells": field.land_cell_count() if field else 0,
	}


func _build_payload(copy: Heightfield) -> Dictionary:
	var ctx := Mesher.prepare(copy)
	var chunks: Dictionary = {}
	for z in int(ctx["chunks_z"]):
		for x in int(ctx["chunks_x"]):
			var key := Vector2i(x, z)
			chunks[key] = Mesher.build_chunk(copy, key, ctx)
	var loops: Array = Mesher.collect_loops(copy, ctx)
	var core: Dictionary = Mesher.build_core(copy, loops)
	return {"ctx": ctx, "chunks": chunks, "loops": loops, "core": core}


func _apply_full(built: Dictionary) -> void:
	if built.is_empty():
		return
	_ctx = built["ctx"]
	_loops = built["loops"]
	_mask_key = _hash_mask()
	for key in _chunk_nodes.keys():
		var node: MeshInstance3D = _chunk_nodes[key]
		node.mesh = null
	for key in built["chunks"].keys():
		_set_chunk(key, built["chunks"][key])
	_set_core_payload(built["core"])
	_update_collision()
	_tune_gradient()


func _rebuild_tops_all() -> void:
	_ctx = Mesher.prepare(field)
	_loops = Mesher.collect_loops(field, _ctx)
	for z in int(_ctx["chunks_z"]):
		for x in int(_ctx["chunks_x"]):
			var key := Vector2i(x, z)
			_set_chunk(key, Mesher.build_chunk(field, key, _ctx))
	_mask_key = _hash_mask()


func _rebuild_tops_rect(rect: Rect2i) -> void:
	var seen: Dictionary = {}
	var cs := Heightfield.CHUNK
	var x0 := mini(rect.position.x, rect.position.x + rect.size.x)
	var x1 := maxi(rect.position.x, rect.position.x + rect.size.x)
	var z0 := mini(rect.position.y, rect.position.y + rect.size.y)
	var z1 := maxi(rect.position.y, rect.position.y + rect.size.y)
	for cz in range(z0 - 1, z1 + 2):
		for cx in range(x0 - 1, x1 + 2):
			if not field.in_cell(cx, cz):
				continue
			var key := Mesher.chunk_of_cell(cx, cz)
			if seen.has(key):
				continue
			seen[key] = true
			_set_chunk(key, Mesher.build_chunk(field, key, _ctx))


func _apply_core() -> void:
	if _loops.is_empty() and not _ctx.is_empty():
		_loops = Mesher.collect_loops(field, _ctx)
	if _loops.is_empty():
		_ctx = Mesher.prepare(field)
		_loops = Mesher.collect_loops(field, _ctx)
	_set_core_payload(Mesher.build_core(field, _loops))


func _apply_rocks() -> void:
	var placed: Dictionary = Rocks.place(field, _loops)
	var by_piece: Dictionary = placed["by_piece"]
	last_rock_count = int(placed["count"])
	var rock_tris := 0
	var used: Dictionary = {}
	for piece_name in by_piece.keys():
		var row: Dictionary = by_piece[piece_name]
		var xforms: Array = row["xf"]
		var bright: PackedFloat32Array = row["bright"]
		var piece: Dictionary = RockKit.piece(piece_name)
		if piece.is_empty() or xforms.is_empty():
			continue
		var node := _rock_node(piece_name, piece["mesh"])
		var mm := node.multimesh
		mm.instance_count = xforms.size()
		mm.visible_instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_custom_data(i, Color(bright[i], 0.0, 0.0, 1.0))
		rock_tris += int(piece["tris"]) * xforms.size()
		used[piece_name] = true
		node.visible = true
	for piece_name in _rocks.keys():
		if not used.has(piece_name):
			_rocks[piece_name].visible = false
	last_rock_tris = rock_tris


func _set_chunk(key: Vector2i, payload: Dictionary) -> void:
	var node: MeshInstance3D = _chunk_nodes.get(key)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Chunk_%d_%d" % [key.x, key.y]
		node.material_override = _top_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_top_root.add_child(node)
		_chunk_nodes[key] = node
	var mesh := _mesh_from(payload)
	node.mesh = mesh
	node.visible = mesh.get_surface_count() > 0


func _set_core_payload(payload: Dictionary) -> void:
	_core.mesh = _mesh_from(payload)
	last_core_tris = int(payload.get("triangles", 0))


func _mesh_from(payload: Dictionary) -> ArrayMesh:
	var verts: PackedVector3Array = payload.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = payload.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_COLOR] = payload.get("colors", PackedColorArray())
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _update_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = field.verts_x
	shape.map_depth = field.verts_z
	var data := PackedFloat32Array()
	data.resize(field.heights.size())
	for iz in field.verts_z:
		for ix in field.verts_x:
			var i := field.vertex_index(ix, iz)
			if field._vertex_has_land(ix, iz):
				data[i] = field.heights[i]
			else:
				data[i] = field.y_bottom - 12.0
	shape.map_data = data
	_shape.shape = shape
	var sx := float(field.verts_x - 1) * field.spacing
	var sz := float(field.verts_z - 1) * field.spacing
	_shape.position = Vector3(field.origin.x + sx * 0.5, 0.0, field.origin.y + sz * 0.5)
	_shape.scale = Vector3(field.spacing, 1.0, field.spacing)


func _rock_node(piece_name: String, mesh: Mesh) -> MultiMeshInstance3D:
	if _rocks.has(piece_name):
		return _rocks[piece_name]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = piece_name
	node.multimesh = mm
	node.material_override = _rock_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rock_root.add_child(node)
	_rocks[piece_name] = node
	return node


func _tune_gradient() -> void:
	var top := 0.4
	var bot := field.y_bottom
	for iz in field.verts_z:
		for ix in field.verts_x:
			if field._vertex_has_land(ix, iz):
				top = maxf(top, field.height_at(ix, iz))
	_rock_mat.set_shader_parameter("top_y", top + 0.05)
	_rock_mat.set_shader_parameter("bottom_y", bot - 0.2)
	# Placement keeps rock tops under the lip. A low clip sliced them into flat slivers.
	_rock_mat.set_shader_parameter("clip_above", top + 4.0)


func _rect_hits_rim(rect: Rect2i) -> bool:
	var x0 := mini(rect.position.x, rect.position.x + rect.size.x) - 1
	var x1 := maxi(rect.position.x, rect.position.x + rect.size.x) + 1
	var z0 := mini(rect.position.y, rect.position.y + rect.size.y) - 1
	var z1 := maxi(rect.position.y, rect.position.y + rect.size.y) + 1
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			if field.in_cell(cx, cz) and field._vertex_is_rim(cx, cz):
				return true
			if field.in_vertex(cx, cz) and field._vertex_is_rim(cx, cz):
				return true
	return false


func _hash_mask() -> int:
	var h := 17
	for i in field.mask.size():
		h = h * 33 + int(field.mask[i])
	return h


func _recount() -> void:
	var tris := 0
	var draws := 0
	var chunks := 0
	for key in _chunk_nodes.keys():
		var node: MeshInstance3D = _chunk_nodes[key]
		if node.mesh and node.mesh.get_surface_count() > 0 and node.visible:
			tris += int(node.mesh.get_faces().size() / 3)
			draws += 1
			chunks += 1
	last_top_tris = tris
	last_chunks = chunks
	if _core.mesh and _core.mesh.get_surface_count() > 0:
		draws += 1
	for piece_name in _rocks.keys():
		var node: MultiMeshInstance3D = _rocks[piece_name]
		if node.visible and node.multimesh and node.multimesh.visible_instance_count > 0:
			draws += 1
	last_draws = draws


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.83, 0.91)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.90)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.12
	env.ssao_enabled = true
	env.ssao_radius = 0.55
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-36.0, -58.0, 0.0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22.0, -130.0, 0.0)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	add_child(fill)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.position = Vector3(11.0, 8.0, 12.0)
	add_child(cam)
	cam.look_at(Vector3(0.0, -1.0, 0.0))

	_top_mat = ShaderMaterial.new()
	_top_mat.shader = load("res://shaders/proto/proto_top.gdshader")
	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = load("res://shaders/proto/proto_rock.gdshader")

	_top_root = Node3D.new()
	_top_root.name = "Top"
	add_child(_top_root)
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.material_override = _rock_mat
	add_child(_core)
	_rock_root = Node3D.new()
	_rock_root.name = "Rocks"
	add_child(_rock_root)
	_body = StaticBody3D.new()
	_body.name = "Collision"
	add_child(_body)
	_shape = CollisionShape3D.new()
	_body.add_child(_shape)
	_add_clouds()


func _add_clouds() -> void:
	var root := Node3D.new()
	root.name = "Clouds"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 0.98)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 4
	var spots := [
		Vector3(-6.0, -7.2, 2.0), Vector3(2.5, -7.6, -4.0), Vector3(8.0, -7.0, 3.5),
		Vector3(-1.0, -8.0, 7.0), Vector3(4.0, -7.4, 6.0), Vector3(-8.0, -7.5, -3.0),
	]
	for i in spots.size():
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = mat
		inst.position = spots[i]
		inst.scale = Vector3(3.2 + float(i % 3) * 0.8, 0.7, 2.2 + float(i % 2))
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
