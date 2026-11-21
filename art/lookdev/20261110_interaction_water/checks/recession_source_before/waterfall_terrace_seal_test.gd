extends SceneTree
## Grazing rays through the reported gap must meet the upper terrace wall,
## instead of the far underside of the island beneath the receiving pond.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const PIXELS: Array[Vector2] = [Vector2(1450, 850), Vector2(1520, 825), Vector2(1470, 780), Vector2(1420, 880)]
var checks: int = 0
var failures: int = 0

func _first_hit(vertices: PackedVector3Array, origin: Vector3, direction: Vector3) -> Vector3:
	var nearest: float = INF
	var result := Vector3(INF, INF, INF)
	for i: int in range(0, vertices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction,
			vertices[i], vertices[i + 1], vertices[i + 2])
		if hit != null and origin.distance_squared_to(hit) < nearest:
			nearest = origin.distance_squared_to(hit)
			result = hit
	return result

func _initialize() -> void:
	var decoration := Decoration.new()
	decoration.load_assets()
	var origin := Vector3(5.6589627, 9.5, 8.1054411)
	var rotation := Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(20.0), 0.0))
	var half_fov: float = tan(deg_to_rad(15.5))
	for seed_value: int in [7301, 2104, 4242, 913]:
		var data := Data.new()
		data.make_preset(0)
		data.seed = seed_value
		var field := Contours.new()
		field.refresh(data)
		decoration._column_layout(field, seed_value)
		for pixel: Vector2 in PIXELS:
			var direction := rotation * Vector3((pixel.x / 2560.0 * 2.0 - 1.0) * half_fov * 2560.0 / 1440.0,
				(1.0 - pixel.y / 1440.0 * 2.0) * half_fov, -1.0).normalized()
			var hit := _first_hit(field.surfaces.cliff.vertices, origin, direction)
			checks += 1
			if not hit.is_finite() or hit.y < 1.45 or hit.y > 3.55:
				failures += 1
				push_error("Waterfall shoulder exposes cavity, seed %d, pixel %s, hit %s" % [seed_value, pixel, hit])
	print("WATERFALL TERRACE SEAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
