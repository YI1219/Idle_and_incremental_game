extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const OUT = "res://art/lookdev/20261110_editor_stability/checks"
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func summarize(field, label: String) -> Dictionary:
	var result: Dictionary = {"label": label, "levels": field.levels, "kinds": {}}
	for kind: String in ["cliff", "stone_mantle", "grass"]:
		if not field.surfaces.has(kind): continue
		var vertices: PackedVector3Array = field.surfaces[kind].vertices
		var sheets: Array = []
		var long_triangles: Array = []
		for i: int in range(0, vertices.size(), 3):
			var a: Vector3 = vertices[i]
			var b: Vector3 = vertices[i+1]
			var c: Vector3 = vertices[i+2]
			var center: Vector3 = (a+b+c)/3.0
			var at: Vector2 = Vector2(center.x, center.z)
			if at.distance_to(Vector2(-8,-5)) > 9.0: continue
			var area: float = (b-a).cross(c-a).length()*.5
			var longest: float = maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
			if longest > 4.0:
				long_triangles.append({"i": i, "area": area, "longest": longest, "a": str(a), "b": str(b), "c": str(c)})
			var support: Dictionary = field.surface_at(at)
			if support.is_empty() or center.y < float(support.height)+.12: continue
			var border: float = INF
			for h: float in field.land_regions:
				if h < center.y: continue
				for loop: PackedVector2Array in field.land_regions[h]:
					for j: int in loop.size():
						border = minf(border, at.distance_to(Geometry2D.get_closest_point_to_segment(at, loop[j], loop[(j+1)%loop.size()])))
			if border > .55 and area > .02:
				sheets.append({"i": i, "area": area, "support": support.height, "border": border, "a": str(a), "b": str(b), "c": str(c)})
		result.kinds[kind] = {"vertices": vertices.size(), "suspicious": sheets, "long": long_triangles}
	return result

func dump_obj(field, path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var index: int = 1
	for kind: String in ["cliff", "stone_mantle", "grass"]:
		if not field.surfaces.has(kind): continue
		f.store_line("o "+kind)
		var vertices: PackedVector3Array = field.surfaces[kind].vertices
		for i: int in range(0, vertices.size(), 3):
			var center: Vector3 = (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
			if Vector2(center.x,center.z).distance_to(Vector2(-8,-5))>10: continue
			for j: int in 3:
				var p: Vector3 = vertices[i+j]
				f.store_line("v %.7f %.7f %.7f"%[p.x,p.y,p.z])
			f.store_line("f %d %d %d"%[index,index+2,index+1])
			index += 3

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	var data = editor.data
	var field = Field.new()
	var decoration = Decoration.new()
	decoration.load_assets()
	var original: Dictionary = data.serialize()
	for iteration: int in 12:
		if iteration > 0:
			var cell := Vector2i(-9,-6)
			var height: float = Data._record_top(data.cells[cell])
			data.begin_stroke()
			data.apply_brush(Vector2(-8,-5),3.8,"lower",false,height,7,height)
			data.end_stroke()
		field.refresh(data)
		records.append(summarize(field,"raw_%02d"%iteration))
		decoration._column_layout(field,data.seed)
		records.append(summarize(field,"final_%02d"%iteration))
		print("PROBE iteration ",iteration," levels ",field.levels," cliff ",field.surfaces.cliff.vertices.size())
		if iteration in [0,4,7,10]:
			dump_obj(field,OUT.path_join("edit_cracks_%02d.obj"%iteration))
			FileAccess.open(OUT.path_join("edit_cracks_fixture_%02d.json"%iteration),FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),"\t"))
	FileAccess.open(OUT.path_join("edit_cracks_probe.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	FileAccess.open(OUT.path_join("edit_cracks_fixture_original.json"),FileAccess.WRITE).store_string(JSON.stringify(original,"\t"))
	editor.free()
	quit()
