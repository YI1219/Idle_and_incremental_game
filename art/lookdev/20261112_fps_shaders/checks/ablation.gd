extends "res://art/lookdev/20261112_fps/checks/ablation.gd"
func run()->void:
	output="res://art/lookdev/20261112_fps_shaders/checks"
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	viewport=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
	editor.set_native_preview(true);viewport.msaa_3d=Viewport.MSAA_2X;RenderingServer.directional_shadow_atlas_set_size(4096,true)
	editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
	var env:Environment=editor.get_node("WorldEnvironment").environment
	for i:int in 40:RenderingServer.force_draw(false);await process_frame
	for size:Vector2i in [Vector2i(2560,1440),Vector2i(3840,2160)]:
		for name:String in ["base","no_dof","no_glow","no_ao","no_il","half_ao","low_il","no_clouds","base_repeat"]:
			editor.camera.dof_attributes.dof_blur_far_enabled=name!="no_dof"
			env.glow_enabled=name!="no_glow";env.ssao_enabled=name!="no_ao";env.ssil_enabled=name!="no_il"
			indirect(name=="half_ao",true)
			if name=="low_il":RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW,true,.5,4,50,300)
			for node:Node in editor.landscape.get_children():
				if node is MeshInstance3D:node.visible=name!="no_clouds"
			await sample(name,size)
	FileAccess.open(output.path_join("ablation.json"),FileAccess.WRITE).store_string(JSON.stringify({"settings":settings,"samples":rows,"method":"current balanced2xMSAA/4096 shadows;fixedBASE_A phase1.25;water.1;15warm+50explicitdraw;no cap or imageIO"},"\t"))
	editor.free();viewport.queue_free();quit()
