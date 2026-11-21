extends "res://tools/art/capture_lookdev.gd"

func run() -> void:
	if not _read_options(): quit(1); return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)): quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var hashes: Dictionary = _source_hashes()
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for fixture: String in ["lower", "raise", "edge"]:
		editor = load("res://scenes/terrain_editor.tscn").instantiate()
		viewport.add_child(editor)
		editor.process_mode = Node.PROCESS_MODE_DISABLED
		editor.renderer.animate_edits = false
		editor.set_native_preview(true)
		var center := Vector2(-8,-5) if fixture == "lower" else Vector2(13,0)
		var operation: String = "lower" if fixture == "lower" else "raise"
		if fixture == "edge": center = Vector2(-13,-1); operation = "lower"
		for i in 4:
			var height: float = editor.data.cells[Vector2i(center.floor())].height
			editor.data.begin_stroke()
			editor.data.apply_brush(center, 3.8, operation, false, height, 7, height)
			editor.data.end_stroke()
			editor.renderer.rebuild_all()
		editor.water_view.reset(editor.data)
		editor.water_view.tick(.1); editor.water_view.flush()
		var f11 := InputEventKey.new(); f11.keycode = KEY_F11; f11.pressed = true
		editor.gameplay.handle_unhandled_input(f11)
		editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
		_freeze_node(editor)
		for yaw: float in [16.0,106.0,196.0,286.0]:
			_frame(center,8,yaw,55)
			editor.camera.position.y += 2.5
			await _capture("%s_%d" % [fixture,roundi(yaw)],progress)
		viewport.remove_child(editor); editor.free()
	var stable: bool = hashes == _source_hashes()
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"valid":errors.is_empty() and stable,"captures":captures,"source_sha256":hashes,"source_stable":stable,"phase":PHASE,"errors":errors},"\t"))
	viewport.queue_free(); quit(0 if errors.is_empty() and stable else 1)
