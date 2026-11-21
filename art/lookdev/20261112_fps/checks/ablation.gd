extends "res://tools/art/capture_lookdev.gd"
var geometry: Array[GeometryInstance3D]=[]
var rows: Array[Dictionary]=[]
var settings: Dictionary={}
func stats(values: Array[float]) -> Dictionary:
	var sorted: Array[float]=values.duplicate();sorted.sort();var total:float=0
	for v:float in values:total+=v
	return {"mean":total/values.size(),"p50":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*.95)]}
func indirect(ao:bool,il:bool) -> void:
	RenderingServer.environment_set_ssao_quality(settings["ssao/quality"],ao,settings["ssao/adaptive_target"],settings["ssao/blur_passes"],settings["ssao/fadeout_from"],settings["ssao/fadeout_to"])
	RenderingServer.environment_set_ssil_quality(settings["ssil/quality"],il,settings["ssil/adaptive_target"],settings["ssil/blur_passes"],settings["ssil/fadeout_from"],settings["ssil/fadeout_to"])
func sample(label: String, size: Vector2i) -> void:
	viewport.size=size
	for i:int in 15:RenderingServer.force_draw(false);await process_frame
	var times:Array[float]=[]
	for i:int in 50:
		var start:int=Time.get_ticks_usec();RenderingServer.force_draw(false);await process_frame
		times.append((Time.get_ticks_usec()-start)/1000.0)
	var row:Dictionary={"name":label,"size":[size.x,size.y],"ms":stats(times),"draws":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"triangles":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
	rows.append(row);print(JSON.stringify(row))
func run()->void:
	output="res://art/lookdev/20261112_fps/checks"
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:
			settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	print("SETTINGS ",settings)
	viewport=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
	editor.set_native_preview(true);editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
	for node:Node in editor.find_children("*","GeometryInstance3D",true,false):geometry.append(node)
	var census:Dictionary={}
	for node:GeometryInstance3D in geometry:
		var mesh:Mesh;var count:int=1
		if node is MeshInstance3D:mesh=node.mesh
		elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh;count=node.multimesh.instance_count
		if mesh==null:continue
		var tris:int=0
		for s:int in mesh.get_surface_count():
			var arrays:Array=mesh.surface_get_arrays(s)
			tris+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
		var key:String="distant_mountains" if editor.landscape.is_ancestor_of(node) and node is MultiMeshInstance3D else ("clouds" if editor.landscape.is_ancestor_of(node) else String(node.name))
		census[key]=int(census.get(key,0))+tris*count
	print("CENSUS ",census)
	for i:int in 60:RenderingServer.force_draw(false);await process_frame
	for variant:String in ["base","no_far_mountains","no_clouds","no_grass","no_decoration","ssao_half","ssil_half","shadow4096","msaa2","base_repeat"]:
		for node:GeometryInstance3D in geometry:
			if not node.has_meta("original_visible"):node.set_meta("original_visible",node.visible)
			node.visible=node.get_meta("original_visible")
		viewport.msaa_3d=Viewport.MSAA_2X if variant=="msaa2" else Viewport.MSAA_4X
		indirect(variant=="ssao_half" or settings["ssao/half_size"],variant=="ssil_half" or settings["ssil/half_size"])
		RenderingServer.directional_shadow_atlas_set_size(4096 if variant=="shadow4096" else 8192,true)
		for node:GeometryInstance3D in geometry:
			var far:bool=editor.landscape.is_ancestor_of(node)
			if variant=="no_far_mountains" and far and node is MultiMeshInstance3D:node.hide()
			if variant=="no_clouds" and far and node is MeshInstance3D:node.hide()
			if variant=="no_grass" and node.name=="grass_blades":node.hide()
			if variant=="no_decoration" and editor.renderer.is_ancestor_of(node) and node is MultiMeshInstance3D and node.name!="grass_blades":node.hide()
		await sample(variant,Vector2i(2560,1440))
	FileAccess.open(output.path_join("ablation.json"),FileAccess.WRITE).store_string(JSON.stringify({"settings":settings,"census_base_triangles_before_lod_culling":census,"samples":rows,"adapter":RenderingServer.get_video_adapter_name(),"native_msaa":4,"method":"fixed BASE_A,phase1.25,water0.1s;15 warmup+50 explicit draw frames;no limiter,no image IO"},"\t"))
	editor.free();viewport.queue_free();quit()
