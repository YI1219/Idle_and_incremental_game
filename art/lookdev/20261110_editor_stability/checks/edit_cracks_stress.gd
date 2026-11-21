extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_probe.gd"

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	var data = editor.data
	var field = Field.new()
	var decoration = Decoration.new()
	decoration.load_assets()
	var centers: Array[Vector2] = [Vector2(-8,-4),Vector2(-8,-7),Vector2(-5,-5),Vector2(-11,-5),Vector2(8,-2),Vector2(12,0),Vector2(15,3),Vector2(13,7)]
	for iteration: int in 48:
		var center: Vector2 = centers[iteration%centers.size()]
		var cell: Vector2i = Vector2i(center.floor())
		var height: float = Data._record_top(data.cells[cell])
		data.begin_stroke()
		for step: int in 5:
			data.apply_brush(center+Vector2(step*.45,-step*.30),3.8,"lower",false,height,7,height)
		data.end_stroke()
		field.refresh(data)
		var raw: Dictionary = summarize(field,"stress_raw_%02d"%iteration)
		records.append(raw)
		decoration._column_layout(field,data.seed)
		var final: Dictionary = summarize(field,"stress_final_%02d"%iteration)
		records.append(final)
		print("STRESS iteration ",iteration," levels ",field.levels," suspicious ", final.kinds.cliff.suspicious.size(),"/",final.kinds.stone_mantle.suspicious.size())
		if iteration in [7,15,23,31,47]:
			dump_obj(field,OUT.path_join("edit_cracks_stress_%02d.obj"%iteration))
			FileAccess.open(OUT.path_join("edit_cracks_stress_fixture_%02d.json"%iteration),FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),"\t"))
	FileAccess.open(OUT.path_join("edit_cracks_stress.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	editor.free()
	quit()
