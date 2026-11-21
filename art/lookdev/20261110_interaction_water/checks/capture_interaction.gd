extends "res://tools/art/capture_lookdev.gd"
## Deterministic phase stills use production input and morph methods.
## Capture I/O is excluded from the separate native latency benchmark.
var phases:Array[Dictionary]=[]
func photo(name:String)->void:
	await process_frame
	RenderingServer.force_draw(false)
	var file:String=output.path_join(name+".png")
	viewport.get_texture().get_image().save_png(file)
	phases.append({"file":name+".png","morph_progress":editor.renderer.morph_progress,"draft":editor.blueprint_data!=null,"cells":editor.data.cells.size()})
func paint(cell:Vector2i,tool_name:String)->Vector2:
	editor.tool=tool_name
	editor.radius=1.6
	editor.snap=true
	var h:float=editor.data.cells[cell].height
	var point:Vector2=editor.camera.unproject_position(Vector3(cell.x+.5,h,cell.y+.5))
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=point
	viewport.push_input(event,true)
	editor._update_brush(point)
	editor.preview.refresh(editor.blueprint_data if editor.blueprint_data!=null else editor.data,editor.renderer,editor.blueprint_data!=null)
	return point
func settle_build()->void:
	var start:int=Time.get_ticks_msec()
	while editor.renderer.has_pending_updates() and Time.get_ticks_msec()-start<12000:
		editor.renderer.flush_dirty(6)
		editor.preview.refresh(editor.data,editor.renderer)
		await process_frame
func release()->void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=false
	viewport.push_input(event,true)
func run()->void:
	if not _read_options():quit(1);return
	var sources:Dictionary=_source_hashes()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):
		push_error("Select a new evidence directory")
		quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new()
	viewport.size=SIZE
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.set_process(false)
	editor.gameplay.time_system.set_progress(.29,editor)
	# UI is hidden for surface legibility; brush and blueprint remain active.
	editor.hud.hide()
	editor.gameplay.shihai_hud.hide()
	_frame(Vector2(-2,-1),32,16,30)
	editor.water_view.tick(.1)
	editor.water_view.flush()
	_freeze_node(editor)
	for i in 20:await process_frame
	editor.brush.visible=false
	await photo("00_before")
	var baseline:Dictionary=editor.data.serialize()
	var at:=Vector2i(-12,3)
	var screen:Vector2=paint(at,"contract")
	if editor.blueprint_data==null:errors.append("Input did not begin draft")
	if editor.data.serialize()!=baseline:errors.append("Held draft changed real terrain")
	await photo("01_held_removal_blueprint")
	var cancel:=InputEventMouseButton.new()
	cancel.button_index=MOUSE_BUTTON_RIGHT
	cancel.pressed=true
	cancel.position=screen
	viewport.push_input(cancel,true)
	editor.preview.refresh(editor.data,editor.renderer)
	if editor.blueprint_data!=null or editor.data.serialize()!=baseline:errors.append("Cancel failed")
	await photo("02_cancelled")
	screen=paint(at,"contract")
	release()
	editor.preview.refresh(editor.data,editor.renderer)
	await photo("03_released_waiting")
	await settle_build()
	editor.brush.visible=false
	for phase:int in 5:
		if phase>0:editor.renderer._process(editor.renderer.MORPH_SECONDS*.25)
		await photo("04_removal_%03d"%[phase*25])
	# Expand into the same deleted footprint: new land rises and fades in.
	editor.tool="expand"
	editor.build_height=3.5
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=screen
	viewport.push_input(event,true)
	editor._update_brush(screen)
	editor.preview.refresh(editor.blueprint_data if editor.blueprint_data!=null else editor.data,editor.renderer,editor.blueprint_data!=null)
	await photo("05_held_addition_blueprint")
	release()
	await settle_build()
	editor.brush.visible=false
	for phase:int in 5:
		if phase>0:editor.renderer._process(editor.renderer.MORPH_SECONDS*.25)
		await photo("06_addition_%03d"%[phase*25])
	# The same occupied ground rejects expansion and shows red.
	editor._update_brush(screen)
	var tint:Color=editor.brush.material_override.albedo_color
	if tint.r<tint.g:errors.append("Invalid expansion cursor is not red")
	await photo("07_invalid_red")
	var report:Dictionary={"scene":"scenes/terrain_editor.tscn","seed":7301,"preset":0,"resolution":[SIZE.x,SIZE.y],"method":"production Viewport.push_input; staged morph sampling, not a latency recording","errors":errors,"valid":errors.is_empty(),"phases":phases,"actor_absent":editor.gameplay.actor==null}
	report["source_sha256"]=sources
	report["sources_unchanged"]=sources==_source_hashes()
	if not report.sources_unchanged:
		errors.append("Production source changed during capture")
		report.valid=false
	FileAccess.open(output.path_join("interaction.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	viewport.remove_child(editor);editor.free();viewport.queue_free()
	print("INTERACTION CAPTURE ",report.valid," ",errors)
	quit(0 if errors.is_empty() else 1)
