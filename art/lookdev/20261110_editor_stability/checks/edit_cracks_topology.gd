extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_probe.gd"

func nesting(field) -> Array:
	var result: Array = []
	for h: float in field.levels:
		for low: float in field.levels:
			if low >= h: continue
			var violations: Array = []
			for loop: PackedVector2Array in field.land_regions[h]:
				for i: int in loop.size():
					var a: Vector2 = loop[i]
					var b: Vector2 = loop[(i+1)%loop.size()]
					var inward := Vector2(a.y-b.y,b.x-a.x).normalized()
					for t: float in [0.0,.25,.5,.75]:
						var p: Vector2 = a.lerp(b,t)+inward*.02
						if Field.contains(field.land_regions[h],p) and not Field.contains(field.land_regions[low],p): violations.append(str(p))
			if not violations.is_empty(): result.append({"high":h,"low":low,"points":violations})
	return result

func run() -> void:
	var report: Dictionary = {}
	for name: String in ["fixture_original","fixture_04","fixture_10","stress_fixture_07","stress_fixture_23","stress_fixture_47","incremental_fixture"]:
		var data = Data.new()
		data.deserialize(JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("edit_cracks_"+name+".json"))))
		var field = Field.new()
		field.refresh(data)
		report[name]=nesting(field)
		print(name," nesting ",report[name])
	FileAccess.open(OUT.path_join("edit_cracks_topology.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
