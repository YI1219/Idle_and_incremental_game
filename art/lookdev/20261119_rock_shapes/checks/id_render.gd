extends "res://tools/art/capture_lookdev.gd"
## Diagnostic only: every cliff piece is drawn in a flat colour unique to its
## instance origin, everything else black, no lighting or post effects. The
## stills feed fragment_metric.py, which counts thin slivers and small chips.
## Usage: godot --path . --script <this> -- --out=res://.../dir [--seed=N --preset=K]
const ID_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 fixed_color = vec3(-1.0);
varying vec3 id_color;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	// Quantised to 6 levels per channel above a floor, so sRGB output keeps ids apart.
	vec3 h = fract(sin(vec3(dot(o, vec3(12.9898, 78.233, 37.719)), dot(o, vec3(93.989, 67.345, 11.135)), dot(o, vec3(41.317, 19.871, 71.553)))) * 43758.5453);
	id_color = fixed_color.x >= 0.0 ? fixed_color : (floor(h * 6.0) + 2.0) / 8.0;
}
void fragment() { ALBEDO = id_color; }
"""
var views: Array[Dictionary] = []
var classes: Dictionary = {}

func _material(fixed: Vector3) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = ID_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fixed_color", fixed)
	return material

func _shader_file(node: GeometryInstance3D) -> String:
	var material: Material = node.material_override
	if material == null:
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
		if mesh != null and mesh.get_surface_count() > 0:
			material = mesh.surface_get_material(0)
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return (material as ShaderMaterial).shader.resource_path.get_file()
	return ""

func run() -> void:
	var seed_arg: int = 7301
	var preset_arg: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--preset="):
			preset_arg = int(arg.trim_prefix("--preset="))
	if output == "":
		push_error("--out required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for yaw: float in [16.0, 61.0, 106.0, 151.0, 196.0, 241.0, 286.0, 331.0]:
		views.append({"name": "orbit_%03d" % int(yaw), "center": Vector2(-2, -1), "height": 32.0, "yaw": yaw, "pitch": 30.0})
	for yaw: float in [16.0, 106.0, 196.0, 286.0]:
		views.append({"name": "low_%03d" % int(yaw), "center": Vector2(-2, -1), "height": 17.0, "yaw": yaw, "pitch": 18.0})
	root.title = "岩体编号诊断 · 自动关闭"
	root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.background_view.enabled = false
	editor.hud.hide()
	editor.gameplay.set_wallpaper_mode(true)
	if preset_arg != 0 or seed_arg != 7301:
		editor.data.seed = seed_arg
		editor.select_preset(preset_arg)
	for index: int in 40:
		await process_frame
	while editor.renderer.has_pending_updates():
		await process_frame
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	editor.background_view.sync()
	var env: Environment = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = false
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.fog_enabled = false
	(editor.camera.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	(editor.camera.attributes as CameraAttributesPractical).dof_blur_near_enabled = false
	var black: ShaderMaterial = _material(Vector3.ZERO)
	var by_origin: ShaderMaterial = _material(Vector3(-1, -1, -1))
	var hull: ShaderMaterial = _material(Vector3(1, 0, 0))
	var mantle: ShaderMaterial = _material(Vector3(0, 0, 1))
	for node: Node in editor.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		var shader: String = _shader_file(geometry)
		var name: String = String(node.name)
		var kind: String = "other"
		if shader == "cliff.gdshader":
			kind = "hull"; geometry.material_override = hull
		elif shader == "stone_mantle.gdshader":
			kind = "mantle"; geometry.material_override = mantle
		elif shader == "cliff_column.gdshader":
			kind = "underside" if name.begins_with("underside_rock") else "column"
			geometry.material_override = by_origin
		elif shader in ["cloud_deck.gdshader", "distant_mountain.gdshader", "ambient_motes.gdshader", "waterfall_mist.gdshader", "foliage_cards.gdshader", "foliage.gdshader", "decor_vertex_color.gdshader"] or name in ["water", "waterfall", "bank", "BreakthroughWave", "FishingSilkAndRipples", "JadeBobber", "Mesh"]:
			geometry.visible = false
		else:
			geometry.material_override = black
		classes[kind] = int(classes.get(kind, 0)) + 1
	var records: Array[Dictionary] = []
	for view: Dictionary in views:
		_frame(view.center, view.height, view.yaw, view.pitch)
		for index: int in 12:
			RenderingServer.force_draw(false)
			await process_frame
		RenderingServer.force_draw(false)
		var file: String = "%s.png" % view.name
		viewport.get_texture().get_image().save_png(output.path_join(file))
		var eye: Vector3 = editor.camera.global_position
		var target := Vector3(view.center.x, 0.0, view.center.y)
		# Pixels per metre at the island centre, for converting widths to metres.
		var px_per_m: float = SIZE.y / (2.0 * eye.distance_to(target) * tan(deg_to_rad(editor.camera.fov * .5)))
		records.append({"file": file, "yaw": view.yaw, "height": view.height, "pitch": view.pitch, "px_per_m": px_per_m})
		print("ID saved ", file, " px_per_m=", px_per_m)
	FileAccess.open(output.path_join("views.json"), FileAccess.WRITE).store_string(JSON.stringify({"diagnostic": true, "seed": seed_arg, "preset": preset_arg, "hull_rgb": [255, 0, 0], "mantle_rgb": [0, 0, 255], "classes": classes, "views": records}, "\t"))
	editor.free()
	viewport.free()
	quit()
