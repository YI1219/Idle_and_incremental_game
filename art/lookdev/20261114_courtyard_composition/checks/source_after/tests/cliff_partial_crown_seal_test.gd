extends "res://tests/interior_terrain_edit_test.gd"
## A crown covering the midpoint must not suppress the exposed half of a step.
func run() -> void:
	var deco := Decoration.new(); deco.load_assets()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/partial_crown_terrain.json"))
	var a := Vector2(-2.0,7.75)
	var b := Vector2(-3.1,9.0)
	var tangent: Vector2 = (b-a).normalized()
	var outward := Vector2(tangent.y,-tangent.x)
	# Keep the original bug reproducer independent from art-preset changes,
	# and exercise the same exposed wall on the current foreground ledge.
	for historical: bool in [true,false]:
		for sample_seed: int in [7301,2104,4242]:
			var data := Data.new()
			if historical:
				check(data.deserialize(fixture),"historical partial-crown fixture loads")
			else:data.make_preset(0)
			data.seed = sample_seed
			var field := Field.new(); field.refresh(data); deco._column_layout(field,data.seed)
			# Seed 2104's wider crown starts before t=.3; only its exposed
			# t=.1/.2 intervals belong to this continuous-wall contract.
			var exposed: Array = [.1,.2] if sample_seed == 2104 else [.1,.2,.3]
			for fraction: float in exposed:
				var point: Vector2 = a.lerp(b,fraction)
				var upper: Dictionary = field.surface_at(point-outward*.3)
				var lower: Dictionary = field.surface_at(point+outward*.3)
				check(not upper.is_empty() and not lower.is_empty() and float(upper.height)>float(lower.height),"fixture contains the exposed terrace step")
				for ratio: float in [.25,.5,.9]:
					var height: float = lerpf(float(lower.height),float(upper.height),ratio)
					var origin := Vector3(point.x+outward.x*.3,height,point.y+outward.y*.3)
					var hit := first_hit(field.surfaces.cliff.vertices,origin,Vector3(-outward.x,0,-outward.y))
					check(hit.is_finite() and origin.distance_to(hit)<.32,"partial crown skips exposed wall historical %s seed %d t %.1f height %.1f hit %s" % [historical,sample_seed,fraction,height,hit])
	print("CLIFF PARTIAL CROWN SEAL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
