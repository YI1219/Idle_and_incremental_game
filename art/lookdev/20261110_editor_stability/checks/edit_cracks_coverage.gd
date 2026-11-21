extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_probe.gd"

func coverage(field) -> Dictionary:
	var missing: Array = []
	var extra: Array = []
	var triangles: PackedVector3Array = field.surfaces.grass.vertices
	for cell: Vector2i in field.source.cells:
		var record: Dictionary = field.source.cells[cell]
		if record.water >= 0: continue
		var p := Vector2(cell)+Vector2(.5,.5)
		var highest: float = -INF
		for i: int in range(0,triangles.size(),3):
			var a: Vector3 = triangles[i]
			var b: Vector3 = triangles[i+1]
			var c: Vector3 = triangles[i+2]
			if maxf(a.x,maxf(b.x,c.x))<p.x or minf(a.x,minf(b.x,c.x))>p.x: continue
			if maxf(a.z,maxf(b.z,c.z))<p.y or minf(a.z,minf(b.z,c.z))>p.y: continue
			var a2 := Vector2(a.x,a.z)
			var ab := Vector2(b.x,b.z)-a2
			var ac := Vector2(c.x,c.z)-a2
			var ap := p-a2
			var denominator: float = ab.cross(ac)
			if absf(denominator)<.0000001: continue
			var u: float = ap.cross(ac)/denominator
			var v: float = ab.cross(ap)/denominator
			if u<-.000001 or v<-.000001 or u+v>1.000001: continue
			highest=maxf(highest,a.y+(b.y-a.y)*u+(c.y-a.y)*v)
		if highest<float(record.height)-.30: missing.append({"cell":str(cell),"expected":record.height,"grass":str(highest)})
		if highest>float(record.height)+.30: extra.append({"cell":str(cell),"expected":record.height,"grass":str(highest)})
	return {"missing":missing,"extra":extra}

func run() -> void:
	var report: Dictionary = {}
	for name: String in ["fixture_original","fixture_04","fixture_10","stress_fixture_07","stress_fixture_23","stress_fixture_47"]:
		var data = Data.new()
		data.deserialize(JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("edit_cracks_"+name+".json"))))
		var field = Field.new()
		field.refresh(data)
		var raw: Dictionary = coverage(field)
		var decoration = Decoration.new()
		decoration.load_assets()
		decoration._column_layout(field,data.seed)
		var final: Dictionary = coverage(field)
		report[name]={"raw":raw,"final":final}
		print(name," raw missing ",raw.missing.size()," extra ",raw.extra.size()," final missing ",final.missing.size()," extra ",final.extra.size())
	FileAccess.open(OUT.path_join("edit_cracks_coverage.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
