extends "res://tools/art/capture_lookdev.gd"
var old_mesh:ArrayMesh
var new_mesh:ArrayMesh
func variant(name:String)->void:
	for node:Node in editor.find_children("grass_blades","MultiMeshInstance3D",true,false):node.multimesh.mesh=old_mesh if name=="before" else new_mesh
	viewport.msaa_3d=Viewport.MSAA_4X if name=="before" else Viewport.MSAA_2X
	shadow_atlas_size=8192 if name=="before" else 4096
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size,true)
func run()->void:
	output="res://art/lookdev/20261112_fps/pairs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	old_mesh=load("res://art/lookdev/20261112_fps/checks/grass_field_before.gd").clump_mesh();new_mesh=load("res://scripts/terrain_editor/grass_field.gd").clump_mesh()
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.renderer.animate_edits=false;editor.set_native_preview(true);Engine.max_fps=0
	editor.gameplay.set_wallpaper_mode(true);editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	var initial_sources:Dictionary=_source_hashes()
	var invariants:Array[Dictionary]=[]
	for layout:Array in [[7301,0],[2104,0],[4242,1],[913,2]]:
		editor.data.seed=layout[0];editor.data.make_preset(layout[1]);editor.renderer.rebuild_all();editor.motes.rebuild_from_data(editor.data);editor.water_view.reset(editor.data);editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
		var data_hash:String=JSON.stringify(editor.data.serialize(),"",true,true).sha256_text()
		for name:String in ["before","after"]:
			variant(name)
			for angle:String in ["whole","reverse","close"]:
				_frame(Vector2(-10,-5) if angle=="close" else Vector2(-2,-1),13 if angle=="close" else 32,196 if angle=="reverse" else 16,30)
				await _capture("%d_%s_%s"%[layout[0],name,angle],.29)
			if layout[0]==7301:
				_frame(Vector2(-8,6),10,16,20);await _capture("7301_"+name+"_low_grass",.29)
				_frame(Vector2(-2,-1),32,16,30);await _capture("7301_"+name+"_night",0.0)
			invariants.append({"seed":layout[0],"variant":name,"data":data_hash,"data_unchanged":data_hash==JSON.stringify(editor.data.serialize(),"",true,true).sha256_text(),"water":editor.water_view.published_volume,"draw_msaa":viewport.msaa_3d,"scale":viewport.scaling_3d_scale})
	var report:Dictionary={"source_sha256":initial_sources,"sources_unchanged":initial_sources==_source_hashes(),"captures":captures,"invariants":invariants,"phase":PHASE,"errors":errors,"notes":"Same live scene; before=task-start grass LOD+4xMSAA+8192 shadow, after=current grass LOD+2xMSAA+4096 shadow; both native2560x1440, no scaling. Geometry/palette/light/water shared. Actual Godot output, not concepts."}
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("PAIRS ",captures.size()," errors ",errors)
	editor.free();viewport.queue_free();quit(1 if not errors.is_empty() else 0)
