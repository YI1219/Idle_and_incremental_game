extends SceneTree
## Exercise budgeted publication, not just synchronous shell construction.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer = preload("res://scripts/terrain_editor/terrain_renderer.gd")
const EPS := 0.0001
const EDIT_CELL := Vector2i(5, 4)
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var data := _fixture()
	var renderer := Renderer.new()
	root.add_child(renderer)
	# Keep the morph clock deterministic; explicitly exercise the real build budget.
	renderer.set_process(false)
	renderer.configure(data)
	renderer.rebuild_all()
	var props_id := renderer.props.get_instance_id()
	var bench := renderer.props.get_node("BenchPlaceholder") as Node3D
	var bench_id := bench.get_instance_id()
	var bench_pose := bench.transform
	var before := _geometry_digest(renderer)
	var old_ids := _chunk_ids(renderer)
	check(renderer.chunks.size() > 1 and _pick_at_height(renderer, 1.5) and bench.visible and not renderer.island.water_regions.is_empty(), "fixture publishes multiple chunks, pickable terrain, water and a supported independent prop")

	data.begin_stroke()
	var changed := data.apply_brush(Vector2(EDIT_CELL) + Vector2(0.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	renderer.flush_dirty(1)
	check(changed == 1 and renderer.has_pending_updates() and _chunk_ids(renderer) == old_ids and _geometry_digest(renderer) == before and _pick_at_height(renderer, 1.5), "partial budget build retains the previous complete visible and pickable revision")
	var published := _flush_pending(renderer)
	check(published and _pick_at_height(renderer, 2.0), "completed budget build publishes the new geometry and matching pick height")
	var after := _geometry_digest(renderer)
	check(renderer.morph_progress < 1.0 and is_equal_approx(renderer.shown_top(EDIT_CELL), 1.5) and _published_seams_match(renderer), "live published morph has matching grass/rim source samples along the long wall")
	renderer._process(Renderer.MORPH_SECONDS)
	check(renderer.props.get_instance_id() == props_id and bench.get_instance_id() == bench_id and bench.visible and bench.transform == bench_pose, "unrelated terrain edit preserves the existing independent prop identity and pose")

	var undone := data.undo()
	var undo_published := _flush_pending(renderer)
	check(undone and undo_published and _pick_at_height(renderer, 1.5) and _geometry_digest(renderer) == before, "undo publishes the original pick height and geometry")
	renderer._process(Renderer.MORPH_SECONDS)
	var redone := data.redo()
	var redo_published := _flush_pending(renderer)
	check(redone and redo_published and _pick_at_height(renderer, 2.0) and _geometry_digest(renderer) == after, "redo publishes the edited pick height and geometry")
	renderer._process(Renderer.MORPH_SECONDS)

	old_ids = _chunk_ids(renderer)
	data.begin_stroke()
	var cells := data.cells.keys()
	for cell: Vector2i in cells:
		data.apply_brush(Vector2(cell) + Vector2(0.5, 0.5), 0.4, "contract", true, 2.0, 0)
	data.end_stroke()
	renderer.flush_dirty(1)
	check(data.cells.is_empty() and renderer.has_pending_updates() and _chunk_ids(renderer) == old_ids and _pick_at_height(renderer, 2.0) and bench.visible, "partial removal build retains the last complete revision and supported props")
	var empty_published := _flush_pending(renderer)
	var stale := _empty_state_issues(renderer)
	check(empty_published and stale.is_empty() and bench.get_instance_id() == bench_id and not bench.visible, "empty publication clears chunks, picking and water caches, and hides rather than deletes props; stale=%s" % ", ".join(stale))
	var restored := data.undo()
	var restored_published := _flush_pending(renderer)
	check(restored and restored_published and _geometry_digest(renderer) == after and _pick_at_height(renderer, 2.0) and not renderer.island.water_regions.is_empty() and bench.get_instance_id() == bench_id and bench.visible, "undoing removal restores geometry, picking, water and the same supported prop")

	renderer.free()
	print("HEIGHTMAP RENDERER: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func _fixture() -> Data:
	var data := Data.new()
	# This exposed run crosses the x=8 chunk boundary.
	for x in 10:
		data.cells[Vector2i(x, 4)] = {"height": 1.5 if x == 5 else 2.0, "water": -1}
	# Preserve the existing bench's ordinary support rules, without inventing a prop editor.
	for z in range(-4, 0):
		for x in range(9, 13):
			data.cells[Vector2i(x, z)] = {"height": 2.0, "water": -1}
	data.cells[Vector2i(20, 4)] = {"height": 0.0, "water": 3}
	return data

func _flush_pending(renderer: Renderer) -> bool:
	var steps := 0
	while renderer.has_pending_updates() and steps < 256:
		renderer.flush_dirty(1)
		steps += 1
	return not renderer.has_pending_updates()

func _pick_at_height(renderer: Renderer, height: float) -> bool:
	var hit := renderer.pick(Vector3(float(EDIT_CELL.x) + 0.5, 20.0, float(EDIT_CELL.y) + 0.5), Vector3.DOWN)
	return not hit.is_empty() and hit.cell == EDIT_CELL and absf(float(hit.position.y) - height) < EPS

func _chunk_ids(renderer: Renderer) -> Dictionary:
	var result := {}
	for chunk in renderer.chunks:
		result[chunk] = renderer.chunks[chunk].get_instance_id()
	return result

func _published_faces(renderer: Renderer, kind: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	for chunk: Node3D in renderer.chunks.values():
		var instance := chunk.get_node_or_null(kind) as MeshInstance3D
		if instance != null:
			result.append_array(instance.mesh.get_faces())
	return result

func _published_seams_match(renderer: Renderer) -> bool:
	var grass := _published_faces(renderer, "grass")
	var cliff := _published_faces(renderer, "cliff")
	for x in range(11):
		for z in [4, 5]:
			var point := Vector3(float(x), 2.0, float(z))
			if not _has_vertex(grass, point) or not _has_vertex(cliff, point):
				return false
	return true

func _has_vertex(vertices: PackedVector3Array, point: Vector3) -> bool:
	for vertex in vertices:
		if vertex.distance_squared_to(point) < EPS * EPS:
			return true
	return false

func _empty_state_issues(renderer: Renderer) -> PackedStringArray:
	var result := PackedStringArray()
	if not renderer.chunks.is_empty():
		result.append("chunks")
	if not renderer._pick_faces.is_empty() or not renderer._pick_bounds.is_empty():
		result.append("pick caches")
	if not renderer.pick(Vector3(5.5, 20.0, 4.5), Vector3.DOWN).is_empty():
		result.append("stale pick")
	for key in ["water_regions", "water_anchor_regions", "fall_veils", "splash_points", "triangle_chunks"]:
		var value = renderer.island.get(key)
		if not value.is_empty():
			result.append(key)
	return result

func _geometry_digest(renderer: Renderer) -> String:
	var triangles := PackedStringArray()
	for kind in ["grass", "cliff", "water", "waterfall", "lake_bed"]:
		var vertices := _published_faces(renderer, kind)
		for i in range(0, vertices.size(), 3):
			var points := PackedStringArray()
			for j in 3:
				var v := vertices[i + j]
				points.append("%.6f,%.6f,%.6f" % [v.x, v.y, v.z])
			points.sort()
			triangles.append(kind + ":" + ";".join(points))
	triangles.sort()
	return "\n".join(triangles).sha256_text()
