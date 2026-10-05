extends SceneTree
const OUT:="res://art/review/terrain_editor/2026-10-05/"
var editor:Node3D
var duration:=60.0
var label:="benchmark"
var stability:=false
var start_usec:=0
var previous_usec:=0
var warm_until:=0
var frames:=PackedFloat64Array()
var latencies:=PackedFloat64Array()
var edit_started:=0
var next_edit:=2.0
var edit_count:=0
var initial_memory:=0.0
var peak_memory:=0.0
var initial_nodes:=0.0
var peak_nodes:=0.0
var initial_layout:Dictionary
var checkpoint:=0.0
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:duration=float(args[0])
	if args.size()>1:label=args[1]
	stability=args.size()>2 and args[2]=="stability"
	call_deferred("setup")
func setup()->void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if stability else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=60 if stability else 0
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.cancel_input()
	editor.data.cells.clear()
	for z in range(-32,32):
		for x in range(-32,32):
			var upper:=x < -8
			var height:=3.5 if upper else 1.5
			var water:=-1
			if (x+18)*(x+18)+(z+6)*(z+6)<49 and upper:
				height=3.0
				water=7
			elif (x-7)*(x-7)+(z-6)*(z-6)<64 and not upper:
				height=1.0
				water=3
			editor.data.cells[Vector2i(x,z)]={"height":height,"water":water}
	editor.renderer.rebuild_all()
	editor.camera.set_process(false)
	editor.camera.set_process_unhandled_input(false)
	editor.set_process_unhandled_input(false)
	editor.camera.wheel(7)
	editor.camera.recenter(Vector2(-5,5))
	editor.camera.advance(10.0)
	initial_layout=editor.data.serialize()
	warm_until=Time.get_ticks_usec()+5000000
	print("READY ",label," cells=",editor.data.cells.size()," pid=",OS.get_process_id()," duration=",duration)
func _process(delta:float)->bool:
	if editor==null or warm_until==0:return false
	var now:=Time.get_ticks_usec()
	if now<warm_until:
		previous_usec=now
		return false
	if start_usec==0:
		start_usec=now
		previous_usec=now
		initial_memory=Performance.get_monitor(Performance.MEMORY_STATIC)
		initial_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		return false
	var elapsed:float=(now-start_usec)/1000000.0
	frames.append((now-previous_usec)/1000.0)
	previous_usec=now
	peak_memory=maxf(peak_memory,Performance.get_monitor(Performance.MEMORY_STATIC))
	peak_nodes=maxf(peak_nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if edit_started>0 and editor.data.dirty_chunks.is_empty():
		latencies.append((now-edit_started)/1000.0)
		edit_started=0
	if elapsed>=next_edit and edit_started==0:
		var operation:="raise" if edit_count%4 in [0,2] else "lower"
		if edit_count%4==3:operation="water"
		editor.data.begin_stroke()
		editor.data.apply_brush(Vector2(20.5,20.5),2.2,operation,false,1.5,7)
		editor.data.end_stroke()
		if edit_count%4 in [2,3]:editor.data.undo()
		edit_count+=1
		edit_started=Time.get_ticks_usec()
		next_edit=elapsed+5.0
	if stability:
		editor.camera.pan(Vector2(sin(elapsed*0.2),cos(elapsed*0.3)),delta*0.02)
		editor.camera.advance(delta)
	if elapsed>=checkpoint:
		print("CHECKPOINT ",label," seconds=",snappedf(elapsed,0.1)," memory_mib=",snappedf(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,0.1)," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		checkpoint=elapsed+60.0
	if elapsed>=duration:finish(elapsed)
	return false
func percentile(values:PackedFloat64Array,fraction:float)->float:
	if values.is_empty():return 0.0
	var sorted:=values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,floori((sorted.size()-1)*fraction))]
func finish(elapsed:float)->void:
	var median:=percentile(frames,0.5)
	var p95:=percentile(frames,0.95)
	var same_layout:bool=editor.data.serialize()==initial_layout
	var result:Dictionary={
		"label":label,"mode":"stability" if stability else "benchmark","duration_seconds":elapsed,"resolution":"1280x720","cells":editor.data.cells.size(),"quality":"low (shadows off, chunked meshes, instanced original CC0 nature)",
		"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"os":OS.get_name(),"processor":OS.get_processor_name(),"engine":Engine.get_version_info().string,
		"frames":frames.size(),"median_ms":median,"p95_ms":p95,"max_ms":percentile(frames,1),"frame_times_ms":Array(frames),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"initial_static_memory_mib":initial_memory/1048576.0,"end_static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"peak_static_memory_mib":peak_memory/1048576.0,"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
		"initial_nodes":initial_nodes,"end_nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"peak_nodes":peak_nodes,"edit_events":edit_count,"edit_response_ms":Array(latencies),"edit_p95_ms":percentile(latencies,0.95),"dirty_chunks_at_end":editor.data.dirty_chunks.size(),"layout_restored":same_layout,
		"performance_threshold_passed":median<=16.7 and p95<=25.0,"stability_state_passed":same_layout and editor.data.dirty_chunks.is_empty() and Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=initial_nodes+12
	}
	DirAccess.make_dir_recursive_absolute(OUT)
	var file:=FileAccess.open(OUT+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("RESULT ",label," median_ms=",median," p95_ms=",p95," edit_p95_ms=",percentile(latencies,0.95)," nodes=",result.end_nodes," restored=",same_layout)
	quit()
