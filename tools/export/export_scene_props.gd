extends SceneTree
## Export the finished on-top scene dressing (trees, bushes, rocks, shore stones, path,
## reeds, lilies, flowers, fern tufts and the four props) of the frozen Godot scene for
## the Rust runtime. Boots the single scene exactly like tools/export/capture_reference.gd
## (windowed, Forward+, SubViewport), then walks the live node tree.
##
##   godot --path . --script res://tools/export/export_scene_props.gd -- \
##       --seed=7301 --preset=0 --out=runtime/data/reference/scene_7301_0
##
## Output: <out>/scene.json, <out>/scene.bin, <out>/textures/*. Never touches user://.
## Ground, cliffs, cliff kit, water, falls, mist, sky, grass blades and helpers are
## left out and only counted in scene.json "excluded_summary".

const SIZE := Vector2i(1280, 832)
## Day progress used by the reference captures (capture_reference.gd default).
const PROGRESS: float = 0.29
## A decoration instance whose anchor lies more than this below the published
## top surface at its own XZ is hanging on a cliff face, not standing on the lawn.
const BELOW_TOP_TOLERANCE: float = 0.35
const BOTANICAL_ATLAS := "res://assets/nature/trees/botanical_foliage_atlas.png"

## Decoration kinds (terrain_decoration.gd placements()) that stand on the top surface.
const ON_TOP_KINDS: Array[String] = ["tree", "tree_b", "bush", "surface_rock", "cliff_rock",
	"shore_rock", "shore_boulder", "shore_pebble", "path", "reeds", "lily", "flower",
	"grass_clump", "grass", "fence", "vine"]
## Of those, kinds whose instances are tested per instance against the top surface.
## Shore stones, reeds and lilies sit at or in the water by design.
const POSITION_TESTED: Array[String] = ["tree", "tree_b", "bush", "surface_rock", "cliff_rock",
	"path", "flower", "grass_clump", "grass", "fence", "vine"]
const PROP_KINDS := {"TaihuScholarRock": "scholar_rock", "BambooGrove": "bamboo",
	"InkStoneDaybed": "bench", "SongStoneLantern": "lantern", "CourtyardPavilion": "pavilion"}

var seed_value: int = 7301
var preset: int = 0
var output: String = ""
var viewport: SubViewport
var editor: Node3D
var errors: Array[String] = []

var bin := PackedByteArray()
var meshes: Array = []
var mesh_index: Dictionary = {}     # "meshid:surface:materialid" -> index
var materials: Array = []
var material_index: Dictionary = {} # material instance id -> index
var textures: Dictionary = {}       # key -> {file, width, height, ...}
var texture_keys: Dictionary = {}   # texture instance id -> key
var objects: Array = []
var excluded: Dictionary = {}       # kind -> {"nodes": n, "instances": n}
var hidden: Dictionary = {}
var instance_rule: Dictionary = {}  # kind -> {"on_top": n, "below_top": n, "off_island": n}
var shader_sources: Dictionary = {} # shader path or id -> expanded source
var other_nodes: Array = []


func _initialize() -> void:
	call_deferred("run")


func _read_options() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			push_error("Expected --key=value option, received: " + arg)
			return false
		var key: String = arg.substr(2, arg.find("=") - 2)
		var value: String = arg.substr(arg.find("=") + 1)
		match key:
			"seed":
				if not value.is_valid_int():
					return false
				seed_value = int(value)
			"preset":
				if not value.is_valid_int():
					return false
				preset = int(value)
			"out":
				output = value
			_:
				push_error("Unknown option: " + key)
				return false
	if output.strip_edges().is_empty() or preset < 0 or preset > 2:
		push_error("Required: --out=<dir> and --preset=0|1|2")
		return false
	if not output.is_absolute_path():
		output = "res://" + output
	return true


# ---------------------------------------------------------------- binary blob

func _append_bytes(bytes: PackedByteArray) -> int:
	var offset: int = bin.size()
	bin.append_array(bytes)
	while bin.size() % 4 != 0:
		bin.append(0)
	return offset


