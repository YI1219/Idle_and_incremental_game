extends "res://tools/perf/resolution_probe.gd"
## Fixed state per simulated frame. No screenshots inside timed section.
func run() -> void:
	output = "/tmp/wallpaper_probe.json"
	var resolution := Vector2i(2560,1440)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg == "--4k": resolution=Vector2i(3840,2160)
	viewport=SubViewport.new(); viewport.size=resolution; viewport.msaa_3d=Viewport.MSAA_4X
	viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene=load("res://scenes/terrain_editor.tscn").instantiate(); viewport.add_child(scene)
	scene.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
	scene.process_mode=Node.PROCESS_MODE_DISABLED
	scene.gameplay.set_wallpaper_mode(true)
	scene.gameplay.time_system.set_progress(.29,scene)
	scene.camera._center=Vector2(-2,-1); scene.camera._height=32; scene.camera._yaw=16; scene.camera._pitch=30; scene.camera.advance(0)
	scene.set_native_preview(true)
	var water: Node3D=scene.water_view
	if "--before" in OS.get_cmdline_user_args():
		water.free()
		water=load("res://art/lookdev/20261111_performance/checks/water_renderer_before.gd").new()
		scene.add_child(water);water.configure(scene.data,scene.renderer)
	Engine.max_fps=0
	var times: Array[float]=[]; var cpu: Array[float]=[]
	for i: int in 160:
		var start: int=Time.get_ticks_usec()
		water.tick(1.0/60.0)
		water._process(1.0/60.0)
		var processed: int=Time.get_ticks_usec()
		RenderingServer.force_draw(false); await process_frame
		if i>=40:
			times.append((Time.get_ticks_usec()-start)/1000.0)
			cpu.append((processed-start)/1000.0)
	var report: Dictionary={"resolution":[resolution.x,resolution.y],"frame_ms":stats(times),"water_main_ms":stats(cpu),"scale":viewport.scaling_3d_scale,"adapter":RenderingServer.get_video_adapter_name(),"water_volume":water.published_volume,"method":"native 4x MSAA explicit draw, frozen light/camera, live water at fixed 1/60s per frame;40 warmup+120 samples;no capture I/O;no limiter"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	scene.free();viewport.queue_free();quit()
