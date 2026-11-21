extends "res://tools/perf/resolution_probe.gd"
func run() -> void:
	output = "res://art/lookdev/20261111_editor_response/checks/performance_diagnosis.json"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.gameplay.time_system.set_progress(.29, scene)
	scene.water_view.tick(.1)
	scene.water_view.flush()
	scene.camera._center = Vector2(-2,-1)
	scene.camera._height = 32
	scene.camera._yaw = 16
	scene.camera._pitch = 30
	scene.camera.advance(0)
	scene.hud.hide()
	var env: Environment = scene.get_node("WorldEnvironment").environment
	for i in 80:
		RenderingServer.force_draw(false)
		await process_frame
	var size := Vector2i(3840,2160)
	await sample("native_base",size,env,true,true,2,1.0)
	await sample("preview_base",size,env,true,true,1,2.0/3.0)
	scene.landscape.visible = false
	await sample("native_no_landscape",size,env,true,true,2,1.0)
	scene.landscape.visible = true
	scene.get_node("SunLight").shadow_enabled = false
	await sample("native_no_shadows",size,env,true,true,2,1.0)
	scene.get_node("SunLight").shadow_enabled = true
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	await sample("native_shadow_low",size,env,true,true,2,1.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	await sample("native_shadow_medium",size,env,true,true,2,1.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM,true,.5,2,50,300)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM,true,.5,4,50,300)
	await sample("native_half_indirect",size,env,true,true,2,1.0)
	await sample("preview_half_indirect",size,env,true,true,1,2.0/3.0)
	await sample("native_no_indirect",size,env,false,false,2,1.0)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"samples":samples,"method":"fixed BASE A; static scene; 80 initial warmup + 12 each; 50 explicit draw frames; no image IO"},"\t"))
	scene.free()
	viewport.queue_free()
	quit()
