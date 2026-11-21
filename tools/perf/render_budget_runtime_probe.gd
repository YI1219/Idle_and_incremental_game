extends SceneTree
## Normal uncapped render/event loop. Variants must be run serially.
var before: bool=false
var high: bool=false
var scaled: bool=false
var output: String="/tmp/render_budget_runtime.json"
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg=="--before":before=true
		if arg=="--4k":high=true
		if arg=="--scaled4k":high=true;scaled=true
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	root.size=Vector2i(1280,720)
	var view:=SubViewport.new()
	view.size=Vector2i(3840,2160) if high else Vector2i(2560,1440)
	view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var scene:Node3D=load("res://scenes/terrain_editor.tscn").instantiate();view.add_child(scene)
	scene.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
	scene.set_native_preview(true)
	scene.gameplay.set_wallpaper_mode(true);scene.gameplay.shihai_hud.tick_ui(4.0,scene.gameplay.state,scene.gameplay.time_system,scene.gameplay.fishing,scene.data.cells.size(),scene.gameplay.stance,true)
	scene.gameplay.time_system.set_progress(.29,scene)
	scene.camera.set_process(false);scene.camera._center=Vector2(-2,-1);scene.camera._height=32;scene.camera._yaw=16;scene.camera._pitch=30;scene.camera.advance(0)
	var mesh:ArrayMesh=load("res://art/lookdev/20261112_fps/checks/grass_field_before.gd").clump_mesh() if before else load("res://scripts/terrain_editor/grass_field.gd").clump_mesh()
	for node:Node in scene.find_children("grass_blades","MultiMeshInstance3D",true,false):node.multimesh.mesh=mesh
	view.msaa_3d=Viewport.MSAA_4X if before and not scaled else Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(8192 if before else 4096,true)
	if scaled:
		view.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR;view.scaling_3d_scale=.5
	var warm:int=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<3000000:await process_frame
	var started:int=Time.get_ticks_usec();var frames:int=0;var frame_ms:Array[float]=[];var last:int=started
	while Time.get_ticks_usec()-started<8000000:
		await process_frame
		var now:int=Time.get_ticks_usec();frame_ms.append((now-last)/1000.0);last=now;frames+=1
	var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0
	frame_ms.sort()
	var report:Dictionary={"before":before,"resolution":[view.size.x,view.size.y],"texture_size":[view.get_texture().get_width(),view.get_texture().get_height()],"scale":view.scaling_3d_scale,"msaa":view.msaa_3d,"frames":frames,"elapsed_seconds":elapsed,"fps":frames/elapsed,"frame_ms_p50":frame_ms[frame_ms.size()/2],"frame_ms_p95":frame_ms[int(frame_ms.size()*.95)],"water_seconds":scene.water_view.simulated_seconds,"adapter":RenderingServer.get_video_adapter_name(),"method":"UPDATE_ALWAYS SubViewport bypasses OS window clamping;production editor process with live light+water;fixed camera;3s warmup+8s sample;real normal render loop;--disable-vsync;native pixels or fixed .5 FSR;limiter disabled in both variants;serial processes;no capture I/O"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));scene.free();view.free();quit()
