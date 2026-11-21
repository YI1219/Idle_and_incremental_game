extends "res://tools/art/capture_lookdev.gd"
## Single-process ablation at a real fixed-pixel target in the normal render loop.
## Every variant is applied, warmed, sampled and restored inside one live scene,
## and the variant list is replayed forward then backward to cancel drift.
## Usage: godot --path . --disable-vsync --script <this> -- --variants=base,ssao0,... [--rounds=2] [--size=3840x2160] [--out=/tmp/x.json] [--list]
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

var rounds: int = 2
var variants: PackedStringArray = ["base"]
var warm_s: float = 1.5
var sample_s: float = 4.0
var px := Vector2i(3840, 2160)
var list_only: bool = false
var _undo: Array[Callable] = []
var _env: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D

func _geometry() -> Array[Node]:
	return editor.find_children("*", "GeometryInstance3D", true, false)

func _shader_of(node: Node) -> String:
	var mesh: Mesh = null
	if node is MeshInstance3D:
		if (node as MeshInstance3D).material_override is ShaderMaterial:
			return ((node as MeshInstance3D).material_override as ShaderMaterial).shader.resource_path.get_file()
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	if (node as GeometryInstance3D).material_override is ShaderMaterial:
		return ((node as GeometryInstance3D).material_override as ShaderMaterial).shader.resource_path.get_file()
	if mesh == null or mesh.get_surface_count() == 0:
		return "-"
	var material: Material = mesh.surface_get_material(0)
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return ((material as ShaderMaterial).shader.resource_path.get_file())
	return material.get_class() if material != null else "none"

func _list() -> Dictionary:
	var groups: Dictionary = {}
	for node: Node in _geometry():
		var instances: int = 1
		var triangles: int = 0
		var mesh: Mesh = null
		if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			instances = (node as MultiMeshInstance3D).multimesh.visible_instance_count
			if instances < 0:
				instances = (node as MultiMeshInstance3D).multimesh.instance_count
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for surface: int in mesh.get_surface_count():
				var arrays_len: int = mesh.surface_get_array_index_len(surface) if mesh is ArrayMesh else 0
				if arrays_len == 0 and mesh is ArrayMesh:
					arrays_len = (mesh as ArrayMesh).surface_get_array_len(surface)
				triangles += arrays_len / 3
		var key: String = "%s|%s|%s|vis=%s|parent=%s" % [node.name, node.get_class(), _shader_of(node), (node as Node3D).is_visible_in_tree(), node.get_parent().name]
		var row: Dictionary = groups.get(key, {"nodes": 0, "instances": 0, "triangles": 0})
		row.nodes += 1
		row.instances += instances
		row.triangles += triangles * instances
		groups[key] = row
	return groups

func _hide(names: PackedStringArray) -> void:
	var touched: Array[Node] = []
	for node: Node in _geometry():
		var match_name: bool = false
		for wanted: String in names:
			if String(node.name) == wanted or (wanted.ends_with("*") and String(node.name).begins_with(wanted.trim_suffix("*"))):
				match_name = true
		if match_name and (node as Node3D).visible:
			(node as Node3D).visible = false
			touched.append(node)
	print("HIDE ", names, " -> ", touched.size(), " nodes")
	_undo.append(func() -> void:
		for node: Node in touched:
			if is_instance_valid(node):
				(node as Node3D).visible = true)

func _hide_shader(file_names: PackedStringArray) -> void:
	var touched: Array[Node] = []
	for node: Node in _geometry():
		if _shader_of(node) in file_names and (node as Node3D).visible:
			(node as Node3D).visible = false
			touched.append(node)
	print("HIDE SHADER ", file_names, " -> ", touched.size(), " nodes")
	_undo.append(func() -> void:
		for node: Node in touched:
			if is_instance_valid(node):
				(node as Node3D).visible = true)

