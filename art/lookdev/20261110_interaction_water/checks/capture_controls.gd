extends "res://art/lookdev/20261110_interaction_water/checks/capture_interaction.gd"
var samples:Array[Dictionary]=[]
func press(button:MouseButton,at:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.position=at;event.pressed=down
	viewport.push_input(event,true)
func run()->void:
	if not _read_options():quit(1);return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):push_error("Select new evidence directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var sources:Dictionary=_source_hashes()
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.set_process(false);editor.camera.set_process(false);editor.renderer.set_process(false)
	editor.gameplay.time_system.set_progress(.29,editor)
	editor.gameplay.shihai_hud.tick_ui(1.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),"sculpt",false)
	_frame(Vector2(-2,-1),32,16,30)
	editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
	await process_frame;RenderingServer.force_draw(false)
	var data_before:Dictionary=editor.data.serialize()
	var hud:Control=editor.gameplay.shihai_hud
	for index:int in [0,2]:
		var at:Vector2=hud._size_hit_rects[index].get_center()
		press(MOUSE_BUTTON_LEFT,at,true);press(MOUSE_BUTTON_LEFT,at,false)
		var world:Vector2=editor.camera.unproject_position(Vector3(-12,3.5,-3))
		editor._update_brush(world)
		if absf(editor.radius-hud.BRUSH_RADII[index])>.001:errors.append("Brush size did not change")
		await photo("brush_%s"%("fine" if index==0 else "wide"))
		samples.append({"radius":editor.radius,"painting":editor.painting})
	editor.brush.visible=false
	for near_view:bool in [true,false]:
		editor.camera.wheel(-100 if near_view else 100)
		for i in 120:editor.camera.advance(1.0/60)
		await photo("zoom_near" if near_view else "zoom_far")
		samples.append({"zoom_setting":editor.camera.height_goal,"actual_height":editor.camera.position.y,"pitch":editor.camera._pitch,"orbit_radius":editor.camera.position.distance_to(Vector3(editor.camera._center.x,0,editor.camera._center.y))})
	_frame(Vector2(-2,-1),32,16,30)
	var focus:=Vector3(editor.camera._center.x,0,editor.camera._center.y)
	var distance:float=editor.camera.position.distance_to(focus)
	var cursor:=Vector2(1280,600)
	press(MOUSE_BUTTON_RIGHT,cursor,true)
	var move:=InputEventMouseMotion.new();move.position=cursor;move.relative=Vector2(120,70);move.button_mask=MOUSE_BUTTON_MASK_RIGHT
	viewport.push_input(move,true);press(MOUSE_BUTTON_RIGHT,cursor,false)
	for i in 120:editor.camera.advance(1.0/60)
	if absf(editor.camera.position.distance_to(focus)-distance)>.001:errors.append("Orbit changed distance")
	await photo("right_drag_orbit")
	if editor.data.serialize()!=data_before:errors.append("Controls changed terrain or water while frozen")
	var report:Dictionary={"scene":"scenes/terrain_editor.tscn","samples":samples,"phases":phases,"source_sha256":sources,"sources_unchanged":sources==_source_hashes(),"errors":errors,"valid":errors.is_empty(),"actor_absent":editor.gameplay.actor==null,"method":"production Viewport.push_input; controlled camera settle; frozen water"}
	FileAccess.open(output.path_join("controls.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	viewport.remove_child(editor);editor.free();viewport.queue_free();print("CONTROLS NATIVE ",report.valid," ",errors);quit(0 if errors.is_empty() else 1)
