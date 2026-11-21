extends "res://art/lookdev/20261112_fps/checks/ablation.gd"
var old_mesh: ArrayMesh
var new_mesh: ArrayMesh
func set_variant(name: String) -> void:
	for node:Node in editor.find_children("grass_blades","MultiMeshInstance3D",true,false):node.multimesh.mesh=new_mesh if name in ["grass_only","balanced"] else old_mesh
	viewport.msaa_3d=Viewport.MSAA_2X if name in ["settings_only","balanced"] else Viewport.MSAA_4X
	RenderingServer.directional_shadow_atlas_set_size(4096 if name in ["settings_only","balanced"] else 8192,true)
func run()->void:
	output="res://art/lookdev/20261112_fps/checks"
	old_mesh=load("res://art/lookdev/20261112_fps/checks/grass_field_before.gd").clump_mesh()
	new_mesh=load("res://scripts/terrain_editor/grass_field.gd").clump_mesh()
	viewport=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
	editor.set_native_preview(true);editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
	for i:int in 40:RenderingServer.force_draw(false);await process_frame
	for size:Vector2i in [Vector2i(2560,1440),Vector2i(3840,2160)]:
		for name:String in ["before","grass_only","settings_only","balanced","before_repeat","balanced"]:
			set_variant(name);await sample(name,size)
	FileAccess.open(output.path_join("candidate_probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"samples":rows,"method":"fixed BASE_A,phase1.25,water0.1s;15 warmup+50 explicit draw frames;native pixels/no cap/no capture IO;old/new same live scene"},"\t"))
	editor.free();viewport.queue_free();quit()
