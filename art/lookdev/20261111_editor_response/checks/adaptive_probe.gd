extends "res://tools/perf/resolution_probe.gd"
func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(3840,2160)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.gameplay.time_system.set_progress(.29,scene)
	scene.water_view.tick(.1)
	scene.water_view.flush()
	scene.camera._center=Vector2(-2,-1)
	scene.camera._height=32
	scene.camera._yaw=16
	scene.camera._pitch=30
	scene.camera.advance(0)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	for i in 80:
		RenderingServer.force_draw(false)
		await process_frame
	for i in 150:
		scene.preview_quality.advance(.025)
	var adaptive: float = viewport.scaling_3d_scale
	await sample("4K_adaptive_settled",Vector2i(3840,2160),env,true,true,Viewport.MSAA_2X,adaptive)
	FileAccess.open("res://art/lookdev/20261111_editor_response/checks/performance_adaptive.json",FileAccess.WRITE).store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"scale":adaptive,"samples":samples},"\t"))
	scene.free()
	viewport.queue_free()
	quit()
