extends SceneTree
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
class Fixture:
	extends "res://scripts/terrain_editor/contour_terrain.gd"
	var strength: float = 1.0
	func surface_at(_point: Vector2) -> Dictionary:
		return {"height": 0.0, "water": 1}
	func _flow_edges(loop: PackedVector2Array, _height: float) -> Array:
		var edges: Array = []
		for index: int in loop.size():
			edges.append({"sample": {"height": 0.0 if index < 2 else 2.0, "water": 1}, "spill": index < 2, "start": float(index), "width": 2.0, "run": 1, "rate": strength * 0.45, "intensity": strength})
		return edges
var failures: int = 0
var checks: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func make_field(strength: float) -> RefCounted:
	var field := Fixture.new()
	field.strength = strength
	for kind: String in ["water", "waterfall", "bank"]:
		field.surfaces[kind] = Geometry.Surface.new()
	field._falls(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1.7,.7),Vector2(1.7,2),Vector2(0,2)]),2.0)
	return field
func _initialize() -> void:
	var field: RefCounted = make_field(1.0)
	var surface: RefCounted = field.surfaces.waterfall
	var lips: Array[Vector3] = []
	var feet: Array[Vector3] = []
	for vertex: Vector3 in surface.vertices:
		if is_equal_approx(vertex.y,2.0): lips.append(vertex)
		if is_equal_approx(vertex.y,.015): feet.append(vertex)
	var lip_width: float = 0.0
	var foot_width: float = 0.0
	for a: Vector3 in lips:
		for b: Vector3 in lips: lip_width=maxf(lip_width,a.distance_to(b))
	for a: Vector3 in feet:
		for b: Vector3 in feet: foot_width=maxf(foot_width,a.distance_to(b))
	check(absf(lip_width-foot_width)<.015,"connected fall preserves mouth width to receiving water")
	check(Contours._fall_offset(2.0,1.0)<.28,"spill lip keeps a shallow gravity trajectory")
	var thin: RefCounted = make_field(.2)
	var strong_uv: bool = true
	var thin_uv: bool = true
	var metric_drop: bool = false
	for uv: Vector2 in surface.uv:
		strong_uv=strong_uv and is_equal_approx(uv.x,1.0)
		metric_drop=metric_drop or uv.y>1.8
	for uv: Vector2 in thin.surfaces.waterfall.uv:
		thin_uv=thin_uv and is_equal_approx(uv.x,.2)
	check(strong_uv,"strong transfer intensity reaches every waterfall vertex")
	check(thin_uv,"weak transfer intensity reaches every waterfall vertex")
	check(metric_drop,"waterfall UV preserves physical drop in metres")
	var core: bool = false
	for color: Color in surface.colors: core=core or color.g>=.495
	check(not core,"one water sheet avoids opaque duplicate core")
	check(is_equal_approx(thin.fall_veils[0].intensity,.2),"veil preserves weak measured intensity")
	check(not thin.splash_points.is_empty() and is_equal_approx(thin.splash_points[0].intensity,.2),"impact preserves weak measured intensity")
	thin._index_triangles()
	var chunks_ok: bool = true
	var chunks_present: bool = false
	for chunk: Vector2i in thin.triangle_chunks:
		var built: Dictionary = thin.build(chunk)
		if built.waterfall.get_surface_count()==0:continue
		for uv: Vector2 in built.waterfall.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
			chunks_present=true
			chunks_ok=chunks_ok and is_equal_approx(uv.x,.2) and uv.y>=-.0001 and uv.y<=1.9851
	check(chunks_present and chunks_ok,"chunk clipping preserves strength and physical drop UV")
	print("WATERFALL FLOW SHAPE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
