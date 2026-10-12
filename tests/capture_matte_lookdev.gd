extends "res://tests/capture_rim_round.gd"
## Runtime stills for the matte grass and lighting pass.
func capture(name:String)->void:
	for i in 8:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error:=viewport.get_texture().get_image().save_png(OUT+name+".png")
	captures.append({"file":name+".png","error":error,"position":str(editor.camera.position),"rotation":str(editor.camera.rotation_degrees)})
func run()->void:
	var args:=OS.get_cmdline_user_args()
	OUT="res://art/review/terrain_fidelity/2026-10-12/matte_lookdev/"
	var tag:="after" if args.is_empty() else args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
	editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
	publish()
	frame(Vector2(0,-1),21.0,16.0,27.0);await capture(tag+"_default")
	frame(Vector2(0,-1),29.0,16.0,24.0);await capture(tag+"_distant")
	frame(Vector2(-12,3),8.2,16.0,27.0);await capture(tag+"_rim")
	editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(tag+"_pond")
	editor.camera.position=Vector3(-16.2,4.35,1.2)
	editor.camera.look_at(Vector3(-13.4,3.52,-0.6))
	await capture(tag+"_grass")
	print("LOOK CAPTURES: ",tag," ",captures.size()," errors ",captures," adapter ",RenderingServer.get_video_adapter_name())
	quit()
