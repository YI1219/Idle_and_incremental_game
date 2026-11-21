extends "res://tools/art/capture_lookdev.gd"
## Native 2K lookdev capture of interactive add/delete/raise/lower strokes
## verifying near-end cliff visual continuity and worker-thread partial rebuilds.

func _find_expand_target(data: RefCounted) -> Vector2:
	# Pick a southern/south-western outer rim edge that produces a distinct peninsula lobe.
	var best := Vector2(-14.5, 3.5)
	var best_score := -INF
	for cell: Vector2i in data.cells:
		var rec: Dictionary = data.cells[cell]
		if int(rec.get("water", -1)) >= 0 or float(rec.height) > 2.2:
			continue
		var has_empty := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not data.cells.has(cell + d):
				has_empty = true
				break
		if not has_empty:
			continue
		var p := Vector2(cell) + Vector2(0.5, 0.5)
		var score := -absf(p.x - (-11.5)) * 0.5 + p.y * 1.1
		if score > best_score:
			best_score = score
			best = p + Vector2(0.0, 1.35)
	return best

func _wait_settled() -> void:
	var started := Time.get_ticks_msec()
	while (editor.renderer.has_pending_updates() or editor.renderer._worker_task != -1) and Time.get_ticks_msec() - started < 12000:
		editor.renderer.flush_dirty(6)
		editor.renderer._process(0.05)
		await process_frame
	editor.renderer.morph_progress = 1.0
	RenderingServer.global_shader_parameter_set("terrain_morph_progress", 1.0)
	editor.water_view.reset(editor.data)
	editor.water_view.tick(0.1)
	editor.water_view.flush()
	_freeze_node(editor)

func _shot(label: String, center: Vector2, height: float, yaw: float, pitch: float) -> void:
	_frame(center, height, yaw, pitch)
	await _capture(label, progress)

func run() -> void:
	if not _read_options():
		quit(1)
		return
	if FileAccess.file_exists(output.path_join("captures.json")):
		push_error("Refusing to overwrite existing edit evidence")
		quit(1)
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Native capture requires graphical Forward+")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var initial_sources: Dictionary = _source_hashes()
	for child: Node in root.get_children():
		if child.scene_file_path == "res://scenes/terrain_editor.tscn":
			if current_scene == child:
				current_scene = null
			root.remove_child(child)
			child.free()
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor = (load("res://scenes/terrain_editor.tscn") as PackedScene).instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	editor.set_native_preview(true)
	Engine.max_fps = 0
	editor.renderer.animate_edits = false
	editor.renderer.threaded_builds = true
	if preset != 0 or seed_value != int(editor.data.seed):
		editor.data.make_preset(preset)
		editor.data.seed = seed_value
		editor.renderer.rebuild_all()
		editor.motes.rebuild_from_data(editor.data)
		editor.gameplay.on_preset_changed()
	editor.water_view.reset(editor.data)
	editor.water_view.tick(0.1)
	editor.water_view.flush()
	var f11 := InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	f11_handled = editor.gameplay.handle_unhandled_input(f11)
	editor.gameplay.shihai_hud.tick_ui(4.0, editor.gameplay.state, editor.gameplay.time_system,
		editor.gameplay.fishing, editor.data.cells.size(), editor.gameplay.stance, editor.gameplay.wallpaper_mode)
	_freeze_node(editor)

	# 1. Expand lobe on outer rim (narrow added peninsula + near-end transition)
	var exp_at := _find_expand_target(editor.data)
	editor.data.begin_stroke()
	editor.data.apply_brush(exp_at, 2.2, "expand", false, 1.5, 7)
	editor.data.end_stroke()
	await _wait_settled()
	await _shot("edit_expand", exp_at + Vector2(0.0, 0.5), 11.5, 16.0, 20.0)
	editor.data.undo()
	await _wait_settled()

	# 2. Contract bite on northwest outer cliff (neighbor continuity after deletion)
	var con_at := Vector2(-12.0, -9.0)
	editor.data.begin_stroke()
	editor.data.apply_brush(con_at, 2.0, "contract", false, 1.5, 3)
	editor.data.end_stroke()
	await _wait_settled()
	await _shot("edit_contract", con_at + Vector2(-0.5, -0.5), 11.5, 196.0, 24.0)
	editor.data.undo()
	await _wait_settled()

	# 3. Lower interior terrace step cut (exposed interior step wall + adjacent cliff)
	var low_at := Vector2(-8.0, -5.0)
	editor.data.begin_stroke()
	for _i in 3:
		editor.data.apply_brush(low_at, 3.2, "lower", false, 1.5, 7)
	editor.data.end_stroke()
	await _wait_settled()
	await _shot("edit_lower", low_at + Vector2(0.5, 0.5), 11.5, 22.0, 28.0)
	editor.data.undo()
	await _wait_settled()

	# 4. Raise interior terrace step block (new stepped rock wall & neighbors)
	var raise_at := Vector2(-6.5, 4.5)
	editor.data.begin_stroke()
	for _i in 3:
		editor.data.apply_brush(raise_at, 2.5, "raise", false, 1.5, 7)
	editor.data.end_stroke()
	await _wait_settled()
	await _shot("edit_raise", raise_at + Vector2(0.0, 0.5), 11.5, 20.0, 24.0)
	editor.data.undo()
	await _wait_settled()

	var report := {
		"scene": "res://scenes/terrain_editor.tscn",
		"resolution": [SIZE.x, SIZE.y],
		"preset": preset,
		"seed": seed_value,
		"expand_at": [exp_at.x, exp_at.y],
		"captures": captures,
		"errors": errors,
		"valid": errors.is_empty() and initial_sources == _source_hashes(),
	}
	var f := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t", true, true))
	viewport.remove_child(editor)
	editor.free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
