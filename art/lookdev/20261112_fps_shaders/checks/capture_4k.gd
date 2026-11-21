extends "res://art/lookdev/20261112_fps_shaders/checks/variants.gd"
func run()->void:
	output="res://art/lookdev/20261112_fps_shaders/pairs4k";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=Vector2i(3840,2160);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.set_native_preview(true);Engine.max_fps=0
	viewport.msaa_3d=Viewport.MSAA_2X;RenderingServer.directional_shadow_atlas_set_size(4096,true)
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	editor.gameplay.set_wallpaper_mode(true);editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor);prepare_shaders()
	var sources:Dictionary=_source_hashes();var data_hash:String=JSON.stringify(editor.data.serialize(),"",true,true).sha256_text()
	for mode:String in ["full","scaled"]:
		viewport.scaling_3d_scale=1.0 if mode=="full" else .5;viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR if mode=="full" else Viewport.SCALING_3D_MODE_FSR
		for name:String in ["before","after"]:
			variant("before" if name=="before" else "combined");editor.gameplay.time_system.set_progress(.29,editor)
			for angle:String in ["whole","close"]:
				_frame(Vector2(-10,-5) if angle=="close" else Vector2(-2,-1),13 if angle=="close" else 32,16,30)
				for i:int in 24:RenderingServer.force_draw(false);await process_frame
				var file:String=mode+"_"+name+"_"+angle+".png";var img:Image=viewport.get_texture().get_image();var error:Error=img.save_png(output.path_join(file))
				captures.append({"file":file,"save_error":error,"size":[img.get_width(),img.get_height()],"scale":viewport.scaling_3d_scale,"msaa":viewport.msaa_3d,"shadow":4096,"ssao_half_size":name!="before","dof_quality":1 if name=="before" else 0,"position":_vector(editor.camera.position),"rotation":_vector(editor.camera.rotation_degrees),"phase":PHASE,"time":.29,"data":data_hash})
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":sources,"sources_unchanged":sources==_source_hashes(),"captures":captures,"data_unchanged":data_hash==JSON.stringify(editor.data.serialize(),"",true,true).sha256_text()},"\t"));print("4K PAIRS ",captures.size());editor.free();viewport.queue_free();quit()
