extends SceneTree
## Native Forward+ regression. These checks inspect pixels drawn by the actual
## terrain materials, including an angled MultiMesh with the production blades.
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Grass = preload("res://scripts/terrain_editor/grass_field.gd")
var output: String = "res://art/lookdev/20261110_editor_stability/checks/flooded_pixels"
var checks: int = 0
var failures: int = 0
var viewport: SubViewport
var scene: Node3D
var camera: Camera3D
var subject: GeometryInstance3D
var field: ImageTexture
var samples: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _water(surface: float, depth: float, active: float = 1.0) -> void:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBAF)
	image.fill(Color(surface, depth, 0.0, 1.0))
	if field == null:
		field = ImageTexture.create_from_image(image)
	else:
		field.update(image)
	RenderingServer.global_shader_parameter_set("live_water_field", field)
	RenderingServer.global_shader_parameter_set("live_water_rect", Vector4(-2, -2, 4, 4))
	RenderingServer.global_shader_parameter_set("live_water_active", active)

func _material(path: String) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(path)
	material.set_shader_parameter("grass_time", 1.25)
	material.set_shader_parameter("wind_strength", 0.0)
	return material

func _ground(height: float) -> void:
	var surface: Geometry.Surface = Geometry.Surface.new()
	surface.quad(Vector3(-.45, height, -.45), Vector3(.45, height, -.45), Vector3(.45, height, .45), Vector3(-.45, height, .45), Color.WHITE, true)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = surface.mesh()
	mesh.material_override = _material("res://shaders/terrain_editor/ground.gdshader")
	_replace(mesh, height)

func _rim(height: float) -> void:
	# The production rim encodes the same root height/XZ on every vertex of a fan.
	var surface: Geometry.Surface = Geometry.Surface.new()
	surface.quad(Vector3(-.20, height, 0), Vector3(.20, height, 0), Vector3(.14, height + .30, .03), Vector3(-.14, height + .30, .03), Color(.5, .5, 1, 1))
	for index: int in surface.vertices.size():
		surface.uv[index] = Vector2(height, 0)
		surface.uv2.append(Vector2.ZERO)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = surface.mesh()
	mesh.material_override = _material("res://shaders/terrain_editor/rim_green.gdshader")
	_replace(mesh, height)

func _blades(height: float) -> void:
	var mesh: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mesh.multimesh = MultiMesh.new()
	mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.multimesh.mesh = Grass.clump_mesh()
	mesh.multimesh.instance_count = 1
	mesh.multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.FORWARD, .65), Vector3(0, height, 0)))
	mesh.material_override = _material("res://shaders/terrain_editor/grass_blades.gdshader")
	_replace(mesh, height)

func _replace(mesh: GeometryInstance3D, height: float) -> void:
	if is_instance_valid(subject):
		subject.free()
	subject = mesh
	scene.add_child(subject)
	camera.position = Vector3(0, height + 1.6, 2.2)
	camera.look_at(Vector3(0, height + .10, 0), Vector3.UP)

func _capture(label: String) -> Image:
	for frame: int in 3:
		RenderingServer.force_draw(false)
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	image.save_png(output.path_join(label + ".png"))
	return image

func _mean(image: Image) -> Color:
	var result: Color = Color(0, 0, 0, 0)
	var pixels: int = 0
	for y: int in range(100, 220):
		for x: int in range(100, 220):
			result += image.get_pixel(x, y)
			pixels += 1
	return result / float(pixels)

func _difference(a: Image, b: Image) -> float:
	var difference: float = 0.0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			difference += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return difference / float(a.get_width() * a.get_height() * 3)

func _visible_pixels(image: Image, background: Image) -> int:
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var back: Color = background.get_pixel(x, y)
			if absf(color.r - back.r) + absf(color.g - back.g) + absf(color.b - back.b) > .025:
				count += 1
	return count

func _leaf_case(kind: String, height: float, surface: float, expect_submerged: bool, background: Image) -> void:
	if kind == "rim":
		_rim(height)
	else:
		_blades(height)
	_water(surface, .50, 0.0)
	var dry: Image = await _capture(kind + "_dry_" + str(height))
	_water(surface, .50)
	var wet: Image = await _capture(kind + "_wet_" + str(height))
	_water(surface, 0.0)
	var drained: Image = await _capture(kind + "_drained_" + str(height))
	var dry_pixels: int = _visible_pixels(dry, background)
	var wet_pixels: int = _visible_pixels(wet, background)
	check(dry_pixels > 200, kind + " fixture renders visible production leaves")
	if expect_submerged:
		check(wet_pixels <= 4, kind + " flooded roots leave no above-water or flattened leaf fragments")
	else:
		check(_difference(dry, wet) < .001, kind + " upper roots above adjacent water keep their dry silhouette")
	check(_difference(dry, drained) < .001, kind + " drainage restores the original leaves")
	samples[kind + str(height)] = {"dry_pixels": dry_pixels, "wet_pixels": wet_pixels, "drained_difference": _difference(dry, drained)}

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("flooded_ground_test needs native Forward+ pixel rendering")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	RenderingServer.global_shader_parameter_set("terrain_morph_progress", 1.0)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.environment = Environment.new()
	environment_node.environment.background_mode = Environment.BG_COLOR
	environment_node.environment.background_color = Color(.03, .03, .03)
	environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_node.environment.ambient_light_color = Color.WHITE
	environment_node.environment.ambient_light_energy = 1.0
	scene.add_child(environment_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	scene.add_child(camera)
	camera.make_current()
	_water(.10, 0.0)
	var background: Image = await _capture("background")
	_ground(0.0)
	_water(.005, .005, 0.0)
	var dry: Image = await _capture("ground_dry")
	_water(.005, .005)
	var wet: Image = await _capture("ground_flooded")
	_water(.005, 0.0)
	var drained: Image = await _capture("ground_drained")
	var color_delta: float = _difference(dry, wet)
	check(color_delta > .035, "flooded ground visibly changes turf into exposed wet substrate")
	var wet_color: Color = _mean(wet)
	check(wet_color.g < wet_color.r * 1.08, "submerged floor has neutral earth pigment instead of green turf")
	check(_difference(dry, drained) < .001, "ground drainage restores approved dry pigmentation")
	samples.ground = {"wet_difference": color_delta, "wet_mean": [wet_color.r, wet_color.g, wet_color.b], "drained_difference": _difference(dry, drained)}
	_ground(.70)
	_water(.10, .50, 0.0)
	var high_dry: Image = await _capture("ground_upper_dry")
	_water(.10, .50)
	var high_water: Image = await _capture("ground_upper_adjacent_water")
	check(_difference(high_dry, high_water) < .001, "upper lip above local water surface stays dry despite wet cell depth")
	await _leaf_case("rim", 0.0, .005, true, background)
	await _leaf_case("blades", 0.0, .005, true, background)
	await _leaf_case("rim", .70, .10, false, background)
	await _leaf_case("blades", .70, .10, false, background)
	await _leaf_case("rim", .102, .10, false, background)
	# A dry texel can retain an arbitrary R height. G=0 must disable flooding.
	_ground(0.0)
	_water(3.0, 0.0)
	var empty: Image = await _capture("ground_empty_high_texel")
	check(_difference(dry, empty) < .001, "zero-depth texel never wets ground using stale absolute height")
	_water(0.0, 0.0, 0.0)
	var report: Dictionary = {"checks": checks, "failures": failures, "samples": samples, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name()}
	FileAccess.open(output.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	viewport.free()
	print("FLOODED GROUND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
