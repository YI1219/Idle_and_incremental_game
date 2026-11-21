extends SceneTree
## Explicit-draw Forward+ GPU probe, same scene/camera, no capture I/O in samples.
var scene:Node3D
var viewport:SubViewport
var output:String="/tmp/resolution_probe.json"
var samples:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func stats(a:Array)->Dictionary:
	if a.is_empty():return {}
	var s:Array=a.duplicate();s.sort()
	return {"p50":s[s.size()/2],"p95":s[mini(s.size()-1,int(s.size()*.95))],"max":s[-1],"mean":a.reduce(func(total:float,value:float)->float:return total+value,0.0)/a.size()}
func sample(name:String,size:Vector2i,env:Environment,ssao:bool,ssil:bool,msaa:int,scale:float,hide:Array[String]=[])->void:
	viewport.size=size
	viewport.msaa_3d=msaa
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR if scale<1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale=scale
	env.ssao_enabled=ssao;env.ssil_enabled=ssil
	for key:String in ["grass_blades","water","waterfall","bank"]:
		for node:Node in scene.find_children("*","GeometryInstance3D",true,false):
			if String(node.name)==key:node.visible=not key in hide
	for i in 12:
		RenderingServer.force_draw(false);await process_frame
	var frame:Array[float]=[];var gpu:Array[float]=[];var cpu:Array[float]=[]
	for i in 50:
		var start:int=Time.get_ticks_usec()
		RenderingServer.force_draw(false);await process_frame
		frame.append((Time.get_ticks_usec()-start)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
	var row:Dictionary={"name":name,"resolution":[size.x,size.y],"scale":scale,"ssao":ssao,"ssil":ssil,"msaa":msaa,"hide":hide,"frame_ms":stats(frame),"gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
	samples.append(row);print(JSON.stringify(row))
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	scene=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(scene);scene.process_mode=Node.PROCESS_MODE_DISABLED
	scene.gameplay.time_system.set_progress(.29,scene)
	scene.water_view.tick(.1);scene.water_view.flush()
	var camera:Camera3D=scene.camera
	camera._center=Vector2(-2,-1);camera._height=32;camera._yaw=16;camera._pitch=30;camera.advance(0)
	scene.hud.hide()
	var env:Environment=scene.get_node("WorldEnvironment").environment
	for i in 80:RenderingServer.force_draw(false);await process_frame
	await sample("2K_full",Vector2i(2560,1440),env,true,true,2,1.0)
	await sample("4K_full",Vector2i(3840,2160),env,true,true,2,1.0)
	await sample("4K_balanced",Vector2i(3840,2160),env,true,true,1,2.0/3.0)
	await sample("4K_no_ssil",Vector2i(3840,2160),env,true,false,2,1.0)
	await sample("4K_no_ssao_ssil",Vector2i(3840,2160),env,false,false,2,1.0)
	await sample("4K_no_msaa",Vector2i(3840,2160),env,true,true,0,1.0)
	await sample("4K_scaled_2K",Vector2i(3840,2160),env,true,true,2,2.0/3.0)
	await sample("4K_no_grass",Vector2i(3840,2160),env,true,true,2,1.0,["grass_blades"])
	await sample("4K_no_water",Vector2i(3840,2160),env,true,true,2,1.0,["water","waterfall","bank"])
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"godot":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"method":"SubViewport explicit draw; --disable-render-loop --disable-vsync; static normal scene; GPU timings may be unsupported (zero) on device","samples":samples},"\t"))
	scene.free();viewport.queue_free();quit(0)
