extends "res://tests/capture_rim_round.gd"
## Fixed visual acceptance views; all pixels are from the runtime renderer.
func run()->void:
 var args:=OS.get_cmdline_user_args()
 OUT="res://art/review/terrain_fidelity/2026-10-11/unified_bottom/"
 var tag:="after" if args.is_empty() else args[0]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 await capture(tag+"_default")
 frame(Vector2(-12,3),9.0,16.0,27.0);await capture(tag+"_rim_upper_front")
 editor.camera.position=Vector3(22,-2.4,15.2);editor.camera.look_at(Vector3(9,-.2,5));await capture(tag+"_underside")
 editor.camera.position=Vector3(12,-14,21);editor.camera.look_at(Vector3(-2,-1,0));await capture(tag+"_underside_bottom")
 editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(tag+"_pond_shore")
 if args.has("orbit"):
  for yaw in [-164,-104,-44,16,76,136]:
   frame(Vector2(0,-1),21,float(yaw),27);await capture(tag+"_orbit_"+str(yaw))
  for yaw in [-120,-60,0,60,120,180]:
   var angle:=deg_to_rad(float(yaw))
   editor.camera.position=Vector3(sin(angle)*32,-12,cos(angle)*32)
   editor.camera.look_at(Vector3(0,-1,0));await capture(tag+"_low_orbit_"+str(yaw))
 var file:=FileAccess.open(OUT+tag+"_captures.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source":"Godot runtime","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1671,941],"captures":captures},"\t"))
 print("GOAL CAPTURES: ",tag," ",captures.size())
 quit()
