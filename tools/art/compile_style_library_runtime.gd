extends SceneTree
## Optional single-material static package; never changes source GLBs or entry scenes.
## godot --headless --path . --script tools/art/compile_style_library_runtime.gd -- --list=/abs/jobs.json
## JSON: {"assets":[{"processed_dir":"assets/candidates/.../asset","out_nested":"godot_runtime"}]}
## A plain array of processed-directory strings is also accepted.
## --verify-only requires an intact identical package; --proof-dir=/new/path saves
## one native render and validation JSON per asset, without changing the package.

const VERSION := 2
var errors: Array[String] = []
var outcomes: Array[Dictionary] = []
var verify_only := false
var proof_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		errors.append(message)
		push_error(message)
	return condition

func absolute(path: String, parent: String = "") -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path.simplify_path()
	var project := ProjectSettings.globalize_path("res://".path_join(path))
	return project if FileAccess.file_exists(project) or DirAccess.dir_exists_absolute(project) or parent.is_empty() else parent.path_join(path).simplify_path()

func resource_path(path: String) -> String:
	return ProjectSettings.localize_path(path)

func json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Cannot write " + path): return false
	file.store_string(JSON.stringify(value, "\t"))
	return true

func vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func box_record(box: AABB) -> Dictionary:
	return {"position": vec(box.position), "size": vec(box.size), "center": vec(box.get_center())}

func record_box(record: Dictionary) -> AABB:
	return AABB(vector(record.position), vector(record.size))

func range_directions() -> Array[Vector3]:
	var result: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, .25, 1), Vector3(-1, .25, 1), Vector3(1, -.25, -1), Vector3(-1, -.25, -1), Vector3(0, 1, .1), Vector3(0, -1, .1)]
	for index: int in result.size(): result[index] = result[index].normalized()
	return result

func visible_range_count(camera_position: Vector3, centers: Array[Vector3], ranges: Array) -> int:
	var count := 0
	for lod: int in centers.size():
		var distance := camera_position.distance_to(centers[lod])
		if (ranges[lod][0] == 0 or distance >= ranges[lod][0]) and (ranges[lod][1] == 0 or distance <= ranges[lod][1]): count += 1
	return count

func verify_visibility_reference(model: Node3D, expected: Dictionary) -> Dictionary:
	var common := record_box(expected.common_root_aabb)
	var centers: Array[Vector3] = []
	var actual: Array[Dictionary] = []
	var tolerance := maxf(common.size.length() * .000001, .0000001)
	for lod: int in 3:
		var child := model.get_node("LOD%d" % lod) as MeshInstance3D
		if not check(same_values(box_record(child.custom_aabb), expected.custom_aabbs[lod]), "Reloaded custom AABB changed for LOD%d" % lod): return {"valid": false}
		var transformed: AABB = child.transform * child.custom_aabb
		for axis: int in 3:
			if not check(transformed.position[axis] <= common.position[axis] + tolerance and transformed.end[axis] >= common.end[axis] - tolerance, "Custom AABB fails to cover merged whole-LOD bounds"): return {"valid": false}
		var center := transformed.get_center()
		if not check(center.distance_to(common.get_center()) <= tolerance, "Custom AABB center differs from common root reference"): return {"valid": false}
		if not centers.is_empty() and not check(center == centers[0], "Stored-precision LOD centers do not coincide exactly; refusing finite range gaps"): return {"valid": false}
		centers.append(center)
		actual.append({"local_custom_aabb": box_record(child.custom_aabb), "transformed_aabb": box_record(transformed)})
	var samples := 0
	var ranges: Array = expected.visibility_ranges
	var span: float = expected.range_span_m
	for boundary: float in [ranges[0][1], ranges[1][1]]:
		for direction: Vector3 in range_directions():
			for relative_offset: float in [-.01, -.001, -.00001, .00001, .001, .01]:
				var position := centers[0] + direction * (boundary + relative_offset * span)
				if not check(visible_range_count(position, centers, ranges) == 1, "Finite gap/overlap in reloaded visibility ranges"): return {"valid": false}
				samples += 1
	return {"valid": true, "common_root_aabb": box_record(common), "actual_distance_reference_m": vec(centers[0]), "exact_same_center_all_lods": true, "maximum_pairwise_center_delta_m": 0.0, "all_lods_covered_by_common_aabb": true, "aabb_coverage_numeric_tolerance_m": tolerance, "lod_aabbs": actual, "finite_offset_directional_samples": samples, "finite_offset_gap_or_overlap": false, "equal_distance_boundary_policy": "Godot 4.7 strict hidden tests dist>end and dist<begin retain both adjacent LODs at exact equality; zero-thickness double render is preserved and documented, no runtime script", "official_source": "https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_scene_cull.cpp"}

func digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func blob_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func collect(node: Node, pose: Transform3D, meshes: Array[Dictionary]) -> void:
	var current: Transform3D = pose * node.transform if node is Node3D else pose
	if node is MeshInstance3D and node.mesh != null:
		meshes.append({"instance": node, "pose": current})
	for child: Node in node.get_children():
		collect(child, current, meshes)

func material_values(material: StandardMaterial3D) -> Dictionary:
	var result: Dictionary = {}
	for item: Dictionary in material.get_property_list():
		var key := str(item.name)
		if not (int(item.usage) & PROPERTY_USAGE_STORAGE) or key.begins_with("resource_") or key == "script": continue
		var value: Variant = material.get(key)
		if value == null:
			# Typed null Object references otherwise stringify as "<Object#null>".
			result[key] = null
		elif value is Texture2D:
			result[key] = "shared_albedo_texture" if key == "albedo_texture" else "unsupported_other_texture"
		elif value is Color:
			result[key] = [value.r, value.g, value.b, value.a]
		elif value is Vector3:
			result[key] = vec(value)
		elif value is Vector2:
			result[key] = [value.x, value.y]
		elif value is bool or value is int or value is float or value is String or value == null:
			result[key] = value
	return result

func same_values(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= 0.000001
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in a.size():
			if not same_values(a[index], b[index]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same_values(a[key], b[key]): return false
		return true
	if typeof(a) != typeof(b): return false
	return a == b

func image_info(image: Image) -> Dictionary:
	if image == null or image.is_empty(): return {}
	var base_end := image.get_mipmap_offset(1) if image.has_mipmaps() else image.get_data().size()
	return {"width": image.get_width(), "height": image.get_height(), "format": image.get_format(), "has_mipmaps": image.has_mipmaps(), "mipmap_count": image.get_mipmap_count(), "base_pixels_sha256": blob_hash(image.get_data().slice(0, base_end)), "all_pixels_sha256": blob_hash(image.get_data()), "data_bytes": image.get_data().size()}

func geometry(mesh: ArrayMesh, pose: Transform3D) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box: AABB = pose * mesh.get_aabb()
	return {"triangles": (indices.size() if not indices.is_empty() else vertices.size()) / 3, "vertices": vertices.size(), "surfaces": mesh.get_surface_count(), "primitive_type": mesh.surface_get_primitive_type(0), "arrays_sha256": digest(arrays), "uv0_sha256": digest(arrays[Mesh.ARRAY_TEX_UV]), "uv1_sha256": digest(arrays[Mesh.ARRAY_TEX_UV2]), "bounds_min_m": vec(box.position), "dimensions_m": vec(box.size), "transform": [vec(pose.basis.x), vec(pose.basis.y), vec(pose.basis.z), vec(pose.origin)]}

func source_hashes(processed: String) -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at(processed):
		if file.get_extension() in ["glb", "blend", "json"]:
			result[file] = FileAccess.get_sha256(processed.path_join(file))
	return result

func save_resource(value: Resource, path: String) -> bool:
	var saved_path := resource_path(path)
	var error := ResourceSaver.save(value, saved_path)
	if not check(error == OK, "Resource save failed (%d): %s" % [error, path]): return false
	# Saving alone leaves fresh resources pathless; explicitly register external identity
	# before saving their dependants, otherwise Godot re-embeds them in every file.
	value.take_over_path(saved_path)
	return true

func verify_package(output: String, expected: Dictionary) -> Dictionary:
	var result := {"valid": false}
	var scene := ResourceLoader.load(resource_path(output.path_join("asset.tscn")), "PackedScene") as PackedScene
	if not check(scene != null, "Cannot ResourceLoader-load prefab: " + output): return result
	var root_node := scene.instantiate() as Node3D
	if not check(root_node != null and root_node.get_child_count() == 3, "Prefab must contain three independent LOD nodes"): return result
	var shared: Material = null
	var texture: Texture2D = null
	var actual_lods: Array[Dictionary] = []
	var dependencies: Dictionary = {}
	for lod: int in 3:
		var instance := root_node.get_node_or_null("LOD%d" % lod) as MeshInstance3D
		if not check(instance != null and instance.mesh is ArrayMesh and instance.mesh.get_surface_count() == 1, "Runtime LOD must be single-surface ArrayMesh"): root_node.free(); return result
		if not check(instance.material_override == null and instance.material_overlay == null and instance.get_surface_override_material(0) == null, "No material overrides permitted; real surface material must be shared"): root_node.free(); return result
		var material := instance.mesh.surface_get_material(0) as StandardMaterial3D
		if not check(material != null, "LOD surface material missing"): root_node.free(); return result
		if lod == 0:
			shared = material
			texture = material.albedo_texture
		if not check(material == shared and material.albedo_texture == texture and texture != null, "Reloaded LODs do not share identical material/texture instances"): root_node.free(); return result
		if not check(same_values(material_values(material), expected.material), "Reloaded actual material parameters changed"): root_node.free(); return result
		var measured := geometry(instance.mesh, instance.transform)
		if not check(same_values(measured, expected.lods[lod]), "Reloaded mesh/UV/transform/bounds differ from source LOD%d" % lod): root_node.free(); return result
		var ranges: Array = expected.visibility_ranges[lod]
		if not check(is_equal_approx(instance.visibility_range_begin, float(ranges[0])) and is_equal_approx(instance.visibility_range_end, float(ranges[1])), "Reloaded visibility ranges differ"): root_node.free(); return result
		var mesh_dependencies := ResourceLoader.get_dependencies(resource_path(output.path_join("lod%d.res" % lod)))
		if not check(mesh_dependencies.size() == 1, "Runtime mesh must have exactly one external material dependency"): root_node.free(); return result
		for dependency: String in mesh_dependencies:
			if not check(not ".glb" in dependency and "shared_material.tres" in dependency, "Old GLB/material dependency remains: " + dependency): root_node.free(); return result
		dependencies["lod%d.res" % lod] = Array(mesh_dependencies)
		actual_lods.append(measured)
	var pixels := image_info(texture.get_image())
	if not check(not pixels.is_empty() and pixels.has_mipmaps and same_values(pixels, expected.image), "Reloaded texture pixels/size/mipmaps differ"): root_node.free(); return result
	var mat_deps := ResourceLoader.get_dependencies(resource_path(output.path_join("shared_material.tres")))
	if not check(mat_deps.size() == 1 and "albedo.res" in mat_deps[0], "Shared material must depend only on saved albedo.res"): root_node.free(); return result
	dependencies["shared_material.tres"] = Array(mat_deps)
	var scene_dependencies := ResourceLoader.get_dependencies(resource_path(output.path_join("asset.tscn")))
	if not check(scene_dependencies.size() == 3, "Prefab must reference exactly the three saved ArrayMeshes"): root_node.free(); return result
	for dependency: String in scene_dependencies:
		if not check("lod0.res" in dependency or "lod1.res" in dependency or "lod2.res" in dependency, "Unexpected prefab embedded dependency"): root_node.free(); return result
	dependencies["asset.tscn"] = Array(scene_dependencies)
	var visibility := verify_visibility_reference(root_node, expected)
	if not visibility.valid: root_node.free(); return result
	result = {"valid": true, "same_material_instance_across_all_lods": true, "same_texture_instance_across_all_lods": true, "material_overrides": false, "old_embedded_surface_materials_removed": true, "source_geometry_uv_transform_equal": true, "material_values_equal": true, "texture_pixels_and_mipmaps_equal": true, "dependencies": dependencies, "lods": actual_lods, "image": pixels}
	result["visibility_reference"] = visibility
	root_node.free()
	return result

func compile_asset(job: Dictionary, list_parent: String) -> Dictionary:
	var processed := absolute(str(job.get("processed_dir", "")), list_parent)
	var nested := str(job.get("out_nested", "godot_runtime"))
	if not check(not nested.is_empty() and not nested in [".", ".."] and not "/" in nested and not "\\" in nested, "out_nested must be one new folder name"): return {}
	if not check(DirAccess.dir_exists_absolute(processed), "Missing processed directory: " + processed): return {}
	var output := processed.path_join(nested)
	var hashes := source_hashes(processed)
	for lod: int in 3:
		if not check(hashes.has("lod%d.glb" % lod), "Missing source LOD in " + processed): return {}
	var identity := {"tool_version": VERSION, "tool_sha256": FileAccess.get_sha256(get_script().resource_path), "godot": Engine.get_version_info().string, "source_files_sha256": hashes}
	var report_path := output.path_join("compile_report.json")
	if DirAccess.dir_exists_absolute(output) and (not DirAccess.get_files_at(output).is_empty() or not DirAccess.get_directories_at(output).is_empty()):
		var existing := json_file(report_path)
		if not check(same_values(existing.get("identity", {}), identity) and existing.get("complete", false), "Refusing existing non-identical/incomplete runtime output: " + output): return {}
		for artifact: Dictionary in existing.get("artifacts", []):
			if not check(FileAccess.get_sha256(output.path_join(str(artifact.file))) == artifact.sha256, "Existing output hash mismatch: " + str(artifact.file)): return {}
		var reloaded := verify_package(output, existing.expected)
		if not reloaded.valid: return {}
		return {"processed_dir": processed, "output": output, "skipped_identical": true, "verification": reloaded, "report": existing}
	if not check(not verify_only, "--verify-only requires an existing intact package: " + output): return {}
	var process_report := json_file(processed.path_join("process_report.json"))
	if not check(process_report.get("processing_complete", false) and not process_report.get("not_game_ready", true), "Only technically ready processed assets may be compiled"): return {}
	var entries: Array[Dictionary] = []
	var source_lods: Array[Dictionary] = []
	var source_material: StandardMaterial3D = null
	var material_signature: Dictionary = {}
	var image_signature: Dictionary = {}
	var pixel_image: Image = null
	for lod: int in 3:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var source := processed.path_join("lod%d.glb" % lod)
		if not check(document.append_from_file(source, state) == OK, "Direct GLB parse failed: " + source): return {}
		var model := document.generate_scene(state)
		if not check(model != null, "GLB generated no scene: " + source): return {}
		var meshes: Array[Dictionary] = []
		collect(model, Transform3D.IDENTITY, meshes)
		if not check(meshes.size() == 1, "Only one static mesh instance per LOD is supported"): model.free(); return {}
		var entry: Dictionary = meshes[0]
		var instance := entry.instance as MeshInstance3D
		var mesh := instance.mesh as ArrayMesh
		if not check(mesh != null and mesh.get_surface_count() == 1 and mesh.get_blend_shape_count() == 0 and mesh.shadow_mesh == null and instance.skin == null and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES, "Only one-surface static triangle ArrayMesh without extra shadow/deformation resources is supported"): model.free(); return {}
		if not check(instance.material_override == null and instance.material_overlay == null and instance.get_surface_override_material(0) == null, "Source overrides are unsupported"): model.free(); return {}
		var source_arrays := mesh.surface_get_arrays(0)
		if not check(source_arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array and source_arrays[Mesh.ARRAY_TEX_UV].size() == source_arrays[Mesh.ARRAY_VERTEX].size(), "Runtime source must preserve UV0 per vertex"): model.free(); return {}
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		if not check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.next_pass == null and material.albedo_texture != null, "Only single opaque StandardMaterial3D with albedo image is supported"): model.free(); return {}
		var signature := material_values(material)
		if not check(not "unsupported_other_texture" in signature.values(), "Material has non-albedo embedded textures; cannot silently discard them"): model.free(); return {}
		var image := material.albedo_texture.get_image()
		if not check(image != null and not image.is_empty(), "Cannot read source albedo image"): model.free(); return {}
		if image.is_compressed():
			if not check(image.decompress() == OK, "Cannot decompress source texture for lossless pixel-backed resource"): model.free(); return {}
		var info := image_info(image)
		if lod == 0:
			source_material = material
			material_signature = signature
			image_signature = info
			pixel_image = image.duplicate()
		else:
			if not check(same_values(signature, material_signature) and info.width == image_signature.width and info.height == image_signature.height and info.base_pixels_sha256 == image_signature.base_pixels_sha256, "LODs do not have equivalent actual material/texture pixels"): model.free(); return {}
		var runtime_mesh := mesh.duplicate() as ArrayMesh
		entries.append({"mesh": runtime_mesh, "pose": entry.pose, "cast_shadow": instance.cast_shadow})
		source_lods.append(geometry(mesh, entry.pose))
		model.free()
	if not pixel_image.has_mipmaps():
		if not check(pixel_image.generate_mipmaps() == OK, "Mipmap generation failed"): return {}
	var shared_texture := ImageTexture.create_from_image(pixel_image)
	var shared_material := source_material.duplicate() as StandardMaterial3D
	shared_material.resource_local_to_scene = false
	shared_material.albedo_texture = shared_texture
	if not check(same_values(material_values(shared_material), material_signature), "Material copy changed real parameters"): return {}
	if not check(source_hashes(processed) == hashes, "Source files changed while compiling; refusing publish"): return {}
	DirAccess.make_dir_recursive_absolute(output)
	if not save_resource(shared_texture, output.path_join("albedo.res")): return {}
	if not save_resource(shared_material, output.path_join("shared_material.tres")): return {}
	var prefab := Node3D.new()
	prefab.name = processed.get_file().validate_node_name()
	var span := maxf(float(source_lods[0].dimensions_m[0]), maxf(float(source_lods[0].dimensions_m[1]), float(source_lods[0].dimensions_m[2])))
	var ranges: Array = [[0.0, span * 4.0], [span * 4.0, span * 10.0], [span * 10.0, 0.0]]
	var common_box := AABB(vector(source_lods[0].bounds_min_m), vector(source_lods[0].dimensions_m))
	for lod: int in range(1, 3):
		common_box = common_box.merge(AABB(vector(source_lods[lod].bounds_min_m), vector(source_lods[lod].dimensions_m)))
	var custom_boxes: Array[Dictionary] = []
	for lod: int in 3:
		var mesh := entries[lod].mesh as ArrayMesh
		# This replaces the actual surface slot, releasing old embedded material/texture refs.
		mesh.surface_set_material(0, shared_material)
		if not check(mesh.surface_get_material(0) == shared_material, "Surface slot replacement failed"): prefab.free(); return {}
		if not save_resource(mesh, output.path_join("lod%d.res" % lod)): prefab.free(); return {}
		var child := MeshInstance3D.new()
		child.name = "LOD%d" % lod
		child.mesh = mesh
		child.transform = entries[lod].pose
		# Visibility ranges use the transformed AABB CENTER, not the node origin.
		# All LODs must therefore enclose the same merged root-space box.
		child.custom_aabb = child.transform.affine_inverse() * common_box
		custom_boxes.append(box_record(child.custom_aabb))
		child.cast_shadow = entries[lod].cast_shadow
		child.visibility_range_begin = ranges[lod][0]
		child.visibility_range_end = ranges[lod][1]
		child.visibility_range_begin_margin = 0.0
		child.visibility_range_end_margin = 0.0
		child.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		prefab.add_child(child)
		child.owner = prefab
	var packed := PackedScene.new()
	if not check(packed.pack(prefab) == OK, "Could not pack editable standalone asset"): prefab.free(); return {}
	if not save_resource(packed, output.path_join("asset.tscn")): prefab.free(); return {}
	prefab.free()
	var expected := {"lods": source_lods, "material": material_signature, "image": image_info(pixel_image), "visibility_ranges": ranges, "range_span_m": span, "common_root_aabb": box_record(common_box), "custom_aabbs": custom_boxes}
	var verified := verify_package(output, expected)
	if not verified.valid: return {}
	if not check(source_hashes(processed) == hashes, "Original files changed after compile"): return {}
	var artifacts: Array[Dictionary] = []
	for file: String in ["albedo.res", "shared_material.tres", "lod0.res", "lod1.res", "lod2.res", "asset.tscn"]:
		artifacts.append({"file": file, "sha256": FileAccess.get_sha256(output.path_join(file)), "bytes": FileAccess.get_file_as_bytes(output.path_join(file)).size()})
	var report := {"complete": true, "identity": identity, "processed_dir": processed, "expected": expected, "verification": verified, "artifacts": artifacts, "source_unchanged": true, "policy": "Optional standalone editable prefab, no default entry/production changes. Real surface materials replaced, all LODs share one material and one pixel-backed albedo ImageTexture .res without PNG import. Material/UV/mesh data retained; mipmaps generated only when absent.", "visibility_range_policy": "max world span ×4 / ×10; LOD2 end=0 is unlimited. Hard range changes, no collision/gameplay/interaction.", "measured_hardware_fps": "unmeasured", "texture_unique_instances": 1, "material_unique_instances": 1, "expected_duplicate_texture_instances_avoided": 2}
	if not write_json(report_path, report): return {}
	return {"processed_dir": processed, "output": output, "skipped_identical": false, "verification": verified, "report": report}

func save_proof(outcome: Dictionary) -> void:
	var path := proof_dir.path_join(str(outcome.processed_dir).get_file())
	DirAccess.make_dir_recursive_absolute(path)
	var proof := {"verification": outcome.verification, "output": outcome.output, "display_server": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "scope": "Reloaded optional resource package, not default courtyard art acceptance or hardware performance", "proof_lighting": "neutral color ambient .6 and directional light 1.4, shadows off for shape/material resource proof only; not production lighting"}
	write_json(path.path_join("reload_proof.json"), proof)
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 960)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var scene := ResourceLoader.load(resource_path(str(outcome.output).path_join("asset.tscn"))) as PackedScene
	var model := scene.instantiate() as Node3D
	stage.add_child(model)
	# Show LOD0 at an actual distance inside its visibility range; source mesh unmodified.
	var info: Dictionary = outcome.report.expected.lods[0]
	var dimensions := Vector3(info.dimensions_m[0], info.dimensions_m[1], info.dimensions_m[2])
	var center := Vector3(info.bounds_min_m[0], info.bounds_min_m[1], info.bounds_min_m[2]) + dimensions * .5
	var span := maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span * 1.35
	camera.position = center + Vector3(1, .7, 1.5).normalized() * span * 3.0
	stage.add_child(camera)
	camera.look_at(center)
	camera.make_current()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.28, .30, .31)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.8, .85, .9)
	environment.environment.ambient_light_energy = .6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 40, 0)
	light.light_energy = 1.4
	light.shadow_enabled = false
	stage.add_child(light)
	for frame: int in 8:
		RenderingServer.force_draw(false)
		await process_frame
	var image := viewport.get_texture().get_image()
	check(image.save_png(path.path_join("lod0_native.png")) == OK, "Could not save native proof")
	proof["native_image"] = {"file": "lod0_native.png", "sha256": FileAccess.get_sha256(path.path_join("lod0_native.png")), "resolution": [1280, 960], "msaa": 4}
	proof["native_visibility_probe"] = await native_visibility_probe(viewport, camera, model, outcome, path)
	write_json(path.path_join("reload_proof.json"), proof)
	viewport.free()

