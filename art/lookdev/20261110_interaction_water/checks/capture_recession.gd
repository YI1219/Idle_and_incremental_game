extends "res://tools/art/capture_lookdev.gd"
## Two diagnostic views of the production pool after 60 simulated seconds.
func run() -> void:
	if not _read_options():
		quit(1)
		return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):
		push_error("Select a new recession diagnostic directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var sources: Dictionary = _source_hashes()
	for path: String in ["res://scripts/terrain_editor/lake_bed.gd", "res://scripts/terrain_editor/local_lake_bed.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F11
	key.pressed = true
	f11_handled = editor.gameplay.handle_unhandled_input(key)
	editor.gameplay.shihai_hud.tick_ui(4.0, editor.gameplay.state, editor.gameplay.time_system, editor.gameplay.fishing, editor.data.cells.size(), editor.gameplay.stance, editor.gameplay.wallpaper_mode)
	_freeze_node(editor)
	var before_beds: Dictionary = editor.data.cells.duplicate(true)
	for tick: int in range(600):
		editor.water_view.tick(0.1)
		editor.water_view.flush()
		if tick % 20 == 0:
			await process_frame
	_frame(Vector2(3.0, 0.8), 7.0, 67.0, 36.0)
	editor.camera.position.y += 2.5
	await _capture("water_060s_outlet", 0.29)
	_frame(Vector2(3.0, 0.8), 7.0, 20.0, 36.0)
	editor.camera.position.y += 2.5
	await _capture("water_060s_shoulder", 0.29)
	var beds_fixed: bool = true
	for cell: Vector2i in before_beds:
		beds_fixed = beds_fixed and editor.data.cells[cell].height == before_beds[cell].height
	var report: Dictionary = {"captures": captures, "errors": errors, "bed_heights_fixed": beds_fixed, "source_sha256": sources, "volume": editor.water_view.published_volume, "discharged": editor.water_view.published_discharged_volume, "seconds": editor.water_view.simulated_seconds}
	FileAccess.open(output.path_join("recession_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	viewport.remove_child(editor)
	editor.free()
	viewport.queue_free()
	quit(0 if errors.is_empty() and beds_fixed else 1)
