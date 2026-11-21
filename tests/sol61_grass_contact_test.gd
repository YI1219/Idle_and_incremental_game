extends SceneTree
const Grass = preload("res://scripts/terrain_editor/grass_field.gd")
const Surface = preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("ok: ", message)

func _initialize() -> void:
	var ribbon_uv:PackedVector2Array=Grass.clump_mesh().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var width_uv:bool=true
	var low:float=INF
	var high:float=-INF
	for uv:Vector2 in ribbon_uv:
		low=minf(low,uv.x);high=maxf(high,uv.x)
		width_uv=width_uv and uv.x>=0.0 and uv.x<=1.0
	check(width_uv and low==0.0 and high==1.0, "ribbon UV spans normalized blade width for pixel filtering")
	var base := Vector3(70, 0, 50)
	var a: Vector3 = base
	var b: Vector3 = base + Vector3(2, 0, 0)
	var c: Vector3 = base + Vector3(0, -0.36, 0.7)
	var surface := Surface.new()
	surface.triangle(a, b, c, Color(0.85, 0.76, 0.65, 1.0), true)
	var grass: MultiMeshInstance3D = Grass.build(surface.mesh(), Vector2i.ZERO)
	check(grass != null, "outer grass lip carries planted tufts instead of a bare strip")
	if grass != null:
		# Dummy headless MultiMesh storage returns identity transforms after a bulk
		# buffer upload. Run this script graphically to check GPU transforms too.
		if DisplayServer.get_name() != "headless":
			var up: Vector3 = (c-a).cross(b-a).normalized()
			var planted: bool = true
			for index: int in grass.multimesh.instance_count:
				var pose: Transform3D = grass.multimesh.get_instance_transform(index)
				planted = planted and pose.basis.y.normalized().dot(up) > 0.995
				var contact: float = (pose.origin-a).dot(up)
				planted = planted and contact >= -0.012 and contact <= 0.001
			check(planted, "every lip tuft follows the real slope with buried roots")
		grass.free()
	var stone := Surface.new()
	stone.triangle(a, b, c, Color(0.7, 0.64, 0.55, 1.0), true)
	var stone_grass: MultiMeshInstance3D = Grass.build(stone.mesh(), Vector2i.ZERO)
	check(stone_grass == null, "grass does not grow on the exposed stone/root strip")
	if stone_grass != null: stone_grass.free()
	var rolled_edge := Surface.new()
	rolled_edge.triangle(base, base+Vector3(2,0,0), base+Vector3(0,-0.5,0.4), Color(0.85,0.76,0.65,1.0), true)
	var rolled_grass: MultiMeshInstance3D = Grass.build(rolled_edge.mesh(), Vector2i.ZERO)
	check(rolled_grass != null, "grass continues onto the rounded outer slope")
	if rolled_grass != null: rolled_grass.free()
	print("SOL61 GRASS CONTACT failures: ", failures)
	quit(1 if failures > 0 else 0)