func native_visibility_probe(viewport: SubViewport, camera: Camera3D, model: Node3D, outcome: Dictionary, path: String) -> Dictionary:
	# Compiler/proof-only sampling. The emitted prefab has no attached script.
	var reference: Dictionary = outcome.verification.visibility_reference
	var center := vector(reference.actual_distance_reference_m)
	var ranges: Array = outcome.report.expected.visibility_ranges
	var span: float = outcome.report.expected.range_span_m
	var centers: Array[Vector3] = []
	for lod: int in 3:
		var child := model.get_node("LOD%d" % lod) as MeshInstance3D
		var box: AABB = child.transform * child.custom_aabb
		centers.append(box.get_center())
	var unit_objects := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
	if not check(unit_objects > 0, "Native viewport render-object statistics unavailable"): return {"valid": false}
	var records: Array[Dictionary] = []
	var finite_samples := 0
	var equality_double_samples := 0
	var valid := true
	for boundary_index: int in 2:
		var boundary: float = ranges[boundary_index][1]
		var directions := range_directions()
		for direction_index: int in directions.size():
			var direction: Vector3 = directions[direction_index]
			for relative_offset: float in [-.01, -.001, -.00001, 0.0, .00001, .001, .01]:
				camera.position = center + direction * (boundary + relative_offset * span)
				camera.look_at(center)
				for frame: int in 3:
					RenderingServer.force_draw(false)
					await process_frame
				var objects := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
				var expected_count := visible_range_count(camera.position, centers, ranges)
				var sample_ok := objects == unit_objects * expected_count
				if relative_offset != 0:
					finite_samples += 1
					sample_ok = sample_ok and expected_count == 1
				elif expected_count == 2 and objects == unit_objects * 2:
					equality_double_samples += 1
				if not check(sample_ok, "Native LOD range count mismatch at boundary %s offset %s direction %d: %d objects, expected %d" % [boundary, relative_offset, direction_index, objects, expected_count * unit_objects]): valid = false
				var record := {"boundary_m": boundary, "direction": vec(direction), "offset_m": relative_offset * span, "actual_distance_m": camera.position.distance_to(center), "expected_visible_lods": expected_count, "render_objects": objects, "objects_per_single_lod": unit_objects, "valid": sample_ok}
				if direction_index == 0 and absf(relative_offset) <= .00001:
					var name := "threshold%d_%s.png" % [boundary_index, "equal" if relative_offset == 0 else ("before" if relative_offset < 0 else "after")]
					viewport.get_texture().get_image().save_png(path.path_join(name))
					record["image"] = name
				records.append(record)
	var result := {"valid": valid, "finite_offset_samples": finite_samples, "finite_gap_or_overlap_detected": not valid, "native_exact_distance_double_render_samples": equality_double_samples, "boundaries_m": [ranges[0][1], ranges[1][1]], "directions": range_directions().size(), "minimum_nonzero_offset_m": span * .00001, "same_actual_materials_and_meshes": true, "measurement": "native SubViewport RENDER_INFO_OBJECTS_IN_FRAME, visible pass; one-LOD baseline calibrated at 3×span; no material overrides or runtime scripts", "exact_boundary_note": "Strict Godot end/begin exclusion permits both meshes at exact equality. This zero-thickness overlap is documented, not hidden or corrected with runtime scripting.", "records": records}
	write_json(path.path_join("native_visibility_ranges.json"), result)
	return result