## Measurement only: replaces root-anchored vertex math with constants to
## show how much of the grass cost is vertex shading. Never a production look.
func _grass_stub(mode: String) -> void:
	var blades: Array[GeometryInstance3D] = []
	for node: Node in _geometry():
		if String(node.name) == "grass_blades":
			blades.append(node as GeometryInstance3D)
	if blades.is_empty():
		return
	var original: ShaderMaterial = blades[0].material_override as ShaderMaterial
	var code: String = original.shader.code.replace("#include \"", "#include \"res://shaders/terrain_editor/")
	var before: String = code
	code = code.replace("vec3 ground=ground_cover(root_world,0.0,slope);", "vec3 ground=vec3(.30,.42,.22);slope=vec2(0.0);")
	if mode == "all":
		code = code.replace("float patch_var=gc_noise(root_world.xz*.55+vec2(4.1,2.7));", "float patch_var=.5;")
		code = code.replace("vec2 pillow_g=gc_pillow_grad(root_world.xz)*(.14*standing);", "vec2 pillow_g=vec2(0.0);")
		code = code.replace("float warp=gc_noise(root_world.xz*.22+vec2(2.3,7.1))*2.6;", "float warp=1.3;")
	print("GRASS STUB ", mode, " changed=", code != before, " length ", before.length(), "->", code.length())
	var shader := Shader.new()
	shader.code = code
	var stub: ShaderMaterial = original.duplicate(false)
	stub.shader = shader
	for blade: GeometryInstance3D in blades:
		blade.material_override = stub
	_undo.append(func() -> void:
		for blade: GeometryInstance3D in blades:
			if is_instance_valid(blade):
				blade.material_override = original)

func _set_quality(native: bool) -> void:
	var quality: RefCounted = editor.preview_quality
	quality.native = native
	quality._last_native = native
	quality._scale = 1.0
	quality._apply()
	editor.background_view.sync()

