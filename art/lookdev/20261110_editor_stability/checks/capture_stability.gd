extends "res://tools/art/capture_lookdev.gd"
const PACKAGE="res://art/lookdev/20261110_editor_stability"
var legacy_field:RefCounted
var legacy_decoration:RefCounted
var legacy_holder:Node3D
var records:Array[Dictionary]=[]
var new_decoration:RefCounted
var source_snapshot:Dictionary={}
func old_script(relative:String,global_name:String)->GDScript:
	var script:=GDScript.new()
	script.source_code=FileAccess.get_file_as_string(PACKAGE+"/checks/source_before/"+relative).replace("class_name "+global_name+"\n","")
	if script.reload()!=OK:errors.append("Cannot load baseline "+relative)
	return script
func prime_legacy()->void:
	legacy_field=old_script("scripts/terrain_editor/contour_terrain.gd","ContourTerrain").new()
	legacy_decoration=old_script("scripts/terrain_editor/terrain_decoration.gd","TerrainDecoration").new()
	legacy_decoration.load_assets()
	legacy_field.refresh(editor.data.copy())
	legacy_decoration._column_layout(legacy_field,editor.data.seed)
func legacy_show()->void:
	legacy_field.refresh(editor.data.copy())
	legacy_decoration._column_layout(legacy_field,editor.data.seed)
	legacy_decoration.contours=legacy_field
	legacy_holder=Node3D.new();legacy_holder.name="BeforeTerrain"
	editor.add_child(legacy_holder)
	for node:Node3D in editor.renderer.chunks.values():node.visible=false
	for chunk:Vector2i in legacy_field.triangle_chunks:
		var geometry:Dictionary=legacy_field.build(chunk)
		var node:=Node3D.new();legacy_holder.add_child(node)
		for key:String in geometry:
			if key in ["water","waterfall","bank"] or geometry[key].get_surface_count()==0:continue
			var mesh:=MeshInstance3D.new();mesh.name=key;mesh.mesh=geometry[key];mesh.material_override=editor.renderer.materials[key]
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["grass","water","waterfall"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.add_child(mesh)
		legacy_decoration.populate(node,editor.data,chunk)
		if geometry.has("grass"):
			var grass:Node3D=load("res://scripts/terrain_editor/grass_field.gd").build(geometry.grass,chunk,editor.renderer._grass_blockers(editor.data,chunk))
			if grass!=null:node.add_child(grass)
	new_decoration=editor.renderer.decoration;editor.renderer.decoration=legacy_decoration
	editor.gameplay.time_system.set_progress(.29,editor);_freeze_node(legacy_holder)
func legacy_hide()->void:
	legacy_holder.free();legacy_holder=null
	editor.renderer.decoration=new_decoration
	for node:Node3D in editor.renderer.chunks.values():node.visible=true
func frame_case(at:Vector2,yaw:float)->void:
	_frame(at,7,yaw,60)
	editor.camera.position.y+=2.5
func photo(label:String,variant:String)->void:
	editor.gameplay.time_system.set_progress(.29,editor)
	for i in 4:RenderingServer.force_draw(false);await process_frame
	var image:Image=viewport.get_texture().get_image()
	var result:Error=image.save_png(output.path_join(label+".png"))
	if result!=OK:errors.append("Save failed "+label)
	records.append({"file":label+".png","variant":variant,"resolution":[image.get_width(),image.get_height()],"position":_vector(editor.camera.position),"rotation":_vector(editor.camera.rotation_degrees),"fov":editor.camera.fov,"sun_rotation":_vector(editor.get_node("SunLight").rotation_degrees),"data_sha256":JSON.stringify(editor.data.serialize(),"",true,true).sha256_text(),"volume":editor.water_view.published_volume,"discharged":editor.water_view.published_discharged_volume,"scale_3d":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d,"morph":editor.renderer.morph_progress,"seed":editor.data.seed,"actor_absent":editor.gameplay.actor==null})
func setup_scene(seed_value:int=7301)->void:
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.renderer.animate_edits=false
	if seed_value!=7301:editor.data.seed=seed_value;editor.renderer.rebuild_all();editor.water_view.reset(editor.data)
	var f11:=InputEventKey.new();f11.keycode=KEY_F11;f11.pressed=true;editor.gameplay.handle_unhandled_input(f11)
	editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	prime_legacy();_freeze_node(editor)
func lower(at:Vector2,count:int=4)->void:
	for i in count:
		var source_cell:=Vector2i(at.floor())
		var height:float=editor.data.cells[source_cell].height
		editor.data.begin_stroke();editor.data.apply_brush(at,3.8,"lower",false,height,3,height);editor.data.end_stroke()
		editor.renderer.rebuild_all()
	for i in 30:editor.water_view.tick(.1);editor.water_view.flush()
	_freeze_node(editor)
func run()->void:
	if not _read_options():quit(1);return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):push_error("Use a new output directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for path:String in ["scripts/terrain_editor/contour_terrain.gd","scripts/terrain_editor/terrain_decoration.gd","scripts/terrain_editor/grass_field.gd","scripts/terrain_editor/editor.gd","scripts/terrain_editor/terrain_data.gd","scripts/terrain_editor/preview_quality.gd","scripts/gameplay/ui/shihai_hud.gd","shaders/terrain_editor/ground.gdshader","shaders/terrain_editor/rim_green.gdshader","shaders/terrain_editor/grass_blades.gdshader","shaders/terrain_editor/live_water.gdshaderinc"]:source_snapshot[path]=FileAccess.get_sha256("res://"+path)
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	setup_scene()
	_frame(Vector2(-2,-1),32,16,30);legacy_show();await photo("00_original_whole","old_geometry_current_grass");legacy_hide();await photo("01_current_whole","current")
	lower(Vector2(-8,-5))
	for yaw:float in [16.0,196.0]:
		frame_case(Vector2(-7.5,-3.5),yaw);legacy_show();await photo("upper_before_%d"%roundi(yaw),"old_geometry_current_grass");legacy_hide();await photo("upper_after_%d"%roundi(yaw),"current")
	# Same production level path: take a high neighbour then preview filling the pit.
	editor.process_mode=Node.PROCESS_MODE_INHERIT;editor.set_process(false);editor.renderer.set_process(false);editor.camera.set_process(false)
	editor.tool="level";editor.radius=2.2
	var start:Vector2=editor.camera.unproject_position(Vector3(-3.5,3.5,-6.5))
	var finish:Vector2=editor.camera.unproject_position(Vector3(-7.5,1.5,-4.5))
	if editor.begin_paint(start):
		editor.continue_paint(finish);editor.preview.refresh(editor.blueprint_data,editor.renderer,true);editor._update_brush(finish)
		await photo("level_blueprint","level_draft")
		editor.cancel_input();editor.preview.refresh(editor.data,editor.renderer);editor.brush.visible=false
	else:errors.append("Level demonstration could not start")
	viewport.remove_child(editor);editor.free()
	setup_scene();lower(Vector2(13,0))
	frame_case(Vector2(13,0),106);legacy_show();await photo("lower_before","old_geometry_current_grass");legacy_hide();await photo("lower_after","current")
	viewport.remove_child(editor);editor.free()
	for seed_value:int in [2104,4242]:
		setup_scene(seed_value);lower(Vector2(-8,-5));frame_case(Vector2(-7.5,-3.5),106);await photo("held_%d"%seed_value,"current");viewport.remove_child(editor);editor.free()
	setup_scene();editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30)
	viewport.size=Vector2i(3840,2160);editor.set_native_preview(true);await photo("4K_native","native_4K")
	editor.set_native_preview(false);await photo("4K_preview","4K_output_2K_3D")
	viewport.remove_child(editor);editor.free()
	var stable:bool=true
	for path:String in source_snapshot:stable=stable and FileAccess.get_sha256("res://"+path)==source_snapshot[path]
	if not stable:errors.append("Source changed during capture")
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"valid":errors.is_empty(),"errors":errors,"scene":"scenes/terrain_editor.tscn","source_sha256":source_snapshot,"source_stable":stable,"captures":records,"phase":PHASE,"day_progress":.29,"before_note":"Only two task-start geometry generators reconstructed in memory; current grass/materials/water shared"},"\t"))
	print("STABILITY CAPTURE ",errors.is_empty()," ",errors);viewport.queue_free();quit(0 if errors.is_empty() else 1)
