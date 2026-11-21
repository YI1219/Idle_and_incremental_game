extends "res://art/lookdev/20261110_interaction_water/checks/capture_interaction.gd"
var samples:Array[Dictionary]=[]
func press(button:MouseButton,at:Vector2,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=button;e.position=at;e.pressed=down
	viewport.push_input(e,true)
func move(at:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=at;e.button_mask=MOUSE_BUTTON_MASK_LEFT if editor.painting else 0
	viewport.push_input(e,true)
	editor._process(0.0)
func leaf_action(id:String)->void:
	var hud:Control=editor.gameplay.shihai_hud
	press(MOUSE_BUTTON_LEFT,hud._scroll_btn_rect.get_center(),true);press(MOUSE_BUTTON_LEFT,hud._scroll_btn_rect.get_center(),false)
	await process_frame;RenderingServer.force_draw(false);await process_frame
	for action:Dictionary in hud._leaf_actions:
		if action.id==id:
			press(MOUSE_BUTTON_LEFT,action.rect.get_center(),true);press(MOUSE_BUTTON_LEFT,action.rect.get_center(),false);return
	errors.append("Missing menu action "+id)
func run()->void:
	if not _read_options():quit(1);return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):push_error("Use new directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var sources:Dictionary=_source_hashes()
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.set_process(false);editor.camera.set_process(false);editor.renderer.set_process(false);editor.renderer.animate_edits=false
	editor.gameplay.time_system.set_progress(.29,editor)
	editor.gameplay.shihai_hud.tick_ui(0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),"sculpt",false)
	# Make one uneven dry patch with the existing lower brush, then align through actual input.
	editor.data.begin_stroke();editor.data.apply_brush(Vector2(-12,-2),1.6,"lower",true,3.5,3,3.5);editor.data.end_stroke();editor.renderer.rebuild_all()
	_frame(Vector2(-11,-3),16,16,48);editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
	for i in 4:await process_frame;RenderingServer.force_draw(false)
	var hud:Control=editor.gameplay.shihai_hud
	press(MOUSE_BUTTON_LEFT,hud._tool_hit_rects[6].get_center(),true);press(MOUSE_BUTTON_LEFT,hud._tool_hit_rects[6].get_center(),false)
	if editor.tool!="level":errors.append("Level toolbar click did not select level")
	var baseline:Dictionary=editor.data.serialize()
	var start:Vector2=editor.camera.unproject_position(Vector3(-14.5,3.5,-3.5))
	var finish:Vector2=editor.camera.unproject_position(Vector3(-11.5,3.0,-1.5))
	move(start);press(MOUSE_BUTTON_LEFT,start,true)
	if not editor.painting:errors.append("Level pointer press did not start")
	move(finish)
	if editor.data.serialize()!=baseline:errors.append("Level draft changed live data")
	var sampled:float=editor.build_height
	if absf(sampled-3.5)>.001:errors.append("Level sampled unexpected height")
	await photo("01_level_draft")
	var grid:bool=bool(editor.renderer.materials.grass.get_shader_parameter("show_grid"))
	if not grid:errors.append("Local grid did not follow production brush")
	var count:int=0
	if editor.blueprint_data!=null:
		for cell:Vector2i in editor.data.cells:
			if editor.data.cells[cell].height!=editor.blueprint_data.cells[cell].height:count+=1
	if count==0:errors.append("Level drag did not align any cell")
	press(MOUSE_BUTTON_RIGHT,finish,true);press(MOUSE_BUTTON_RIGHT,finish,false)
	if editor.blueprint_data!=null or editor.data.serialize()!=baseline:errors.append("Right cancel level failed")
	await photo("02_level_cancelled")
	move(start);press(MOUSE_BUTTON_LEFT,start,true);move(finish);press(MOUSE_BUTTON_LEFT,finish,false)
	await settle_build();editor.renderer._process(1);editor.brush.visible=false;editor.preview.refresh(editor.data,editor.renderer)
	if editor.data.serialize()==baseline:errors.append("Level release did not commit")
	await photo("03_level_committed")
	# Existing undo control restores the aligned stroke without touching water.
	press(MOUSE_BUTTON_LEFT,hud._undo_hit_rect.get_center(),true);press(MOUSE_BUTTON_LEFT,hud._undo_hit_rect.get_center(),false);await settle_build()
	if editor.data.serialize()!=baseline:errors.append("Level undo did not restore one stroke")
	samples.append({"sampled_height":sampled,"aligned_cells":count,"grid_visible":grid,"cancel_restores":true,"undo_restores":editor.data.serialize()==baseline})
	viewport.size=Vector2i(3840,2160);editor.preview_quality.refresh();await process_frame;RenderingServer.force_draw(false);await process_frame
	await leaf_action("preview_native")
	if not editor.preview_quality.native or viewport.scaling_3d_scale!=1:errors.append("Native menu failed")
	samples.append({"quality":"native","scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d})
	await leaf_action("preview_auto")
	if editor.preview_quality.native or viewport.scaling_3d_scale>.7:errors.append("Smooth menu failed")
	samples.append({"quality":"smooth","scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d})
	await leaf_action("grid_snap")
	if editor.snap:errors.append("Grid switch off failed")
	await leaf_action("grid_snap")
	if not editor.snap:errors.append("Grid switch on failed")
	press(MOUSE_BUTTON_LEFT,hud._scroll_btn_rect.get_center(),true);press(MOUSE_BUTTON_LEFT,hud._scroll_btn_rect.get_center(),false)
	await photo("04_4K_settings")
	var report:Dictionary={"valid":errors.is_empty(),"errors":errors,"samples":samples,"frames":phases,"method":"production Viewport.push_input through toolbar/menu and terrain press/drag/release/right cancel; frozen water; manual render/update stepping","sources_unchanged":sources==_source_hashes(),"source_sha256":sources,"actor_absent":editor.gameplay.actor==null}
	FileAccess.open(output.path_join("controls.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STABILITY CONTROLS ",report.valid," ",errors);viewport.remove_child(editor);editor.free();viewport.queue_free();quit(0 if report.valid else 1)
