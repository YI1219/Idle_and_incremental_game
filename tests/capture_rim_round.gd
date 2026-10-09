extends SceneTree
## Close rim views and a terrain-edit before/after in the actual runtime scene.
## Usage: godot --path . -s res://tests/capture_rim_round.gd -- <tag> [out=<review dir>]
## The edit is applied through TerrainData's brush/undo API and published by
## the scene's own TerrainRenderer, as an editor stroke would be.
var OUT := "res://art/review/terrain_fidelity/2026-10-08/round5/"
var viewport:SubViewport
var editor:Node3D
var captures:Array=[]
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
	for i in 30:await process_frame
	await RenderingServer.frame_post_draw
	var error:=viewport.get_texture().get_image().save_png(OUT+name+".png")
	captures.append({"file":name+".png","error":error,"position":str(editor.camera.position),"rotation":str(editor.camera.rotation_degrees),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
func frame(center:Vector2,height:float,yaw:float,pitch:float)->void:
	var camera=editor.camera
	camera._center_goal=center;camera.height_goal=height;camera._yaw_goal=yaw;camera._pitch_goal=pitch
	camera._center=center;camera._height=height;camera._yaw=yaw;camera._pitch=pitch
	camera.advance(0.0)
func publish()->void:
	while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
func run()->void:
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("out="):OUT="res://art/review/terrain_fidelity/"+arg.trim_prefix("out=")+"/"
	var tag:="after" if args.is_empty() or args[0].begins_with("out=") else args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport=SubViewport.new()
	viewport.size=Vector2i(1671,941)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
	# Close views of the rim at the gameplay pitch.
	frame(Vector2(-12,3),9.0,16.0,27.0)
	await capture(tag+"_rim_upper_front")
	frame(Vector2(14,7),9.0,16.0,27.0)
	await capture(tag+"_rim_lower_right")
	frame(Vector2(-3,2),9.0,-30.0,30.0)
	await capture(tag+"_rim_terrace_step")
	# Low camera outside the lower lobe, looking up at the foot of the wall.
	editor.camera.position=Vector3(22.0,-3.2,16.5)
	editor.camera.look_at(Vector3(8.5,-1.2,4.5))
	await capture(tag+"_underside")
	# Expand the lower terrace's dry right edge, raise part of it, then undo.
	frame(Vector2(15.5,4.0),13.0,48.0,30.0)
	await capture(tag+"_edit_0_before")
	var data=editor.data
	data.begin_stroke();data.apply_brush(Vector2(19.2,4.6),2.8,"expand",false,1.5,3);data.end_stroke()
	publish()
	await capture(tag+"_edit_1_expanded")
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	publish()
	await capture(tag+"_edit_2_raised")
	data.undo();data.undo();data.undo()
	publish()
	await capture(tag+"_edit_3_undone")
	var file:=FileAccess.open(OUT+tag+"_rim.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1671,941],"captures":captures},"\t"))
	print("RIM CAPTURES: ",JSON.stringify(captures))
	quit()