func _basis_origin(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


# ---------------------------------------------------------------- shaders

func _expand_includes(source: String, base: String) -> String:
	var result: PackedStringArray = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var relative: String = line.get_slice('"', 1)
			var path: String = relative if relative.begins_with("res://") else base.path_join(relative)
			result.append(_expand_includes(FileAccess.get_file_as_string(path), path.get_base_dir()))
		else:
			result.append(line)
	return "\n".join(result)


func _shader_source(shader: Shader) -> String:
	var key: String = shader.resource_path if not shader.resource_path.is_empty() else str(shader.get_instance_id())
	if not shader_sources.has(key):
		var base: String = shader.resource_path.get_base_dir()
		if base.is_empty():
			base = "res://shaders/terrain_editor"
		shader_sources[key] = _expand_includes(shader.code, base)
	return shader_sources[key]


func _shader_traits(shader: Shader) -> Dictionary:
	var code: String = _shader_source(shader)
	var modes: Array = []
	var re_mode := RegEx.new()
	re_mode.compile("(?m)^\\s*render_mode\\s+([^;]+);")
	for m: RegExMatch in re_mode.search_all(code):
		for part: String in m.get_string(1).split(","):
			modes.append(part.strip_edges())
	var cull: String = "back"
	if "cull_disabled" in modes:
		cull = "disabled"
	elif "cull_front" in modes:
		cull = "front"
	var re_scissor := RegEx.new()
	re_scissor.compile("ALPHA_SCISSOR_THRESHOLD\\s*=\\s*([0-9.eE+-]+)\\s*;")
	var scissor: RegExMatch = re_scissor.search(code)
	var re_alpha := RegEx.new()
	re_alpha.compile("(?<![A-Z_])ALPHA\\s*=\\s*([^;]+);")
	var alpha: RegExMatch = re_alpha.search(code)
	var re_hash := RegEx.new()
	re_hash.compile("ALPHA_HASH_SCALE\\s*=")
	var transparency: String = "opaque"
	if alpha != null:
		if scissor != null:
			transparency = "alpha_scissor"
		elif re_hash.search(code) != null:
			transparency = "alpha_hash"
		else:
			transparency = "alpha_blend"
	if "depth_prepass_alpha" in modes and alpha != null and scissor == null:
		transparency = "alpha_depth_prepass"
	# Sampler hints per uniform (source_color, filter, repeat), read from the source.
	var hints: Dictionary = {}
	var re_sampler := RegEx.new()
	re_sampler.compile("uniform\\s+sampler2D\\s+(\\w+)\\s*(?::\\s*([^;=]+))?")
	for m: RegExMatch in re_sampler.search_all(code):
		hints[m.get_string(1)] = m.get_string(2).strip_edges()
	return {
		"render_mode": modes, "cull_mode": cull, "transparency": transparency,
		"alpha_scissor_threshold": float(scissor.get_string(1)) if scissor != null else null,
		"alpha_expression": alpha.get_string(1).strip_edges() if alpha != null else null,
		"alpha_to_coverage": "alpha_to_coverage" in modes or "alpha_to_coverage_and_one" in modes,
		"sampler_hints": hints,
	}


# ---------------------------------------------------------------- textures

func _texture_key(texture: Texture2D) -> Variant:
	if texture == null:
		return null
	var tid: int = texture.get_instance_id()
	if texture_keys.has(tid):
		return texture_keys[tid]
	var source: String = texture.resource_path
	if source.is_empty() and texture == TerrainModels._botanical_atlas_tex:
		source = BOTANICAL_ATLAS   # built in script from this file by Image.load_from_file
	var base: String = source.get_file().get_basename() if not source.is_empty() else "runtime_%s" % texture.get_class().to_snake_case()
	base = base.replace(" ", "_")
	var key: String = base
	var n: int = 2
	while textures.has(key):
		key = "%s_%d" % [base, n]
		n += 1
	var entry: Dictionary = {"width": texture.get_width(), "height": texture.get_height(),
		"source": source if not source.is_empty() else null, "class": texture.get_class()}
	var dir: String = output.path_join("textures")
	var ext: String = source.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg"] and FileAccess.file_exists(source):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
		var file := FileAccess.open(dir.path_join(key + "." + ext), FileAccess.WRITE)
		if file == null:
			errors.append("Cannot write texture " + key)
		else:
			file.store_buffer(bytes)
			file.close()
		entry["file"] = key + "." + ext
		entry["origin"] = "copied"
		var probe := Image.new()
		var probe_error: Error = probe.load_png_from_buffer(bytes) if ext == "png" else probe.load_jpg_from_buffer(bytes)
		if probe_error == OK and not probe.is_empty():
			entry["width"] = probe.get_width()
			entry["height"] = probe.get_height()
	else:
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			errors.append("Texture has no image: " + key)
			entry["file"] = null
		else:
			image = image.duplicate()
			var original_format: int = image.get_format()
			if image.is_compressed():
				image.decompress()
			if image.has_mipmaps():
				image.clear_mipmaps()
			if image.get_format() not in [Image.FORMAT_L8, Image.FORMAT_LA8, Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
				image.convert(Image.FORMAT_RGBA8)
			var result: Error = image.save_png(dir.path_join(key + ".png"))
			if result != OK:
				errors.append("save_png failed for %s (%d)" % [key, result])
			entry["file"] = key + ".png"
			entry["origin"] = "saved_from_image"
			entry["image_format"] = original_format
			entry["width"] = image.get_width()
			entry["height"] = image.get_height()
	textures[key] = entry
	texture_keys[tid] = key
	return key


# ---------------------------------------------------------------- materials

func _json_value(value: Variant) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is String:
		return value
	if value is float:
		return value if is_finite(value) else null
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]
	if value is Vector4 or value is Vector4i or value is Quaternion:
		return [value.x, value.y, value.z, value.w]
	if value is Plane:
		return [value.normal.x, value.normal.y, value.normal.z, value.d]
	if value is Basis:
		return [value.x.x, value.x.y, value.x.z, value.y.x, value.y.y, value.y.z, value.z.x, value.z.y, value.z.z]
	if value is Transform3D:
		return _basis_origin(value)
	if value is Projection:
		return [value.x.x, value.x.y, value.x.z, value.x.w, value.y.x, value.y.y, value.y.z, value.y.w,
			value.z.x, value.z.y, value.z.z, value.z.w, value.w.x, value.w.y, value.w.z, value.w.w]
	if value is Texture2D:
		return {"texture": _texture_key(value)}
	if value is Texture:
		errors.append("Non-2D texture parameter not exported: " + value.get_class())
		return {"texture": null, "class": value.get_class()}
	if value is PackedFloat32Array or value is PackedFloat64Array or value is PackedInt32Array or value is PackedInt64Array:
		return Array(value)
	if value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray or value is PackedVector4Array or value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_json_value(item))
		return out
	return str(value)


