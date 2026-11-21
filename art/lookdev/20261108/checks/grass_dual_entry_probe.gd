extends SceneTree

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	print("DUAL_PROBE args=", OS.get_cmdline_args())
	for i in 2:
		await process_frame
	print("DUAL_PROBE current_scene=", current_scene)
	for child in root.get_children():
		print("DUAL_PROBE root_child=", child.name, " path=", child.scene_file_path, " processing=", child.can_process())
	if current_scene == null or current_scene.get("renderer") == null:
		quit(2)
		return
	var mat: ShaderMaterial = current_scene.renderer.materials.grass_blades
	print("DUAL_PROBE original=", mat.get_shader_parameter("grass_base"), " id=", mat.get_instance_id(), " progress=", current_scene.gameplay.time_system.day_progress)
	mat.set_shader_parameter("grass_base", Color(.1512, .2613, .2199))
	mat.set_shader_parameter("grass_highlight", Color(.2625, .372, .3002))
	print("DUAL_PROBE set_night=", mat.get_shader_parameter("grass_base"))
	for i in 24:
		await process_frame
	print("DUAL_PROBE after24=", mat.get_shader_parameter("grass_base"), " progress=", current_scene.gameplay.time_system.day_progress)
	quit(0)
