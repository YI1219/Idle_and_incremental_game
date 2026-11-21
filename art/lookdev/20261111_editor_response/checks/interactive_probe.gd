extends "res://tools/perf/resolution_probe.gd"
func run() -> void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(3840,2160)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene=Node3D.new()
	scene.set_script(load("res://art/lookdev/20261111_editor_response/checks/profile_editor.gd"))
	viewport.add_child(scene)
	scene.camera.set_process(false)
	scene.camera._center=Vector2(-2,-1)
	scene.camera._height=32
	scene.camera._yaw=16
	scene.camera._pitch=30
	scene.camera.advance(0)
	scene.gameplay.time_system.set_progress(.29,scene)
	var mode: String = "normal"
	if OS.get_cmdline_user_args().has("--native"):
		mode = "native"
		scene.set_native_preview(true)
	if OS.get_cmdline_user_args().has("--realtime"):
		mode = "realtime"
		scene.get_node("WorldEnvironment").environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	if OS.get_cmdline_user_args().has("--paused-time"):
		mode = "paused_time"
		scene.gameplay.time_system.paused = true
	if OS.get_cmdline_user_args().has("--no-water"):
		mode = "no_water"
		scene.water_view._data = null
	if OS.get_cmdline_user_args().has("--hide-hud"):
		mode = "hide_hud"
		scene.gameplay.shihai_hud.hide()
	if OS.get_cmdline_user_args().has("--no-editor"):
		mode = "no_editor"
		scene.set_process(false)
	var hover:=InputEventMouseMotion.new()
	hover.position=scene.camera.unproject_position(Vector3(-12,3.5,-2))
	viewport.push_input(hover,true)
	for i in 240:
		RenderingServer.force_draw(false)
		await process_frame
	var draw_count: Dictionary = {"n":0}
	scene.gameplay.shihai_hud.draw.connect(func(): draw_count.n += 1)
	var times: Array[float]=[]
	for i in 120:
		var start:int=Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		await process_frame
		times.append(float(Time.get_ticks_usec()-start)/1000.0)
	var report:Dictionary={"hud_redraws":draw_count.n,"editor_process_ms":stats(scene.process_costs),"water_surface_vertices":scene.water_view.published_surfaces.water.vertices.size(),"falls":scene.water_view.fall_veils.size(),"grass_changing":scene.water_view.grass_recovery._changing.size(),"variant":mode,"method":"production editor process, hover and water workers active; fixed BASE A; 240 warmup,120 frames; no screenshot IO","frame_ms":stats(times),"scale":viewport.scaling_3d_scale,"resolution":[viewport.size.x,viewport.size.y],"adapter":RenderingServer.get_video_adapter_name(),"water_volume":scene.water_view.published_volume,"discharged":scene.water_view.published_discharged_volume}
	FileAccess.open("res://art/lookdev/20261111_editor_response/checks/performance_interactive_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(report)
	scene.free()
	viewport.queue_free()
	quit()