func _material(material: Material) -> int:
	if material == null:
		return -1
	var mid: int = material.get_instance_id()
	if material_index.has(mid):
		return material_index[mid]
	var index: int = materials.size()
	material_index[mid] = index
	materials.append({})   # reserve slot (next_pass recursion)
	var entry: Dictionary = {"render_priority": material.render_priority}
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		var mat := material as ShaderMaterial
		var shader: Shader = mat.shader
		var traits: Dictionary = _shader_traits(shader)
		var params: Dictionary = {}
		var explicit: Array = []
		for uniform: Dictionary in shader.get_shader_uniform_list(true):
			if int(uniform.usage) & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_CATEGORY):
				continue
			var uname: String = uniform.name
			var value: Variant = mat.get_shader_parameter(uname)
			if value == null:
				value = RenderingServer.shader_get_parameter_default(shader.get_rid(), uname)
			else:
				explicit.append(uname)
			params[uname] = _json_value(value)
		var albedo_tex: Variant = null
		for candidate: String in ["albedo_tex", "albedo_texture", "texture_albedo", "leaf_atlas"]:
			if params.get(candidate) is Dictionary:
				albedo_tex = params[candidate].texture
				break
		var albedo_color: Variant = null
		for candidate: String in ["albedo_color", "albedo", "base_color"]:
			if params.has(candidate):
				albedo_color = params[candidate]
				break
		explicit.sort()
		entry.merge({
			"kind": "shader", "shader": shader.resource_path if not shader.resource_path.is_empty() else null,
			"albedo_color": albedo_color, "albedo_texture": albedo_tex, "params": params,
			"params_set_explicitly": explicit,
			"transparency": traits.transparency, "alpha_scissor_threshold": traits.alpha_scissor_threshold,
			"alpha_expression": traits.alpha_expression, "alpha_to_coverage": traits.alpha_to_coverage,
			"cull_mode": traits.cull_mode, "render_mode": traits.render_mode,
			"sampler_hints": traits.sampler_hints,
		})
	elif material is BaseMaterial3D:
		var std := material as BaseMaterial3D
		var transparency_names := ["disabled", "alpha", "alpha_scissor", "alpha_hash", "alpha_depth_prepass"]
		var cull_names := ["back", "front", "disabled"]
		entry.merge({
			"kind": "standard", "shader": null,
			"albedo_color": _json_value(std.albedo_color),
			"albedo_texture": _texture_key(std.albedo_texture),
			"params": {
				"vertex_color_use_as_albedo": std.vertex_color_use_as_albedo,
				"vertex_color_is_srgb": std.vertex_color_is_srgb,
				"roughness": std.roughness, "metallic": std.metallic,
				"shading_mode": std.shading_mode,
				"normal_texture": _texture_key(std.normal_texture) if std.normal_enabled else null,
				"emission": _json_value(std.emission) if std.emission_enabled else null,
			},
			"transparency": transparency_names[std.transparency] if std.transparency < transparency_names.size() else str(std.transparency),
			"alpha_scissor_threshold": std.alpha_scissor_threshold if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else null,
			"alpha_to_coverage": std.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF,
			"cull_mode": cull_names[std.cull_mode] if std.cull_mode < cull_names.size() else str(std.cull_mode),
		})
	else:
		entry.merge({"kind": material.get_class(), "shader": null, "albedo_color": null, "albedo_texture": null,
			"params": {}, "transparency": null, "alpha_scissor_threshold": null, "cull_mode": null})
		errors.append("Unsupported material class: " + material.get_class())
	entry["next_pass"] = _material(material.next_pass) if material.next_pass != null else null
	materials[index] = entry
	return index


