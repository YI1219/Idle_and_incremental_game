extends RefCounted
## Experimental in-memory candidate. Never writes assets or production sources.
## Keep this object alive until restore(); apply only to a settled live scene.
## Modes: early_alpha (default), exact_index, combined.

const GEOMETRY := preload("res://scripts/terrain_editor/chunk_geometry.gd")
const SHADER_PATH := "res://shaders/terrain_editor/foliage_cards.gdshader"
const SAMPLE_LINE := "\tvec4 tex=texture(leaf_atlas,UV);\n"
const EARLY_LINE := "\tif(tex.a<.23)discard; // Candidate: same existing scissor test, before pigment math.\n"
const SLOTS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
var _mesh_users: Array[Dictionary] = []
var _shaders: Array[Dictionary] = []

func apply(editor: Node, mode: String = "early_alpha") -> Dictionary:
	assert(_mesh_users.is_empty() and _shaders.is_empty(), "restore the previous candidate before apply")
	assert(mode in ["early_alpha", "exact_index", "combined"], "unknown foliage candidate mode")
	var report: Dictionary = {
		"mode": mode, "mesh_count": 0, "shader_count": 0,
		"vertices_before": 0, "vertices_after": 0, "triangles": 0,
		"geometry_area_ratio": 1.0, "skipped": [],
	}
	var replacements: Dictionary = {}
	var seen_shaders: Dictionary = {}
	var stack: Array[Node] = [editor]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var owner: Object
		var mesh: Mesh
		if node is MultiMeshInstance3D and node.multimesh != null:
			owner = node.multimesh
			mesh = node.multimesh.mesh
		elif node is MeshInstance3D:
			owner = node
			mesh = node.mesh
		if mesh == null:
			continue
		var uses_cards: bool = false
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != SHADER_PATH:
				continue
			uses_cards = true
			var shader: Shader = material.shader
			if mode != "exact_index" and not seen_shaders.has(shader):
				seen_shaders[shader] = true
				var before: String = shader.code
				if before.count(SAMPLE_LINE) != 1 or not before.contains("ALPHA_SCISSOR_THRESHOLD=.23;") or not before.contains("ALPHA_ANTIALIASING_EDGE=.27;"):
					report.skipped.append("unexpected foliage shader body")
					continue
				var after: String = before.replace(SAMPLE_LINE, SAMPLE_LINE + EARLY_LINE)
				_shaders.append({"shader": shader, "before": before, "after": after})
				# Mutate only this loaded Resource: its production resource_path stays
				# intact for the existing environment/day-night palette binding.
				shader.code = after
				report.shader_count += 1
		if not uses_cards or mode == "early_alpha":
			continue
		if not replacements.has(mesh):
			var replacement: Mesh = exact_index_mesh(mesh)
			replacements[mesh] = replacement
			if replacement == mesh:
				report.skipped.append("unsupported or already indexed foliage mesh")
			else:
				var before_arrays: Array = GEOMETRY.arrays_of(mesh)
				var after_arrays: Array = GEOMETRY.arrays_of(replacement)
				report.mesh_count += 1
				report.vertices_before += before_arrays[Mesh.ARRAY_VERTEX].size()
				report.vertices_after += after_arrays[Mesh.ARRAY_VERTEX].size()
				report.triangles += after_arrays[Mesh.ARRAY_INDEX].size() / 3
		var after_mesh: Mesh = replacements[mesh]
		if after_mesh != mesh:
			_mesh_users.append({"owner": owner, "before": mesh, "after": after_mesh})
			owner.set("mesh", after_mesh)
	return report

func restore() -> void:
	# Do not overwrite a third party's later edits to these live objects.
	for record: Dictionary in _mesh_users:
		if is_instance_valid(record.owner) and record.owner.get("mesh") == record.after:
			record.owner.set("mesh", record.before)
	_mesh_users.clear()
	for record: Dictionary in _shaders:
		if is_instance_valid(record.shader) and record.shader.code == record.after:
			record.shader.code = record.before
	_shaders.clear()

static func exact_index_mesh(source: Mesh) -> Mesh:
	# Deliberately narrow: generated botanical meshes have one triangle surface
	# and these simple streams. Keep unfamiliar geometry intact.
	if source.get_surface_count() != 1 or source.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return source
	var original: Array = GEOMETRY.arrays_of(source)
	if original[Mesh.ARRAY_INDEX] != null and not original[Mesh.ARRAY_INDEX].is_empty():
		return source
	var vertex_count: int = original[Mesh.ARRAY_VERTEX].size()
	if vertex_count == 0 or vertex_count % 3 != 0:
		return source
	for slot in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_INDEX or original[slot] == null or original[slot].is_empty():
			continue
		if slot not in SLOTS or original[slot].size() != vertex_count:
			return source
	for required_slot: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		if original[required_slot] == null or original[required_slot].size() != vertex_count:
			return source
	var indexed: Array = original.duplicate(true)
	var present: Array[int] = []
	for slot: int in SLOTS:
		if original[slot] != null and not original[slot].is_empty():
			present.append(slot)
			indexed[slot].clear()
	var indices := PackedInt32Array()
	indices.resize(vertex_count)
	var seen: Dictionary = {}
	for i in vertex_count:
		var values: Array = []
		for slot: int in present:
			values.append(original[slot][i])
		# Exact serialized components prevent approximate welding and preserve
		# UV/normal/color seams, signed zero, and every original fan corner.
		var key: String = var_to_bytes(values).hex_encode()
		if not seen.has(key):
			seen[key] = indexed[Mesh.ARRAY_VERTEX].size()
			for slot: int in present:
				indexed[slot].append(original[slot][i])
		indices[i] = seen[key]
	if indexed[Mesh.ARRAY_VERTEX].size() == vertex_count:
		return source
	indexed[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, indexed)
	result.surface_set_material(0, source.surface_get_material(0))
	result.set_meta("cpu_arrays", [indexed])
	result.set_meta("cpu_faces", GEOMETRY.faces_of(source))
	return result
