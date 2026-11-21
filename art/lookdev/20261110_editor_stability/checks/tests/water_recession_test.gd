extends SceneTree
## A receding pool must pass over its fixed physical bed through the mouth.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Flow = preload("res://scripts/terrain_editor/water_flow.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func first_hit(vertices: PackedVector3Array, origin: Vector3, direction: Vector3) -> Vector3:
	var nearest: float = INF
	var result: Vector3 = Vector3.INF
	for index: int in range(0, vertices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, vertices[index], vertices[index + 1], vertices[index + 2])
		if hit != null and origin.distance_squared_to(hit) < nearest:
			nearest = origin.distance_squared_to(hit)
			result = hit
	return result

func _initialize() -> void:
	var data: Data = Data.new()
	data.make_preset(0)
	var field: ContourTerrain = Contours.new()
	field.refresh(data)
	var decoration: RefCounted = Decoration.new()
	decoration.load_assets()
	decoration._column_layout(field, 7301)
	var original_beds: Dictionary = data.cells.duplicate(true)
	var solver: RefCounted = Flow.new()
	solver.configure(data)
	for tick: int in range(600):
		solver.step(0.1)
	check(absf(float(solver.heights[Vector2i(1, 1)]) - 3.14567522935513) < 0.00000001, "the regression reaches the observed receded upper pool")
	check(data.cells == original_beds, "natural recession leaves every authored bed fixed")
	var origin: Vector3 = Vector3(11.868763923645, 9.5, 4.56456661224365)
	var camera: Basis = Basis.from_euler(Vector3(deg_to_rad(-36.0), deg_to_rad(67.0), 0.0))
	var lens: float = tan(deg_to_rad(15.5))
	var solid: PackedVector3Array = field.surfaces.cliff.vertices.duplicate()
	solid.append_array(field.surfaces.lake_bed.vertices)
	for pixel: Vector2 in [Vector2(1000, 465), Vector2(1075, 465), Vector2(1150, 465), Vector2(1075, 510)]:
		var direction: Vector3 = camera * Vector3((pixel.x / 2560.0 * 2.0 - 1.0) * lens * 2560.0 / 1440.0, (1.0 - pixel.y / 1440.0 * 2.0) * lens, -1.0).normalized()
		var hit: Vector3 = first_hit(solid, origin, direction)
		check(hit.is_finite() and hit.y <= 3.00001, "the old nominal lip is at or below the physical 3m bed at pixel %s, hit %s" % [pixel, hit])
	for z: int in [0, 1]:
		var hit: Vector3 = first_hit(solid, Vector3(1.5, 3.1, float(z) + 0.5), Vector3.RIGHT)
		check(not hit.is_finite() or hit.x > 2.75, "the exposed outlet above its bed stays open to receding water at row %d, hit %s" % [z, hit])
	var soft: ContourTerrain = Contours.new()
	soft.soft_water_corners = true
	soft.refresh(data)
	for x: float in [1.55, 1.75, 1.95]:
		var top: Vector3 = first_hit(soft.surfaces.lake_bed.vertices, Vector3(x, 4.0, 1.25), Vector3.DOWN)
		check(top.is_finite() and top.y <= 3.00001, "the alternate local-bed mesh keeps the same physical outlet height at x %s, hit %s" % [x, top])
	var dry: Data = data.copy()
	for cell: Vector2i in dry.cells:
		dry.cells[cell].water_volume = 0.0
	solver.configure(dry)
	check(solver.total_volume() == 0.0, "the fully dry endpoint has no residual or regenerated physical water")
	var dry_field: ContourTerrain = Contours.new()
	dry_field.refresh(dry)
	var dry_decoration: RefCounted = Decoration.new()
	dry_decoration.load_assets()
	dry_decoration._column_layout(dry_field, 7301)
	# Compare the actual two water states. The old absolute hashes also locked
	# unsafe interior source walls, intentionally removed by the edit-crack fix.
	check(dry_field.surfaces.grass.vertices == field.surfaces.grass.vertices, "water recession retains every dry grass crown vertex")
	check(hash(dry_decoration._columns) == hash(decoration._columns) and hash(dry_decoration._mass) == hash(decoration._mass), "water recession keeps independent rock masses in place")
	check(dry_field.surfaces.cliff.vertices == field.surfaces.cliff.vertices, "the fixed outlet facade is independent of current water volume")
	check(dry_field.surfaces.lake_bed.vertices == field.surfaces.lake_bed.vertices, "the fully exposed pool bed retains the same static physical mouth")
	print("RECESSION BASELINE grass=", hash(field.surfaces.grass.vertices), " columns=", hash(decoration._columns), " mass=", hash(decoration._mass))
	print("WATER RECESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
