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
var _skip_rocks := false
var _rock_full := true
var _rock_dirty := Rect2()
var _asm = Rocks.new()
var _chunk_payloads: Dictionary = {}
var _top_node: MeshInstance3D


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
		if not _skip_rocks:
			_apply_rocks()
		last_dress_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_dress_core = false
		_skip_rocks = false
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
	_rock_full = true
	_apply_rocks()
	last_full_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_recount()
	return last_full_ms


func stroke(op: String, center: Vector3, radius: float, strength: float) -> float:
	## Sync cost is the dirty top cells plus the heightmap. Rock dress waits one frame
	## and only restamps the coast segment the brush touched.
	var t0 := Time.get_ticks_usec()
	var before := _hash_mask()
	var origin_before := field.origin
	var vx_before := field.verts_x
	var vz_before := field.verts_z
	var applied: Dictionary = field.apply_brush(op, center, radius, strength, false)
	var grew := field.origin != origin_before or field.verts_x != vx_before or field.verts_z != vz_before
	var mask_changed := grew or _hash_mask() != before
	var rect: Rect2i = applied.get("rect", Rect2i())
	var hit_rim := mask_changed or _rect_hits_rim(rect)
	if grew or _ctx.is_empty():
		_rebuild_tops_all()
		_dress_core = true
	elif mask_changed:
		# The grid did not grow. New faces are the brush neighbourhood; other
		# chunks only refresh the skirt that follows the smoothed coast.
		_ctx = Mesher.refresh_mask(field, _ctx, rect)
		_loops = _ctx["loops"]
		_rebuild_tops_rect(rect, true)
		_refresh_skirts()
		_publish_top()
		_mask_key = _hash_mask()
		_dress_core = true
	else:
		_rebuild_tops_rect(rect, hit_rim)
		_dress_core = hit_rim
	_rock_dirty = Rect2(center.x - radius, center.z - radius, radius * 2.0, radius * 2.0)
	_rock_full = grew or _asm.slots.is_empty()
	_skip_rocks = not hit_rim and not _rock_full
	_update_collision()
	_defer_dress = true
	last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return last_stroke_ms


func flush_dress() -> float:
	var t0 := Time.get_ticks_usec()
	if _dress_core or _loops.is_empty():
		_apply_core()
	if not _skip_rocks:
		_apply_rocks()
	_defer_dress = false
	_dress_core = false
	_skip_rocks = false
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
	_chunk_payloads = built["chunks"]
	_publish_top()
	_set_core_payload(built["core"])
	_update_collision()
	_tune_gradient()


func _rebuild_tops_all() -> void:
	_ctx = Mesher.prepare(field)
	_loops = Mesher.collect_loops(field, _ctx)
	_chunk_payloads.clear()
	for z in int(_ctx["chunks_z"]):
		for x in int(_ctx["chunks_x"]):
			var key := Vector2i(x, z)
			_chunk_payloads[key] = Mesher.build_chunk(field, key, _ctx)
	_publish_top()
	_mask_key = _hash_mask()


func _refresh_skirts() -> void:
	for key in _chunk_payloads.keys():
		_patch_chunk(key, [], true)


func _rebuild_tops_rect(rect: Rect2i, rebuild_skirt: bool) -> void:
	var dirty: Dictionary = {}
	var x0 := mini(rect.position.x, rect.position.x + rect.size.x)
	var x1 := maxi(rect.position.x, rect.position.x + rect.size.x)
	var z0 := mini(rect.position.y, rect.position.y + rect.size.y)
	var z1 := maxi(rect.position.y, rect.position.y + rect.size.y)
	for cz in range(z0 - 1, z1 + 2):
		for cx in range(x0 - 1, x1 + 2):
			if not field.in_cell(cx, cz):
				continue
			var key := Mesher.chunk_of_cell(cx, cz)
			if not dirty.has(key):
				dirty[key] = []
			(dirty[key] as Array).append(Vector2i(cx, cz))
	for key in dirty.keys():
		_patch_chunk(key, dirty[key], rebuild_skirt)
	_publish_top()


