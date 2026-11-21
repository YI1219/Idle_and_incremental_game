extends "res://tools/art/capture_lookdev.gd"
func bed_signature()->int:
	var values:Dictionary={}
	for cell:Vector2i in editor.data.cells:
		values[cell]=[editor.data.cells[cell].height,editor.data.cells[cell].water]
	return hash(values)
func run()->void:
	if not _read_options():quit(1);return
	var sources:Dictionary=_source_hashes()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):
		push_error("Select a new evidence directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.process_mode=Node.PROCESS_MODE_DISABLED
	var key:=InputEventKey.new();key.keycode=KEY_F11;key.pressed=true
	f11_handled=editor.gameplay.handle_unhandled_input(key)
	editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,editor.gameplay.wallpaper_mode)
	_freeze_node(editor)
	var initial:float=editor.water_view.published_volume
	var geometry:int=bed_signature()
	var samples:Array[Dictionary]=[]
	var elapsed:float=0.0
	for target:float in [0.0,10.0,60.0]:
		while elapsed<target-.000001:
			editor.water_view.tick(.1)
			editor.water_view.flush()
			elapsed+=.1
			if roundi(elapsed*10)%10==0:await process_frame
		var balance:float=editor.water_view.published_volume+editor.water_view.published_discharged_volume-initial
		if absf(balance)>.00000001:errors.append("Water balance error at "+str(target))
		if bed_signature()!=geometry:errors.append("Fluid changed terrain geometry")
		var sample:Dictionary={"seconds":target,"volume":editor.water_view.published_volume,"discharged":editor.water_view.published_discharged_volume,"balance_error":balance,"basins":[],"active_falls":editor.water_view.fall_veils.size()}
		for basin:Dictionary in editor.water_view.published_basins:sample.basins.append({"height":basin.height,"volume":basin.volume,"cells":basin.cells.size()})
		samples.append(sample)
		_frame(Vector2(-2,-1),32,16,30)
		await _capture("water_%03ds_whole"%roundi(target),.29)
		_frame(Vector2(3,.8),7,67,36);editor.camera.position.y+=2.5
		await _capture("water_%03ds_outlet"%roundi(target),.29)
		print("WATER EVOLUTION ",target,"s ",sample.volume," retained; ",sample.discharged," discharged")
	var report:Dictionary={"scene":"scenes/terrain_editor.tscn","resolution":[SIZE.x,SIZE.y],"seed":7301,"preset":0,"f11":f11_handled,"initial_volume":initial,"geometry_unchanged":bed_signature()==geometry,"no_source":true,"samples":samples,"captures":captures,"errors":errors,"valid":errors.is_empty(),"method":"production water_view .1-second ticks and flush; still phase1.25; accelerated offline sampling, not wall-clock video"}
	report["source_sha256"]=sources
	report["sources_unchanged"]=sources==_source_hashes()
	if not report.sources_unchanged:
		errors.append("Production source changed during capture")
		report.valid=false
	FileAccess.open(output.path_join("water_evolution.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	viewport.remove_child(editor);editor.free();viewport.queue_free()
	quit(0 if errors.is_empty() else 1)
