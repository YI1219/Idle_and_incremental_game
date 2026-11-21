extends SceneTree
## Real event/render loop and process CPU seconds. Run variants serially.
var scene: Node3D
var output: String="/tmp/runtime_load.json"
var before: bool=false
var hidden: bool=false
func _initialize() -> void:call_deferred("run")
func cpu_seconds() -> float:
	var lines: Array=[]
	OS.execute("/bin/ps",PackedStringArray(["-p",str(OS.get_process_id()),"-o","time="]),lines)
	var parts: PackedStringArray=String(lines[0]).strip_edges().split(":")
	var seconds: float=0.0
	for part: String in parts: seconds=seconds*60.0+float(part)
	return seconds
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg=="--before":before=true
		if arg=="--hidden":hidden=true
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	root.size=Vector2i(1280,720)
	scene=load("res://art/lookdev/20261111_performance/checks/editor_before.gd").new() if before else load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(scene);scene.set_native_preview(true)
	scene.camera.set_process(false);scene.camera._center=Vector2(-2,-1);scene.camera._height=32;scene.camera._yaw=16;scene.camera._pitch=30;scene.camera.advance(0)
	scene.gameplay.set_wallpaper_mode(true)
	if hidden:root.mode=Window.MODE_MINIMIZED
	var warm: int=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<3000000:await process_frame
	var start: int=Time.get_ticks_usec();var cpu: float=cpu_seconds();var frames: int=0
	while Time.get_ticks_usec()-start<8000000:
		await process_frame;frames+=1
	var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0
	var cpu_used: float=cpu_seconds()-cpu
	var report: Dictionary={"variant":"before" if before else "after","hidden":hidden,"frame_limit":Engine.max_fps,"frames":frames,"elapsed_seconds":elapsed,"fps":frames/elapsed,"process_cpu_seconds":cpu_used,"process_cpu_percent_one_core":cpu_used/elapsed*100.0,"resolution":[root.size.x,root.size.y],"internal_scale":root.scaling_3d_scale,"method":"normal runtime loop; --disable-vsync; native 1280x720; live time and water;3s warmup+8s sample; process CPU via ps time delta (not power/thermal measurement)"}
	if hidden:
		root.mode=Window.MODE_WINDOWED
		for i: int in 3:await process_frame
		report["resumed_scene"]=scene.can_process()
		report["resumed_cap"]=Engine.max_fps
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));scene.free();quit()
