extends "res://art/lookdev/20261112_fps/checks/ablation.gd"
var shader_pairs:Array[Dictionary]=[]
func prepare_shaders(freeze:bool=true)->void:
	var old_palette:String=FileAccess.get_file_as_string("res://art/lookdev/20261112_fps_shaders/checks/sky_palette_before.gdshaderinc.txt")
	var pairs:Array=[[editor.get_node("WorldEnvironment").environment.sky.sky_material,"sky"],[editor.landscape.material,"distant_mountain"]]
	for material:ShaderMaterial in editor.landscape.cloud_materials:pairs.append([material,"cloud_deck"])
	for pair:Array in pairs:
		var material:ShaderMaterial=pair[0]
		var old_code:String=FileAccess.get_file_as_string("res://art/lookdev/20261112_fps_shaders/checks/"+pair[1]+"_before.gdshader.txt").replace('#include "sky_palette.gdshaderinc"',old_palette)
		if freeze:
			var token:=RegEx.new();token.compile("\\bTIME\\b");old_code=token.sub(old_code,str(PHASE),true)
		var old:=Shader.new();old.code=old_code
		var uniforms:Dictionary={}
		for uniform:Dictionary in material.shader.get_shader_uniform_list():uniforms[uniform.name]=material.get_shader_parameter(uniform.name)
		shader_pairs.append({"material":material,"before":old,"after":material.shader,"uniforms":uniforms})
func variant(name:String)->void:
	for pair:Dictionary in shader_pairs:
		pair.material.shader=pair.before if name.begins_with("before") else pair.after
		for key:String in pair.uniforms:pair.material.set_shader_parameter(key,pair.uniforms[key])
	indirect(name in ["half_ao","combined"],true)
	RenderingServer.camera_attributes_set_dof_blur_quality(0 if name in ["low_dof","combined"] else 1,false)
func run()->void:
	output="res://art/lookdev/20261112_fps_shaders/checks"
	for name:String in ["ssao","ssil"]:
		for key:String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:settings[name+"/"+key]=ProjectSettings.get_setting("rendering/environment/"+name+"/"+key)
	print("DOF DEFAULT ",ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_quality"))
	viewport=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
	editor.set_native_preview(true);viewport.msaa_3d=Viewport.MSAA_2X;RenderingServer.directional_shadow_atlas_set_size(4096,true)
	editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor);prepare_shaders()
	for i:int in 40:RenderingServer.force_draw(false);await process_frame
	for size:Vector2i in [Vector2i(2560,1440),Vector2i(3840,2160)]:
		for name:String in ["before","math_only","half_ao","low_dof","combined","before_repeat","combined"]:
			variant(name);await sample(name,size)
	FileAccess.open(output.path_join("variants.json"),FileAccess.WRITE).store_string(JSON.stringify({"settings":settings,"samples":rows,"method":"same live scene;2xMSAA/4096shadows;fixedBASE_A phase1.25 water.1;15warm+50explicit;old/new shaders switch in memory;no cap or capture IO"},"\t"))
	editor.free();viewport.queue_free();quit()
