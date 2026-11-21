extends "res://tests/courtyard_composition_test.gd"
## Inspect real uploaded grass transforms, rather than duplicating its filter.
func run() -> void:
	var data := Data.new()
	data.make_preset(0)
	var field := Field.new()
	field.refresh(data)
	var grass: MultiMeshInstance3D = preload("res://scripts/terrain_editor/grass_field.gd").build(field.surfaces.grass.mesh(), Vector2i.ZERO)
	check(grass != null, "actual courtyard grass instances exist")
	if grass != null:
		var count: int = grass.multimesh.instance_count
		var clear: bool = true
		var nearest: float = INF
		for index: int in count:
			var p: Vector3 = grass.multimesh.get_instance_transform(index).origin
			nearest = minf(nearest, route_distance(Vector2(p.x, p.z)))
			clear = clear and route_distance(Vector2(p.x, p.z)) >= .6
		check(count > 1000, "inspect the full actual grass field")
		check(clear, "actual grass roots leave the paved corridor open (nearest %.4fm)" % nearest)
		grass.free()
	print("courtyard_grass_clearance: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
