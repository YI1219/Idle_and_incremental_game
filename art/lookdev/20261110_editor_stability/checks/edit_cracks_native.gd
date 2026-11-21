extends "res://tools/art/capture_lookdev.gd"
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")

func lower(center: Vector2, radius: float) -> void:
	var cell := Vector2i(center.floor())
	var height: float = Data._record_top(editor.data.cells[cell])
	editor.data.begin_stroke()
	editor.data.apply_brush(center,radius,"lower",false,height,7,height)
	editor.data.end_stroke()
	editor.renderer.flush_dirty(1<<20)
	_freeze_node(editor)

func run() -> void:
	output="res://art/lookdev/20261110_editor_stability/checks/crack_native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var sources: Dictionary = _source_hashes()
	viewport=SubViewport.new()
	viewport.size=SIZE
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.process_mode=Node.PROCESS_MODE_DISABLED
	editor.renderer.threaded_builds=false
	var key:=InputEventKey.new()
	key.keycode=KEY_F11
	key.pressed=true
	editor.gameplay.handle_unhandled_input(key)
	editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,editor.gameplay.wallpaper_mode)
	editor.water_view.reset(editor.data)
	editor.water_view.tick(.1)
	editor.water_view.flush()
	_freeze_node(editor)
	_frame(Vector2(-8,-5),8.0,16,55)
	await _capture("00_upper_baseline",.29)
	for i: int in 3:
		lower(Vector2(-8,-5),3.8)
		editor.renderer._process(1.0)
	lower(Vector2(-8,-5),3.8)
	editor.renderer._process(.275)
	await _capture("01_upper_half_morph",.29)
	editor.renderer._process(1.0)
	await _capture("02_upper_final",.29)
	_frame(Vector2(-8,-5),8.0,196,55)
	await _capture("03_upper_final_reverse",.29)
	for i: int in 4:
		lower(Vector2(-8,-5),3.8)
		editor.renderer._process(1.0)
	_frame(Vector2(-8,-5),8.0,16,55)
	await _capture("04_upper_deep_final",.29)
	editor.data.make_preset(0)
	editor.renderer.rebuild_all()
	for i: int in 4:
		lower(Vector2(13,0),3.8)
		editor.renderer._process(1.0)
	_frame(Vector2(12,0),7.0,16,55)
	await _capture("05_lower_final",.29)
	_frame(Vector2(12,0),7.0,196,55)
	await _capture("06_lower_final_reverse",.29)
	FileAccess.open(output.path_join("diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"source_sha256":sources,"sources_unchanged":sources==_source_hashes(),"errors":errors,"phase":PHASE,"size":str(SIZE),"morph_final":editor.renderer.morph_progress},"\t"))
	editor.free()
	quit()
