extends "res://art/lookdev/20261112_fps_shaders/checks/variants.gd"
func run()->void:
	output="res://art/lookdev/20261112_fps_shaders/pairs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.renderer.animate_edits=false;editor.set_native_preview(true);Engine.max_fps=0
	viewport.msaa_3d=Viewport.MSAA_2X;shadow_atlas_size=4096;RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size,true)
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	editor.gameplay.set_wallpaper_mode(true);editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	_freeze_node(editor);prepare_shaders()
	var sources:Dictionary=_source_hashes();var invariants:Array[Dictionary]=[]
	for layout:Array in [[7301,0],[2104,0],[4242,1],[913,2]]:
		editor.data.seed=layout[0];editor.data.make_preset(layout[1]);editor.renderer.rebuild_all();editor.motes.rebuild_from_data(editor.data);editor.water_view.reset(editor.data);editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
		var data_hash:String=JSON.stringify(editor.data.serialize(),"",true,true).sha256_text()
		for name:String in ["before","after"]:
			variant("before" if name=="before" else "combined")
			ssao_half_size=name!="before";dof_blur_quality=1 if name=="before" else 0
			for angle:String in ["whole","reverse","close"]:
				_frame(Vector2(-10,-5) if angle=="close" else Vector2(-2,-1),13 if angle=="close" else 32,196 if angle=="reverse" else 16,30)
				await _capture("%d_%s_%s"%[layout[0],name,angle],.29)
			if layout[0]==7301:
				_frame(Vector2(-8,6),10,16,20);await _capture("7301_"+name+"_low",.29)
				_frame(Vector2(-2,-1),32,16,30);await _capture("7301_"+name+"_night",0.0)
			invariants.append({"seed":layout[0],"variant":name,"data":data_hash,"data_unchanged":data_hash==JSON.stringify(editor.data.serialize(),"",true,true).sha256_text(),"water":editor.water_view.published_volume})
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"invariants":invariants,"source_sha256":sources,"sources_unchanged":sources==_source_hashes(),"errors":errors,"phase":PHASE,"notes":"Same scene/material uniforms,2xMSAA/4096shadows/native2K;before angular sky+full AO+low DOF;after direct sky+half AO+verylow DOF;no scene geometry change"},"\t"));print("PAIRS ",captures.size()," ",errors)
	editor.free();viewport.queue_free();quit(1 if not errors.is_empty() else 0)