func _apply(variant: String) -> void:
	var attributes: CameraAttributesPractical = editor.camera.attributes as CameraAttributesPractical
	var part_arg: String = ""
	for part: String in variant.split("&"):
		if part == "base":
			pass
		elif part == "native":
			_set_quality(true)
			_undo.append(func() -> void: _set_quality(false))
		elif part.begins_with("msaa"):
			var old: int = viewport.msaa_3d
			viewport.msaa_3d = {"0": Viewport.MSAA_DISABLED, "2": Viewport.MSAA_2X, "4": Viewport.MSAA_4X, "8": Viewport.MSAA_8X}[part.trim_prefix("msaa")]
			_undo.append(func() -> void: viewport.msaa_3d = old)
		elif part == "ssao0":
			_env.ssao_enabled = false
			_undo.append(func() -> void: _env.ssao_enabled = true)
		elif part == "ssil0":
			_env.ssil_enabled = false
			_undo.append(func() -> void: _env.ssil_enabled = true)
		elif part == "glow0":
			_env.glow_enabled = false
			_undo.append(func() -> void: _env.glow_enabled = true)
		elif part == "fog0":
			_env.fog_enabled = false
			_undo.append(func() -> void: _env.fog_enabled = true)
		elif part == "adj0":
			_env.adjustment_enabled = false
			_undo.append(func() -> void: _env.adjustment_enabled = true)
		elif part == "dof0":
			var far: bool = attributes.dof_blur_far_enabled
			attributes.dof_blur_far_enabled = false
			_undo.append(func() -> void: attributes.dof_blur_far_enabled = far)
		elif part == "shadow0":
			_sun.shadow_enabled = false
			_undo.append(func() -> void: _sun.shadow_enabled = true)
		elif part == "shadow8k":
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			_undo.append(func() -> void: RenderingServer.directional_shadow_atlas_set_size(4096, true))
		elif part.begins_with("softq"):
			RenderingServer.directional_soft_shadow_filter_set_quality(int(part.trim_prefix("softq")))
			_undo.append(func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))))
		elif part == "angular0":
			var angle: float = _sun.light_angular_distance
			_sun.light_angular_distance = 0.0
			_undo.append(func() -> void: _sun.light_angular_distance = angle)
		elif part == "blend0":
			_sun.directional_shadow_blend_splits = false
			_undo.append(func() -> void: _sun.directional_shadow_blend_splits = true)
		elif part == "fill0":
			_fill.visible = false
			_undo.append(func() -> void: _fill.visible = true)
		elif part.begins_with("scale"):
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = float(part.trim_prefix("scale"))
			_undo.append(func() -> void:
				viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				viewport.scaling_3d_scale = 1.0)
		elif part == "unshaded":
			viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
			_undo.append(func() -> void: viewport.debug_draw = Viewport.DEBUG_DRAW_DISABLED)
		elif part == "bg0":
			editor.background_view.enabled = false
			editor.background_view.sync()
			_undo.append(func() -> void:
				editor.background_view.enabled = true
				editor.background_view.sync())
		elif part == "motes0":
			var shown: bool = editor.motes.visible
			editor.motes.visible = false
			_undo.append(func() -> void: editor.motes.visible = shown)
		elif part == "nogeo":
			_hide(PackedStringArray(["*"]))
		elif part == "grass_before":
			# Task-start clump mesh (old LOD table) on the same live instances.
			var before_mesh: ArrayMesh = load("res://art/lookdev/20261119_native4k/checks/source_before/scripts/terrain_editor/grass_field.gd").clump_mesh()
			var swapped: Dictionary = {}
			for node: Node in _geometry():
				if String(node.name) == "grass_blades":
					swapped[node] = (node as MultiMeshInstance3D).multimesh.mesh
					(node as MultiMeshInstance3D).multimesh.mesh = before_mesh
			_undo.append(func() -> void:
				for node: Node in swapped:
					if is_instance_valid(node):
						(node as MultiMeshInstance3D).multimesh.mesh = swapped[node])
		elif part.begins_with("grass_stub"):
			_grass_stub(part.trim_prefix("grass_stub_"))
		elif part.begins_with("grasslod"):
			var bias: float = float(part.trim_prefix("grasslod"))
			var changed: Dictionary = {}
			for node: Node in _geometry():
				if String(node.name) == "grass_blades":
					changed[node] = (node as GeometryInstance3D).lod_bias
					(node as GeometryInstance3D).lod_bias = bias
			_undo.append(func() -> void:
				for node: Node in changed:
					if is_instance_valid(node):
						(node as GeometryInstance3D).lod_bias = changed[node])
		elif part.begins_with("ssilq") or part.begins_with("ssilblur"):
			var prefix: String = "rendering/environment/ssil/"
			var quality: int = int(ProjectSettings.get_setting(prefix + "quality"))
			var half: bool = bool(ProjectSettings.get_setting(prefix + "half_size"))
			var target: float = float(ProjectSettings.get_setting(prefix + "adaptive_target"))
			var blur: int = int(ProjectSettings.get_setting(prefix + "blur_passes"))
			var from: float = float(ProjectSettings.get_setting(prefix + "fadeout_from"))
			var to: float = float(ProjectSettings.get_setting(prefix + "fadeout_to"))
			if part.begins_with("ssilq"):
				RenderingServer.environment_set_ssil_quality(int(part.trim_prefix("ssilq")), half, target, blur, from, to)
			else:
				RenderingServer.environment_set_ssil_quality(quality, half, target, int(part.trim_prefix("ssilblur")), from, to)
			# Return to whatever production preview quality currently selects.
			_undo.append(func() -> void: editor.preview_quality._apply())
		elif part.begins_with("dofshape"):
			var shape: int = int(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_shape"))
			RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(int(part.trim_prefix("dofshape")))
			_undo.append(func() -> void: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(shape))
		elif part == "skycolor":
			_env.background_mode = Environment.BG_COLOR
			_undo.append(func() -> void: _env.background_mode = Environment.BG_SKY)
		elif part == "noproc":
			editor.set_process(false)
			_undo.append(func() -> void: editor.set_process(true))
		elif part == "nowater":
			editor.water_view.set_process(false)
			editor.water_view.set_physics_process(false)
			_undo.append(func() -> void:
				editor.water_view.set_process(true)
				editor.water_view.set_physics_process(true))
		elif part == "noshadowcast":
			var casters: Array[GeometryInstance3D] = []
			for node: Node in _geometry():
				var geometry: GeometryInstance3D = node as GeometryInstance3D
				if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and String(node.name).begins_with(part_arg):
					casters.append(geometry)
					geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_undo.append(func() -> void:
				for geometry: GeometryInstance3D in casters:
					if is_instance_valid(geometry):
						geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		elif part.begins_with("hide:"):
			_hide(part.trim_prefix("hide:").split("+"))
		elif part.begins_with("hideshader:"):
			_hide_shader(part.trim_prefix("hideshader:").split("+"))
		else:
			push_error("unknown variant part " + part)

func _restore() -> void:
	_undo.reverse()
	for undo: Callable in _undo:
		undo.call()
	_undo.clear()

func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame

func _sample() -> Dictionary:
	var drawn: int = Engine.get_frames_drawn()
	var frames: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var start: int = last
	while Time.get_ticks_usec() - start < int(sample_s * 1000000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	frames.sort()
	var rendered: int = Engine.get_frames_drawn() - drawn
	return {"fps": rendered / elapsed, "ms": elapsed * 1000.0 / maxi(rendered, 1), "p50": frames[frames.size() / 2], "p95": frames[int(frames.size() * .95)], "rendered": rendered, "idle": frames.size(), "primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), "draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variants="):
			variants = arg.trim_prefix("--variants=").split(",")
		if arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
		if arg.begins_with("--sample="):
			sample_s = float(arg.trim_prefix("--sample="))
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			px = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg == "--list":
			list_only = true
	root.title = "性能验证 · 自动关闭"
	root.size = Vector2i(1280, 720)
	root.always_on_top = true
	viewport = SubViewport.new()
	viewport.size = px
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.preview_quality = FixedQuality.new()
	editor.preview_quality.configure(viewport)
	editor.preview_quality._scale = 1.0
	editor.preview_quality._apply()
	editor.hud.hide()
	editor.gameplay.time_system.set_progress(.29, editor)
	_frame(Vector2(-2, -1), 32, 16, 30)
	editor.background_view.sync()
	_env = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	_sun = editor.get_node("SunLight") as DirectionalLight3D
	_fill = editor.get_node("FillLight") as DirectionalLight3D
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait(3.0)
	var listing: Dictionary = _list()
	var keys: Array = listing.keys()
	keys.sort()
	for key: String in keys:
		print("NODE ", key, " ", JSON.stringify(listing[key]))
	print("INFO draw_calls=", viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), " primitives=", viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), " shadow_draw_calls=", viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), " shadow_primitives=", viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), " texture=", viewport.get_texture().get_size(), " msaa=", viewport.msaa_3d, " scale=", viewport.scaling_3d_scale, " bg_active=", editor.background_view.is_active())
	if list_only:
		editor.free()
		viewport.free()
		quit()
		return
	var results: Dictionary = {}
	for variant: String in variants:
		results[variant] = []
	for round_index: int in rounds:
		var order: Array = Array(variants)
		if round_index % 2 == 1:
			order.reverse()
		for variant: String in order:
			_apply(variant)
			await _wait(warm_s)
			var row: Dictionary = await _sample()
			_restore()
			(results[variant] as Array).append(row)
			print("SAMPLE round=", round_index, " ", variant, " ", JSON.stringify(row))
	var summary: Array[Dictionary] = []
	var base_ms: float = 0.0
	for variant: String in variants:
		var total_ms: float = 0.0
		var worst_p95: float = 0.0
		for row: Dictionary in results[variant]:
			total_ms += float(row.ms)
			worst_p95 = maxf(worst_p95, float(row.p95))
		var mean_ms: float = total_ms / (results[variant] as Array).size()
		if variant == "base":
			base_ms = mean_ms
		summary.append({"variant": variant, "ms": mean_ms, "fps": 1000.0 / mean_ms, "worst_p95": worst_p95, "rounds": results[variant]})
	for row: Dictionary in summary:
		row["delta_ms_vs_base"] = float(row.ms) - base_ms
		print("RESULT %-44s %7.2f ms %6.2f fps  delta %+6.2f ms" % [row.variant, row.ms, row.fps, row.delta_ms_vs_base])
	if output != "":
		var report: Dictionary = {"adapter": RenderingServer.get_video_adapter_name(), "resolution": [px.x, px.y], "rounds": rounds, "warm_seconds": warm_s, "sample_seconds": sample_s, "summary": summary, "method": "one live scene; normal render loop; real fixed-pixel SubViewport shown in a visible 1280x720 window; balanced quality scale 1 unless a variant says otherwise; no cap/vsync/image IO; forward then reverse order"}
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	editor.free()
	viewport.free()
	quit()
