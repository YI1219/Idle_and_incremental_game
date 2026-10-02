extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=Node3D.new()
	root.add_child(world)
	var model:Node3D=load("res://assets/characters/qinglan/qinglan_candidate.glb").instantiate()
	world.add_child(model)
	var animation:AnimationPlayer=find_animation(model)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("c0ccca")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d7e1df")
	env.environment.ambient_light_energy=.8
	world.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-30,0)
	light.light_energy=1.0
	light.shadow_enabled=true
	world.add_child(light)
	var ground:=MeshInstance3D.new()
	ground.mesh=PlaneMesh.new()
	ground.scale=Vector3.ONE*50
	ground.position.y=-.035
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("b6c3bd")
	ground.material_override=material
	world.add_child(ground)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.55
	camera.position=Vector3(-1.9,1.0,3.0)
	camera.look_at(Vector3(0,.55,0))
	camera.current=true
	DirAccess.make_dir_recursive_absolute("/tmp/yunlu-motion")
	for frame in 108:
		var clip: String="walk" if frame<48 else ("attack_1" if frame<63 else ("idle" if frame<73 else ("attack_2" if frame<92 else "idle")))
		var start:int=0 if frame<48 else (48 if frame<63 else (63 if frame<73 else (73 if frame<92 else 92)))
		var time:float=float(frame%24 if frame<48 else frame-start)/30.0
		animation.play(clip)
		animation.seek(time,true)
		animation.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/yunlu-motion/%03d.png" % frame)
	quit()
func find_animation(node:Node) -> AnimationPlayer:
	if node is AnimationPlayer:return node
	for child in node.get_children():
		var result:=find_animation(child)
		if result:return result
	return null
