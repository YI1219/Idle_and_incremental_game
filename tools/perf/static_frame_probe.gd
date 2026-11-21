extends SceneTree
## Static frame-cost probe at the game camera (run with --disable-vsync).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.hud.hide()
	editor.set_process(false)
	if "--no-grass" in OS.get_cmdline_user_args():
		editor.renderer.grass_blades_enabled = false
		editor.renderer.rebuild_all()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 300:
		await process_frame
	var t0 := Time.get_ticks_usec()
	var gpu := 0.0
	for i in 300:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	print("STATIC frame %.2f ms (%.0f fps) gpu %.2f ms, draw calls %d, primitives %d" % [ms, 1000.0 / ms, gpu / 300.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	quit(0)