# ---------------------------------------------------------------- meshes

func _mesh_surfaces(mesh: Mesh, node: GeometryInstance3D) -> Array:
	var result: Array = []
	if mesh == null:
		return result
	for surface: int in mesh.get_surface_count():
		var material: Material = node.material_override
		if material == null and node is MeshInstance3D:
			material = (node as MeshInstance3D).get_surface_override_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		var key: String = "%d:%d:%d" % [mesh.get_instance_id(), surface, material.get_instance_id() if material != null else 0]
		if mesh_index.has(key):
			result.append(mesh_index[key])
			continue
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			errors.append("Non-triangle surface skipped on " + str(node.name))
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var entry: Dictionary = {"vertices": positions.size(), "indices": 0,
			"pos": -1, "normal": -1, "uv": -1, "uv2": -1, "color": -1, "index": -1}
		var flat := PackedFloat32Array()
		flat.resize(positions.size() * 3)
		for i: int in positions.size():
			flat[i * 3] = positions[i].x
			flat[i * 3 + 1] = positions[i].y
			flat[i * 3 + 2] = positions[i].z
		entry.pos = _append_bytes(flat.to_byte_array())
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == positions.size():
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var nf := PackedFloat32Array()
			nf.resize(normals.size() * 3)
			for i: int in normals.size():
				nf[i * 3] = normals[i].x
				nf[i * 3 + 1] = normals[i].y
				nf[i * 3 + 2] = normals[i].z
			entry.normal = _append_bytes(nf.to_byte_array())
		else:
			errors.append("Surface without normals on " + str(node.name))
		for pair: Array in [[Mesh.ARRAY_TEX_UV, "uv"], [Mesh.ARRAY_TEX_UV2, "uv2"]]:
			if arrays[pair[0]] is PackedVector2Array and (arrays[pair[0]] as PackedVector2Array).size() == positions.size():
				var uvs: PackedVector2Array = arrays[pair[0]]
				var uf := PackedFloat32Array()
				uf.resize(uvs.size() * 2)
				for i: int in uvs.size():
					uf[i * 2] = uvs[i].x
					uf[i * 2 + 1] = uvs[i].y
				entry[pair[1]] = _append_bytes(uf.to_byte_array())
		if arrays[Mesh.ARRAY_COLOR] is PackedColorArray and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == positions.size():
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var cf := PackedFloat32Array()
			cf.resize(colors.size() * 4)
			for i: int in colors.size():
				cf[i * 4] = colors[i].r
				cf[i * 4 + 1] = colors[i].g
				cf[i * 4 + 2] = colors[i].b
				cf[i * 4 + 3] = colors[i].a
			entry.color = _append_bytes(cf.to_byte_array())
		for c: int in 4:
			if arrays[Mesh.ARRAY_CUSTOM0 + c] != null:
				errors.append("CUSTOM%d channel present but not exported on %s" % [c, node.name])
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			entry.indices = idx.size()
			entry.index = _append_bytes(idx.to_byte_array())
		var box: AABB = AABB()
		if positions.size() > 0:
			box = AABB(positions[0], Vector3.ZERO)
			for p: Vector3 in positions:
				box = box.expand(p)
		entry["aabb"] = [box.position.x, box.position.y, box.position.z, box.end.x, box.end.y, box.end.z]
		entry["triangles"] = (entry.indices if entry.indices > 0 else entry.vertices) / 3
		entry["material"] = _material(material)
		entry["source_mesh"] = mesh.resource_path if not mesh.resource_path.is_empty() else null
		var index: int = meshes.size()
		meshes.append(entry)
		mesh_index[key] = index
		result.append(index)
	return result


