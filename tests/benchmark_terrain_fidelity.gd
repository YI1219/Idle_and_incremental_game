extends SceneTree
const OUT:="res://art/review/terrain_fidelity/2026-10-05/"
var _sampling:=false
var _frames:Array=[]
var _last_frame:=0
var _window_samples:Array=[]
var _cpu_frames:Array=[]
var _gpu_frames:Array=[]
var _setup_frames:Array=[]
var _focused_frames:=0
var _lookdev:=false
var _tag:="baseline"
var _offscreen:=false
var _render_viewport:Viewport
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="lookdev":_lookdev=true
		elif arg=="offscreen":_offscreen=true
		else:_tag=arg
	process_frame.connect(_record_frame)
	root.size_changed.connect(_record_window_size)
	call_deferred("run")
func _record_window_size()->void:
	if not _sampling:return
	var window:=DisplayServer.window_get_size()
	var viewport:Vector2i=_render_viewport.size if _render_viewport is SubViewport else root.size
	var texture:=_render_viewport.get_texture().get_size()
	_window_samples.append({"window_size":[window.x,window.y],"viewport_size":[viewport.x,viewport.y],"render_texture_size":[texture.x,texture.y]})
func _record_frame()->void:
	if not _sampling:return
	var now:=Time.get_ticks_usec()
	_frames.append((now-_last_frame)/1000.0)
	if _lookdev:
		_cpu_frames.append(RenderingServer.viewport_get_measured_render_time_cpu(_render_viewport.get_viewport_rid()))
		_gpu_frames.append(RenderingServer.viewport_get_measured_render_time_gpu(_render_viewport.get_viewport_rid()))
		_setup_frames.append(RenderingServer.get_frame_setup_time_cpu())
		if DisplayServer.window_is_focused():_focused_frames+=1
	_last_frame=now
func percentile(values:Array,amount:float)->float:
	var sorted:=values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*amount))]
func run()->void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	_render_viewport=root
	if _offscreen:
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(1280,720)
		viewport.own_world_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d=root.msaa_3d
		viewport.screen_space_aa=root.screen_space_aa
		viewport.use_taa=root.use_taa
		root.add_child(viewport)
		_render_viewport=viewport
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if _lookdev:
		RenderingServer.viewport_set_measure_render_time(_render_viewport.get_viewport_rid(),true)
		# Identical compositor/focus conditions; no accidental live user strokes.
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	_render_viewport.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	if _lookdev:
		editor.camera.set_process(false)
		editor.set_process(false)
		editor.set_process_input(false)
		editor.set_process_unhandled_input(false)
		editor.camera.set_process_input(false)
		editor.camera.set_process_unhandled_input(false)
	var initial:Dictionary=editor.data.serialize()
	var reports:Array=[]
	for pass_index in 3:
		editor.data.deserialize(initial)
		editor.renderer.rebuild_all()
		var warm_start:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-warm_start<2000000:await process_frame
		_frames.clear()
		_cpu_frames.clear()
		_gpu_frames.clear()
		_setup_frames.clear()
		_focused_frames=0
		_window_samples.clear()
		_last_frame=Time.get_ticks_usec()
		_sampling=true
		_record_window_size()
		var edits:Array=[]
		var start:=Time.get_ticks_usec()
		var next_edit:=4.0
		var operation:=0
		var specs:=[["raise",Vector2(-13,2),2.3],["lower",Vector2(13,7),2.0],["expand",Vector2(18,4),2.6],["contract",Vector2(3,7),2.2]]
		while (Time.get_ticks_usec()-start)/1000000.0<12.0:
			if _lookdev:editor.renderer.flush_dirty(2)
			if _offscreen:RenderingServer.force_draw(false)
			await process_frame
			var now:=Time.get_ticks_usec()
			var elapsed:float=(now-start)/1000000.0
			if _lookdev:
				# Matched time-based inspection path, independent of frame count.
				var height:=21.0-2.0*sin(elapsed*.6)
				var yaw:=deg_to_rad(16.0+24.0*sin(elapsed*.8))
				var offset:=height/tan(deg_to_rad(27.0))
				editor.camera.position=Vector3(1.4*sin(elapsed*.7)+sin(yaw)*offset,height,-1+sin(elapsed*.5)+cos(yaw)*offset)
				editor.camera.rotation=Vector3(deg_to_rad(-27),yaw,0)
			if operation<4 and elapsed>=next_edit:
				var spec:Array=specs[operation]
				var edit_start:=Time.get_ticks_usec()
				editor.data.begin_stroke()
				var changed:int=editor.data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3)
				editor.data.end_stroke()
				while editor.renderer.has_pending_updates():
					if _lookdev:editor.renderer.flush_dirty(2)
					if _offscreen:RenderingServer.force_draw(false)
					await process_frame
				edits.append({"operation":spec[0],"changed_cells":changed,"visible_response_ms":(Time.get_ticks_usec()-edit_start)/1000.0})
				operation+=1
				next_edit+=1.5
		_record_window_size()
		_sampling=false
		var frames:=_frames.duplicate()
		var report:={"run":pass_index+1,"duration_seconds":(Time.get_ticks_usec()-start)/1000000.0,"frame_count":frames.size(),"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":frames.max(),"cells":editor.data.cells.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"edits":edits}
		report["actual_size_samples"]=_window_samples.duplicate(true)
		report["rendered_primitives_sample"]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		report["process_seconds_sample"]=Performance.get_monitor(Performance.TIME_PROCESS)
		report["offscreen"]=_offscreen
		report["msaa_3d"]=_render_viewport.msaa_3d
		if _lookdev:
			report["focused_frame_fraction"]=float(_focused_frames)/frames.size()
			for metric in [["render_cpu",_cpu_frames],["render_gpu",_gpu_frames],["render_setup_cpu",_setup_frames]]:
				report[metric[0]+"_median_ms"]=percentile(metric[1],.5)
				report[metric[0]+"_p95_ms"]=percentile(metric[1],.95)
			report["gpu_time"]="viewport measured GPU timer; zero values mean unavailable on this backend"
		else:report["gpu_time"]="unavailable; wall-clock frame intervals reported"
		if _offscreen:
			RenderingServer.force_draw(false)
			_render_viewport.get_texture().get_image().save_png("res://art/review/terrain_fidelity/2026-10-06/"+_tag+"_render.png")
			report["submission"]="minimized native window; actual Forward+ SubViewport rendered via force_draw(false), same 4x MSAA; intervals are not presentation FPS"
		reports.append(report)
		print("FIDELITY BENCH: ",JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute(OUT)
	var output:=OUT+"performance.json"
	if _lookdev:
		output="res://art/review/terrain_fidelity/2026-10-06/"+_tag+"_performance.json"
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"backend":"Metal Forward+","resolution":[1280,720],"shadows":true,"ssao":true,"vsync":"disabled","scope":"current reference demo, 12-second measurement per run; target laptops and long idle stability unmeasured this round","controlled_lookdev":_lookdev,"lookdev_conditions":"nonfocused window, input and live pointer picking disabled, manual normal two-chunk/frame publication; time-based inspection pan/zoom/yaw path; 2s warmup then 12s x 3 runs","runs":reports},"\t"))
	quit()
