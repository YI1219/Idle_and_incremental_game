extends SceneTree
const OldGrass = preload("/private/tmp/grass_field_before_20.gd")
const NewGrass = preload("res://scripts/terrain_editor/grass_field.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func triangle(points: Array[Vector3], greens: Array[float]) -> Mesh:
	var surface = Geometry.Surface.new()
	var n: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if n.y < 0.0:
		n = -n
	for i in 3:
		surface.vertices.append(points[i])
		surface.normals.append(n)
		surface.colors.append(Color(1.0, greens[i], 1.0, 1.0))
		surface.uv.append(Vector2.ZERO)
	return surface.mesh()

func exact_transform_set(node: MultiMeshInstance3D) -> Dictionary:
	var result: Dictionary = {}
	if node == null:
		return result
	var buffer: PackedFloat32Array = node.multimesh.buffer
	for i in node.multimesh.instance_count:
		result[buffer.slice(i * 12, i * 12 + 12).to_byte_array().hex_encode()] = true
	return result

func check_soft(points: Array[Vector3], label: String) -> void:
	var mesh: Mesh = triangle(points, [0.90, 0.90, 0.90])
	var old: MultiMeshInstance3D = OldGrass.build(mesh, Vector2i.ZERO)
	var added: MultiMeshInstance3D = NewGrass.build(mesh, Vector2i.ZERO)
	check(old == null, label + ": before excludes soft lip")
	check(added != null and added.multimesh.instance_count > 0, label + ": new soft lip is planted")
	if added != null:
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		if normal.y < 0.0:
			normal = -normal
		var max_normal_error: float = 0.0
		var max_depth_error: float = 0.0
		var max_root_error: float = 0.0
		var arrays: Array = added.multimesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var packed: PackedFloat32Array = added.multimesh.buffer
		for i in added.multimesh.instance_count:
			var off: int = i * 12
			var tr := Transform3D(Basis(Vector3(packed[off], packed[off + 4], packed[off + 8]), Vector3(packed[off + 1], packed[off + 5], packed[off + 9]), Vector3(packed[off + 2], packed[off + 6], packed[off + 10])), Vector3(packed[off + 3], packed[off + 7], packed[off + 11]))
			max_normal_error = maxf(max_normal_error, tr.basis.y.normalized().distance_to(normal))
			max_depth_error = maxf(max_depth_error, absf(normal.dot(tr.origin - points[0]) + 0.008))
			for j in vertices.size():
				if colors[j].r == 0.0:
					max_root_error = maxf(max_root_error, absf(normal.dot(tr * vertices[j] - points[0]) + 0.008))
		print("%s count=%d normal_error=%.9f depth_error=%.9f root_error=%.9f" % [label, added.multimesh.instance_count, max_normal_error, max_depth_error, max_root_error])
		check(max_normal_error < 0.00001, label + ": UP follows upward triangle normal")
		check(max_depth_error < 0.00001, label + ": clump center is buried exactly 8mm")
		check(max_root_error < 0.00001, label + ": every blade root stays 8mm inside plane")
		added.free()

func run() -> void:
	var flat_points: Array[Vector3] = [Vector3(30, 0, 30), Vector3(34, 0, 30), Vector3(30, 0, 34)]
	var slope_points: Array[Vector3] = [Vector3(30, 0, 30), Vector3(34, -0.8, 30), Vector3(30, 0, 34)]
	var flat: Mesh = triangle(flat_points, [1.0, 1.0, 1.0])
	var before: MultiMeshInstance3D = OldGrass.build(flat, Vector2i.ZERO)
	var after: MultiMeshInstance3D = NewGrass.build(flat, Vector2i.ZERO)
	check(before != null and after != null and before.multimesh.buffer == after.multimesh.buffer, "flat interior packed transforms are byte-for-byte unchanged")
	print("flat count=", after.multimesh.instance_count)
	before.free()
	after.free()
	var mixed: Mesh = triangle(slope_points, [1.0, 0.98, 0.80])
	before = OldGrass.build(mixed, Vector2i.ZERO)
	after = NewGrass.build(mixed, Vector2i.ZERO)
	var old_set: Dictionary = exact_transform_set(before)
	var new_set: Dictionary = exact_transform_set(after)
	var preserved: bool = not old_set.is_empty()
	for key in old_set:
		preserved = preserved and new_set.has(key)
	check(preserved, "all old mixed-edge transforms are present byte-for-byte")
	check(new_set.size() > old_set.size(), "mixed edge gains only new samples")
	print("mixed old=%d new=%d" % [old_set.size(), new_set.size()])
	before.free()
	after.free()
	check_soft(slope_points, "downward winding")
	var reverse_points: Array[Vector3] = [slope_points[0], slope_points[2], slope_points[1]]
	check_soft(reverse_points, "upward winding")
	var outer: MultiMeshInstance3D = NewGrass.build(triangle(slope_points, [0.80, 0.80, 0.80]), Vector2i.ZERO)
	check(outer == null, "outer lip below G=.82 remains clear")
	print("GRASS FIELD 20: checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