# ---------------------------------------------------------------- classification

func _count(table: Dictionary, kind: String, nodes: int, instances: int) -> void:
	if not table.has(kind):
		table[kind] = {"nodes": 0, "instances": 0}
	table[kind].nodes += nodes
	table[kind].instances += instances


func _rule(kind: String, verdict: String) -> void:
	if not instance_rule.has(kind):
		instance_rule[kind] = {"on_top": 0, "below_top": 0, "off_island": 0}
	instance_rule[kind][verdict] += 1


func _top_verdict(origin: Vector3) -> String:
	var surface: Dictionary = editor.renderer.contours.surface_at(Vector2(origin.x, origin.z))
	if surface.is_empty():
		return "off_island"
	if origin.y < float(surface.height) - BELOW_TOP_TOLERANCE:
		return "below_top"
	return "on_top"


func _chunk_of(node: Node) -> Node:
	var renderer: Node = editor.renderer
	var current: Node = node
	while current != null and current.get_parent() != renderer:
		current = current.get_parent()
	if current == null:
		return null
	if current in editor.renderer.chunks.values():
		return current
	return null


func _prop_kind(node: Node) -> String:
	var props: Node = editor.renderer.props
	var current: Node = node
	while current != null and current.get_parent() != props:
		current = current.get_parent()
	if current == null:
		return ""
	return PROP_KINDS.get(String(current.name), String(current.name).to_snake_case())


func _visit(node: Node) -> void:
	for child: Node in node.get_children():
		_visit(child)
	if not node is VisualInstance3D:
		return
	if node is Light3D or node is Camera3D or node is ReflectionProbe or node is VoxelGI or node is LightmapGI or node is Decal or node is FogVolume:
		return
	var kind: String = ""
	var on_top: bool = false
	var chunk: Node = _chunk_of(node)
	var prop: String = _prop_kind(node)
	if chunk != null and node.get_parent() == chunk:
		var name: String = String(node.name)
		if node is MultiMeshInstance3D and name.contains("_joined_"):
			kind = name.get_slice("_joined_", 0)
		elif node is MultiMeshInstance3D and name != "grass_blades":
			var re := RegEx.new()
			re.compile("^(.*)_(\\d+)$")
			var m: RegExMatch = re.search(name)
			kind = m.get_string(1) if m != null else name
			on_top = kind in ON_TOP_KINDS
		elif node is MultiMeshInstance3D:
			kind = "grass_blades"
		else:
			kind = "chunk_mesh:" + name
	elif not prop.is_empty():
		kind = prop
		on_top = true
	else:
		var path: String = str(editor.get_path_to(node))
		var head: String = path.get_slice("/", 0)
		var re_num := RegEx.new()
		re_num.compile("[0-9]+")
		kind = "other:%s:%s/%s" % [node.get_class(), re_num.sub(head, "#", true), re_num.sub(String(node.name), "#", true)]
	var instances: int = 1
	if node is MultiMeshInstance3D:
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		instances = mm.visible_instance_count if mm != null and mm.visible_instance_count >= 0 else (mm.instance_count if mm != null else 0)
	if not (node as Node3D).is_visible_in_tree():
		_count(hidden, kind, 1, instances)
		return
	if not on_top or not (node is MeshInstance3D or node is MultiMeshInstance3D):
		if on_top:
			errors.append("On-top node of unsupported class " + node.get_class())
		_count(excluded, kind, 1, instances)
		if kind.begins_with("other:"):
			_note_other(node as VisualInstance3D, instances)
		return
	_export_object(node as GeometryInstance3D, kind, prop.is_empty())


