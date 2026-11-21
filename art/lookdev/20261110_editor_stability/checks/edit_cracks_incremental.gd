extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_probe.gd"
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")

func mesh_faces(chunk: Node3D, kind: String) -> PackedVector3Array:
	if chunk == null: return PackedVector3Array()
	var instance: MeshInstance3D = chunk.get_node_or_null(kind)
	if instance == null: return PackedVector3Array()
	return Geometry.faces_of(instance.mesh)

func compare_chunks(renderer) -> Array:
	var diffs: Array = []
	var all_chunks: Dictionary = renderer.chunks.duplicate()
	all_chunks.merge(renderer.contours.triangle_chunks,true)
	for chunk: Vector2i in all_chunks:
		var fresh: Dictionary = renderer.contours.build(chunk)
		var entry: Dictionary = {"chunk":str(chunk),"kinds":{}}
		for kind: String in ["cliff","stone_mantle","grass","rim_green"]:
			var expected: PackedVector3Array = Geometry.faces_of(fresh[kind]) if fresh.has(kind) else PackedVector3Array()
			var actual: PackedVector3Array = mesh_faces(renderer.chunks.get(chunk),kind)
			if actual == expected: continue
			entry.kinds[kind] = {"actual_vertices":actual.size(),"expected_vertices":expected.size()}
		if not entry.kinds.is_empty(): diffs.append(entry)
	return diffs

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	var data = editor.data
	var renderer = editor.renderer
	var centers: Array[Vector2] = [Vector2(-8,-4),Vector2(-8,-7),Vector2(-5,-5),Vector2(-11,-5),Vector2(8,-2),Vector2(12,0),Vector2(15,3),Vector2(13,7)]
	var report: Array = []
	for iteration: int in 24:
		var center: Vector2 = centers[iteration%centers.size()]
		var cell: Vector2i = Vector2i(center.floor())
		var height: float = Data._record_top(data.cells[cell])
		data.begin_stroke()
		for step: int in 5:
			data.apply_brush(center+Vector2(step*.45,-step*.30),3.8,"lower",false,height,7,height)
		data.end_stroke()
		var snapshot = renderer._snapshot()
		var wanted: Dictionary = renderer._affected_chunks(snapshot)
		renderer._back_contours.inherit_generation_cache(renderer.contours)
		renderer._contour_revision = data.revision
		data.dirty_chunks.clear()
		renderer._worker_build(snapshot,renderer._back_contours,wanted,Time.get_ticks_usec())
		renderer._adopt_worker_result()
		renderer._flush_staging()
		renderer._process(1.0)
		var diffs: Array = compare_chunks(renderer)
		var entry: Dictionary = {"iteration":iteration,"wanted":str(wanted.keys()),"morph":renderer.morph_progress,"retiring":renderer._retiring_chunks.size(),"differences":diffs}
		report.append(entry)
		print("INCREMENTAL ",iteration," wanted ",wanted.size()," diffs ",diffs)
		if iteration == 23:
			FileAccess.open(OUT.path_join("edit_cracks_incremental_fixture.json"),FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),"\t"))
	renderer.rebuild_all()
	report.append({"full_rebuild_differences":compare_chunks(renderer),"morph":renderer.morph_progress,"retiring":renderer._retiring_chunks.size()})
	FileAccess.open(OUT.path_join("edit_cracks_incremental.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	editor.free()
	quit()
