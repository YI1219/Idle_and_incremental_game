extends SceneTree

const HELPER := "res://art/lookdev/20261113_background_foliage/checks/foliage_candidate.gd"
const GEOMETRY := preload("res://scripts/terrain_editor/chunk_geometry.gd")
const SHADER := preload("res://shaders/terrain_editor/foliage_cards.gdshader")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture() -> ArrayMesh:
	var points: Array[Vector3] = [Vector3(0, .2, 0), Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	var coordinates: Array[Vector2] = [Vector2(.25, .25), Vector2(0, .5), Vector2(.5, .5), Vector2(.5, 0), Vector2(0, 0)]
	var surface = GEOMETRY.Surface.new()
	for triangle: Array in [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1]]:
		for i: int in triangle:
			surface.vertices.append(points[i])
			surface.normals.append((Vector3.UP + points[i] * .2).normalized())
			surface.colors.append(Color(.96, .3 + float(i) * .1, .4 + float(i) * .1, 1))
			surface.uv.append(coordinates[i])
	var mesh: ArrayMesh = surface.mesh()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("sway_strength", .065)
	material.set_shader_parameter("leaf_mid", Color(.2, .31, .19))
	mesh.surface_set_material(0, material)
	return mesh

func expanded(arrays: Array, slot: int) -> Array:
	var values: Array = []
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in indices.size():
		values.append(arrays[slot][indices[i]])
	return values

func run() -> void:
	check(FileAccess.file_exists(HELPER), "candidate helper is available")
	if failures:
		print("FOLIAGE CANDIDATE ", checks, " checks, ", failures, " failures")
		quit(1)
		return
	var candidate = load(HELPER).new()
	var parent := Node3D.new()
	var original := fixture()
	var source: Array = GEOMETRY.arrays_of(original)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = original
	mm.instance_count = 2
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(3, 0, 0)))
	var buffer_before: PackedFloat32Array = mm.buffer
	var multi := MultiMeshInstance3D.new()
	multi.multimesh = mm
	multi.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(8, 3, 4))
	parent.add_child(multi)
	var single := MeshInstance3D.new()
	single.mesh = original
	parent.add_child(single)
	var unrelated := MeshInstance3D.new()
	unrelated.mesh = BoxMesh.new()
	var unrelated_mesh: Mesh = unrelated.mesh
	parent.add_child(unrelated)
	var live_shader: Shader = SHADER
	var shader_before: String = live_shader.code
	var report: Dictionary = candidate.apply(parent, "exact_index")
	var optimized: Mesh = mm.mesh
	var indexed: Array = GEOMETRY.arrays_of(optimized)
	check(report.get("mesh_count") == 1, "shared source mesh is rebuilt once")
	check(report.get("vertices_before") == 12 and report.get("vertices_after") == 5, "twelve fan vertices become five exact vertices")
	check(indexed[Mesh.ARRAY_INDEX].size() == 12, "all four curved triangles remain")
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		check(expanded(indexed, slot) == Array(source[slot]), "expanded vertex stream is exact for slot %d" % slot)
	check(optimized.get_faces() == original.get_faces(), "ordered geometric triangles are exact")
	check(optimized.get_aabb() == original.get_aabb(), "automatic bounding box remains exact")
	check(optimized.surface_get_material(0) == original.surface_get_material(0), "material and all uniforms remain shared and unchanged")
	check(mm.mesh == single.mesh, "all users of shared source mesh reuse indexed replacement")
	check(mm.buffer == buffer_before and mm.instance_count == 2, "placement buffers and instance quantity remain exact")
	check(multi.custom_aabb == AABB(Vector3(-2, -1, -2), Vector3(8, 3, 4)), "instance culling bounds remain exact")
	check(unrelated.mesh == unrelated_mesh and live_shader.code == shader_before, "index mode leaves other geometry and shader unchanged")
	candidate.restore()
	check(mm.mesh == original and single.mesh == original, "restore recovers original mesh references")
	var early_report: Dictionary = candidate.apply(parent, "early_alpha")
	check(early_report.get("shader_count") == 1, "shared foliage shader is patched once")
	check(live_shader.code == shader_before.replace("\tvec4 tex=texture(leaf_atlas,UV);\n", "\tvec4 tex=texture(leaf_atlas,UV);\n\tif(tex.a<.23)discard; // Candidate: same existing scissor test, before pigment math.\n"), "early alpha changes only the location of the existing cutoff")
	check(mm.mesh == original and single.mesh == original, "early alpha mode changes no geometry")
	check(live_shader.resource_path == "res://shaders/terrain_editor/foliage_cards.gdshader", "shader resource path remains usable by daily palette updates")
	candidate.restore()
	check(live_shader.code == shader_before, "restore recovers source shader byte for byte")
	var repeat_report: Dictionary = candidate.apply(parent, "combined")
	check(repeat_report.get("mesh_count") == 1 and repeat_report.get("shader_count") == 1, "combined candidate applies both independent changes")
	candidate.restore()
	parent.free()
	print("FOLIAGE CANDIDATE ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