## Nodes outside the terrain chunks and props, for auditing the exclusion.
func _note_other(node: VisualInstance3D, instances: int) -> void:
	var shader: Variant = null
	var mesh: Mesh = null
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	var material: Material = (node as GeometryInstance3D).material_override if node is GeometryInstance3D else null
	if material == null and mesh != null and mesh.get_surface_count() > 0:
		material = mesh.surface_get_material(0)
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		shader = (material as ShaderMaterial).shader.resource_path
	var box: AABB = node.global_transform * node.get_aabb()
	var script: Script = node.get_parent().get_script()
	other_nodes.append({"name": str(editor.get_path_to(node)), "class": node.get_class(), "instances": instances,
		"parent_script": script.resource_path if script != null else null, "shader": shader,
		"world_aabb": [box.position.x, box.position.y, box.position.z, box.end.x, box.end.y, box.end.z]})


func _export_object(node: GeometryInstance3D, kind: String, decoration: bool) -> void:
	var entry: Dictionary = {"name": str(editor.get_path_to(node)), "kind": kind, "category": "on_top",
		"transform": _basis_origin(node.global_transform)}
	if decoration:
		entry["part"] = int(String(node.name).get_slice("_", String(node.name).get_slice_count("_") - 1))
	else:
		entry["source"] = "terrain_props.gd:" + String(node.get_parent().name)
	if node is MeshInstance3D:
		var mesh_ids: Array = _mesh_surfaces((node as MeshInstance3D).mesh, node)
		entry["meshes"] = mesh_ids
		entry["triangles"] = _triangles(mesh_ids)
		objects.append(entry)
		return
	var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
	var count: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	var world: Transform3D = node.global_transform
	var transforms := PackedFloat32Array()
	var colors := PackedFloat32Array()
	var customs := PackedFloat32Array()
	var kept: int = 0
	var dropped: Dictionary = {}
	for i: int in count:
		var t: Transform3D = world * mm.get_instance_transform(i)
		if kind in POSITION_TESTED:
			var verdict: String = _top_verdict(t.origin)
			_rule(kind, verdict)
			if verdict != "on_top":
				dropped[verdict] = int(dropped.get(verdict, 0)) + 1
				continue
		transforms.append_array(PackedFloat32Array(_basis_origin(t)))
		if mm.use_colors:
			var c: Color = mm.get_instance_color(i)
			colors.append_array(PackedFloat32Array([c.r, c.g, c.b, c.a]))
		if mm.use_custom_data:
			var d: Color = mm.get_instance_custom_data(i)
			customs.append_array(PackedFloat32Array([d.r, d.g, d.b, d.a]))
		kept += 1
	for verdict: String in dropped:
		_count(excluded, "%s (%s)" % [kind, verdict], 0, dropped[verdict])
	if kept == 0:
		return
	var mesh_ids: Array = _mesh_surfaces(mm.mesh, node)
	entry["meshes"] = mesh_ids
	entry["instances"] = {
		"count": kept, "transform": _append_bytes(transforms.to_byte_array()),
		"color": _append_bytes(colors.to_byte_array()) if mm.use_colors else -1,
		"custom": _append_bytes(customs.to_byte_array()) if mm.use_custom_data else -1,
	}
	entry["triangles"] = _triangles(mesh_ids) * kept
	objects.append(entry)


