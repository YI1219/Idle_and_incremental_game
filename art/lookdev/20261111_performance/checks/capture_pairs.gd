extends "res://tools/art/capture_lookdev.gd"
const Before=preload("res://art/lookdev/20261111_performance/checks/water_renderer_before.gd")
const After=preload("res://scripts/terrain_editor/water_renderer.gd")
func run() -> void:
	output="res://art/lookdev/20261111_performance/pairs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
	editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.renderer.animate_edits=false
	editor.set_native_preview(true);Engine.max_fps=0
	editor.water_view.free()
	editor.gameplay.set_wallpaper_mode(true)
	editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
	_freeze_node(editor)
	var source_before: Dictionary=_source_hashes()
	var rows:Array[Dictionary]=[]
	for layout:Array in [[7301,0],[2104,0],[4242,1],[913,2]]:
		editor.data.seed=layout[0];editor.data.make_preset(layout[1]);editor.renderer.rebuild_all();editor.motes.rebuild_from_data(editor.data)
		_freeze_node(editor)
		var original: Dictionary=editor.data.cells.duplicate(true)
		for variant:String in ["before","after"]:
			editor.data.cells=original.duplicate(true)
			var water:Node3D=Before.new() if variant=="before" else After.new()
			editor.add_child(water);water.configure(editor.data,editor.renderer)
			for i:int in 10:water.tick(.1);water.flush()
			var data_hash:String=JSON.stringify(editor.data.serialize(),"",true,true).sha256_text()
			for angle:String in ["whole","reverse"]:
				_frame(Vector2(-2,-1),32,16 if angle=="whole" else 196,30)
				var label:String="%d_%s_%s"%[layout[0],variant,angle]
				await _capture(label,.29)
				rows.append({"file":label+".png","data":data_hash,"volume":water.published_volume})
			if layout[0]==7301:
				_frame(Vector2(-10,-5),13,16,30)
				await _capture("7301_"+variant+"_close",.29)
				_frame(Vector2(-2,-1),32,16,30)
				await _capture("7301_"+variant+"_night",0.0)
			water.free()
	var report: Dictionary={"captures":captures,"rows":rows,"sources_unchanged":source_before==_source_hashes(),"phase":PHASE,"native_size":[SIZE.x,SIZE.y],"water_simulated_seconds":1.0,"errors":errors,"notes":"Same live scene; only water renderer switches between task-start snapshot and current. All other geometry/material/light sources shared. F11 production UI state; native 4x MSAA."}
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PAIRS ",captures.size()," errors ",errors," sources_unchanged=",report.sources_unchanged)
	editor.free();viewport.queue_free();quit(1 if not errors.is_empty() else 0)
