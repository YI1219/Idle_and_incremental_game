extends "res://tests/interior_terrain_edit_test.gd"
func run() -> void:
	var decoration := Decoration.new()
	decoration.load_assets()
	for center: Vector2 in [Vector2(-8, -5), Vector2(13, 0)]:
		var data := Data.new()
		data.make_preset(0)
		for iteration: int in 4: lower(data, center, 3.8)
		var field := Field.new()
		field.refresh(data)
		var raw: PackedVector3Array = field.surfaces.cliff.vertices.duplicate()
		decoration._column_layout(field, data.seed)
		for height: float in field.land_regions:
			for loop: PackedVector2Array in field.land_regions[height]:
				for i: int in loop.size():
					var a: Vector2 = loop[i]
					var b: Vector2 = loop[(i + 1) % loop.size()]
					var p: Vector2 = (a + b) * .5
					if p.distance_to(center) > 4.3 or a.distance_to(b) < .12: continue
					var direction: Vector2 = (b - a).normalized()
					var outward := Vector2(direction.y, -direction.x)
					var receiver: Dictionary = field.surface_at(p + outward * .3)
					var upper: Dictionary = field.surface_at(p - outward * .25)
					if receiver.is_empty() or upper.is_empty() or int(receiver.water) >= 0 or int(upper.water) >= 0: continue
					var bottom: float = receiver.height
					if absf(float(upper.height) - height) > .01 or height - bottom < .4: continue
					for y: float in [height - .025, (height + bottom) * .5, bottom + .025]:
						var origin := Vector3(p.x + outward.x * 2.0, y, p.y + outward.y * 2.0)
						var dir := Vector3(-outward.x, 0.0, -outward.y)
						var hit := first_hit(field.surfaces.cliff.vertices, origin, dir)
						if not hit.is_finite() or origin.distance_to(hit) > 3.5:
							var before: Vector2 = loop[(i - 1 + loop.size()) % loop.size()]
							var after: Vector2 = loop[(i + 2) % loop.size()]
							var na := Vector2(b.y-before.y,before.x-b.x).normalized()
							var nb := Vector2(after.y-a.y,a.x-after.x).normalized()
							print("GAP ", p, " y ", y, " raw ", first_hit(raw,origin,dir), " a ", a, " b ", b, " profile_a ", field._cliff_profile(a,na), " profile_b ", field._cliff_profile(b,nb))
	quit()
