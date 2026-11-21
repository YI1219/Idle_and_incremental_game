extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rows: Array = []
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261111_editor_response/checks/source_before/scripts/terrain_editor/editor.gd").replace("class_name TerrainEditor\n", "")
	if baseline.reload() != OK:
		quit(1)
		return
	for old: bool in [true, false]:
		var editor: Node3D = Node3D.new()
		editor.set_script(baseline if old else load("res://scripts/terrain_editor/editor.gd"))
		root.add_child(editor)
		editor.set_process(false)
		editor.camera.set_process(false)
		var point: Vector2 = editor.camera.unproject_position(Vector3(-10.5,3.5,-2.5))
		var samples: Array = []
		for i in 100:
			var start: int = Time.get_ticks_usec()
			editor._update_brush(point+Vector2(i%5,i%7))
			samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		samples.sort()
		rows.append({"version":"before" if old else "current","p50_ms":samples[50],"p95_ms":samples[95],"max_ms":samples[-1]})
		editor.free()
	FileAccess.open("res://art/lookdev/20261111_editor_response/checks/pointer_benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print(rows)
	quit()
