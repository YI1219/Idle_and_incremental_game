extends "res://tools/art/capture_lookdev.gd"
var old_deco_script: GDScript
var current_deco: RefCounted
var old_deco: RefCounted
var pairs: Array[Dictionary] = []

func junction(label: String, at: Vector2, yaw: float, time_progress: float = .29) -> void:
	_frame(at, 10, yaw, 32)
	for variant: String in ["before", "after"]:
		editor.renderer.decoration = old_deco if variant == "before" else current_deco
		editor.renderer.rebuild_all()
		editor.water_view.flush()
		_freeze_node(editor)
		await _capture(label + "_" + variant, time_progress)
	pairs.append({"label":label,"seed":editor.data.seed,"data_sha256":JSON.stringify(editor.data.serialize(),"",true,true).sha256_text(),"volume":editor.water_view.published_volume})

func run() -> void:
	if not _read_options(): quit(1); return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)): quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var hashes: Dictionary = _source_hashes()
	old_deco_script = GDScript.new()
	old_deco_script.source_code = FileAccess.get_file_as_string("res://scripts/terrain_editor/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "").replace("res://scripts/terrain_editor/rim_union.gd", "res://art/lookdev/20261111_cliff_repair/checks/rim_baseline.gd").replace("field.close_unclad_dry_steps(_columns,assets)", 'preload("res://art/lookdev/20261111_cliff_repair/checks/legacy_seal.gd").apply(field,_columns,assets)')
	if old_deco_script.reload() != OK: quit(2); return
	viewport = SubViewport.new(); viewport.size = SIZE; viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for sample_seed: int in [7301,2104,4242]:
		editor = load("res://scenes/terrain_editor.tscn").instantiate(); viewport.add_child(editor)
		editor.process_mode = Node.PROCESS_MODE_DISABLED; editor.renderer.animate_edits = false
		editor.set_native_preview(true)
		editor.data.seed = sample_seed; editor.renderer.rebuild_all()
		current_deco = editor.renderer.decoration
		old_deco = old_deco_script.new(); old_deco.load_assets()
		editor.water_view.reset(editor.data); editor.water_view.tick(.1); editor.water_view.flush()
		var f11 := InputEventKey.new(); f11.keycode = KEY_F11; f11.pressed = true
		editor.gameplay.handle_unhandled_input(f11)
		editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
		_freeze_node(editor)
		await junction("seed%d_front" % sample_seed, Vector2(-3.1,7.96),16)
		await junction("seed%d_back" % sample_seed, Vector2(8.03,-6.17),196)
		if sample_seed == 7301:
			await junction("front_oblique",Vector2(-3.1,7.96),65)
			await junction("front_night",Vector2(-3.1,7.96),16,0.0)
			for i in 4:
				var height: float = editor.data.cells[Vector2i(13,0)].height
				editor.data.begin_stroke();editor.data.apply_brush(Vector2(13,0),3.8,"raise",false,height,7,height);editor.data.end_stroke()
			editor.water_view.reset(editor.data); editor.water_view.tick(.1); editor.water_view.flush()
			await junction("raised_join",Vector2(12.1,-3.0),196)
		editor.renderer.decoration = current_deco
		viewport.remove_child(editor); editor.free()
	var stable: bool = hashes == _source_hashes()
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"valid":errors.is_empty() and stable,"captures":captures,"pairs":pairs,"source_sha256":hashes,"source_stable":stable,"phase":PHASE,"errors":errors,"method":"Same live scene and authoritative data per pair. Mantle generator and dry-step seal switch to task-start snapshots through a baseline rim-union/decorator; all other geometry generators, materials and light are current. Native 2K,4xMSAA,frozen TIME. Water has advanced .1 seconds per fixture then is frozen."},"\t"))
	viewport.queue_free(); quit(0 if errors.is_empty() and stable else 1)