func _patch_chunk(key: Vector2i, cells: Array, rebuild_skirt: bool) -> void:
	var payload: Dictionary = _chunk_payloads.get(key, {})
	if payload.is_empty() or not payload.has("spans"):
		_chunk_payloads[key] = Mesher.build_chunk(field, key, _ctx)
		return
	var fresh: Dictionary = {}
	for cell in cells:
		var c: Vector2i = cell
		fresh[c] = Mesher.cell_geometry(field, c.x, c.y, _ctx)
	var old_v: PackedVector3Array = payload["vertices"]
	var old_n: PackedVector3Array = payload["normals"]
	var old_c: PackedColorArray = payload["colors"]
	var spans: Dictionary = payload["spans"]
	var x0: int = payload["x0"]
	var z0: int = payload["z0"]
	var x1: int = payload["x1"]
	var z1: int = payload["z1"]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var new_spans: Dictionary = {}
	for cz in range(z0, z1):
		for cx in range(x0, x1):
			var cell := Vector2i(cx, cz)
			var begin := verts.size()
			if fresh.has(cell):
				var part: Dictionary = fresh[cell]
				var pv: PackedVector3Array = part.get("vertices", PackedVector3Array())
				if not pv.is_empty():
					verts.append_array(pv)
					norms.append_array(part["normals"])
					cols.append_array(part["colors"])
			elif spans.has(cell):
				var span: Vector2i = spans[cell]
				verts.append_array(old_v.slice(span.x, span.y))
				norms.append_array(old_n.slice(span.x, span.y))
				cols.append_array(old_c.slice(span.x, span.y))
			var end := verts.size()
			if end > begin:
				new_spans[cell] = Vector2i(begin, end)
	var skirt_from := verts.size()
	if rebuild_skirt:
		var skirt: Dictionary = Mesher.skirt_geometry(field, key, _ctx)
		var sv: PackedVector3Array = skirt.get("vertices", PackedVector3Array())
		if not sv.is_empty():
			verts.append_array(sv)
			norms.append_array(skirt["normals"])
			cols.append_array(skirt["colors"])
	else:
		var sf: int = int(payload.get("skirt_from", old_v.size()))
		if sf < old_v.size():
			verts.append_array(old_v.slice(sf, old_v.size()))
			norms.append_array(old_n.slice(sf, old_n.size()))
			cols.append_array(old_c.slice(sf, old_c.size()))
	payload["vertices"] = verts
	payload["normals"] = norms
	payload["colors"] = cols
	payload["triangles"] = int(verts.size() / 3)
	payload["spans"] = new_spans
	payload["skirt_from"] = skirt_from
	_chunk_payloads[key] = payload


func _publish_top() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var chunks := 0
	for key in _chunk_payloads.keys():
		var payload: Dictionary = _chunk_payloads[key]
		var v: PackedVector3Array = payload.get("vertices", PackedVector3Array())
		if v.is_empty():
			continue
		verts.append_array(v)
		norms.append_array(payload.get("normals", PackedVector3Array()))
		cols.append_array(payload.get("colors", PackedColorArray()))
		chunks += 1
	last_chunks = chunks
	last_top_tris = int(verts.size() / 3)
	if _top_node == null:
		_top_node = MeshInstance3D.new()
		_top_node.name = "TopMesh"
		_top_node.material_override = _top_mat
		_top_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_top_root.add_child(_top_node)
	_top_node.mesh = _mesh_from({"vertices": verts, "normals": norms, "colors": cols})
	_top_node.visible = not verts.is_empty()


func _apply_core() -> void:
	if _loops.is_empty() and not _ctx.is_empty():
		_loops = Mesher.collect_loops(field, _ctx)
	if _loops.is_empty():
		_ctx = Mesher.prepare(field)
		_loops = Mesher.collect_loops(field, _ctx)
	_set_core_payload(Mesher.build_core(field, _loops))


func _apply_rocks() -> void:
	_asm.rebuild(field, _loops, _rock_dirty, _rock_full or _asm.slots.is_empty())
	_rock_full = false
	var by_piece: Dictionary = _asm.batches()
	last_rock_count = _asm.rock_count
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
		rock_tris += int(row["tris"]) * xforms.size()
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
	var draws := 0
	if _top_node and _top_node.visible and _top_node.mesh and _top_node.mesh.get_surface_count() > 0:
		draws += 1
	if _core.mesh and _core.mesh.get_surface_count() > 0 and _core.visible:
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
