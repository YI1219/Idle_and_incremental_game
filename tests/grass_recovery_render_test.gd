extends "res://tests/flooded_ground_test.gd"
func bind_growth(recovery: RefCounted) -> void:
	var bounds: Rect2 = recovery.rect
	RenderingServer.global_shader_parameter_set("grass_recovery_field",recovery.texture)
	RenderingServer.global_shader_parameter_set("grass_recovery_rect",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
	RenderingServer.global_shader_parameter_set("grass_recovery_active",1.0)
func run() -> void:
	if DisplayServer.get_name() == "headless":quit(2);return
	output = "res://art/lookdev/20261111_editor_response/checks/grass_pixels"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	environment_node.environment.background_mode = Environment.BG_COLOR
	environment_node.environment.background_color = Color(.03,.03,.03)
	environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_node.environment.ambient_light_color = Color.WHITE
	environment_node.environment.ambient_light_energy = 1.0
	scene.add_child(environment_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	scene.add_child(camera)
	camera.make_current()
	_water(.1,.1)
	var background: Image = await _capture("background")
	var recovery: RefCounted = load("res://scripts/terrain_editor/grass_recovery.gd").new()
	var cells: Dictionary = {}
	var depths: Dictionary = {}
	for z in range(-2,3):
		for x in range(-2,4):
			var cell := Vector2i(x,z)
			cells[cell] = {"height":0.0}
			if x >= 0:depths[cell]=.1
	for kind: String in ["blades","rim"]:
		recovery.clear()
		recovery.sync(cells,{})
		if kind == "blades":_blades(0.0)
		else:_rim(0.0)
		subject.position += Vector3(.5,0,.5)
		camera.position += Vector3(.5,0,.5)
		camera.look_at(Vector3(.5,.1,.5))
		bind_growth(recovery)
		var dry: Image = await _capture(kind+"_dry")
		recovery.sync(cells,depths)
		recovery.advance(.3)
		bind_growth(recovery)
		var partial: Image = await _capture(kind+"_fading")
		recovery.advance(.5)
		bind_growth(recovery)
		var hidden: Image = await _capture(kind+"_hidden")
		var a: int = _visible_pixels(dry,background)
		var b: int = _visible_pixels(partial,background)
		var c: int = _visible_pixels(hidden,background)
		check(a>200 and b>4 and b<a,kind+" fades through intermediate visible pixels")
		check(c<=4,kind+" completes disappearance")
		recovery.sync(cells,{})
		recovery.advance(.4)
		bind_growth(recovery)
		var growing: Image = await _capture(kind+"_growing")
		var g: int = _visible_pixels(growing,background)
		check(g>4 and g<a,kind+" returns gradually from neighbouring lawn")
		recovery.advance(2.0)
		bind_growth(recovery)
		var restored: Image = await _capture(kind+"_restored")
		check(_difference(dry,restored)<.001,kind+" fully restores the dry silhouette")
		print(kind," pixels ",a," -> ",b," -> ",c," -> ",g)
	RenderingServer.global_shader_parameter_set("grass_recovery_active",0.0)
	viewport.free()
	print("GRASS RECOVERY PIXELS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
