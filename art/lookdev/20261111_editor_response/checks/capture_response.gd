extends "res://tools/art/capture_lookdev.gd"
var records: Array[Dictionary] = []
var snapshots: Dictionary = {}
var fixed_volume: float = 0.0
var frames_path: String = "/tmp/scroll_grass_response_frames_20261111"
func draw_photo(label: String) -> void:
	for i in 3:
		RenderingServer.force_draw(false)
		await process_frame
	var picture: Image = viewport.get_texture().get_image()
	picture.save_png(output.path_join(label+".png"))
	records.append({"file":label+".png","size":[picture.get_width(),picture.get_height()],"position":_vector(editor.camera.position),"rotation":_vector(editor.camera.rotation_degrees),"data_sha256":JSON.stringify(editor.data.serialize(),"",true,true).sha256_text(),"volume":editor.water_view.published_volume,"coverage":editor.water_view.grass_recovery.coverage.duplicate(),"scale":viewport.scaling_3d_scale})
func movie_frame(label: String, index: int) -> void:
	RenderingServer.force_draw(false)
	await process_frame
	viewport.get_texture().get_image().save_png(frames_path.path_join(label+"_%03d.png"%index))
func run() -> void:
	if not _read_options(): quit(1); return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute(frames_path)
	var before: Dictionary = _source_hashes()
	var extra_sources: Dictionary = {}
	for path: String in ["res://scripts/terrain_editor/grass_recovery.gd","res://scripts/terrain_editor/preview_quality.gd"]:
		extra_sources[path] = FileAccess.get_sha256(path)
	viewport=SubViewport.new()
	viewport.size=SIZE
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.process_mode=Node.PROCESS_MODE_DISABLED
	editor.renderer.animate_edits=false
	editor.gameplay.time_system.set_progress(.29,editor)
	var f11:=InputEventKey.new()
	f11.keycode=KEY_F11
	f11.pressed=true
	editor.gameplay.handle_unhandled_input(f11)
	editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	editor.water_view.tick(.1)
	editor.water_view.flush()
	_freeze_node(editor)
	_frame(Vector2(-2,-1),32,16,30)
	await draw_photo("whole_current")
	viewport.size=Vector2i(3840,2160)
	editor.set_native_preview(true)
	await draw_photo("4K_native")
	editor.set_native_preview(false)
	for i in 150:editor.preview_quality.advance(.025)
	await draw_photo("4K_adaptive")
	viewport.size=SIZE
	editor.set_native_preview(true)
	# Real lower-brush authoring + finite water solver, then freeze physical
	# water while advancing only the production visual grass clock.
	for height: float in [3.5,3.0]:
		editor.data.begin_stroke()
		editor.data.apply_brush(Vector2(-7.5,-3.5),2.2,"lower",false,height,7,height)
		editor.data.end_stroke()
		editor.renderer.rebuild_all()
		editor.water_view.flush()
	for i in 30:
		editor.water_view.tick(.1)
		editor.water_view.flush()
	_frame(Vector2(-7.5,-3.5),7,16,65)
	editor.camera.position.y+=2.5
	fixed_volume=editor.water_view.published_volume
	await draw_photo("flood_00")
	var phase: float = 0.0
	viewport.size=Vector2i(1280,720)
	for i in 19:
		if i>0:
			editor.water_view._process(.05)
			phase+=.05
		await movie_frame("flood",i)
		if i in [4,8,14,18]:
			viewport.size=SIZE
			await draw_photo("flood_%02d"%i)
			viewport.size=Vector2i(1280,720)
	if absf(editor.water_view.published_volume-fixed_volume)>.00001:errors.append("Visual grass changed water")
	editor.data.begin_stroke()
	editor.data.apply_brush(Vector2(-3,0),16.0,"dry",false,3.5,7)
	editor.data.end_stroke()
	editor.renderer.rebuild_all()
	editor.water_view.flush()
	viewport.size=SIZE
	await draw_photo("regrow_00")
	viewport.size=Vector2i(1280,720)
	for i in 121:
		if i>0:editor.water_view._process(.05)
		await movie_frame("regrow",i)
		if i in [10,20,40,80,120]:
			viewport.size=SIZE
			await draw_photo("regrow_%03d"%i)
			viewport.size=Vector2i(1280,720)
	# Start a real expansion from existing upper land, then drag beyond edge.
	viewport.remove_child(editor)
	editor.free()
	viewport.size=SIZE
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.set_process(false)
	editor.water_view.set_process(false)
	editor.gameplay.time_system.set_progress(.29,editor)
	editor.gameplay.shihai_hud.tick_ui(0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),"sculpt",false)
	_frame(Vector2(-16,-3),24,16,48)
	_freeze_node(editor)
	editor.tool="expand"
	editor.radius=.49
	var start_cell:=Vector2i(-12,-2)
	var edge_x: int = start_cell.x
	while editor.data.cells.has(Vector2i(edge_x-1,start_cell.y)):
		edge_x -= 1
	var height:float=editor.data.cells[start_cell].height
	var start:Vector2=editor.camera.unproject_position(Vector3(start_cell.x+.5,height,start_cell.y+.5))
	var end:Vector2=editor.camera.unproject_position(Vector3(edge_x-2.5,height,start_cell.y+.5))
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=start
	press.pressed=true
	viewport.push_input(press,true)
	if not editor.painting:errors.append("Top sampling failed")
	editor.continue_paint(end)
	editor._update_brush(end)
	editor.preview.refresh(editor.blueprint_data,editor.renderer,true)
	var added:int=0
	if editor.blueprint_data!=null:
		for cell:Vector2i in editor.blueprint_data.cells:
			if editor.data.cells.has(cell):continue
			added+=1
			if absf(editor.blueprint_data.cells[cell].height-height)>.001:errors.append("Expansion wrong height")
	if added==0:errors.append("Expansion did not add cells")
	await draw_photo("upper_plane_expansion")
	snapshots={"sampled_height":height,"build_height":editor.build_height,"brush_y":editor.brush.position.y,"added_cells":added,"tools":editor.gameplay.shihai_hud.SCULPT_TOOLS.size()}
	press.pressed=false
	press.position=end
	viewport.push_input(press,true)
	var started: int = Time.get_ticks_msec()
	while editor.renderer.has_pending_updates() and Time.get_ticks_msec()-started<12000:
		editor.renderer.flush_dirty(6)
		await process_frame
	editor.renderer._process(1.0)
	editor.water_view.flush()
	editor.preview.refresh(editor.data,editor.renderer)
	editor.brush.visible=false
	_freeze_node(editor)
	await draw_photo("upper_plane_committed")
	editor.cancel_input()
	var stable:bool=before==_source_hashes()
	for path: String in extra_sources:
		stable = stable and FileAccess.get_sha256(path) == extra_sources[path]
	if not stable:errors.append("Source changed")
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"valid":errors.is_empty(),"errors":errors,"records":records,"input":snapshots,"source_sha256":before,"extra_sources":extra_sources,"source_stable":stable,"actor_absent":editor.gameplay.actor==null,"animation_method":"production grass clock in 0.05s steps; physical water frozen after lower + 3s conserved flow; recovery uses existing dry tool","flood_frame_seconds":.05,"regrow_frame_seconds":.05},"\t"))
	print("RESPONSE CAPTURE ",errors.is_empty()," ",errors)
	viewport.remove_child(editor)
	editor.free()
	viewport.queue_free()
	quit(1 if not errors.is_empty() else 0)