func _triangles(mesh_ids: Array) -> int:
	var total: int = 0
	for id: int in mesh_ids:
		total += int(meshes[id].triangles)
	return total


# ---------------------------------------------------------------- main

func run() -> void:
	if not _read_options():
		quit(1)
		return
	if FileAccess.file_exists(output.path_join("scene.json")):
		push_error("Refusing to overwrite existing export; remove the directory first: " + output)
		quit(1)
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Export requires a graphical Forward+ renderer; do not use --headless")
		quit(1)
		return
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("textures")))
	if dir_error != OK:
		push_error("Cannot create output directory: %d" % dir_error)
		quit(1)
		return
	# Same single-scene boot as capture_reference.gd.
	for child: Node in root.get_children():
		if child.scene_file_path == "res://scenes/terrain_editor.tscn":
			if current_scene == child:
				current_scene = null
			root.remove_child(child)
			child.free()
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor = (load("res://scenes/terrain_editor.tscn") as PackedScene).instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	editor.set_native_preview(true)
	editor.renderer.animate_edits = false
	if preset != 0 or seed_value != int(editor.data.seed):
		editor.data.make_preset(preset)
		editor.data.seed = seed_value
		editor.renderer.rebuild_all()
		editor.motes.rebuild_from_data(editor.data)
		editor.gameplay.on_preset_changed()
	# Material palettes at the reference capture time of day.
	editor.gameplay.time_system.set_progress(PROGRESS, editor)
	for i: int in 4:
		RenderingServer.force_draw(false)
		await process_frame
	if editor.renderer.has_pending_updates():
		errors.append("Renderer still has pending updates at export time")
	_visit(editor)
	var bin_file := FileAccess.open(output.path_join("scene.bin"), FileAccess.WRITE)
	if bin_file == null:
		errors.append("Cannot write scene.bin")
	else:
		bin_file.store_buffer(bin)
		bin_file.close()
	var excluded_summary: Dictionary = {}
	for kind: String in excluded:
		excluded_summary[kind] = excluded[kind]
	var report: Dictionary = {
		"seed": seed_value, "preset": preset, "godot": Engine.get_version_info().string,
		"scene": "res://scenes/terrain_editor.tscn", "day_progress": PROGRESS,
		"layout": {
			"bin_little_endian": true,
			"pos": "float32 x3 per vertex", "normal": "float32 x3 per vertex",
			"uv": "float32 x2 per vertex or -1", "uv2": "float32 x2 per vertex or -1",
			"color": "float32 x4 per vertex (raw Godot vertex colour) or -1",
			"index": "uint32 per index, triangle list; -1 when not indexed",
			"transform": "12 float32: basis column x, column y, column z, origin (world space)",
			"instances.color": "float32 x4 per instance or -1", "instances.custom": "float32 x4 per instance or -1",
			"aabb": "local min xyz, max xyz",
		},
		"rules": {
			"on_top_decoration_kinds": ON_TOP_KINDS, "position_tested_kinds": POSITION_TESTED,
			"position_test": "instance origin XZ must lie on the published top surface (contours.surface_at) and its Y no more than %.2f m below that surface; otherwise the instance is excluded" % BELOW_TOP_TOLERANCE,
			"instance_verdicts": instance_rule,
		},
		"meshes": meshes, "materials": materials, "textures": textures, "objects": objects,
		"excluded_summary": excluded_summary, "hidden_summary": hidden,
		"excluded_other_nodes": other_nodes,
		"bin_bytes": bin.size(), "errors": errors,
	}
	var json_file := FileAccess.open(output.path_join("scene.json"), FileAccess.WRITE)
	if json_file == null:
		errors.append("Cannot write scene.json")
	else:
		json_file.store_string(JSON.stringify(report, "  ", true))
		json_file.close()
	print("EXPORT: objects=%d meshes=%d materials=%d textures=%d bin=%d errors=%s" % [objects.size(), meshes.size(), materials.size(), textures.size(), bin.size(), str(errors)])
	viewport.remove_child(editor)
	editor.free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
