extends "res://art/lookdev/20261112_fps_shaders/checks/variants.gd"
## Normal event/render loop; same current geometry, MSAA, shadows and actual pixels.
func run()->void:
	var before:bool=false;var high:bool=false;var scaled:bool=false
	output="/tmp/sky_runtime.json"
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--before":before=true
		if arg=="--4k":high=true
		if arg=="--scaled4k":high=true;scaled=true
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	root.size=Vector2i(1280,720)
	viewport=SubViewport.new();viewport.size=Vector2i(3840,2160) if high else Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0;editor.set_native_preview(true)
	viewport.msaa_3d=Viewport.MSAA_2X;RenderingServer.directional_shadow_atlas_set_size(4096,true)
	if scaled:viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR;viewport.scaling_3d_scale=.5
	editor.gameplay.set_wallpaper_mode(true);editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	editor.gameplay.time_system.set_progress(.29,editor);editor.camera.set_process(false);_frame(Vector2(-2,-1),32,16,30)
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	prepare_shaders(false);variant("before" if before else "combined")
	var warm:int=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<3000000:await process_frame
	var start:int=Time.get_ticks_usec();var last:int=start;var times:Array[float]=[]
	while Time.get_ticks_usec()-start<8000000:
		await process_frame;var now:int=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0;times.sort()
	var report:Dictionary={"before":before,"resolution":[viewport.size.x,viewport.size.y],"texture_size":[viewport.get_texture().get_width(),viewport.get_texture().get_height()],"scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d,"frames":times.size(),"elapsed_seconds":elapsed,"fps":times.size()/elapsed,"p50_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"water_seconds":editor.water_view.simulated_seconds,"adapter":RenderingServer.get_video_adapter_name(),"method":"same current14-triangle grass+2xMSAA+4096shadow;real normal render loop and production editor/water/time;3s warm+8s sample;limiter/vsync off;fixed SubViewport pixels;no screenshot IO;before=angular sky/full AO/low DOF;after=direct sky/half AO/verylow DOF"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));editor.free();viewport.queue_free();quit()
