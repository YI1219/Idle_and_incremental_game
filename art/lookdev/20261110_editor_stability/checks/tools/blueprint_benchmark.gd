extends SceneTree
## Native editor input-path benchmark. No screenshot I/O during timing.
var editor: Node3D
var out_path: String = "/tmp/blueprint_bench.json"
var frames: Array[float] = []
var published_at: int = 0
func _initialize() -> void: call_deferred("run")
static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var s: Array = values.duplicate()
	s.sort()
	return {"n":s.size(),"p50":s[s.size()/2],"p95":s[mini(s.size()-1,int(s.size()*.95))],"max":s[-1]}
func tick() -> void:
	editor.renderer.flush_dirty(6)
	editor.preview.refresh(editor.blueprint_data if editor.blueprint_data != null else editor.data, editor.renderer, editor.blueprint_data != null)
	if not editor.renderer.has_pending_updates(): editor.water_view.tick(1.0/60.0)
	var before: int = Time.get_ticks_usec()
	await process_frame
	frames.append((Time.get_ticks_usec()-before)/1000.0)
func on_published() -> void: published_at = Time.get_ticks_usec()
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_path = arg.trim_prefix("--out=")
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.terrain_published.connect(on_published)
	for i in 180: await process_frame
	var report: Dictionary = {"godot":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"rendering_method":RenderingServer.get_current_rendering_method(),"method":"production begin/continue + global release input; water active; no capture I/O", "cases":[]}
	for spec: Dictionary in [{"name":"short_raise","tool":"raise","hold":.05,"drag":false},{"name":"held_raise","tool":"raise","hold":1.2,"drag":false},{"name":"drag_raise","tool":"raise","hold":1.2,"drag":true},{"name":"short_contract","tool":"contract","hold":.05,"drag":false},{"name":"held_contract","tool":"contract","hold":1.2,"drag":false},{"name":"drag_contract","tool":"contract","hold":1.2,"drag":true},{"name":"wide_short_contract","tool":"contract","hold":.05,"drag":false,"radius":3.8},{"name":"wide_drag_raise","tool":"raise","hold":1.2,"drag":true,"radius":3.8}]:
		editor.select_preset(0)
		editor.camera._center=Vector2(-2,-1)
		editor.camera._height=32
		editor.camera._yaw=16
		editor.camera._pitch=30
		editor.camera._process(0.0)
		editor.tool=spec.tool
		editor.radius=float(spec.get("radius",1.6))
		for i in 30: await process_frame
		frames.clear()
		var point: Vector3 = Vector3(-11.5,1.5,-8.5)
		var screen: Vector2 = editor.camera.unproject_position(point)
		var started: bool = editor.begin_paint(screen)
		var held_start: int = Time.get_ticks_usec()
		var continue_ms: Array[float]=[]
		while float(Time.get_ticks_usec()-held_start)/1000000.0 < float(spec.hold):
			var t: float = minf(1,float(Time.get_ticks_usec()-held_start)/1000000.0/float(spec.hold))
			if spec.drag:
				screen=editor.camera.unproject_position(point+Vector3(5*t,0,1.5*t))
				var cstart: int=Time.get_ticks_usec()
				editor.continue_paint(screen)
				continue_ms.append((Time.get_ticks_usec()-cstart)/1000.0)
			await tick()
		var prepared: bool = editor.renderer._prepared_blueprint_stamp == editor.renderer._blueprint_stamp(editor.blueprint_data)
		var held_frames: Dictionary=stats(frames)
		frames.clear()
		published_at=0
		var released: int=Time.get_ticks_usec()
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=false
		editor._input(event)
		var commit_ms: float=(Time.get_ticks_usec()-released)/1000.0
		while (editor.renderer.has_pending_updates() or editor.renderer.morph_progress<1) and Time.get_ticks_usec()-released<12000000:
			await tick()
		var row: Dictionary={"name":spec.name,"started":started,"prepared_on_release":prepared,"commit_ms":commit_ms,"release_to_start_ms":(published_at-released)/1000.0 if published_at>0 else -1,"release_to_complete_ms":(Time.get_ticks_usec()-released)/1000.0,"held_frames_ms":held_frames,"release_frames_ms":stats(frames),"continue_ms":stats(continue_ms),"worker_ms":editor.renderer.last_worker_ms,"worker_stages":editor.renderer.last_worker_stages}
		report.cases.append(row)
		print(JSON.stringify(row))
	FileAccess.open(out_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	editor.free()
	quit(0)
