extends "res://tests/interior_terrain_edit_test.gd"
## A crown covering the midpoint must not suppress the exposed half of a step.
func run() -> void:
	var deco := Decoration.new(); deco.load_assets()
	var a := Vector2(-2.0,7.75)
	var b := Vector2(-3.1,9.0)
	var tangent: Vector2 = (b-a).normalized()
	var outward := Vector2(tangent.y,-tangent.x)
	for sample_seed: int in [7301,2104,4242]:
		var data := Data.new(); data.make_preset(0); data.seed = sample_seed
		var field := Field.new(); field.refresh(data); deco._column_layout(field,data.seed)
		# Seed 2104's wider crown starts before t=.3; only its exposed
		# t=.1/.2 intervals belong to this continuous-wall contract.
		var exposed: Array = [.1,.2] if sample_seed == 2104 else [.1,.2,.3]
		for fraction: float in exposed:
			var point: Vector2 = a.lerp(b,fraction)
			for height: float in [2.0,2.5,3.3]:
				var origin := Vector3(point.x+outward.x*.3,height,point.y+outward.y*.3)
				var hit := first_hit(field.surfaces.cliff.vertices,origin,Vector3(-outward.x,0,-outward.y))
				check(hit.is_finite() and origin.distance_to(hit)<.32,"partial crown skips exposed wall seed %d t %.1f height %.1f hit %s" % [sample_seed,fraction,height,hit])
	print("CLIFF PARTIAL CROWN SEAL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
