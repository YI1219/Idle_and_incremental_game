extends SceneTree
const OUT:="res://art/review/terrain_fidelity/2026-10-05/"
var _sampling:=false
var _frames:Array=[]
var _last_frame:=0
func _initialize()->void:
	process_frame.connect(_record_frame)
	call_deferred("run")
func _record_frame()->void:
	if not _sampling:return
	var now:=Time.get_ticks_usec()
	_frames.append((now-_last_frame)/1000.0)
	_last_frame=now
func percentile(values:Array,amount:float)->float:
	var sorted:=values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*amount))]
func run()->void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	var initial:Dictionary=editor.data.serialize()
	var reports:Array=[]
	for pass_index in 3:
		editor.data.deserialize(initial)
		editor.renderer.rebuild_all()
		var warm_start:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-warm_start<2000000:await process_frame
		_frames.clear()
		_last_frame=Time.get_ticks_usec()
		_sampling=true
		var edits:Array=[]
		var start:=Time.get_ticks_usec()
		var next_edit:=4.0
		var operation:=0
		var specs:=[["raise",Vector2(-13,2),2.3],["lower",Vector2(13,7),2.0],["expand",Vector2(18,4),2.6],["contract",Vector2(3,7),2.2]]
		while (Time.get_ticks_usec()-start)/1000000.0<12.0:
			await process_frame
			var now:=Time.get_ticks_usec()
			var elapsed:float=(now-start)/1000000.0
			if operation<4 and elapsed>=next_edit:
				var spec:Array=specs[operation]
				var edit_start:=Time.get_ticks_usec()
				editor.data.begin_stroke()
				var changed:int=editor.data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3)
				editor.data.end_stroke()
				while editor.renderer.has_pending_updates():
					await process_frame
				edits.append({"operation":spec[0],"changed_cells":changed,"visible_response_ms":(Time.get_ticks_usec()-edit_start)/1000.0})
				operation+=1
				next_edit+=1.5
		_sampling=false
		var frames:=_frames.duplicate()
		var report:={"run":pass_index+1,"duration_seconds":(Time.get_ticks_usec()-start)/1000000.0,"frame_count":frames.size(),"median_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),"max_ms":frames.max(),"cells":editor.data.cells.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"edits":edits}
		reports.append(report)
		print("FIDELITY BENCH: ",JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute(OUT)
	var file:=FileAccess.open(OUT+"performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"backend":"Metal Forward+","resolution":[1280,720],"shadows":true,"ssao":true,"vsync":"disabled","scope":"current reference demo, 12-second measurement per run; target laptops and long idle stability unmeasured this round","runs":reports},"\t"))
	quit()