func run() -> void:
	var list_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--list="): list_path = absolute(arg.trim_prefix("--list="))
		if arg == "--verify-only": verify_only = true
		if arg.begins_with("--proof-dir="): proof_dir = absolute(arg.trim_prefix("--proof-dir="))
	if not check(not list_path.is_empty() and FileAccess.file_exists(list_path), "Required: --list=/path/jobs.json"): quit(2); return
	if not proof_dir.is_empty() and DirAccess.dir_exists_absolute(proof_dir) and (not DirAccess.get_files_at(proof_dir).is_empty() or not DirAccess.get_directories_at(proof_dir).is_empty()):
		check(false, "Proof output must be new/empty: " + proof_dir); quit(2); return
	var parser := JSON.new()
	if not check(parser.parse(FileAccess.get_file_as_string(list_path)) == OK, "Invalid list JSON"): quit(2); return
	var data: Variant = parser.data
	var jobs: Array = data if data is Array else (data.get("assets", data.get("processed_dirs", [])) if data is Dictionary else [])
	if not check(not jobs.is_empty(), "No processed-directory jobs"): quit(2); return
	for value: Variant in jobs:
		var job: Dictionary = {"processed_dir": value} if value is String else value
		var outcome := compile_asset(job, list_path.get_base_dir())
		if outcome.is_empty(): continue
		outcomes.append(outcome)
		print("RUNTIME_PACKAGE ", JSON.stringify({"output": outcome.output, "skipped_identical": outcome.skipped_identical, "valid": outcome.verification.valid}))
		if not proof_dir.is_empty(): await save_proof(outcome)
	print("RUNTIME_COMPILE_SUMMARY ", JSON.stringify({"assets": outcomes.size(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)
