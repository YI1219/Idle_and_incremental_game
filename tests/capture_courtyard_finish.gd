extends "res://tests/capture_rim_round.gd"
func run()->void:
 var args:=OS.get_cmdline_user_args()
 var tag:="after" if args.is_empty() else args[0]
 OUT="res://art/review/terrain_fidelity/2026-10-14/courtyard_finish/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 frame(Vector2(-9,-7),13.5,16,34);await capture(tag+"_courtyard")
 frame(Vector2(0,-1),21,16,27);await capture(tag+"_overview")
 if args.has("camera"):
  frame(Vector2(-8,-7),12.3,-18,32);await capture(tag+"_camera_a")
  frame(Vector2(-8,-7),14.5,-18,32);await capture(tag+"_camera_b")
  frame(Vector2(-7,-4),16.5,16,32);await capture(tag+"_camera_c")
 if not args.has("quick"):
  frame(Vector2(0,-1),29,16,24);await capture(tag+"_distant")
  editor.camera.position=Vector3(-10,7,3);editor.camera.look_at(Vector3(-12,3.5,0));await capture(tag+"_ground")
  editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(tag+"_shore")
  frame(Vector2(-12,3),7,16,30);await capture(tag+"_rim")
  frame(Vector2(0,-1),21,-104,30);await capture(tag+"_reverse")
  editor.camera.position=Vector3(12,-14,21);editor.camera.look_at(Vector3(-2,-1,0));await capture(tag+"_bottom")
 var file:=FileAccess.open(OUT+tag+"_captures.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source":"Godot runtime","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1671,941],"captures":captures},"\t"))
 print("COURTYARD CAPTURES: ",tag," ",captures.size())
 quit()
